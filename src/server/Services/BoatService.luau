--!strict
--[[
	BoatService.luau
	Watercraft: spawn, boarding, health and destruction.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)
local Boats = require(Shared.Config.BoatConfig)

local BoatService = {
	Name = "BoatService",
}

export type BoatInstance = {
	id: string,
	boatId: string,
	owner: Player?,
	health: number,
	maxHealth: number,
	passengers: { [Player]: boolean },
	spawnedAt: number,
}

local spawned: { [string]: BoatInstance } = {}
local nextId = 0
local services: any = nil

function BoatService.Init(svc: any)
	services = svc
end

function BoatService.Start(svc: any)
	services = svc
	services.NetworkService.On(Remotes.RequestBoat.name, function(player, args)
		return BoatService.Request(player, tostring(args[1]), tostring(args[2]))
	end)
end

function BoatService.Request(player: Player, action: string, boatId: string): boolean
	if action == "Spawn" then
		return BoatService.Spawn(player, boatId)
	elseif action == "Board" then
		return BoatService.Board(player, boatId)
	elseif action == "Leave" then
		return BoatService.Leave(player, boatId)
	end
	return false
end

function BoatService.Spawn(player: Player, boatId: string): boolean
	local boat = Boats:Get(boatId)
	if not boat then
		return false
	end
	-- The player must own the boat item and pay the deployment cost.
	if services.InventoryService.CountItem(player, boat.itemId) < 1 then
		return false
	end
	local position = services.WorldService and services.WorldService.PositionOf(player)
	if not position then
		return false
	end
	if not Boats.CanSpawnAt(boatId, position) then
		services.NetworkService.Fire(player, Remotes.BoatStateUpdated.name, { accepted = false, reason = "NotDeepEnoughWater" })
		return false
	end
	nextId += 1
	local id = string.format("boat_%d", nextId)
	spawned[id] = {
		id = id,
		boatId = boatId,
		owner = player,
		health = boat.oceanHealth,
		maxHealth = boat.oceanHealth,
		passengers = { [player] = true },
		spawnedAt = os.time(),
	}
	services.NetworkService.Fire(player, Remotes.BoatStateUpdated.name, { accepted = true, id = id, boatId = boatId })
	Logger.Debug("BoatService", string.format("%s spawned %s", tostring(player.Name), boatId))
	return true
end

function BoatService.Board(player: Player, instanceId: string): boolean
	local boat = spawned[instanceId]
	if not boat then
		return false
	end
	local def = Boats:Get(boat.boatId)
	if not def then
		return false
	end
	local count = 0
	for _ in boat.passengers do
		count += 1
	end
	if count >= def.crewCapacity then
		return false
	end
	boat.passengers[player] = true
	services.NetworkService.Fire(player, Remotes.BoatStateUpdated.name, { boarded = true, id = instanceId })
	return true
end

function BoatService.Leave(player: Player, instanceId: string): boolean
	local boat = spawned[instanceId]
	if not boat then
		return false
	end
	boat.passengers[player] = nil
	local count = 0
	for _ in boat.passengers do
		count += 1
	end
	if count == 0 then
		task.delay(60, function()
			if spawned[instanceId] == boat then
				spawned[instanceId] = nil
			end
		end)
	end
	services.NetworkService.Fire(player, Remotes.BoatStateUpdated.name, { left = true, id = instanceId })
	return true
end

function BoatService.ApplyDamage(instanceId: string, amount: number, source: Player?)
	local boat = spawned[instanceId]
	if not boat then
		return
	end
	boat.health = math.max(0, boat.health - amount)
	if boat.health > 0 then
		return
	end
	-- A destroyed boat ejects its passengers instead of killing them.
	for passenger in boat.passengers do
		local state = services.PlayerService.Get(passenger)
		if state and state.alive then
			services.PlayerService.ApplyDamage(passenger, state.health * 0.25, "boat_destroyed")
		end
		services.NetworkService.Fire(passenger, Remotes.BoatStateUpdated.name, { destroyed = true, id = instanceId })
	end
	spawned[instanceId] = nil
	_ = source
end

function BoatService.OnPlayerRemoving(player: Player)
	for id, boat in spawned do
		boat.passengers[player] = nil
		local count = 0
		for _ in boat.passengers do
			count += 1
		end
		if count == 0 then
			spawned[id] = nil
		end
	end
end

function BoatService.ActiveCount(): number
	local count = 0
	for _ in spawned do
		count += 1
	end
	return count
end

return BoatService
