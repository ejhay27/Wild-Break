--!strict
--[[
	DeploymentService.luau
	Quick Drop (solo glide from the drop ship), Tactical Deployment (squad drop
	to a validated landing zone) and the respawn-to-hub flow.

	The client picks a region and, optionally, a landing zone. The server
	validates the choice against the player's reputation and the curated zone
	list, then resolves the final spawn. A client can never supply its own
	landing position.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)
local Deployment = require(Shared.Config.DeploymentConfig)
local Regions = require(Shared.Config.RegionConfig)
local Movement = require(Shared.Config.MovementConfig)

local DeploymentService = {
	Name = "DeploymentService",
}

local pending: { [Player]: { mode: string, regionId: string, zoneId: string?, startedAt: number } } = {}
local cooldowns: { [Player]: number } = {}
local services: any = nil

local function now(): number
	return os.clock()
end

function DeploymentService.Init(svc: any)
	services = svc
end

function DeploymentService.Start(svc: any)
	services = svc
	local Network = services.NetworkService
	Network.On(Remotes.RequestDeploy.name, function(player, args)
		return DeploymentService.RequestDeploy(player, tostring(args[1]), tostring(args[2]), args[3])
	end)
	Network.On(Remotes.RequestTeleport.name, function(player, args)
		return DeploymentService.RequestTeleport(player, tostring(args[1]), args[2])
	end)
end

-- ---------------------------------------------------------------------------
-- Quick Drop / Tactical Deployment
-- ---------------------------------------------------------------------------

function DeploymentService.RequestDeploy(player: Player, mode: string, regionId: string, zoneId: any?): boolean
	local state = services.PlayerService.Get(player)
	if not state then
		return false
	end
	local modeDef = Deployment.Modes[mode]
	if not modeDef then
		return false
	end
	if not Regions:Has(regionId) or Regions.IsHub(regionId) then
		services.NetworkService.Fire(player, Remotes.DeployStarted.name, { accepted = false, reason = "UnknownRegion" })
		return false
	end
	local cooldown = cooldowns[player]
	if cooldown and now() < cooldown then
		services.NetworkService.Fire(player, Remotes.DeployStarted.name, { accepted = false, reason = "Cooldown" })
		return false
	end
	if modeDef.requiresSquad then
		local squad = services.SquadService and services.SquadService.SquadOf(player)
		if not squad or #squad.members < Deployment.DropShip.minPlayersForTactical then
			services.NetworkService.Fire(player, Remotes.DeployStarted.name, { accepted = false, reason = "SquadRequired" })
			return false
		end
	end

	-- The landing zone is resolved server-side from the curated list.
	local profile = services.PlayerService.Profile(player)
	local reputation = profile and profile.mastery["reputation_" .. string.lower(regionId)] or 0
	local zone = Deployment.ResolveLanding(regionId, type(zoneId) == "string" and zoneId or nil, reputation, nil)
	if not zone then
		services.NetworkService.Fire(player, Remotes.DeployStarted.name, { accepted = false, reason = "NoLandingZone" })
		return false
	end

	pending[player] = { mode = mode, regionId = regionId, zoneId = zone.id, startedAt = now() }
	state.deploymentPhase = Enums.DeployPhase.Launching
	cooldowns[player] = now() + modeDef.cooldownSeconds

	services.NetworkService.Fire(player, Remotes.DeployStarted.name, {
		accepted = true,
		mode = mode,
		regionId = regionId,
		zoneId = zone.id,
		position = zone.position,
		altitude = Deployment.DropShip.cruiseAltitudeStuds,
		windowSeconds = Deployment.DropShip.windowSeconds,
		glide = Movement.Glide,
	})
	Logger.Info("DeploymentService", string.format("%s deploying to %s (%s)", tostring(player.Name), regionId, zone.id))
	return true
end

-- Called by the client when the player jumps from the ship.
function DeploymentService.BeginGlide(player: Player): boolean
	local state = services.PlayerService.Get(player)
	if not state or state.deploymentPhase ~= Enums.DeployPhase.Launching then
		return false
	end
	state.deploymentPhase = Enums.DeployPhase.Gliding
	return true
end

-- Called when the player touches the ground. Fall damage is forgiven inside
-- the configured grace window after a glide landing.
function DeploymentService.Land(player: Player, landingSpeed: number?): boolean
	local state = services.PlayerService.Get(player)
	if not state or state.deploymentPhase ~= Enums.DeployPhase.Gliding then
		return false
	end
	state.deploymentPhase = Enums.DeployPhase.Complete
	state.regionId = pending[player] and pending[player].regionId or state.regionId
	pending[player] = nil

	local damage = 0
	if landingSpeed and Movement.FallDamage then
		damage = Movement.FallDamageFor(landingSpeed, state.maxHealth, true)
		if damage > 0 then
			services.PlayerService.ApplyDamage(player, damage, "fall")
		end
	end
	services.NetworkService.Fire(player, Remotes.DeployLanded.name, { accepted = true, regionId = state.regionId, fallDamage = damage })
	task.delay(1, function()
		if state.deploymentPhase == Enums.DeployPhase.Complete then
			state.deploymentPhase = Enums.DeployPhase.Idle
		end
	end)
	return true
end

-- ---------------------------------------------------------------------------
-- Teleport (fast travel between discovered landmarks, and back to the hub)
-- ---------------------------------------------------------------------------

function DeploymentService.RequestTeleport(player: Player, destinationId: string, _unused: any?): boolean
	local state = services.PlayerService.Get(player)
	if not state then
		return false
	end
	-- The hub is always available; every other destination must be discovered.
	if destinationId ~= Deployment.Respawn.hubId then
		local profile = services.PlayerService.Profile(player)
		if not profile or not profile.discoveries[destinationId] then
			services.NetworkService.Fire(player, Remotes.Notification.name, {
				kind = "Warning",
				title = "Not discovered",
				body = "You must find this location before you can travel to it.",
			})
			return false
		end
	end
	if state.inBossEncounter then
		services.NetworkService.Fire(player, Remotes.Notification.name, {
			kind = "Warning",
			title = "Cannot travel",
			body = "Fast travel is unavailable during a boss encounter.",
		})
		return false
	end
	state.regionId = destinationId == Deployment.Respawn.hubId and nil or destinationId
	services.NetworkService.Fire(player, Remotes.DeployLanded.name, { accepted = true, teleported = true, destinationId = destinationId })
	return true
end

-- ---------------------------------------------------------------------------
-- Respawn
-- ---------------------------------------------------------------------------

function DeploymentService.ReturnToHub(player: Player)
	local state = services.PlayerService.Get(player)
	if not state then
		return
	end
	services.PlayerService.Respawn(player)
	state.regionId = nil
	state.deploymentPhase = Enums.DeployPhase.Idle
	services.NetworkService.Fire(player, Remotes.DeployLanded.name, { accepted = true, hub = true, hubId = Deployment.Respawn.hubId })
end

function DeploymentService.OnPlayerRemoving(player: Player)
	pending[player] = nil
	cooldowns[player] = nil
end

return DeploymentService
