--!strict
--[[
	HazardService.luau
	Environmental hazards: heat, cold, contamination, storms, volcanic,
	underwater pressure, void anomalies and fall damage.

	Design rule: hazards are tactical survival pressure, not hardcore
	punishment. Food and water are buffs and are never mandatory to survive a
	normal expedition; protective gear and salves give meaningful mitigation.
	Fall damage is always computed by the server from a validated velocity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Hazards = require(Shared.Config.HazardConfig)
local Regions = require(Shared.Config.RegionConfig)
local Movement = require(Shared.Config.MovementConfig)
local StatusEffects = require(Shared.Combat.StatusEffects)

local HazardService = {
	Name = "HazardService",
}

local services: any = nil
local lastTick: { [Player]: number } = {}

function HazardService.Init(svc: any)
	services = svc
end

function HazardService.Start(svc: any)
	services = svc
	task.spawn(function()
		while true do
			task.wait(1)
			HazardService.Tick()
		end
	end)
end

-- Mitigation comes from equipped protection items and active buffs.
function HazardService.MitigationFor(player: Player, hazardId: string): number
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return 0
	end
	local equipped: { string } = {}
	for slot in profile.equipped do
		local id = profile.equipped[slot]
		if type(id) == "string" then
			table.insert(equipped, id)
		end
	end
	local state = services.PlayerService.Get(player)
	local buffs = {}
	if state then
		for _, effect in state.statusEffects.active do
			table.insert(buffs, effect.id)
		end
	end
	return Hazards.Mitigation(hazardId, equipped, buffs)
end

function HazardService.Tick()
	for player, state in services.PlayerService and {} or {} do
		_ = player
		_ = state
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		HazardService.TickPlayer(player)
	end
end

function HazardService.TickPlayer(player: Player)
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return
	end
	local regionId = state.regionId
	if not regionId then
		return
	end
	local region = Regions:Get(regionId)
	if not region then
		return
	end
	local now = os.clock()
	lastTick[player] = lastTick[player] or now
	local delta = now - lastTick[player]
	lastTick[player] = now
	if delta <= 0 then
		return
	end

	for _, hazardId in region.hazards do
		local hazard = Hazards:Get(hazardId)
		if not hazard then
			continue
		end
		local exposure = Hazards.Exposure(hazardId, regionId, state.position)
		if exposure <= 0 then
			continue
		end
		local mitigation = HazardService.MitigationFor(player, hazardId)
		local damagePerSecond = Hazards.DamagePerSecond(hazardId, mitigation) * exposure
		if damagePerSecond <= 0 then
			continue
		end
		-- Hazard damage is applied through the same single pipeline.
		local applied = damagePerSecond * delta
		services.PlayerService.ApplyDamage(player, applied, "hazard_" .. hazardId)
		if hazard.statusEffect then
			StatusEffects.Apply(state.statusEffects, hazard.statusEffect, now, { duration = hazard.statusDuration })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fall damage (server computed)
-- ---------------------------------------------------------------------------

function HazardService.ResolveFall(player: Player, impactSpeed: number, graceOverride: boolean?): number
	local state = services.PlayerService.Get(player)
	if not state then
		return 0
	end
	-- The server decides whether the glide/deployment grace window applies;
	-- the client cannot claim it.
	local grace = graceOverride == true
		or state.deploymentPhase == Enums.DeployPhase.Gliding
		or state.deploymentPhase == Enums.DeployPhase.Landing
	local damage = Movement.FallDamageFor(impactSpeed, state.maxHealth, grace)
	if damage > 0 then
		services.PlayerService.ApplyDamage(player, damage, "fall")
	end
	return damage
end

function HazardService.OnPlayerRemoving(player: Player)
	lastTick[player] = nil
end

return HazardService
