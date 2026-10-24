--!strict
--[[
	StateController.luau
	The client's mirror of server state. Presentation reads from here; nothing
	here ever decides gameplay.

	Reconnect behaviour: when a profile arrives the UI is rebuilt from scratch
	rather than patched, so a dropped or duplicated packet cannot leave the HUD
	showing stale numbers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)

local StateController = { Name = "StateController" }

local controllers: any = nil

StateController.Profile = nil :: any?
StateController.Runtime = nil :: any?
StateController.Inventory = nil :: any?
StateController.Combat = nil :: any?
StateController.World = {
	regionId = nil,
	bosses = {},
	beasts = {},
	events = {},
}

local profileListeners: { (any) -> () } = {}
local runtimeListeners: { (any) -> () } = {}

function StateController.Init(svc: any)
	controllers = svc
end

function StateController.OnProfile(listener: (any) -> ())
	table.insert(profileListeners, listener)
	if StateController.Profile then
		listener(StateController.Profile)
	end
end

function StateController.OnRuntime(listener: (any) -> ())
	table.insert(runtimeListeners, listener)
	if StateController.Runtime then
		listener(StateController.Runtime)
	end
end

function StateController.RequestProfile()
	local Network = controllers.NetworkController
	local profile = Network.Invoke(Remotes.RequestProfileData.name, {}, 8)
	if profile then
		StateController.SetProfile(profile)
	end
end

function StateController.SetProfile(profile: any)
	StateController.Profile = profile
	for _, listener in profileListeners do
		pcall(listener, profile)
	end
end

function StateController.SetRuntime(runtime: any)
	StateController.Runtime = runtime
	for _, listener in runtimeListeners do
		pcall(listener, runtime)
	end
end

function StateController.Start()
	local Network = controllers.NetworkController

	Network.On(Remotes.PlayerProfileUpdated.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		-- A profile packet replaces the whole profile; it is never merged, so
		-- a partial packet cannot half-apply.
		if StateController.Profile and type(StateController.Profile) == "table" then
			for key, value in payload do
				StateController.Profile[key] = value
			end
		else
			StateController.Profile = payload
		end
		StateController.SetProfile(StateController.Profile)
	end)

	Network.On(Remotes.PlayerStateUpdated.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		StateController.Runtime = payload
		StateController.SetRuntime(payload)
	end)

	Network.On(Remotes.InventoryUpdated.name, function(payload: any)
		StateController.Inventory = payload
	end)

	Network.On(Remotes.CombatStateUpdated.name, function(payload: any)
		StateController.Combat = payload
	end)

	Network.On(Remotes.BossStateUpdated.name, function(payload: any)
		if type(payload) ~= "table" or not payload.id then
			return
		end
		StateController.World.bosses[payload.id] = payload
	end)

	Network.On(Remotes.BossDefeated.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if StateController.World.bosses[payload.id] then
			StateController.World.bosses[payload.id] = nil
		end
	end)

	Network.On(Remotes.BeastStateUpdated.name, function(payload: any)
		if type(payload) ~= "table" or not payload.id then
			return
		end
		if payload.dead then
			StateController.World.beasts[payload.id] = nil
		else
			StateController.World.beasts[payload.id] = payload
		end
	end)

	Network.On(Remotes.WorldEventUpdated.name, function(payload: any)
		if type(payload) ~= "table" or not payload.id then
			return
		end
		if payload.state == Enums.WorldEventState.Inactive or payload.state == Enums.WorldEventState.Cooldown then
			StateController.World.events[payload.id] = nil
		else
			StateController.World.events[payload.id] = payload
		end
	end)

	Network.On(Remotes.RegionDiscovered.name, function(payload: any)
		if type(payload) == "table" and payload.regionId then
			StateController.World.regionId = payload.regionId
		end
	end)
end

return StateController
