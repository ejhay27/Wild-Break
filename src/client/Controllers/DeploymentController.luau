--!strict
--[[
	DeploymentController.luau
	Quick Drop and Tactical Deployment.

	The client picks a region and, for Quick Drop, a glide direction. The
	server decides the landing zone: a client can never supply its own landing
	position, so a tampered client cannot teleport into a locked area.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)

local DeploymentController = { Name = "DeploymentController" }

local controllers: any = nil
local phase = Enums.DeployPhase.Idle
local activeDrop: any? = nil

function DeploymentController.Init(svc: any)
	controllers = svc
end

function DeploymentController.Phase(): string
	return phase
end

function DeploymentController.Request(mode: string, regionId: string, zoneId: string?)
	if phase ~= Enums.DeployPhase.Idle then
		return
	end
	controllers.NetworkController.Fire(Remotes.RequestDeploy.name, {
		mode = mode,
		regionId = regionId,
		zoneId = zoneId,
	})
end

-- The player steps out of the drop ship and starts gliding.
function DeploymentController.BeginGlide()
	if phase ~= Enums.DeployPhase.Launching then
		return
	end
	phase = Enums.DeployPhase.Gliding
end

-- Reports the landing and the impact speed so the server can compute fall
-- damage from a validated value.
function DeploymentController.Land(impactSpeed: number)
	if phase ~= Enums.DeployPhase.Gliding then
		return
	end
	phase = Enums.DeployPhase.Landing
	controllers.NetworkController.Fire(Remotes.RequestMovementSkill.name, {
		skillId = "glide_land",
		impactSpeed = impactSpeed,
	})
end

function DeploymentController.ReturnToHub()
	controllers.NetworkController.Fire(Remotes.RequestTeleport.name, { destinationId = "hub" })
end

function DeploymentController.Start()
	local Network = controllers.NetworkController
	local Input = controllers.InputController

	Network.On(Remotes.DeployStarted.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if not payload.accepted then
			controllers.NotificationController.Notify("Deployment refused", tostring(payload.reason))
			return
		end
		activeDrop = payload
		phase = Enums.DeployPhase.Launching
		controllers.HudController.ShowDeployment(payload)
	end)

	Network.On(Remotes.DeployLanded.name, function(payload: any)
		activeDrop = nil
		phase = Enums.DeployPhase.Idle
		controllers.HudController.HideDeployment()
		if type(payload) == "table" and payload.accepted then
			controllers.StateController.World.regionId = payload.regionId
		end
	end)

	Network.On(Remotes.MovementResolved.name, function(payload: any)
		if type(payload) == "table" and payload.skillId == "glide_land" then
			phase = Enums.DeployPhase.Idle
			controllers.HudController.HideDeployment()
		end
	end)

	Input.Bind("Deploy", function(down: boolean)
		if down then
			controllers.HudController.ToggleScreen("Deployment")
		end
	end)
end

function DeploymentController.ActiveDrop(): any?
	return activeDrop
end

return DeploymentController
