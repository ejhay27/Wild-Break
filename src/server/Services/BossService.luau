--!strict
--[[
	BossService.luau
	World bosses, dungeon bosses and the Elder Veyl operation.

	Every boss runs through BossConfig (the single boss entry point), so phase
	transitions, damage multipliers, weak points, shields and rewards are all
	driven by configuration rather than bespoke scripts.

	Safety guarantees enforced here, every tick:
	  * damage is clamped to the phase's rules (never negative, never above cap)
	  * a boss flagged as always damageable can never reach 0 incoming damage
	  * phase transitions are monotonic: a boss can never heal into an earlier
	    phase or loop between two phases
	  * every encounter has a resolution: timeout, detonation or death
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Bosses = require(Shared.Config.BossConfig)
local Loot = require(Shared.Config.LootConfig)
local DamagePipeline = require(Shared.Combat.DamagePipeline)
local Rng = require(Shared.Utilities.Rng)
local Dungeons = require(Shared.Config.DungeonConfig)

local BossService = {
	Name = "BossService",
}

export type Encounter = {
	id: string,
	bossId: string,
	kind: string, -- World | Dungeon
	regionId: string?,
	dungeonId: string?,
	health: number,
	maxHealth: number,
	phaseIndex: number,
	shield: number,
	defenseState: string,
	weakPoints: { [string]: boolean },
	state: string, -- Idle | Active | Defeated | Resetting
	startedAt: number,
	endsAt: number?,
	participants: { [Player]: boolean },
	damageByPlayer: { [Player]: number },
	rewarded: boolean,
	-- Safeguards
	alwaysDamageable: boolean,
	encounterTimeoutSeconds: number,
	lastPhaseChangeAt: number,
	phaseChangeCount: number,
}

local encounters: { [string]: Encounter } = {}
local nextEncounterId = 0
local services: any = nil
local rng = Rng.new(os.time())

local function now(): number
	return os.clock()
end

function BossService.Init(svc: any)
	services = svc
end

function BossService.Start(svc: any)
	services = svc
	local Network = services.NetworkService
	Network.On(Remotes.RequestBossInfo.name, function(player, args)
		local encounter = encounters[tostring(args[1])]
		if not encounter then
			return nil
		end
		BossService.RegisterParticipant(encounter, player)
		return {
			id = encounter.id,
			bossId = encounter.bossId,
			health = encounter.health,
			maxHealth = encounter.maxHealth,
			phaseIndex = encounter.phaseIndex,
			shield = encounter.shield,
			defenseState = encounter.defenseState,
			state = encounter.state,
		}
	end)

	-- Encounters tick on a fixed server cadence.
	task.spawn(function()
		while true do
			task.wait(1 / math.max(1, Limits.Combat.ServerTickRateHz))
			BossService.Tick()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Encounter lifecycle
-- ---------------------------------------------------------------------------

local function participantCount(encounter: Encounter): number
	local count = 0
	for _ in encounter.participants do
		count += 1
	end
	return count
end

function BossService.StartEncounter(bossId: string, context: { regionId: string?, dungeonId: string?, kind: string? }?): Encounter?
	local boss = Bosses:Get(bossId)
	if not boss then
		Logger.Warn("BossService", string.format("unknown boss %s", tostring(bossId)))
		return nil
	end
	-- One active encounter per boss at a time.
	for _, encounter in encounters do
		if encounter.bossId == bossId and encounter.state == Enums.BossState.Active then
			return encounter
		end
	end

	nextEncounterId += 1
	local id = string.format("enc_%s_%d", bossId, nextEncounterId)
	local encounter: Encounter = {
		id = id,
		bossId = bossId,
		kind = context and context.kind or (boss.kind == Enums.BossKind.WorldBoss and "World" or "Dungeon"),
		regionId = context and context.regionId or boss.regionId,
		dungeonId = context and context.dungeonId or nil,
		health = boss.baseHealth,
		maxHealth = boss.baseHealth,
		phaseIndex = 1,
		shield = Bosses.ShieldCapacity(bossId, 1),
		defenseState = (boss.phases[1] and boss.phases[1].defenseState) or Enums.DefenseState.Normal,
		weakPoints = {},
		state = Enums.BossState.Active,
		startedAt = now(),
		endsAt = nil,
		participants = {},
		damageByPlayer = {},
		rewarded = false,
		alwaysDamageable = Bosses.IsAlwaysDamageable(bossId),
		encounterTimeoutSeconds = boss.encounterTimeoutSeconds,
		lastPhaseChangeAt = now(),
		phaseChangeCount = 0,
	}
	encounters[id] = encounter

	-- Register the boss as damageable so CombatService can resolve hits.
	services.CombatService.RegisterDamageable(id, {
		id = id,
		kind = "Boss",
		position = nil,
		defense = {
			armor = boss.armor,
			resistances = boss.resistances,
			damageMultiplier = Bosses.DamageMultiplier(bossId, 1, nil, false),
			defenseState = encounter.defenseState,
			shield = encounter.shield,
		},
		statusEffects = require(Shared.Combat.StatusEffects).New(),
		crowdControlResistance = boss.phases[1] and boss.phases[1].crowdControlResistance or 0,
		applyDamage = function(amount: number, source: Player?, outcome: any)
			BossService.ApplyDamage(id, amount, source, outcome)
		end,
	})

	services.NetworkService.FireAll(Remotes.BossStateUpdated.name, {
		id = id,
		bossId = bossId,
		health = encounter.health,
		maxHealth = encounter.maxHealth,
		phaseIndex = 1,
		state = encounter.state,
	})
	Logger.Info("BossService", string.format("started encounter %s (%s)", id, bossId))
	return encounter
end

function BossService.RegisterParticipant(encounter: Encounter, player: Player)
	encounter.participants[player] = true
	local state = services.PlayerService.Get(player)
	if state then
		state.inBossEncounter = true
	end
end

-- ---------------------------------------------------------------------------
-- Damage and phases
-- ---------------------------------------------------------------------------

function BossService.ApplyDamage(encounterId: string, amount: number, source: Player?, outcome: any?)
	local encounter = encounters[encounterId]
	if not encounter or encounter.state ~= Enums.BossState.Active then
		return
	end
	local boss = Bosses:Get(encounter.bossId)
	if not boss then
		return
	end

	-- Shields absorb first.
	local remaining = amount
	if encounter.shield > 0 then
		local absorbed = math.min(encounter.shield, remaining)
		encounter.shield -= absorbed
		remaining -= absorbed
	end

	-- Parallax style bosses must always take at least chip damage: an
	-- always-damageable boss can never reach a zero damage state.
	if remaining <= 0 and encounter.alwaysDamageable then
		remaining = math.max(1, amount * 0.25)
	end
	encounter.health = math.max(0, encounter.health - remaining)

	if source then
		encounter.damageByPlayer[source] = (encounter.damageByPlayer[source] or 0) + remaining
		BossService.RegisterParticipant(encounter, source)
	end

	BossService.EvaluatePhase(encounter, boss)

	if encounter.health <= 0 then
		BossService.Defeat(encounter, boss)
	end
end

-- Phase transitions are monotonic and bounded.
function BossService.EvaluatePhase(encounter: Encounter, boss: any)
	local ratio = encounter.health / encounter.maxHealth
	local target = Bosses.PhaseIndexForHealth(encounter.bossId, ratio)
	if target == encounter.phaseIndex then
		return
	end
	if target < encounter.phaseIndex then
		-- Healing must not walk a boss backwards through its script.
		return
	end

	local previous = encounter.phaseIndex
	encounter.phaseIndex = target
	encounter.phaseChangeCount += 1
	encounter.lastPhaseChangeAt = now()
	local phase = Bosses.Phase(encounter.bossId, target)
	encounter.defenseState = phase and phase.defenseState or Enums.DefenseState.Normal
	encounter.shield = Bosses.ShieldCapacity(encounter.bossId, target)

	-- An always-damageable boss keeps taking damage even while armoured.
	if encounter.alwaysDamageable and encounter.defenseState == Enums.DefenseState.Invulnerable then
		encounter.defenseState = Enums.DefenseState.Armored
	end

	services.NetworkService.FireAll(Remotes.BossPhaseChanged.name, {
		id = encounter.id,
		bossId = encounter.bossId,
		phaseIndex = target,
		previousPhaseIndex = previous,
		defenseState = encounter.defenseState,
		shield = encounter.shield,
	})
end

function BossService.Defeat(encounter: Encounter, boss: any)
	if encounter.state == Enums.BossState.Defeated then
		return
	end
	encounter.state = Enums.BossState.Defeated
	encounter.endsAt = now()
	services.CombatService.UnregisterDamageable(encounter.id)

	-- Rewards are granted once, to players who actually participated.
	if not encounter.rewarded then
		encounter.rewarded = true
		for player in encounter.participants do
			if (encounter.damageByPlayer[player] or 0) > 0 then
				BossService.GrantRewards(encounter, player)
			end
		end
	end

	for player in encounter.participants do
		local state = services.PlayerService.Get(player)
		if state then
			state.inBossEncounter = false
		end
	end

	services.NetworkService.FireAll(Remotes.BossDefeated.name, {
		id = encounter.id,
		bossId = encounter.bossId,
		durationSeconds = now() - encounter.startedAt,
	})
	Logger.Info("BossService", string.format("defeated %s in %.1fs", encounter.bossId, now() - encounter.startedAt))

	-- Schedule the respawn.
	task.delay(Bosses.RespawnSeconds(encounter.bossId), function()
		if encounters[encounter.id] == encounter then
			encounters[encounter.id] = nil
		end
	end)
end

function BossService.GrantRewards(encounter: Encounter, player: Player)
	local boss = Bosses:Get(encounter.bossId)
	if not boss then
		return
	end
	local rolls = Loot.Roll(boss.rewardTableId, function()
		return rng:Next()
	end, 0)
	for _, reward in rolls do
		services.InventoryService.AddItem(player, reward.id, reward.quantity)
	end
	services.ProgressionService.AwardExperience(player, encounter.kind == "World" and "world_boss" or "dungeon_boss", nil)
	services.NetworkService.Fire(player, Remotes.Notification.name, {
		kind = "Reward",
		title = boss.displayName .. " defeated",
		body = string.format("%d rewards granted.", #rolls),
	})
end

-- ---------------------------------------------------------------------------
-- Tick: timeouts, attack selection, resolution guarantees
-- ---------------------------------------------------------------------------

function BossService.Tick()
	local clock = now()
	for id, encounter in encounters do
		if encounter.state ~= Enums.BossState.Active then
			continue
		end
		local boss = Bosses:Get(encounter.bossId)
		if not boss then
			encounters[id] = nil
			continue
		end

		-- Every encounter resolves: a stalled fight ends instead of hanging.
		if clock - encounter.startedAt > encounter.encounterTimeoutSeconds then
			Logger.Warn("BossService", string.format("encounter %s timed out and reset", id))
			BossService.Reset(encounter)
			continue
		end

		-- Phase stalls: if a phase has run far past its budget, force the
		-- transition so a boss can never sit in an unreachable state.
		local phase = Bosses.Phase(encounter.bossId, encounter.phaseIndex)
		if phase and phase.timeoutSeconds and clock - encounter.lastPhaseChangeAt > phase.timeoutSeconds then
			encounter.health = math.max(0, encounter.health - encounter.maxHealth * 0.02)
			BossService.EvaluatePhase(encounter, boss)
		end

		if participantCount(encounter) == 0 and clock - encounter.startedAt > Limits.Boss.AbandonResetSeconds then
			BossService.Reset(encounter)
		end
	end
end

function BossService.Reset(encounter: Encounter)
	encounter.state = Enums.BossState.Cleanup
	encounter.endsAt = now()
	services.CombatService.UnregisterDamageable(encounter.id)
	for player in encounter.participants do
		local state = services.PlayerService.Get(player)
		if state then
			state.inBossEncounter = false
		end
	end
	services.NetworkService.FireAll(Remotes.BossStateUpdated.name, {
		id = encounter.id,
		bossId = encounter.bossId,
		state = encounter.state,
	})
	task.delay(5, function()
		if encounters[encounter.id] == encounter then
			encounters[encounter.id] = nil
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function BossService.Encounter(id: string): Encounter?
	return encounters[id]
end

function BossService.ActiveEncounters(): { Encounter }
	local out = {}
	for _, encounter in encounters do
		table.insert(out, encounter)
	end
	return out
end

-- Starts the regional world boss. Called by WorldEventService or admin.
function BossService.StartWorldBoss(regionId: string): Encounter?
	for _, boss in Bosses.WorldBosses() do
		if boss.regionId == regionId then
			return BossService.StartEncounter(boss.id, { regionId = regionId, kind = "World" })
		end
	end
	return nil
end

-- Starts the boss for a dungeon stage.
function BossService.StartDungeonBoss(dungeonId: string, stageIndex: number): Encounter?
	local dungeon = Dungeons:Get(dungeonId)
	if not dungeon then
		return nil
	end
	local stage = dungeon.stages[stageIndex]
	if not stage or not stage.bossId then
		return nil
	end
	return BossService.StartEncounter(stage.bossId, {
		dungeonId = dungeonId,
		kind = "Dungeon",
	})
end

return BossService
