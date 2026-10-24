--!strict
--[[
	BossService.luau
	World bosses, dungeon bosses and the Elder Veyl operation.

	This service is the Roblox-facing half of a boss encounter. ALL of the
	rules live in the pure state machine at
	src/shared/Combat/BossEncounter.luau; this module owns the actors, applies
	the events the machine emits, and cleans up afterwards.

	The split is deliberate: boss defeats have to be provable, and a pure
	machine can be tested headlessly (see tests/spec/boss_encounter_spec).

	What this service is responsible for:
	  * creating and destroying the encounter per boss id
	  * registering the boss with CombatService so player weapons can hit it
	  * updating participant distances from the authoritative player positions
	  * applying attack and detonation damage to real characters
	  * granting rewards exactly once (the machine latches this)
	  * disconnecting everything and removing temporary objects on cleanup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Bosses = require(Shared.Config.BossConfig)
local Loot = require(Shared.Config.LootConfig)
local BossEncounter = require(Shared.Combat.BossEncounter)
local StatusEffects = require(Shared.Combat.StatusEffects)
local Rng = require(Shared.Utilities.Rng)

local BossService = {
	Name = "BossService",
}

-- Participants are keyed by player so Roblox objects never enter the pure
-- machine; the machine only ever sees string ids.
local encounters: { [string]: any } = {}
local playerToEncounter: { [Player]: string } = {}
local encounterPlayers: { [string]: { Player } } = {}
local damageables: { [string]: any } = {}
local nextEncounterId = 0
local services: any = nil
local rng = Rng.new(os.time())

local function random01(): number
	return rng:Next()
end

local function now(): number
	return os.clock()
end

local function participantId(player: Player): string
	return string.format("p%d", player.UserId)
end

function BossService.Init(svc: any)
	services = svc
end

function BossService.Start(svc: any)
	services = svc
	local Network = services.NetworkService

	Network.On(Remotes.RequestBossInfo.name, function(player, args)
		local id = tostring(args[1])
		local encounter = encounters[id]
		if not encounter then
			return nil
		end
		BossService._registerPlayer(id, player)
		return encounter:Snapshot()
	end)

	-- Bosses tick on the fixed server cadence.
	task.spawn(function()
		while true do
			task.wait(1 / math.max(1, Limits.Combat.ServerTickRateHz))
			BossService.Tick()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function BossService.StartEncounter(bossId: string, context: { regionId: string?, dungeonId: string?, kind: string? }?): any?
	for _, existing in encounters do
		if existing.bossId == bossId and not existing:IsTerminal() then
			return existing
		end
	end

	local encounter = BossEncounter.new(bossId, {
		random = random01,
		now = now(),
	})
	if not encounter then
		Logger.Warn("BossService", string.format("unknown boss %s", tostring(bossId)))
		return nil
	end

	nextEncounterId += 1
	local id = string.format("enc_%s_%d", bossId, nextEncounterId)
	encounter.id = id
	encounter.regionId = context and context.regionId or encounter.def.regionId
	encounter.dungeonId = context and context.dungeonId or nil
	encounter.kind = context and context.kind or "World"

	encounters[id] = encounter
	encounterPlayers[id] = {}

	BossService._registerDamageable(id, encounter)

	services.NetworkService.FireAll(Remotes.BossStateUpdated.name, encounter:Snapshot())
	Logger.Info("BossService", string.format("started %s (%s)", id, bossId))
	return encounter
end

-- Exposes the boss to CombatService so player weapons can resolve hits.
function BossService._registerDamageable(id: string, encounter: any)
	local def = encounter.def
	local damageable = {
		id = id,
		kind = "Boss",
		position = nil,
		defense = {
			armor = def.armor,
			resistances = def.resistances,
			damageMultiplier = encounter:EffectiveDamageMultiplier(nil, false),
			defenseState = encounter:EffectiveDefenseState(),
			shield = encounter.shield,
			level = def.tier or 1,
		},
		statusEffects = StatusEffects.New(),
		crowdControlResistance = (encounter:Phase() and encounter:Phase().crowdControlResistance) or 0,
		applyDamage = function(amount: number, source: Player?, outcome: any)
			BossService.ApplyDamage(id, amount, source, outcome)
		end,
	}
	damageables[id] = damageable
	services.CombatService.RegisterDamageable(id, damageable)
end

function BossService._registerPlayer(id: string, player: Player)
	local encounter = encounters[id]
	if not encounter then
		return
	end
	local pid = participantId(player)
	if not encounter.participants[pid] then
		encounter:AddParticipant(pid, 0)
	end
	if not table.find(encounterPlayers[id] or {}, player) then
		table.insert(encounterPlayers[id], player)
	end
	playerToEncounter[player] = id
	local state = services.PlayerService.Get(player)
	if state then
		state.inBossEncounter = true
	end
end

-- ---------------------------------------------------------------------------
-- Damage
-- ---------------------------------------------------------------------------

function BossService.ApplyDamage(encounterId: string, amount: number, source: Player?, outcome: any?)
	local encounter = encounters[encounterId]
	if not encounter then
		return
	end

	local damageType = outcome and outcome.damageType or nil
	local isArea = outcome and outcome.isAreaDamage or false

	if source then
		BossService._registerPlayer(encounterId, source)
	end

	local removed, _ = encounter:ApplyDamage(amount, source and participantId(source) or nil, damageType, isArea)
	-- Events are buffered on the encounter and delivered by Tick, so nothing
	-- is lost here.
	if removed > 0 then
		services.NetworkService.FireAll(Remotes.TargetHealthUpdated.name, {
			targetId = encounterId,
			kind = "Boss",
			health = encounter.health,
			maxHealth = encounter.maxHealth,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Tick: drive the machine and apply whatever it emits
-- ---------------------------------------------------------------------------

function BossService.Tick()
	for id, encounter in encounters do
		if encounter:IsClean() then
			continue
		end

		BossService._updateDistances(id, encounter)

		local events = encounter:Tick(1 / math.max(1, Limits.Combat.ServerTickRateHz))
		if #events > 0 then
			BossService._handleEvents(id, encounter, events)
		end

		if encounter:IsTerminal() and not encounter.cleanupAcknowledged then
			BossService._cleanup(id, encounter)
		end
	end
end

function BossService._updateDistances(id: string, encounter: any)
	local players = encounterPlayers[id]
	if not players then
		return
	end
	local position = damageables[id] and damageables[id].position
	if not position then
		return
	end
	for _, player in players do
		local playerPosition = services.WorldService and services.WorldService.PositionOf(player)
		if playerPosition then
			encounter:SetParticipantDistance(participantId(player), (playerPosition - position).Magnitude)
		end
	end
end

function BossService._handleEvents(id: string, encounter: any, events: { any })
	for _, event in events do
		local kind = event.kind

		if kind == "PhaseChanged" then
			BossService._refreshDamageable(id, encounter)
			services.NetworkService.FireAll(Remotes.BossPhaseChanged.name, {
				id = id,
				bossId = event.bossId,
				phaseIndex = event.phaseIndex,
				previousPhaseIndex = event.previousPhaseIndex,
				phaseName = event.phaseName,
				defenseState = event.defenseState,
				shield = event.shield,
			})
			Logger.Info(
				"BossService",
				string.format("%s entered phase %d (%s) via %s", id, event.phaseIndex, tostring(event.phaseName), tostring(event.reason))
			)

		elseif kind == "DetonationStarted" then
			-- Telegraph: every client sees the countdown before it lands.
			services.NetworkService.FireAll(Remotes.Cinematic.name, {
				kind = "BossDetonation",
				bossId = event.bossId,
				countdownSeconds = event.countdownSeconds,
			})
			services.NetworkService.FireAll(Remotes.Announcement.name, {
				kind = "Warning",
				title = "Celestial Detonation",
				body = string.format("Survive the next %.0f seconds.", event.countdownSeconds),
			})

		elseif kind == "DetonationResolved" then
			BossService._applyDetonation(id, encounter, event)

		elseif kind == "BossDefeated" then
			BossService._onDefeated(id, encounter, event)

		elseif kind == "EncounterWiped" then
			BossService._onWiped(id, encounter, event)

		elseif kind == "AttackStarted" then
			services.NetworkService.FireAll(Remotes.PlayEffect.name, {
				kind = "BossAttack",
				bossId = event.bossId,
				attackId = event.attackId,
				telegraph = event.telegraph,
				radius = event.radius,
			})

		elseif kind == "Vanished" or kind == "Reappeared" or kind == "GlitchToggled" then
			services.NetworkService.FireAll(Remotes.BossStateUpdated.name, encounter:Snapshot())

		elseif kind == "ShieldAbsorbed" or kind == "PhaseStallDecay" then
			services.NetworkService.FireAll(Remotes.BossStateUpdated.name, encounter:Snapshot())
		end
	end
end

function BossService._refreshDamageable(id: string, encounter: any)
	local damageable = damageables[id]
	if not damageable then
		return
	end
	damageable.defense.damageMultiplier = encounter:EffectiveDamageMultiplier(nil, false)
	damageable.defense.defenseState = encounter:EffectiveDefenseState()
	damageable.defense.shield = encounter.shield
	local phase = encounter:Phase()
	damageable.crowdControlResistance = phase and phase.crowdControlResistance or 0
end

-- The Light Samurai's final explosion. This is the only place the blast
-- damages players, and it is driven by the machine so it fires once.
function BossService._applyDetonation(id: string, encounter: any, event: any)
	local players = encounterPlayers[id] or {}
	local byId: { [string]: Player } = {}
	for _, player in players do
		byId[participantId(player)] = player
	end

	for _, pid in event.targets do
		local player = byId[pid]
		if player then
			services.PlayerService.ApplyDamage(player, event.damage, "boss_detonation")
			services.NetworkService.Fire(player, Remotes.DamageFeedback.name, {
				source = id,
				damage = event.damage,
				kind = "Detonation",
			})
		end
	end

	services.NetworkService.FireAll(Remotes.PlayEffect.name, {
		kind = "Detonation",
		bossId = event.bossId,
		radiusStuds = event.radiusStuds,
	})
end

function BossService._onDefeated(id: string, encounter: any, event: any)
	-- Reward latch: even if this event were replayed, rewards fire once.
	if not encounter:ClaimRewards() then
		return
	end

	local boss = encounter.def
	for _, pid in event.participants do
		local player = BossService._playerFor(id, pid)
		if player then
			local rolls = Loot.Roll(boss.rewardTableId, random01, 0)
			for _, reward in rolls do
				services.InventoryService.AddItem(player, reward.id, reward.quantity)
			end
			services.ProgressionService.AwardExperience(player, encounter.kind == "World" and "world_boss" or "dungeon_boss", nil)
			services.NetworkService.Fire(player, Remotes.RewardSummary.name, {
				source = boss.displayName,
				rewards = rolls,
			})
		end
	end

	services.NetworkService.FireAll(Remotes.BossDefeated.name, {
		id = id,
		bossId = encounter.bossId,
		cause = event.cause,
		durationSeconds = event.durationSeconds,
	})
	Logger.Info(
		"BossService",
		string.format("%s defeated in %.1fs (%s)", encounter.bossId, event.durationSeconds, tostring(event.cause))
	)

	if encounter.dungeonId and services.DungeonService then
		services.DungeonService.OnStageBossDefeated(encounter.dungeonId)
	end
end

function BossService._onWiped(id: string, encounter: any, event: any)
	-- A wipe is a loss, not a defeat. The boss is scheduled to return rather
	-- than being left alive in its final phase.
	Logger.Info("BossService", string.format("%s wiped the raid on %s", id, encounter.bossId))
	services.NetworkService.FireAll(Remotes.DefeatSummary.name, {
		bossId = encounter.bossId,
		respawnSeconds = event.respawnSeconds,
	})
end

function BossService._playerFor(id: string, pid: string): Player?
	for _, player in encounterPlayers[id] or {} do
		if participantId(player) == pid then
			return player
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Cleanup: death stops attacks, listeners are disconnected and temporary
-- objects are removed. Runs exactly once per encounter.
-- ---------------------------------------------------------------------------

function BossService._cleanup(id: string, encounter: any)
	BossService._unregisterDamageable(id)

	for _, player in encounterPlayers[id] or {} do
		local state = services.PlayerService.Get(player)
		if state then
			state.inBossEncounter = false
		end
		playerToEncounter[player] = nil
	end
	encounterPlayers[id] = nil

	encounter:AcknowledgeCleanup()

	services.NetworkService.FireAll(Remotes.BossStateUpdated.name, encounter:Snapshot())

	-- Remove the encounter after its respawn window.
	task.delay(Bosses.RespawnSeconds(encounter.bossId), function()
		if encounters[id] == encounter then
			encounters[id] = nil
		end
	end)
end

function BossService._unregisterDamageable(id: string)
	if not damageables[id] then
		return
	end
	services.CombatService.UnregisterDamageable(id)
	damageables[id] = nil
end

-- ---------------------------------------------------------------------------
-- Queries and helpers
-- ---------------------------------------------------------------------------

function BossService.Encounter(id: string)
	return encounters[id]
end

function BossService.EncounterOf(player: Player)
	local id = playerToEncounter[player]
	return id and encounters[id] or nil
end

function BossService.ActiveEncounters(): { any }
	local out = {}
	for _, encounter in encounters do
		if not encounter:IsTerminal() then
			table.insert(out, encounter)
		end
	end
	return out
end

function BossService.StartWorldBoss(regionId: string)
	local boss = Bosses.WorldBossForRegion(regionId)
	if not boss then
		return nil
	end
	return BossService.StartEncounter(boss.id, { regionId = regionId, kind = "World" })
end

function BossService.StartDungeonBoss(dungeonId: string, stageIndex: number)
	local Dungeons = require(Shared.Config.DungeonConfig)
	local dungeon = Dungeons:Get(dungeonId)
	if not dungeon then
		return nil
	end
	local stage = dungeon.stages and dungeon.stages[stageIndex]
	if not stage or not stage.bossId then
		return nil
	end
	return BossService.StartEncounter(stage.bossId, { dungeonId = dungeonId, kind = "Dungeon" })
end

function BossService.OnPlayerRemoving(player: Player)
	local id = playerToEncounter[player]
	if id and encounters[id] then
		encounters[id]:SetParticipantAlive(participantId(player), false)
	end
	playerToEncounter[player] = nil
end

return BossService
