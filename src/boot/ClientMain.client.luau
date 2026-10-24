--!strict
--[[
	ClientMain.client.luau
	Client entry point (StarterPlayerScripts.WildbreakClientMain).

	Bootstrap order matters:
	  1. wait for the replicated containers
	  2. Init every controller (build state, no side effects)
	  3. Start every controller (connect remotes, bind input, build UI)
	  4. tell the server the client is ready so it can push state

	The client never trusts itself with gameplay decisions: it sends INTENTS
	and renders the state the server sends back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent:WaitForChild("Client")

local Logger = require(Shared.Utilities.Logger)
local Remotes = require(Shared.Networking.Remotes)

local NetworkController = require(Client.Controllers.NetworkController)
local StateController = require(Client.Controllers.StateController)
local SettingsController = require(Client.Controllers.SettingsController)
local InputController = require(Client.Controllers.InputController)
local CameraController = require(Client.Controllers.CameraController)
local CombatController = require(Client.Controllers.CombatController)
local InventoryController = require(Client.Controllers.InventoryController)
local DeploymentController = require(Client.Controllers.DeploymentController)
local CompanionController = require(Client.Controllers.CompanionController)
local AudioController = require(Client.Controllers.AudioController)
local PerformanceController = require(Client.Controllers.PerformanceController)
local NotificationController = require(Client.Controllers.NotificationController)
local HudController = require(Client.Controllers.HudController)

local ControllerList = {
	NetworkController,
	StateController,
	SettingsController,
	InputController,
	CameraController,
	CombatController,
	InventoryController,
	DeploymentController,
	CompanionController,
	AudioController,
	PerformanceController,
	NotificationController,
	HudController,
}

local controllers: { [string]: any } = {}
for _, controller in ControllerList do
	controllers[controller.Name] = controller
end

local player = Players.LocalPlayer
Logger.Info("Client", "WILDBREAK client starting")

-- 1. Init
for _, controller in ControllerList do
	if controller.Init then
		local ok, err = pcall(function()
			controller.Init(controllers, player)
		end)
		if not ok then
			Logger.Error("Client", string.format("%s failed to init: %s", tostring(controller.Name), tostring(err)))
		end
	end
end

-- 2. Start
for _, controller in ControllerList do
	if controller.Start then
		local ok, err = pcall(function()
			controller.Start(controllers, player)
		end)
		if not ok then
			Logger.Error("Client", string.format("%s failed to start: %s", tostring(controller.Name), tostring(err)))
		end
	end
end

-- 3. Ready handshake: the server pushes profile and world state after this.
task.spawn(function()
	-- Give the remote folder a moment to exist, then retry until the server
	-- acknowledges. A dropped handshake must not leave the HUD blank.
	for attempt = 1, 10 do
		local ok = pcall(function()
			NetworkController.Fire(Remotes.ClientReady.name, {
				platform = NetworkController.Platform(),
			})
		end)
		if ok then
			break
		end
		task.wait(0.5 * attempt)
	end
	StateController.RequestProfile()
end)

-- 4. Frame loop: presentation only.
RunService.RenderStepped:Connect(function(delta)
	for _, controller in ControllerList do
		if controller.Render then
			pcall(function()
				controller.Render(delta)
			end)
		end
	end
end)

Logger.Info("Client", "WILDBREAK client ready")
