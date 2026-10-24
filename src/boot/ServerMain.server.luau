--!strict
--[[
	Main.server.luau
	Server entry point. Loads every service, wires them together and starts
	the game loop.

	Order of operations:
	  1. Init every service (construct state, no side effects)
	  2. Start every service (register handlers, begin loops)
	  3. Connect player lifecycle to the services that need it
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Shared modules are replicated (both sides need them). Server modules are
-- NOT: they live under ServerScriptService so DataStore logic, admin
-- authorisation and rate-limit internals never reach a client.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")

local Logger = require(Shared.Utilities.Logger)

-- Load order matters: dependencies first.
local NetworkService = require(Services.NetworkService)
local DataService = require(Services.DataService)
local AdminService = require(Services.AdminService)
local ProgressionService = require(Services.ProgressionService)
local PlayerService = require(Services.PlayerService)
local InventoryService = require(Services.InventoryService)
local CombatService = require(Services.CombatService)
local ResourceService = require(Services.ResourceService)
local WorldService = require(Services.WorldService)
local BeastService = require(Services.BeastService)
local BossService = require(Services.BossService)
local DungeonService = require(Services.DungeonService)
local WorldEventService = require(Services.WorldEventService)
local CompanionService = require(Services.CompanionService)
local DeploymentService = require(Services.DeploymentService)
local HazardService = require(Services.HazardService)
local SquadService = require(Services.SquadService)
local ClanService = require(Services.ClanService)
local TradingService = require(Services.TradingService)
local BoatService = require(Services.BoatService)
local AudioService = require(Services.AudioService)
local PerformanceService = require(Services.PerformanceService)

local ServiceList = {
	NetworkService,
	DataService,
	AdminService,
	ProgressionService,
	PlayerService,
	InventoryService,
	CombatService,
	ResourceService,
	WorldService,
	BeastService,
	BossService,
	DungeonService,
	WorldEventService,
	CompanionService,
	DeploymentService,
	HazardService,
	SquadService,
	ClanService,
	TradingService,
	BoatService,
	AudioService,
	PerformanceService,
}

-- The shared services table every service receives.
local services: { [string]: any } = {}
for _, service in ServiceList do
	services[service.Name] = service
end

Logger.Info("Main", "WILDBREAK server starting")

-- 1. Init
for _, service in ServiceList do
	if service.Init then
		local ok, err = pcall(function()
			service.Init(services)
		end)
		if not ok then
			Logger.Error("Main", string.format("%s failed to init: %s", tostring(service.Name), tostring(err)))
		end
	end
end

-- 2. Start
for _, service in ServiceList do
	if service.Start then
		local ok, err = pcall(function()
			service.Start(services)
		end)
		if not ok then
			Logger.Error("Main", string.format("%s failed to start: %s", tostring(service.Name), tostring(err)))
		end
	end
end

-- 3. Player lifecycle
Players.PlayerAdded:Connect(function(player)
	PlayerService.OnPlayerAdded(player)
	InventoryService.OnPlayerAdded(player)
	CombatService.OnPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	for _, service in ServiceList do
		if service.OnPlayerRemoving then
			pcall(function()
				service.OnPlayerRemoving(player)
			end)
		end
	end
end)

-- Players who joined before the server finished loading.
for _, player in Players:GetPlayers() do
	task.spawn(function()
		PlayerService.OnPlayerAdded(player)
		InventoryService.OnPlayerAdded(player)
		CombatService.OnPlayerAdded(player)
	end)
end

-- 4. Fixed server tick: the single authoritative game loop.
local accumulator = 0
RunService.Heartbeat:Connect(function(delta)
	accumulator += delta
	local step = 1 / 30
	while accumulator >= step do
		accumulator -= step
		PlayerService.Tick(step)
		CombatService.Tick(step)
		CompanionService.Tick(step)
	end
end)

-- 5. Graceful shutdown: flush every profile before the server closes.
game:BindToClose(function()
	Logger.Info("Main", "server closing, flushing profiles")
	DataService.SaveAll()
end)

Logger.Info("Main", "WILDBREAK server ready")
