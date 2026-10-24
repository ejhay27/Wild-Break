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
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Logger = require(Shared.Utilities.Logger)
local Limits = require(Shared.Constants.Limits)
local Regions = require(Shared.Config.RegionConfig)
local Bosses = require(Shared.Config.BossConfig)
local WorldBuilder = require(Server:WaitForChild("World"):WaitForChild("WorldBuilder"))

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

-- The server's own reading of where a player is. Client reports are only
-- accepted after validation (see ReportPosition), and this is the fallback
-- that keeps region tracking and boss distances working even before a client
-- has reported anything.
function WorldService.CharacterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local position = root.Position
	if position.Magnitude > Limits.Networking.MaxPositionMagnitude then
		return nil
	end
	return position
end

-- Recycling: when a player respawns, drop the stale reported position so the
-- server re-reads it from the new character instead of teleporting them
-- backwards through the region logic.
function WorldService.ResetPosition(player: Player)
	positions[player] = nil
	regionOf[player] = nil
end

-- Wakes a region's world boss when players reach its arena. This is the real
-- gameplay hook for BossService.StartWorldBoss; it is driven by measured
-- positions, so a client cannot summon a boss by claiming a position.
function WorldService._updateBossActivation()
	for _, player in game:GetService("Players"):GetPlayers() do
		local regionId = regionOf[player]
		if not regionId or Regions.IsHub(regionId) then
			continue
		end
		local bossId = Regions:Get(regionId) and Regions:Get(regionId).worldBossId
		if not bossId or bossId == "" then
			continue
		end

		local position = positions[player]
		local arena = WorldBuilder.ArenaPosition(regionId)
		if not position or not arena then
			continue
		end

		-- Entering the arena starts the fight. StartWorldBoss is idempotent:
		-- if an encounter is already live it returns that one.
		local activationRadius = WorldBuilder.ArenaRadius(regionId) * 1.25
		if (position - arena).Magnitude <= activationRadius then
			local existing = services.BossService and services.BossService.ActiveEncounterForBoss(bossId)
			if not existing then
				Logger.Info("WorldService", string.format("players reached the %s arena, waking %s", regionId, bossId))
				services.BossService.StartWorldBoss(regionId)
			end
		end
	end
end

function WorldService.Tick()
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		if not player.Character then
			continue
		end
		-- Prefer the validated report; fall back to reading the character so
		-- the server always has a position to work from.
		local position = positions[player] or WorldService.CharacterPosition(player)
		if not position then
			continue
		end
		positions[player] = position

		local current = Regions.RegionAt(position.X, position.Z)
		if current ~= regionOf[player] then
			local previous = regionOf[player]
			regionOf[player] = current
			local state = services.PlayerService.Get(player)
			if state then
				state.regionId = current
			end
			if current and current ~= previous then
				WorldService._onRegionEntered(player, current)
			end
		end
	end

	WorldService._updateBossActivation()

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

-- The authoritative position of a player. Never nil-by-default: if there is
-- no validated client report the server reads the character itself. Callers
-- that need a distance must treat nil as "unknown", never as zero.
function WorldService.PositionOf(player: Player): Vector3?
	return positions[player] or WorldService.CharacterPosition(player)
end

-- Called when a player crosses into a new region: swap the atmosphere to the
-- region's own lighting so the world reads as distinct places.
function WorldService._onRegionEntered(player: Player, regionId: string)
	if not player or not regionId then
		return
	end
	local definition = Regions:Get(regionId)
	if not definition then
		return
	end
	Logger.Debug("WorldService", string.format("%s entered %s", tostring(player.Name), regionId))

	-- The atmosphere follows the region the server is most populated in, so
	-- everyone shares one sky rather than each client blending its own.
	local dominant = WorldService.DominantRegion()
	if dominant and WorldBuilder.CurrentLightingRegion ~= dominant then
		WorldBuilder.ApplyLighting(dominant)
	end
end

-- The region holding the most players, used to choose the shared atmosphere.
function WorldService.DominantRegion(): string?
	local tally: { [string]: number } = {}
	local best, bestCount = nil, 0
	for _, regionId in regionOf do
		if regionId then
			tally[regionId] = (tally[regionId] or 0) + 1
			if tally[regionId] > bestCount then
				best, bestCount = regionId, tally[regionId]
			end
		end
	end
	return best
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
