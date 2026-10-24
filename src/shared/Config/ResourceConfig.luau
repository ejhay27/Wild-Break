--!strict
--[[
	ResourceConfig.luau
	Gathering definitions and the authoritative respawn rules.

	RULE: ordinary trees and common ore deposits regrow after EXACTLY three
	minutes (180 seconds). The value lives in Constants/Limits and is asserted
	by the automated tests. Rare and special nodes use longer configurable
	cooldowns. All timers are server-side.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type Yield = { itemId: string, min: number, max: number, chance: number? }

export type ResourceNodeDef = {
	id: string,
	displayName: string,
	kind: string,
	toolRequirement: string,
	harvestSeconds: number,
	yields: { Yield },
	respawnSeconds: number,
	respawnClass: string, -- Ordinary | Rare | Special
	regions: { string },
	biomes: { string }?,
	requiresDiving: boolean?,
	minLevel: number?,
	yieldsCoreChance: number?,
	yieldsCoreCategories: { string }?,
	interactionPrompt: string,
	description: string,
}

local function node(def: ResourceNodeDef): ResourceNodeDef
	-- Ordinary nodes always use the exact three minute rule.
	if def.respawnClass == "Ordinary" then
		def.respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds
	end
	def.harvestSeconds = math.max(Limits.Resource.MinHarvestSeconds, def.harvestSeconds)
	return def
end

local entries: { [string]: ResourceNodeDef } = {
	-- -------------------------------------------------------------------------
	-- ORDINARY: exactly 180 seconds
	-- -------------------------------------------------------------------------
	["tree_softwood"] = node({
		id = "tree_softwood",
		displayName = "Softwood Tree",
		kind = Enums.ResourceKind.Timber,
		toolRequirement = Enums.ToolRequirement.Axe,
		harvestSeconds = 2.2,
		yields = {
			{ itemId = "timber_softwood", min = 3, max = 6 },
			{ itemId = "fiber_vine", min = 1, max = 2, chance = 0.5 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Chop",
		description = "The most common tree in Verdant Reach.",
	}),
	["tree_hardwood"] = node({
		id = "tree_hardwood",
		displayName = "Hardwood Tree",
		kind = Enums.ResourceKind.Timber,
		toolRequirement = Enums.ToolRequirement.Axe,
		harvestSeconds = 3.2,
		yields = {
			{ itemId = "timber_hardwood", min = 2, max = 5 },
			{ itemId = "fiber_vine", min = 1, max = 2, chance = 0.6 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Chop",
		description = "Dense ancient hardwood.",
	}),
	["stone_outcrop"] = node({
		id = "stone_outcrop",
		displayName = "Stone Outcrop",
		kind = Enums.ResourceKind.Stone,
		toolRequirement = Enums.ToolRequirement.Pickaxe,
		harvestSeconds = 2.0,
		yields = {
			{ itemId = "stone_rubble", min = 3, max = 6 },
			{ itemId = "crystal_resonant", min = 1, max = 1, chance = 0.08 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach, Enums.RegionId.Cinderfall, Enums.RegionId.Frostveil },
		interactionPrompt = "Mine",
		description = "Common stone outcrop.",
	}),
	["ore_common"] = node({
		id = "ore_common",
		displayName = "Common Ore Deposit",
		kind = Enums.ResourceKind.Ore,
		toolRequirement = Enums.ToolRequirement.Pickaxe,
		harvestSeconds = 2.8,
		yields = {
			{ itemId = "ferrite", min = 2, max = 4 },
			{ itemId = "rootiron", min = 1, max = 3, chance = 0.6 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Mine",
		description = "The standard ore seam. Regrows exactly three minutes after depletion.",
	}),
	["herb_patch"] = node({
		id = "herb_patch",
		displayName = "Herb Patch",
		kind = Enums.ResourceKind.Plant,
		toolRequirement = Enums.ToolRequirement.None,
		harvestSeconds = 1.2,
		yields = {
			{ itemId = "herb_emeraldleaf", min = 2, max = 4 },
			{ itemId = "fiber_vine", min = 1, max = 2, chance = 0.4 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Harvest",
		description = "Common medicinal herbs.",
	}),
	["fiber_bush"] = node({
		id = "fiber_bush",
		displayName = "Fibre Bush",
		kind = Enums.ResourceKind.Fiber,
		toolRequirement = Enums.ToolRequirement.None,
		harvestSeconds = 1.0,
		yields = { { itemId = "fiber_vine", min = 3, max = 5 } },
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Harvest",
		description = "Tough fibrous bushes.",
	}),
	["mushroom_cluster"] = node({
		id = "mushroom_cluster",
		displayName = "Glowcap Cluster",
		kind = Enums.ResourceKind.Mushroom,
		toolRequirement = Enums.ToolRequirement.None,
		harvestSeconds = 1.0,
		yields = {
			{ itemId = "mushroom_glowcap", min = 2, max = 4 },
			{ itemId = "mushroom_sporepod", min = 1, max = 1, chance = 0.15 },
		},
		respawnSeconds = Limits.Resource.OrdinaryRespawnSeconds,
		respawnClass = "Ordinary",
		regions = { Enums.RegionId.VerdantReach, Enums.RegionId.UmbraExpanse },
		interactionPrompt = "Harvest",
		description = "Bioluminescent fungi growing in the shade.",
	}),

	-- -------------------------------------------------------------------------
	-- RARE: longer configurable cooldowns
	-- -------------------------------------------------------------------------
	["tree_ironwood"] = node({
		id = "tree_ironwood",
		displayName = "Ironwood Tree",
		kind = Enums.ResourceKind.Timber,
		toolRequirement = Enums.ToolRequirement.Axe,
		harvestSeconds = 4.5,
		yields = {
			{ itemId = "timber_ironwood", min = 1, max = 3 },
			{ itemId = "timber_hardwood", min = 2, max = 4 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.VerdantReach },
		minLevel = 10,
		interactionPrompt = "Chop",
		description = "Mineralised heartwood. Rare and slow to regrow.",
	}),
	["ore_regional"] = node({
		id = "ore_regional",
		displayName = "Regional Ore Seam",
		kind = Enums.ResourceKind.Ore,
		toolRequirement = Enums.ToolRequirement.Pickaxe,
		harvestSeconds = 4.0,
		yields = {
			{ itemId = "emberite", min = 1, max = 3 },
			{ itemId = "glacite", min = 1, max = 2, chance = 0.5 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.Cinderfall, Enums.RegionId.Frostveil, Enums.RegionId.UmbraExpanse, Enums.RegionId.SolaraBasin },
		minLevel = 12,
		interactionPrompt = "Mine",
		description = "Region-specific ore seam. Yields depend on where it is found.",
	}),
	["crystal_formation"] = node({
		id = "crystal_formation",
		displayName = "Resonant Crystal Formation",
		kind = Enums.ResourceKind.Crystal,
		toolRequirement = Enums.ToolRequirement.Extractor,
		harvestSeconds = 3.5,
		yields = {
			{ itemId = "crystal_resonant", min = 2, max = 4 },
			{ itemId = "energy_cell", min = 1, max = 2, chance = 0.4 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.VerdantReach, Enums.RegionId.SolaraBasin, Enums.RegionId.NullHorizon },
		minLevel = 8,
		interactionPrompt = "Extract",
		description = "Humming crystal spires.",
	}),
	["cache_facility"] = node({
		id = "cache_facility",
		displayName = "Facility Cache",
		kind = Enums.ResourceKind.Cache,
		toolRequirement = Enums.ToolRequirement.None,
		harvestSeconds = 5.0,
		yields = {
			{ itemId = "research_data", min = 1, max = 3 },
			{ itemId = "energy_cell", min = 1, max = 3, chance = 0.7 },
			{ itemId = "bp_module_experimental", min = 1, max = 1, chance = 0.05 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.VerdantReach },
		interactionPrompt = "Search",
		description = "Abandoned research cache. Searchable once per cycle.",
	}),
	["research_terminal"] = node({
		id = "research_terminal",
		displayName = "Research Terminal",
		kind = Enums.ResourceKind.ResearchSample,
		toolRequirement = Enums.ToolRequirement.Scanner,
		harvestSeconds = 6.0,
		yields = {
			{ itemId = "research_sample", min = 2, max = 5 },
			{ itemId = "research_data", min = 1, max = 2, chance = 0.5 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.VerdantReach },
		minLevel = 6,
		interactionPrompt = "Investigate",
		description = "Partially functional research terminal.",
	}),

	-- -------------------------------------------------------------------------
	-- SPECIAL: bosses, elites, events and controlled materials
	-- -------------------------------------------------------------------------
	["sap_deposit"] = node({
		id = "sap_deposit",
		displayName = "World Tree Sap Deposit",
		kind = Enums.ResourceKind.Sap,
		toolRequirement = Enums.ToolRequirement.Extractor,
		harvestSeconds = 8.0,
		yields = {
			{ itemId = "world_tree_sap", min = 1, max = 2 },
		},
		respawnSeconds = Limits.Resource.SpecialRespawnSeconds,
		respawnClass = "Special",
		regions = { Enums.RegionId.VerdantReach },
		minLevel = 30,
		interactionPrompt = "Extract",
		description = "Naturally accumulated sap. Controlled yield: the World Tree is never chopped down.",
	}),
	["sapheart"] = node({
		id = "sapheart",
		displayName = "The Sapheart",
		kind = Enums.ResourceKind.Sap,
		toolRequirement = Enums.ToolRequirement.Extractor,
		harvestSeconds = 12.0,
		yields = {
			{ itemId = "world_tree_sap", min = 3, max = 6 },
			{ itemId = "world_tree_sap_concentrate", min = 1, max = 1, chance = 0.35 },
		},
		respawnSeconds = Limits.Resource.SpecialRespawnSeconds,
		respawnClass = "Special",
		regions = { Enums.RegionId.VerdantReach },
		minLevel = 40,
		interactionPrompt = "Extract",
		description = "Only reachable after the Sapheart guardian is defeated. Rewards are validated by encounter participation.",
	}),
	["aquatic_node"] = node({
		id = "aquatic_node",
		displayName = "Shallow Reef Node",
		kind = Enums.ResourceKind.Aquatic,
		toolRequirement = Enums.ToolRequirement.DivingGear,
		harvestSeconds = 4.0,
		yields = {
			{ itemId = "mat_coral_sample", min = 2, max = 5 },
			{ itemId = "mat_abyssal_pearl", min = 1, max = 1, chance = 0.12 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = { Enums.RegionId.PelagicFrontier },
		requiresDiving = true,
		interactionPrompt = "Collect",
		description = "Underwater harvesting node.",
	}),
	["beast_carcass"] = node({
		id = "beast_carcass",
		displayName = "Beast Carcass",
		kind = Enums.ResourceKind.BeastMaterial,
		toolRequirement = Enums.ToolRequirement.Harvester,
		harvestSeconds = 3.0,
		yields = {
			{ itemId = "hide_beast", min = 1, max = 3 },
			{ itemId = "bone_beast", min = 1, max = 2, chance = 0.8 },
			{ itemId = "sinew_beast", min = 1, max = 2, chance = 0.6 },
		},
		respawnSeconds = Limits.Resource.RareRespawnSeconds,
		respawnClass = "Rare",
		regions = Enums.RegionOrder,
		interactionPrompt = "Harvest",
		description = "Harvested from a defeated beast. Only the participants' server-side loot is granted.",
	}),
}

local Resource = Registry.new("Resource", entries, { "id", "displayName", "kind" })

function Resource.RespawnSeconds(nodeId: string): number
	local def = Resource:Get(nodeId)
	if not def then
		return Limits.Resource.OrdinaryRespawnSeconds
	end
	if def.respawnClass == "Ordinary" then
		return Limits.Resource.OrdinaryRespawnSeconds
	end
	return def.respawnSeconds
end

-- Rolls a yield table on the server. `random` is passed in so tests are
-- deterministic and so the client never decides what a node drops.
function Resource.RollYields(nodeId: string, random: () -> number, luck: number?): { [string]: number }
	local def = Resource:Get(nodeId)
	if not def then
		return {}
	end
	local out: { [string]: number } = {}
	local bonus = math.clamp(luck or 0, 0, 1)
	for _, entry in def.yields do
		local chance = math.clamp((entry.chance or 1) + bonus * 0.1, 0, 1)
		if random() <= chance then
			local quantity = entry.min + math.floor(random() * (entry.max - entry.min + 1))
			if quantity > 0 then
				out[entry.itemId] = (out[entry.itemId] or 0) + quantity
			end
		end
	end
	return out
end

function Resource.ByRegion(regionId: string): { ResourceNodeDef }
	return Resource:Filter(function(def)
		return table.find(def.regions, regionId) ~= nil
	end)
end

function Resource.ValidateAll(): { string }
	local problems = Registry.Validate(Resource)
	for _, def in Resource:List() do
		if not Enums.ResourceKind[def.kind] then
			table.insert(problems, string.format("[Resource] %s has unknown kind %q", def.id, tostring(def.kind)))
		end
		if not Enums.ToolRequirement[def.toolRequirement] then
			table.insert(problems, string.format("[Resource] %s has unknown tool requirement %q", def.id, tostring(def.toolRequirement)))
		end
		if def.respawnClass == "Ordinary" and def.respawnSeconds ~= Limits.Resource.OrdinaryRespawnSeconds then
			table.insert(problems, string.format("[Resource] ordinary node %s does not use the 180 second rule", def.id))
		end
		if #def.yields == 0 then
			table.insert(problems, string.format("[Resource] %s has no yields", def.id))
		end
	end
	return problems
end

Resource.Registry = Resource
return Resource
