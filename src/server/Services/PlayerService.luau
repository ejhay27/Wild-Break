--!strict
--[[
	PlayerService.luau
	Join/leave lifecycle, the authoritative runtime state for each player,
	stamina, health, revive/down handling and the respawn flow.

	The server owns every number here. Clients receive snapshots and may
	request actions; they never set health, stamina or position directly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Profile = require(Shared.PlayerData.Profile)
local Movement = require(Shared.Config.MovementConfig)
local Deployment = require(Shared.Config.DeploymentConfig)

local PlayerService = {
	Name = "PlayerService",
}

export type RuntimeState = {
	userId: number,
	profile: any,
	health: number,
	maxHealth: number,
	stamina: number,
	maxStamina: number,
	alive: boolean,
	downed: boolean,
	downedUntil: number?,
	regionId: string?,
	inDungeon: boolean,
	inClanWar: boolean,
	inBossEncounter: boolean,
	deploymentPhase: string,
	lastValidatedPosition: Vector3?,
	lastValidatedAt: number,
	lastDamageAt: number,
	statusEffects: any,
	-- Server-side cooldown bookkeeping (abilityId -> readyAt).
	cooldowns: { [string]: number },
	-- Anti-cheat counters.
	positionViolations: number,
	sessionStartedAt: number,
}

local states: { [Player]: RuntimeState } = {}
local services: any = nil

local function now(): number
	return os.clock()
end

function PlayerService.Init(svc: any)
	services = svc
end

function PlayerService.Start(svc: any)
	services = svc

	Players.PlayerAdded:Connect(function(player)
		PlayerService.OnPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayerService.OnPlayerRemoving(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerService.OnPlayerAdded(player)
		end)
	end

	-- Heartbeat: regenerate stamina and out-of-combat health, tick status
	-- effects and expire cooldowns.
	game:GetService("RunService").Heartbeat:Connect(function(delta)
		PlayerService.Tick(delta)
	end)

	local Network = services.NetworkService
	Network.On(Remotes.RequestProfileData.name, function(player)
		local state = states[player]
		if not state then
			return nil
		end
		return {
			level = state.profile.level,
			experience = state.profile.experience,
			experienceTotal = state.profile.experienceTotal,
			sap = state.profile.sap,
			coin = state.profile.coin,
			unsaved = services.DataService.IsUnsaved(player),
			adminRevision = state.profile.adminRevision,
		}
	end)

	Network.On(Remotes.RequestMovementSkill.name, function(player, args)
		return PlayerService.RequestMovementSkill(player, args[1], args[2])
	end)
end

function PlayerService.Get(player: Player): RuntimeState?
	return states[player]
end

function PlayerService.Profile(player: Player): any
	local state = states[player]
	return state and state.profile or nil
end

function PlayerService.OnPlayerAdded(player: Player)
	local profile = services.DataService.Load(player)
	local maxHealth = Limits.Survival.MaxHealth

	local state: RuntimeState = {
		userId = player.UserId,
		profile = profile,
		health = maxHealth,
		maxHealth = maxHealth,
		stamina = Movement.Stamina.max,
		maxStamina = Movement.Stamina.max,
		alive = true,
		downed = false,
		downedUntil = nil,
		regionId = nil,
		inDungeon = false,
		inClanWar = false,
		inBossEncounter = false,
		deploymentPhase = Enums.DeployPhase.Idle,
		lastValidatedPosition = nil,
		lastValidatedAt = now(),
		lastDamageAt = 0,
		statusEffects = require(Shared.Combat.StatusEffects).New(),
		cooldowns = {},
		positionViolations = 0,
		sessionStartedAt = os.time(),
	}
	states[player] = state

	if services.DataService.IsUnsaved(player) then
		services.NetworkService.Fire(player, Remotes.Notification.name, {
			kind = "Warning",
			title = "Progress may not be saved",
			body = "The data store is unreachable right now. Your session is playable but progress will not be stored.",
		})
	end

	services.NetworkService.Fire(player, Remotes.PlayerProfileUpdated.name, {
		level = profile.level,
		experience = profile.experience,
		sap = profile.sap,
		coin = profile.coin,
	})
	services.NetworkService.Fire(player, Remotes.PlayerStateUpdated.name, PlayerService.Snapshot(player))
	Logger.Info("PlayerService", string.format("%s joined (level %d)", tostring(player.Name), profile.level))
end

function PlayerService.OnPlayerRemoving(player: Player)
	local state = states[player]
	if state then
		state.profile.playtimeSeconds += os.time() - state.sessionStartedAt
	end
	services.DataService.Release(player)
	states[player] = nil
end

function PlayerService.Snapshot(player: Player): { [string]: any }
	local state = states[player]
	if not state then
		return {}
	end
	return {
		health = state.health,
		maxHealth = state.maxHealth,
		stamina = state.stamina,
		maxStamina = state.maxStamina,
		alive = state.alive,
		downed = state.downed,
		regionId = state.regionId,
		inDungeon = state.inDungeon,
		inBossEncounter = state.inBossEncounter,
		deploymentPhase = state.deploymentPhase,
	}
end

-- ---------------------------------------------------------------------------
-- Health, damage, down and revive
-- ---------------------------------------------------------------------------

function PlayerService.ApplyDamage(player: Player, amount: number, source: string?): number
	local state = states[player]
	if not state or not state.alive then
		return 0
	end
	local applied = math.max(0, amount)
	state.health = math.max(0, state.health - applied)
	state.lastDamageAt = now()
	if state.health <= 0 then
		PlayerService.Down(player, source)
	end
	services.NetworkService.Fire(player, Remotes.PlayerStateUpdated.name, PlayerService.Snapshot(player))
	return applied
end

function PlayerService.Heal(player: Player, amount: number): number
	local state = states[player]
	if not state then
		return 0
	end
	local before = state.health
	state.health = math.min(state.maxHealth, state.health + math.max(0, amount))
	services.NetworkService.Fire(player, Remotes.PlayerStateUpdated.name, PlayerService.Snapshot(player))
	return state.health - before
end

-- Being downed is not death: a squad member can revive inside the window.
function PlayerService.Down(player: Player, source: string?)
	local state = states[player]
	if not state or state.downed then
		return
	end
	state.downed = true
	state.alive = false
	state.health = 0
	state.downedUntil = now() + Deployment.Respawn.downedBleedOutSeconds
	state.profile.deaths += 1
	Logger.Info("PlayerService", string.format("%s went down (%s)", tostring(player.Name), tostring(source)))
	-- Any live boss encounter has to learn about this immediately: a downed
	-- player is not an active participant.
	if services.BossService and services.BossService.OnPlayerDowned then
		services.BossService.OnPlayerDowned(player)
	end
	services.NetworkService.Fire(player, Remotes.CombatStateUpdated.name, { state = Enums.CombatState.Downed, source = source })
end

function PlayerService.Revive(player: Player, by: Player?): boolean
	local state = states[player]
	if not state or not state.downed then
		return false
	end
	state.downed = false
	state.alive = true
	state.downedUntil = nil
	state.health = math.max(1, math.floor(state.maxHealth * 0.35))
	if services.BossService and services.BossService.OnPlayerRevived then
		services.BossService.OnPlayerRevived(player)
	end
	services.NetworkService.Fire(player, Remotes.CombatStateUpdated.name, { state = Enums.CombatState.Alive, revivedBy = by and by.Name or nil })
	services.NetworkService.Fire(player, Remotes.PlayerStateUpdated.name, PlayerService.Snapshot(player))
	return true
end

-- Respawn always returns the player to the hub; they deploy again from there.
function PlayerService.Respawn(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.downed = false
	state.alive = true
	state.health = state.maxHealth
	state.stamina = Movement.Stamina.max
	state.downedUntil = nil
	state.regionId = nil
	state.inDungeon = false
	state.inBossEncounter = false
	state.deploymentPhase = Enums.DeployPhase.Idle
	state.statusEffects = require(Shared.Combat.StatusEffects).New()
	state.cooldowns = {}
	if services.BossService and services.BossService.OnPlayerRespawned then
		services.BossService.OnPlayerRespawned(player)
	end
	if services.WorldService and services.WorldService.ResetPosition then
		services.WorldService.ResetPosition(player)
	end
	-- Respawning has to put the character back in the world, not just reset
	-- the numbers.
	if services.SpawnService and services.SpawnService.RespawnAtHub then
		services.SpawnService.RespawnAtHub(player)
	end
	services.NetworkService.Fire(player, Remotes.PlayerStateUpdated.name, PlayerService.Snapshot(player))
end

-- ---------------------------------------------------------------------------
-- Movement skill requests (server simulated)
-- ---------------------------------------------------------------------------

function PlayerService.RequestMovementSkill(player: Player, skillId: string, direction: Vector3?): boolean
	local state = states[player]
	if not state or not state.alive then
		return false
	end
	local skill = Movement.Get(skillId)
	if not skill then
		return false
	end
	if not Movement.IsUnlocked(skillId, state.profile.level) then
		return false
	end
	if not Movement.CanAfford(skillId, state.stamina, state.profile.level) then
		return false
	end
	local readyAt = state.cooldowns["movement_" .. skillId] or 0
	if now() < readyAt then
		return false
	end

	state.stamina = math.max(0, state.stamina - skill.staminaCost)
	if skill.cooldownSeconds > 0 then
		state.cooldowns["movement_" .. skillId] = now() + skill.cooldownSeconds
	end

	services.NetworkService.Fire(player, Remotes.MovementResolved.name, {
		skillId = skillId,
		approved = true,
		stamina = state.stamina,
		direction = direction,
		serverSimulated = skill.serverSimulated,
	})
	return true
end

-- ---------------------------------------------------------------------------
-- Per-frame update
-- ---------------------------------------------------------------------------

function PlayerService.Tick(delta: number)
	local clock = now()
	for player, state in states do
		if not state.downed then
			-- Stamina regenerates after a short delay.
			if clock - state.lastDamageAt > Movement.Stamina.regenDelaySeconds then
				state.stamina = math.min(state.maxStamina, state.stamina + Movement.Stamina.regenPerSecond * delta)
			end
			-- Out-of-combat health regeneration.
			if clock - state.lastDamageAt > Limits.Survival.HealthRegenDelaySeconds then
				state.health = math.min(state.maxHealth, state.health + Limits.Survival.BaseHealthRegenPerSecond * delta)
			end
		elseif state.downedUntil and clock >= state.downedUntil then
			PlayerService.Respawn(player)
		end

		local status = require(Shared.Combat.StatusEffects)
		local tickResult = status.Tick(state.statusEffects, clock)
		for _, entry in tickResult.damage do
			PlayerService.ApplyDamage(player, entry.amount, "status_" .. entry.id)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Position validation (anti teleport)
-- ---------------------------------------------------------------------------

function PlayerService.ValidatePosition(player: Player, position: Vector3, seconds: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	if not state.lastValidatedPosition then
		state.lastValidatedPosition = position
		state.lastValidatedAt = now()
		return true
	end
	local previous = state.lastValidatedPosition :: Vector3
	local horizontal = math.sqrt((position.X - previous.X) ^ 2 + (position.Z - previous.Z) ^ 2)
	local vertical = math.abs(position.Y - previous.Y)
	if Movement.IsPlausibleMove(horizontal, seconds, vertical) then
		state.lastValidatedPosition = position
		state.lastValidatedAt = now()
		state.positionViolations = 0
		return true
	end
	state.positionViolations += 1
	if state.positionViolations >= Movement.Validation.graceViolations then
		Logger.Warn("PlayerService", string.format("%s exceeded the movement validation budget", tostring(player.Name)))
		state.positionViolations = 0
		return false
	end
	return true
end

return PlayerService
