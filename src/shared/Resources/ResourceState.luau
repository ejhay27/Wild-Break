--!strict
--[[
	ResourceState.luau
	Lifecycle of a single gathering node in the world.

	The server owns every node: it decides when a node depletes, when it
	respawns and what it yields. The client only ever sends "I am interacting
	with node X"; the harvest timer and the roll happen here.

	Ordinary nodes respawn in exactly Limits.Resource.OrdinaryRespawnSeconds
	(180 seconds / 3 minutes) from the moment they are depleted. The value is
	read from ResourceConfig, never hard-coded here, so the single source of
	truth stays the configuration.
]]

local Resources = require(script.Parent.Parent.Config.ResourceConfig)
local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local ResourceState = {}

export type NodeState = {
	nodeId: string,
	state: string,
	-- Depletion time. nil while the node is available.
	depletedAt: number?,
	respawnAt: number?,
	-- Harvest bookkeeping.
	harvestedBy: { [number]: boolean },
	progress: number,
	lastHarvestAt: number?,
	-- How many times this node has been harvested since the server started.
	harvestCount: number,
	-- Server-assigned identity of this specific node instance.
	instanceId: string,
}

function ResourceState.New(nodeId: string, instanceId: string): NodeState
	return {
		nodeId = nodeId,
		state = Enums.ResourceState.Available,
		depletedAt = nil,
		respawnAt = nil,
		harvestedBy = {},
		progress = 0,
		lastHarvestAt = nil,
		harvestCount = 0,
		instanceId = instanceId,
	}
end

function ResourceState.IsAvailable(node: NodeState, now: number): boolean
	if node.state == Enums.ResourceState.Depleted then
		return now >= (node.respawnAt or math.huge)
	end
	return node.state == Enums.ResourceState.Available
end

function ResourceState.HarvestSeconds(nodeId: string): number
	local def = Resources:Get(nodeId)
	if not def then
		return 1
	end
	return math.max(0.1, def.harvestTime or 1)
end

-- Seconds until the node comes back; 0 when it is already available.
function ResourceState.RemainingSeconds(node: NodeState, now: number): number
	if node.state ~= Enums.ResourceState.Depleted then
		return 0
	end
	return math.max(0, (node.respawnAt or now) - now)
end

-- Advances a harvest. `rateMultiplier` comes from the player's tool, mastery
-- and buffs, and is always validated by the caller.
function ResourceState.Harvest(node: NodeState, now: number, deltaSeconds: number, rateMultiplier: number?): boolean
	if node.state ~= Enums.ResourceState.Available then
		return false
	end
	local rate = math.clamp(rateMultiplier or 1, 0.1, 10)
	local needed = ResourceState.HarvestSeconds(node.nodeId)
	node.progress += deltaSeconds * rate
	if node.progress < needed then
		return false
	end
	return true
end

-- Depletes the node and schedules its respawn. Returns the yields rolled by
-- the supplied RNG so the caller can grant them through the inventory.
function ResourceState.Deplete(node: NodeState, now: number, random: () -> number, luck: number?): { [string]: number }
	node.state = Enums.ResourceState.Depleted
	node.depletedAt = now
	node.progress = 0
	node.harvestCount += 1
	node.lastHarvestAt = now
	node.respawnAt = now + Resources.RespawnSeconds(node.nodeId)
	return Resources.RollYields(node.nodeId, random, luck)
end

-- Brings depleted nodes back. Returns the nodes that respawned this tick.
function ResourceState.Update(nodes: { NodeState }, now: number): { NodeState }
	local respawned = {}
	for _, node in nodes do
		if node.state == Enums.ResourceState.Depleted and now >= (node.respawnAt or math.huge) then
			node.state = Enums.ResourceState.Available
			node.depletedAt = nil
			node.respawnAt = nil
			node.progress = 0
			node.harvestedBy = {}
			table.insert(respawned, node)
		end
	end
	return respawned
end

-- A full interaction helper used by the server: harvest, deplete, roll.
-- Returns nil when the node cannot be harvested right now.
function ResourceState.TryHarvest(
	node: NodeState,
	now: number,
	deltaSeconds: number,
	rateMultiplier: number?,
	random: () -> number,
	luck: number?
): { yields: { [string]: number }, respawnAt: number }?
	if not ResourceState.IsAvailable(node, now) then
		return nil
	end
	if not ResourceState.Harvest(node, now, deltaSeconds, rateMultiplier) then
		return nil
	end
	local yields = ResourceState.Deplete(node, now, random, luck)
	return { yields = yields, respawnAt = node.respawnAt or now }
end

function ResourceState.ValidateAll(): { string }
	local problems = {}
	-- Ordinary nodes must respawn in exactly three minutes.
	local ordinary = Resources:Filter(function(def)
		return def.respawnClass == "Ordinary"
	end)
	if #ordinary == 0 then
		table.insert(problems, "[ResourceState] no ordinary nodes exist")
	end
	for _, def in ordinary do
		local node = ResourceState.New(def.id, "test_" .. def.id)
		local now = 1000
		ResourceState.Deplete(node, now, function()
			return 0.5
		end, 0)
		local remaining = ResourceState.RemainingSeconds(node, now)
		if remaining ~= Limits.Resource.OrdinaryRespawnSeconds then
			table.insert(problems, string.format("[ResourceState] %s respawns in %.0fs, expected %d", def.id, remaining, Limits.Resource.OrdinaryRespawnSeconds))
		end
		if Limits.Resource.OrdinaryRespawnSeconds ~= 180 then
			table.insert(problems, string.format("[ResourceState] ordinary respawn is %ds, the design requires 180", Limits.Resource.OrdinaryRespawnSeconds))
		end
		if ResourceState.IsAvailable(node, now) then
			table.insert(problems, string.format("[ResourceState] %s is available immediately after depletion", def.id))
		end
		if ResourceState.IsAvailable(node, now + 179) then
			table.insert(problems, string.format("[ResourceState] %s respawned early", def.id))
		end
		if not ResourceState.IsAvailable(node, now + 180) then
			table.insert(problems, string.format("[ResourceState] %s did not respawn on time", def.id))
		end
		local respawned = ResourceState.Update({ node }, now + 180)
		if #respawned ~= 1 then
			table.insert(problems, string.format("[ResourceState] %s was not reported as respawned", def.id))
		end
		if node.harvestCount ~= 1 then
			table.insert(problems, string.format("[ResourceState] %s harvest count is wrong", def.id))
		end
	end

	-- Harvest timing.
	local node = ResourceState.New("tree_softwood", "test_timber")
	if ResourceState.Harvest(node, 0, 0.1, 1) then
		table.insert(problems, "[ResourceState] a node completed instantly")
	end
	local needed = ResourceState.HarvestSeconds("tree_softwood")
	if not ResourceState.Harvest(node, 0, needed * 2, 1) then
		table.insert(problems, "[ResourceState] a full harvest did not complete")
	end

	-- A depleted node cannot be harvested again.
	local depleted = ResourceState.New("ore_common", "test_ore")
	ResourceState.Deplete(depleted, 0, function()
		return 0.5
	end, 0)
	if ResourceState.TryHarvest(depleted, 1, 10, 1, function()
		return 0.5
	end, 0) ~= nil then
		table.insert(problems, "[ResourceState] a depleted node was harvested again")
	end

	-- Yields must be non-negative integers.
	for _ = 1, 40 do
		local yields = ResourceState.Deplete(ResourceState.New("ore_common", "t"), 0, function()
			return 0.5
		end, 0)
		for itemId, quantity in yields do
			if type(itemId) ~= "string" or quantity < 1 or math.floor(quantity) ~= quantity then
				table.insert(problems, string.format("[ResourceState] invalid yield %s x%s", tostring(itemId), tostring(quantity)))
			end
		end
	end

	return problems
end

return ResourceState
