--!strict
--[[
	OreConfig.luau
	Ore registry with ranks (C..X) and tiers (1..5).

	Rank  = broad classification of the mineral.
	Tier  = grade inside that classification.
	Region determines where an ore occurs and how common it is; deposit
	quality influences yield, but all yield maths happens on the server.
]]

local Registry = require(script.Parent.Registry)
local Enums = require(script.Parent.Parent.Constants.Enums)

export type OreDef = {
	id: string,
	displayName: string,
	rank: string,
	minTier: number,
	maxTier: number,
	element: string,
	regions: { [string]: number },
	color: { number },
	baseYield: number,
	yieldPerTier: number,
	hardness: number,
	toolRequirement: string,
	uses: { string },
	description: string,
}

local function ore(def: OreDef): OreDef
	return def
end

local entries: { [string]: OreDef } = {
	ferrite = ore({
		id = "ferrite",
		displayName = "Ferrite",
		rank = "C",
		minTier = 1,
		maxTier = 3,
		element = "Forest",
		regions = { VerdantReach = 100, Cinderfall = 40, Frostveil = 35, PelagicFrontier = 30 },
		color = { 0.55, 0.50, 0.46 },
		baseYield = 3,
		yieldPerTier = 1,
		hardness = 1,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Attachments", "Construction" },
		description = "Soft iron-rich ore. The backbone of every outpost workshop.",
	}),
	rootiron = ore({
		id = "rootiron",
		displayName = "Rootiron",
		rank = "C",
		minTier = 1,
		maxTier = 3,
		element = "Forest",
		regions = { VerdantReach = 80 },
		color = { 0.42, 0.52, 0.33 },
		baseYield = 3,
		yieldPerTier = 1,
		hardness = 1,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Construction" },
		description = "Iron mineralised inside ancient root networks.",
	}),
	emberite = ore({
		id = "emberite",
		displayName = "Emberite",
		rank = "B",
		minTier = 1,
		maxTier = 4,
		element = "Fire",
		regions = { Cinderfall = 100, VerdantReach = 12 },
		color = { 0.85, 0.35, 0.15 },
		baseYield = 3,
		yieldPerTier = 1.2,
		hardness = 2,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Evolution", "Research" },
		description = "Still warm to the touch. Stores geothermal energy.",
	}),
	glacite = ore({
		id = "glacite",
		displayName = "Glacite",
		rank = "B",
		minTier = 1,
		maxTier = 4,
		element = "Ice",
		regions = { Frostveil = 100 },
		color = { 0.62, 0.85, 0.98 },
		baseYield = 3,
		yieldPerTier = 1.2,
		hardness = 2,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Evolution", "Research" },
		description = "Crystalline ore that resists thermal shock.",
	}),
	umbralith = ore({
		id = "umbralith",
		displayName = "Umbralith",
		rank = "A",
		minTier = 2,
		maxTier = 5,
		element = "Dark",
		regions = { UmbraExpanse = 100, NullHorizon = 25 },
		color = { 0.20, 0.17, 0.28 },
		baseYield = 2,
		yieldPerTier = 1.1,
		hardness = 3,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Modules", "Research" },
		description = "Absorbs light. Used in concealment hardware.",
	}),
	heliosite = ore({
		id = "heliosite",
		displayName = "Heliosite",
		rank = "A",
		minTier = 2,
		maxTier = 5,
		element = "Light",
		regions = { SolaraBasin = 100 },
		color = { 1.0, 0.88, 0.45 },
		baseYield = 2,
		yieldPerTier = 1.1,
		hardness = 3,
		toolRequirement = "Pickaxe",
		uses = { "WeaponCrafting", "Modules", "Evolution" },
		description = "Photonic mineral that slowly glows in daylight.",
	}),
	pelagite = ore({
		id = "pelagite",
		displayName = "Pelagite",
		rank = "A",
		minTier = 2,
		maxTier = 5,
		element = "Water",
		regions = { PelagicFrontier = 100 },
		color = { 0.16, 0.62, 0.80 },
		baseYield = 2,
		yieldPerTier = 1.1,
		hardness = 3,
		toolRequirement = "Extractor",
		uses = { "WeaponCrafting", "Boats", "Equipment" },
		description = "Pressure-formed seabed alloy. Essential for hulls.",
	}),
	voidshard = ore({
		id = "voidshard",
		displayName = "Voidshard",
		rank = "S",
		minTier = 3,
		maxTier = 5,
		element = "Void",
		regions = { NullHorizon = 100 },
		color = { 0.55, 0.32, 0.90 },
		baseYield = 1,
		yieldPerTier = 0.9,
		hardness = 4,
		toolRequirement = "Extractor",
		uses = { "WeaponCrafting", "Evolution", "Modules" },
		description = "Holds its shape only while observed.",
	}),
	aurumite = ore({
		id = "aurumite",
		displayName = "Aurumite",
		rank = "S",
		minTier = 3,
		maxTier = 5,
		element = "Light",
		regions = { SolaraBasin = 45, Cinderfall = 30, PelagicFrontier = 20 },
		color = { 0.98, 0.80, 0.28 },
		baseYield = 1,
		yieldPerTier = 0.9,
		hardness = 4,
		toolRequirement = "Pickaxe",
		uses = { "Evolution", "Cosmetics", "Research" },
		description = "Noble alloy used for ceremonial and prismatic hardware.",
	}),
	titanite = ore({
		id = "titanite",
		displayName = "Titanite",
		rank = "S",
		minTier = 3,
		maxTier = 5,
		element = "Fire",
		regions = { Cinderfall = 55, Frostveil = 40, UmbraExpanse = 30 },
		color = { 0.70, 0.72, 0.78 },
		baseYield = 1,
		yieldPerTier = 0.9,
		hardness = 5,
		toolRequirement = "Pickaxe",
		uses = { "Armor", "Construction", "Boats" },
		description = "Structural ore for armor plating and heavy hulls.",
	}),
	cryonix = ore({
		id = "cryonix",
		displayName = "Cryonix",
		rank = "SS",
		minTier = 4,
		maxTier = 5,
		element = "Ice",
		regions = { Frostveil = 40, NullHorizon = 25 },
		color = { 0.75, 0.95, 1.0 },
		baseYield = 1,
		yieldPerTier = 0.7,
		hardness = 5,
		toolRequirement = "Extractor",
		uses = { "Evolution", "Modules", "Research" },
		description = "Near-absolute-zero lattice used in cooling modules.",
	}),
	infernium = ore({
		id = "infernium",
		displayName = "Infernium",
		rank = "SS",
		minTier = 4,
		maxTier = 5,
		element = "Fire",
		regions = { Cinderfall = 40, SolaraBasin = 20 },
		color = { 1.0, 0.45, 0.12 },
		baseYield = 1,
		yieldPerTier = 0.7,
		hardness = 5,
		toolRequirement = "Extractor",
		uses = { "Evolution", "Modules" },
		description = "Molten core alloy, stable only inside forged barrels.",
	}),
	abyssite = ore({
		id = "abyssite",
		displayName = "Abyssite",
		rank = "SS",
		minTier = 4,
		maxTier = 5,
		element = "Water",
		regions = { PelagicFrontier = 40 },
		color = { 0.12, 0.45, 0.62 },
		baseYield = 1,
		yieldPerTier = 0.7,
		hardness = 5,
		toolRequirement = "Extractor",
		uses = { "Evolution", "Boats", "Equipment" },
		description = "Trench-pressure mineral.never survives careless handling.",
	}),
	nullite = ore({
		id = "nullite",
		displayName = "Nullite",
		rank = "X",
		minTier = 5,
		maxTier = 5,
		element = "Void",
		regions = { NullHorizon = 45 },
		color = { 0.35, 0.18, 0.55 },
		baseYield = 1,
		yieldPerTier = 0.5,
		hardness = 6,
		toolRequirement = "Extractor",
		uses = { "Evolution", "Modules", "Research" },
		description = "Anomalous mineral recovered from fractured space.",
	}),
	sapcrystal = ore({
		id = "sapcrystal",
		displayName = "Sapcrystal",
		rank = "X",
		minTier = 5,
		maxTier = 5,
		element = "Forest",
		regions = { VerdantReach = 30 },
		color = { 0.45, 0.95, 0.55 },
		baseYield = 1,
		yieldPerTier = 0.5,
		hardness = 6,
		toolRequirement = "Extractor",
		uses = { "Evolution", "Modules", "SapCrafting" },
		description = "Crystallised World Tree sap from the deep roots.",
	}),
}

local Ore = Registry.new("Ore", entries, { "id", "displayName", "rank", "minTier" })

function Ore.Yield(oreId: string, tier: number, depositQuality: number?): number
	local def = Ore:Get(oreId)
	if not def then
		return 0
	end
	local clampedTier = math.clamp(math.floor(tier), def.minTier, def.maxTier)
	local quality = math.clamp(depositQuality or 1, 0.5, 2.0)
	return math.max(1, math.floor((def.baseYield + (clampedTier - 1) * def.yieldPerTier) * quality))
end

function Ore.RankLabel(oreId: string, tier: number): string
	local def = Ore:Get(oreId)
	if not def then
		return "Unknown"
	end
	return string.format("%s-Rank Tier %d", def.rank, math.clamp(math.floor(tier), def.minTier, def.maxTier))
end

function Ore.ByRegion(regionId: string): { OreDef }
	return Ore:Filter(function(def)
		return (def.regions[regionId] or 0) > 0
	end)
end

-- Weighted roll for a region, returning an ore id and a tier.
function Ore.RollForRegion(regionId: string, random: number?, regionTierBonus: number?): (string?, number)
	local candidates = Ore.ByRegion(regionId)
	if #candidates == 0 then
		return nil, 1
	end
	local total = 0
	for _, def in candidates do
		total += def.regions[regionId] or 0
	end
	local roll = (random or math.random()) * total
	local cumulative = 0
	for _, def in candidates do
		cumulative += def.regions[regionId] or 0
		if roll <= cumulative then
			local bonus = regionTierBonus or 0
			local tier = math.clamp(def.minTier + math.floor((random or math.random()) * (def.maxTier - def.minTier + 1)) + bonus, def.minTier, def.maxTier)
			return def.id, tier
		end
	end
	local last = candidates[#candidates]
	return last.id, last.minTier
end

function Ore.ValidateAll(): { string }
	local problems = Registry.Validate(Ore)
	for _, def in Ore:List() do
		if not Enums.IsValidRank(def.rank) then
			table.insert(problems, string.format("[Ore] %s has invalid rank %q", def.id, tostring(def.rank)))
		end
		if not Enums.IsValidTier(def.minTier) or not Enums.IsValidTier(def.maxTier) then
			table.insert(problems, string.format("[Ore] %s has invalid tier range", def.id))
		end
		if def.maxTier < def.minTier then
			table.insert(problems, string.format("[Ore] %s maxTier below minTier", def.id))
		end
	end
	return problems
end

Ore.Registry = Ore
return Ore
