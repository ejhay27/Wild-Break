--!strict
--[[
	RarityConfig.luau
	Weapon / item rarity, star structure and stat scaling.

	Rarity is a classification, NOT a damage multiplier by itself. Stars are
	progression steps inside a rarity and also are not raw multipliers: they
	feed the configurable curve below, which intentionally has diminishing
	returns so high rarity opens possibilities instead of deleting every
	lower-rarity weapon.
]]

local Registry = require(script.Parent.Registry)
local Enums = require(script.Parent.Parent.Constants.Enums)

export type RarityDef = {
	id: string,
	displayName: string,
	order: number,
	stars: number,
	color: { number },
	-- Multiplier applied to a weapon's base stats at zero stars.
	baseMultiplier: number,
	-- Additional multiplier per star (diminishing).
	perStarMultiplier: number,
	-- Extra attachment / module capacity granted by the rarity.
	moduleSlots: number,
	weight: number,
	description: string,
}

local entries: { [string]: RarityDef } = {
	Common = {
		id = "Common",
		displayName = "Common",
		order = 1,
		stars = 1,
		color = { 0.72, 0.75, 0.78 },
		baseMultiplier = 1.0,
		perStarMultiplier = 0.0,
		moduleSlots = 0,
		weight = 1000,
		description = "Standard issue. Reliable and easy to maintain.",
	},
	Rare = {
		id = "Rare",
		displayName = "Rare",
		order = 2,
		stars = 2,
		color = { 0.30, 0.62, 0.95 },
		baseMultiplier = 1.04,
		perStarMultiplier = 0.008,
		moduleSlots = 0,
		weight = 520,
		description = "Field-tuned variants recovered from expeditions.",
	},
	Epic = {
		id = "Epic",
		displayName = "Epic",
		order = 3,
		stars = 3,
		color = { 0.62, 0.35, 0.95 },
		baseMultiplier = 1.09,
		perStarMultiplier = 0.009,
		moduleSlots = 1,
		weight = 210,
		description = "Purple-tier hardware with one experimental module slot.",
	},
	Legendary = {
		id = "Legendary",
		displayName = "Legendary",
		order = 4,
		stars = 6,
		color = { 0.98, 0.68, 0.16 },
		baseMultiplier = 1.16,
		perStarMultiplier = 0.0075,
		moduleSlots = 1,
		weight = 70,
		description = "Beast-forged weaponry with signature behaviour.",
	},
	Mythical = {
		id = "Mythical",
		displayName = "Mythical",
		order = 5,
		stars = 8,
		color = { 0.98, 0.24, 0.36 },
		baseMultiplier = 1.24,
		perStarMultiplier = 0.0065,
		moduleSlots = 2,
		weight = 22,
		description = "Salvaged apex technology. Two module slots.",
	},
	Prismatic = {
		id = "Prismatic",
		displayName = "Prismatic",
		order = 6,
		stars = 10,
		color = { 0.20, 0.95, 0.85 },
		baseMultiplier = 1.32,
		perStarMultiplier = 0.0055,
		moduleSlots = 2,
		weight = 6,
		description = "Refracted-core weapons tuned at the Helios stations.",
	},
	Unknown = {
		id = "Unknown",
		displayName = "Unknown",
		order = 7,
		stars = 1,
		color = { 0.10, 0.10, 0.12 },
		baseMultiplier = 1.0,
		perStarMultiplier = 0.0,
		moduleSlots = 3,
		weight = 1,
		description = "Unclassified. A single star of Unknown can outclass Prismatic in its specialised role.",
	},
}

local Rarity = Registry.new("Rarity", entries, { "id", "displayName", "stars" })

function Rarity.MaxStars(rarityId: string): number
	local def = Rarity:Get(rarityId)
	if not def then
		return 1
	end
	return def.stars
end

function Rarity.Color(rarityId: string): Color3
	local def = Rarity:Get(rarityId) or (Rarity:Get("Common") :: RarityDef)
	return Color3.new(def.color[1], def.color[2], def.color[3])
end

function Rarity.SortKey(rarityId: string): number
	local def = Rarity:Get(rarityId)
	return def and def.order or 0
end

-- Star multiplier with diminishing returns. Unknown weapons intentionally
-- ignore the curve and instead rely on their specialised base stats.
function Rarity.StatMultiplier(rarityId: string, stars: number): number
	local def = Rarity:Get(rarityId)
	if not def then
		return 1
	end
	if rarityId == Enums.Rarity.Unknown then
		return 1
	end
	local clampedStars = math.clamp(math.floor(stars or 0), 0, def.stars)
	local diminishing = 0
	for index = 1, clampedStars do
		-- Later stars are worth slightly less than earlier ones.
		diminishing += def.perStarMultiplier * (1 - (index - 1) * 0.045)
	end
	return def.baseMultiplier + diminishing
end

function Rarity.ModuleSlots(rarityId: string): number
	local def = Rarity:Get(rarityId)
	return def and def.moduleSlots or 0
end

function Rarity.Order(): { string }
	return Enums.RarityOrder
end

function Rarity.ValidateAll(): { string }
	local problems = Registry.Validate(Rarity)
	local seenOrder: { [number]: string } = {}
	for _, def in Rarity:List() do
		if def.stars < 1 then
			table.insert(problems, string.format("[Rarity] %s needs at least one star", def.id))
		end
		if def.baseMultiplier <= 0 then
			table.insert(problems, string.format("[Rarity] %s has a non-positive base multiplier", def.id))
		end
		if def.perStarMultiplier < 0 then
			table.insert(problems, string.format("[Rarity] %s has a negative per-star multiplier", def.id))
		end
		if #def.color ~= 3 then
			table.insert(problems, string.format("[Rarity] %s needs a 3 component colour", def.id))
		end
		if seenOrder[def.order] then
			table.insert(
				problems,
				string.format("[Rarity] %s and %s share order %d", seenOrder[def.order], def.id, def.order)
			)
		end
		seenOrder[def.order] = def.id
		if def.weight <= 0 then
			table.insert(problems, string.format("[Rarity] %s has a non-positive drop weight", def.id))
		end
	end
	for _, rarityId in ipairs(Enums.RarityOrder) do
		if not Rarity:Has(rarityId) then
			table.insert(problems, string.format("[Rarity] RarityOrder references unknown rarity %s", tostring(rarityId)))
		end
	end
	return problems
end

Rarity.Registry = Rarity
return Rarity
