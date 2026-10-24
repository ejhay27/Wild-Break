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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ReplicatedStorage:WaitForChild("Server")

local Logger = require(Shared.Utilities.Logger)

-- Load order matters: dependencies first.
local NetworkService = require(Server.Services.NetworkService)
local DataService = require(Server.Services.DataService)
local AdminService = require(Server.Services.AdminService)
local ProgressionService = require(Server.Services.ProgressionService)
local PlayerService = require(Server.Services.PlayerService)
local InventoryService = require(Server.Services.InventoryService)
local CombatService = require(Server.Services.CombatService)
local ResourceService = require(Server.Services.ResourceService)
local WorldService = require(Server.Services.WorldService)
local BeastService = require(Server.Services.BeastService)
local BossService = require(Server.Services.BossService)
local DungeonService = require(Server.Services.DungeonService)
local WorldEventService = require(Server.Services.WorldEventService)
local CompanionService = require(Server.Services.CompanionService)
local DeploymentService = require(Server.Services.DeploymentService)
local HazardService = require(Server.Services.HazardService)
local SquadService = require(Server.Services.SquadService)
local ClanService = require(Server.Services.ClanService)
local TradingService = require(Server.Services.TradingService)
local BoatService = require(Server.Services.BoatService)
local AudioService = require(Server.Services.AudioService)
local PerformanceService = require(Server.Services.PerformanceService)

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
