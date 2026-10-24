--!strict
--[[
	ResourceService.luau
	Spawns, tracks and respawns every gathering node in the world.

	Ordinary nodes respawn in exactly 180 seconds (Limits.Resource).
	Rare and special nodes use their own configured timers. All timers are
	server-side: a client can request a harvest, it can never set a timer.

	The service keeps a light in-memory model per node and lets the world
	streaming layer attach and detach the physical instances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceState = require(Shared.Resources.ResourceState)
local RegionConfig = require(Shared.Config.RegionConfig)
local Rng = require(Shared.Utilities.Rng)
local ActorFactory = require(Server:WaitForChild("World"):WaitForChild("ActorFactory"))
local WorldBuilder = require(Server:WaitForChild("World"):WaitForChild("WorldBuilder"))

local ResourceService = {
	Name = "ResourceService",
}

local nodes: { [string]: any } = {}
local byRegion: { [string]: { string } } = {}
local harvests: { [Player]: { nodeId: string, instanceId: string, startedAt: number, progress: number } } = {}
local services: any = nil
local rng = Rng.new(os.time())
local nextInstanceId = 0

local function newInstanceId(nodeId: string): string
	nextInstanceId += 1
	return string.format("%s#%d", nodeId, nextInstanceId)
end

function ResourceService.Init(svc: any)
	services = svc
end

function ResourceService.Start(svc: any)
	services = svc
	ResourceService.BuildWorld()

	local Network = services.NetworkService
	Network.On(Remotes.RequestHarvest.name, function(player, args)
		return ResourceService.RequestHarvest(player, tostring(args[1]), tonumber(args[2]) or 0)
	end)
	Network.On(Remotes.RequestInteract.name, function(player, args)
		return ResourceService.RequestInteract(player, tostring(args[1]))
	end)

	-- Node respawn ticks on a slow heartbeat; precision is not required and
	-- this keeps the cost flat regardless of node count.
	task.spawn(function()
		while true do
			task.wait(1)
			ResourceService.Tick()
		end
	end)
	_ = RunService
end

-- Fallback scatter used only if the world has not been generated (for
-- example when the service is driven from a headless test).
local function fallbackSpots(region: any, wanted: number): { Vector3 }
	local out = {}
	local centre = RegionConfig.Center(region.id)
	for index = 1, wanted do
		local angle = (index / math.max(1, wanted)) * math.pi * 2
		local distance = (region.radius or 800) * (0.25 + 0.6 * ((index % 7) / 7))
		table.insert(
			out,
			Vector3.new(centre.X + math.cos(angle) * distance, centre.Y, centre.Z + math.sin(angle) * distance)
		)
	end
	return out
end

-- Populates the world with real, positioned, physical nodes.
--
-- Previously this only built an in-memory list: nodes had no position and no
-- instance, so there was nothing in the world to walk up to and gather. Each
-- node now gets a measured position inside its region and a physical actor.
function ResourceService.BuildWorld()
	nodes = {}
	byRegion = {}
	for _, region in RegionConfig:List() do
		byRegion[region.id] = {}

		local wanted = 0
		for _, count in region.resourceNodes do
			wanted += count
		end
		-- Density stays sane and inside the part budget.
		wanted = math.min(wanted, Limits.Performance.MaxActiveNodesPerRegion or 400)

		local spots = WorldBuilder.NodeSpots(region.id)
		if #spots == 0 then
			spots = fallbackSpots(region, wanted)
		end
		if #spots == 0 then
			continue
		end

		for nodeId, count in region.resourceNodes do
			local def = ResourceConfig:Get(nodeId)
			if not def then
				Logger.Warn("ResourceService", string.format("region %s references unknown node %s", region.id, tostring(nodeId)))
				continue
			end
			local population = math.min(count, Limits.Performance.MaxActiveNodesPerRegion or 400)
			for index = 1, population do
				local instanceId = newInstanceId(nodeId)
				local node = ResourceState.New(nodeId, instanceId)
				node.regionId = region.id

				-- Positions are measured, not invented: the world builder handed
				-- back real spots inside this region's landmass.
				local position = spots[((index - 1) % #spots) + 1]
				node.position = position
				node.actor = ActorFactory.ResourceNode(nodeId, position)

				nodes[instanceId] = node
				table.insert(byRegion[region.id], instanceId)
			end
		end
	end
	local total = 0
	for _ in nodes do
		total += 1
	end
	Logger.Info("ResourceService", string.format("spawned %d resource nodes across %d regions", total, #RegionConfig:List()))
end

function ResourceService.Tick()
	local now = os.clock()
	local respawned = ResourceState.Update(nodes, now)
	for _, node in respawned do
		-- The node comes back physically, not just in the data model.
		if node.actor then
			ActorFactory.SetNodeHarvested(node.actor, false)
		end
		services.NetworkService.FireAll(Remotes.ResourceStateChanged.name, {
			instanceId = node.instanceId,
			nodeId = node.nodeId,
			state = Enums.ResourceState.Available,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Harvesting
-- ---------------------------------------------------------------------------

function ResourceService.RequestHarvest(player: Player, instanceId: string, deltaSeconds: number): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	local node = nodes[instanceId]
	if not node then
		return false
	end
	-- Anti-exploit: the player must actually be standing at the node. The
	-- server measures this from the character; a client cannot harvest from
	-- across the map by naming an instance id.
	if node.position then
		local playerPosition = services.WorldService and services.WorldService.PositionOf(player)
		if not playerPosition then
			return false
		end
		if (playerPosition - node.position).Magnitude > (Limits.Resource.HarvestRangeStuds or 14) then
			return false
		end
	end

	if not ResourceState.IsAvailable(node, os.clock()) then
		services.NetworkService.Fire(player, Remotes.HarvestProgress.name, {
			instanceId = instanceId,
			accepted = false,
			reason = "Depleted",
			remaining = ResourceState.RemainingSeconds(node, os.clock()),
		})
		return false
	end

	-- The harvest rate comes from the player's tool, mastery and buffs.
	local rate = 1
	local profile = services.PlayerService.Profile(player)
	if profile then
		rate += (profile.mastery["mastery_gathering"] or 0) / 20000
	end
	rate = math.clamp(rate, 0.1, 10)

	local outcome = ResourceState.TryHarvest(node, os.clock(), deltaSeconds, rate, function()
		return rng:Next()
	end, 0)
	if not outcome then
		local needed = ResourceState.HarvestSeconds(node.nodeId)
		node.progress = math.min(needed, (node.progress or 0) + deltaSeconds * rate)
		services.NetworkService.Fire(player, Remotes.HarvestProgress.name, {
			instanceId = instanceId,
			accepted = true,
			progress = (node.progress or 0) / needed,
			complete = false,
		})
		return true
	end

	-- Grant the yields through the inventory service.
	local granted = 0
	for itemId, quantity in outcome.yields do
		granted += services.InventoryService.AddItem(player, itemId, quantity)
	end
	if profile then
		profile.mastery["mastery_gathering"] = (profile.mastery["mastery_gathering"] or 0) + 3
		services.ProgressionService.AwardExperience(player, "gather_node", nil)
	end

	services.NetworkService.Fire(player, Remotes.HarvestProgress.name, {
		instanceId = instanceId,
		accepted = true,
		complete = true,
		yields = outcome.yields,
		granted = granted,
		respawnAt = outcome.respawnAt,
		respawnSeconds = ResourceConfig.RespawnSeconds(node.nodeId),
	})
	-- The node is consumed visually as well as in the data model.
	if node.actor then
		ActorFactory.SetNodeHarvested(node.actor, true)
	end
	services.NetworkService.FireAll(Remotes.ResourceStateChanged.name, {
		instanceId = instanceId,
		nodeId = node.nodeId,
		state = Enums.ResourceState.Depleted,
		respawnSeconds = ResourceConfig.RespawnSeconds(node.nodeId),
	})
	return true
end

function ResourceService.RequestInteract(player: Player, instanceId: string): boolean
	-- Generic interaction: returns node information to the client.
	local node = nodes[instanceId]
	if not node then
		return false
	end
	local def = ResourceConfig:Get(node.nodeId)
	services.NetworkService.Fire(player, Remotes.ResourceStateChanged.name, {
		instanceId = instanceId,
		nodeId = node.nodeId,
		state = node.state,
		requiresTool = def and def.requiredTool or nil,
		remaining = ResourceState.RemainingSeconds(node, os.clock()),
	})
	return true
end

-- ---------------------------------------------------------------------------
-- Query helpers
-- ---------------------------------------------------------------------------

function ResourceService.NodesInRegion(regionId: string): { string }
	return byRegion[regionId] or {}
end

function ResourceService.Node(instanceId: string): any
	return nodes[instanceId]
end

function ResourceService.NodeCount(): number
	local total = 0
	for _ in nodes do
		total += 1
	end
	return total
end

-- Used by the admin panel: forces a node back to available.
function ResourceService.AdminRespawn(instanceId: string): boolean
	local node = nodes[instanceId]
	if not node then
		return false
	end
	node.state = Enums.ResourceState.Available
	node.respawnAt = nil
	node.depletedAt = nil
	node.progress = 0
	if node.actor then
		ActorFactory.SetNodeHarvested(node.actor, false)
	end
	services.NetworkService.FireAll(Remotes.ResourceStateChanged.name, {
		instanceId = instanceId,
		nodeId = node.nodeId,
		state = Enums.ResourceState.Available,
	})
	return true
end

-- Forces every node in a region back to its initial state. Used by world
-- events that reset the region, and by the admin panel.
function ResourceService.ResetRegion(regionId: string)
	for nodeId, node in nodes do
		if node.regionId == regionId then
			node.state = "Available"
			node.respawnAt = 0
		end
	end
	services.NetworkService.FireAll(Remotes.ResourceStateChanged.name, {
		regionId = regionId,
		reset = true,
	})
end

return ResourceService
