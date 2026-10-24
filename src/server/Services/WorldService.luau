--!strict
--[[
	WorldService.luau
	Tracks where players are, which region they are in, and provides the
	spatial queries the other services need (population, nearest player,
	distance). Also owns world pickups dropped by players.

	This service is the server's spatial authority: region membership and
	proximity are always computed here, never reported by a client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.Utilities.Logger)
local Regions = require(Shared.Config.RegionConfig)

local WorldService = {
	Name = "WorldService",
}

local positions: { [Player]: Vector3 } = {}
local regionOf: { [Player]: string? } = {}
local pickups: { [string]: { id: string, itemId: string, quantity: number, position: Vector3, createdAt: number } } = {}
local nextPickupId = 0
local services: any = nil

function WorldService.Init(svc: any)
	services = svc
end

function WorldService.Start(svc: any)
	services = svc
	RunService.Heartbeat:Connect(function()
		WorldService.Tick()
	end)
end

function WorldService.Tick()
	for player, position in positions do
		if not player.Character then
			continue
		end
		local current = Regions.RegionAt(position.X, position.Z)
		if current ~= regionOf[player] then
			regionOf[player] = current
			local state = services.PlayerService.Get(player)
			if state then
				state.regionId = current
			end
		end
	end

	-- Expire dropped pickups so the world never accumulates clutter.
	local now = os.time()
	for id, pickup in pickups do
		if now - pickup.createdAt > 600 then
			pickups[id] = nil
		end
	end
end

-- The client reports its position; the server validates it before using it.
function WorldService.ReportPosition(player: Player, position: Vector3, seconds: number): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end
	if not services.PlayerService.ValidatePosition(player, position, seconds) then
		return false
	end
	positions[player] = position
	return true
end

function WorldService.PositionOf(player: Player): Vector3?
	return positions[player]
end

function WorldService.RegionOf(player: Player): string?
	return regionOf[player]
end

function WorldService.PlayerCountInRegion(regionId: string): number
	local count = 0
	for _, region in regionOf do
		if region == regionId then
			count += 1
		end
	end
	return count
end

function WorldService.PlayersInRegion(regionId: string): { Player }
	local out = {}
	for player, region in regionOf do
		if region == regionId then
			table.insert(out, player)
		end
	end
	return out
end

function WorldService.NearestPlayerTo(position: Vector3?, maxDistance: number): Player?
	if not position then
		return nil
	end
	local best, bestDistance = nil, maxDistance
	for player, playerPosition in positions do
		local distance = (playerPosition - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = player, distance
		end
	end
	return best
end

function WorldService.DistanceTo(position: Vector3?, player: Player): number
	if not position then
		return math.huge
	end
	local playerPosition = positions[player]
	if not playerPosition then
		return math.huge
	end
	return (playerPosition - position).Magnitude
end

-- ---------------------------------------------------------------------------
-- Pickups
-- ---------------------------------------------------------------------------

function WorldService.SpawnPickup(player: Player, itemId: string, quantity: number): string?
	local position = positions[player]
	if not position then
		return nil
	end
	nextPickupId += 1
	local id = string.format("pickup_%d", nextPickupId)
	pickups[id] = {
		id = id,
		itemId = itemId,
		quantity = quantity,
		position = position,
		createdAt = os.time(),
	}
	Logger.Debug("WorldService", string.format("%s dropped %d x %s", tostring(player.Name), quantity, itemId))
	return id
end

function WorldService.CollectPickup(player: Player, id: string): boolean
	local pickup = pickups[id]
	if not pickup then
		return false
	end
	local position = positions[player]
	if position and (position - pickup.position).Magnitude > 20 then
		return false
	end
	local added = services.InventoryService.AddItem(player, pickup.itemId, pickup.quantity)
	if added <= 0 then
		return false
	end
	if added < pickup.quantity then
		pickup.quantity -= added
		return true
	end
	pickups[id] = nil
	return true
end

function WorldService.OnPlayerRemoving(player: Player)
	positions[player] = nil
	regionOf[player] = nil
end

function WorldService.PickupCount(): number
	local count = 0
	for _ in pickups do
		count += 1
	end
	return count
end

return WorldService
