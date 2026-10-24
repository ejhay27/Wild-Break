--!strict
--[[
	ItemConfig.luau
	Every non-weapon item in WILDBREAK: materials, ores (see OreConfig for
	the mineral registry itself), Beast Cores, consumables, blueprints,
	equipment, boats, companion eggs, research items and cosmetics.

	`stackSize` is enforced by the server inventory: clients may request a
	quantity but the server clamps and rejects overflow.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type ItemDef = {
	id: string,
	displayName: string,
	itemType: string,
	rarity: string,
	stackSize: number,
	weight: number, -- inventory "bulk" used for capacity calculations
	region: string?,
	description: string,
	consumable: { effects: { [string]: any }, cooldown: number }?,
	value: number?,
	tags: { string }?,
}

local function item(def: ItemDef): ItemDef
	def.stackSize = def.stackSize or Limits.Inventory.DefaultStackSize
	def.weight = def.weight or 0.1
	def.rarity = def.rarity or Enums.Rarity.Common
	return def
end

local M = Enums.ItemType.Material
local C = Enums.ItemType.Consumable
local B = Enums.ItemType.Blueprint
local E = Enums.ItemType.Equipment

local entries: { [string]: ItemDef } = {
	-- -------------------------------------------------------------------------
	-- Raw materials: timber, stone, fibre, plants, fungi, animal
	-- -------------------------------------------------------------------------
	["timber_softwood"] = item({ id = "timber_softwood", displayName = "Softwood Timber", itemType = M, description = "Fast-growing timber from the Verdant Reach lowlands." }),
	["timber_hardwood"] = item({ id = "timber_hardwood", displayName = "Hardwood Timber", itemType = M, weight = 0.2, description = "Dense timber from ancient giant trees." }),
	["timber_ironwood"] = item({ id = "timber_ironwood", displayName = "Ironwood Timber", itemType = M, rarity = Enums.Rarity.Rare, weight = 0.3, description = "Mineralised heartwood used in weapon stocks." }),
	["stone_rubble"] = item({ id = "stone_rubble", displayName = "Stone Rubble", itemType = M, description = "Common building stone." }),
	["stone_dressed"] = item({ id = "stone_dressed", displayName = "Dressed Stone", itemType = M, weight = 0.2, description = "Cut and finished stone for structures." }),
	["fiber_vine"] = item({ id = "fiber_vine", displayName = "Vine Fibre", itemType = M, description = "Tough plant fibre." }),
	["fiber_silk"] = item({ id = "fiber_silk", displayName = "Silkworm Silk", itemType = M, rarity = Enums.Rarity.Rare, description = "Spun silk harvested from forest nests." }),
	["herb_emeraldleaf"] = item({ id = "herb_emeraldleaf", displayName = "Emeraldleaf", itemType = M, description = "Common medicinal herb." }),
	["herb_ashbloom"] = item({ id = "herb_ashbloom", displayName = "Ashbloom", itemType = M, region = Enums.RegionId.Cinderfall, rarity = Enums.Rarity.Rare, description = "Volcanic flower used in heat resistance salves." }),
	["herb_frostlily"] = item({ id = "herb_frostlily", displayName = "Frostlily", itemType = M, region = Enums.RegionId.Frostveil, rarity = Enums.Rarity.Rare, description = "Glacial bloom used in cold resistance salves." }),
	["mushroom_glowcap"] = item({ id = "mushroom_glowcap", displayName = "Glowcap", itemType = M, description = "Bioluminescent fungus from shaded groves." }),
	["mushroom_sporepod"] = item({ id = "mushroom_sporepod", displayName = "Sporepod", itemType = M, rarity = Enums.Rarity.Rare, description = "Pressurised spore sac used in bio ammunition." }),
	["hide_beast"] = item({ id = "hide_beast", displayName = "Beast Hide", itemType = M, description = "Tanned hide from ordinary beasts." }),
	["hide_apex"] = item({ id = "hide_apex", displayName = "Apex Hide", itemType = M, rarity = Enums.Rarity.Epic, weight = 0.4, description = "Armour-grade hide from an apex predator." }),
	["bone_beast"] = item({ id = "bone_beast", displayName = "Beast Bone", itemType = M, description = "Dense beast bone used in grips and stocks." }),
	["sinew_beast"] = item({ id = "sinew_beast", displayName = "Beast Sinew", itemType = M, description = "Elastic sinew used for bowstrings and bindings." }),
	["crystal_resonant"] = item({ id = "crystal_resonant", displayName = "Resonant Crystal", itemType = M, rarity = Enums.Rarity.Rare, description = "Humming crystal used in energy ammunition." }),

	-- -------------------------------------------------------------------------
	-- Regional materials
	-- -------------------------------------------------------------------------
	["mat_ember_ash"] = item({ id = "mat_ember_ash", displayName = "Ember Ash", itemType = M, region = Enums.RegionId.Cinderfall, description = "Volcanic ash packed with thermal energy." }),
	["mat_obsidian_shard"] = item({ id = "mat_obsidian_shard", displayName = "Obsidian Shard", itemType = M, region = Enums.RegionId.Cinderfall, rarity = Enums.Rarity.Rare, description = "Volcanic glass sharp enough to be a weapon edge." }),
	["mat_glacial_ice"] = item({ id = "mat_glacial_ice", displayName = "Glacial Ice", itemType = M, region = Enums.RegionId.Frostveil, description = "Compressed ancient ice." }),
	["mat_frost_shard"] = item({ id = "mat_frost_shard", displayName = "Frost Shard", itemType = M, region = Enums.RegionId.Frostveil, rarity = Enums.Rarity.Rare, description = "Crystallised cold that never fully melts." }),
	["mat_umbral_resin"] = item({ id = "mat_umbral_resin", displayName = "Umbral Resin", itemType = M, region = Enums.RegionId.UmbraExpanse, rarity = Enums.Rarity.Rare, description = "Light-absorbing resin from the shadowed valleys." }),
	["mat_void_essence"] = item({ id = "mat_void_essence", displayName = "Void Essence", itemType = M, region = Enums.RegionId.NullHorizon, rarity = Enums.Rarity.Epic, description = "Condensed anomaly energy. Handle with containment protocols." }),
	["mat_solar_alloy"] = item({ id = "mat_solar_alloy", displayName = "Solar Alloy", itemType = M, region = Enums.RegionId.SolaraBasin, rarity = Enums.Rarity.Epic, description = "Photonic alloy that stores sunlight." }),
	["mat_coral_sample"] = item({ id = "mat_coral_sample", displayName = "Coral Sample", itemType = M, region = Enums.RegionId.PelagicFrontier, description = "Marine sample from the shallow reefs." }),
	["mat_abyssal_pearl"] = item({ id = "mat_abyssal_pearl", displayName = "Abyssal Pearl", itemType = M, region = Enums.RegionId.PelagicFrontier, rarity = Enums.Rarity.Epic, description = "Pressure-formed pearl from the deep trenches." }),
	["mat_biolab_culture"] = item({ id = "mat_biolab_culture", displayName = "Biolab Culture", itemType = M, region = Enums.RegionId.VerdantReach, rarity = Enums.Rarity.Rare, description = "Living culture recovered from the Overgrowth Biolab." }),

	-- -------------------------------------------------------------------------
	-- Research, energy and sap
	-- -------------------------------------------------------------------------
	["research_data"] = item({ id = "research_data", displayName = "Research Data", itemType = Enums.ItemType.ResearchItem, rarity = Enums.Rarity.Rare, description = "Recovered research data. Spend it at the research station." }),
	["research_sample"] = item({ id = "research_sample", displayName = "Research Sample", itemType = Enums.ItemType.ResearchItem, description = "Field sample for the research station." }),
	["energy_cell"] = item({ id = "energy_cell", displayName = "Energy Cell", itemType = M, description = "Standard energy cell for gadgets and modules." }),
	["energy_core_high"] = item({ id = "energy_core_high", displayName = "High-Density Energy Core", itemType = M, rarity = Enums.Rarity.Epic, description = "Dense core used in experimental modules." }),
	["world_tree_sap"] = item({
		id = "world_tree_sap",
		displayName = "World Tree Sap",
		itemType = Enums.ItemType.Sap,
		rarity = Enums.Rarity.Legendary,
		stackSize = 99,
		weight = 0.5,
		description = "Rare sap used for the highest tier crafting, weapon evolution and experimental modules.",
		tags = { "Rootfall", "Controlled" },
	}),
	["world_tree_sap_concentrate"] = item({
		id = "world_tree_sap_concentrate",
		displayName = "Sap Concentrate",
		itemType = Enums.ItemType.Sap,
		rarity = Enums.Rarity.Mythical,
		stackSize = 25,
		weight = 1,
		description = "Refined World Tree sap. Required for Prismatic evolution paths.",
		tags = { "Rootfall", "Controlled" },
	}),

	-- -------------------------------------------------------------------------
	-- Beast Cores
	-- -------------------------------------------------------------------------
	["core_wild_shard"] = item({ id = "core_wild_shard", displayName = "Wild Core Shard", itemType = Enums.ItemType.BeastCore, rarity = Enums.Rarity.Rare, description = "Fragment of a Wild Core.", tags = { "Core", "Wild" } }),
	["core_wild"] = item({ id = "core_wild", displayName = "Wild Core", itemType = Enums.ItemType.BeastCore, rarity = Enums.Rarity.Rare, description = "General crafting and research core.", tags = { "Core", "Wild" } }),
	["core_resonance"] = item({ id = "core_resonance", displayName = "Resonance Core", itemType = Enums.ItemType.BeastCore, rarity = Enums.Rarity.Epic, description = "Energy and disruption upgrades.", tags = { "Core", "Resonance" } }),
	["core_apex"] = item({ id = "core_apex", displayName = "Apex Core", itemType = Enums.ItemType.BeastCore, rarity = Enums.Rarity.Legendary, description = "Elite and boss upgrades.", tags = { "Core", "Apex" } }),
	["core_anomaly"] = item({ id = "core_anomaly", displayName = "Anomaly Core", itemType = Enums.ItemType.BeastCore, rarity = Enums.Rarity.Mythical, description = "Rare evolution and experimental variants.", tags = { "Core", "Anomaly" } }),

	-- -------------------------------------------------------------------------
	-- Beast / boss materials
	-- -------------------------------------------------------------------------
	["mat_thornmaw_bark"] = item({ id = "mat_thornmaw_bark", displayName = "Thornmaw Bark", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Legendary, description = "Mineralised bark from Thornmaw.", tags = { "Boss:thornmaw" } }),
	["mat_pyraxis_scale"] = item({ id = "mat_pyraxis_scale", displayName = "Pyraxis Scale", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Legendary, description = "Eclipse-warmed scale from Pyr axis.", tags = { "Boss:pyraxis" } }),
	["mat_glacieron_core"] = item({ id = "mat_glacieron_core", displayName = "Glacieron Core Shard", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Legendary, description = "Frozen core fragment from Glacieron.", tags = { "Boss:glacieron" } }),
	["mat_noctyra_veil"] = item({ id = "mat_noctyra_veil", displayName = "Noctyra Veil", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Legendary, description = "A strip of living shadow.", tags = { "Boss:noctyra" } }),
	["mat_aurion_feather"] = item({ id = "mat_aurion_feather", displayName = "Aurion Feather", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Mythical, description = "A feather from the Sunheart Colossus.", tags = { "Boss:light_samurai" } }),
	["mat_abyssalith_plate"] = item({ id = "mat_abyssalith_plate", displayName = "Abyssalith Plate", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Mythical, description = "Armour plate from the Deepwater Sovereign.", tags = { "Boss:abyssalith" } }),
	["mat_parallax_fragment"] = item({ id = "mat_parallax_fragment", displayName = "Parallax Fragment", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Mythical, description = "A fragment of distorted space.", tags = { "Boss:parallax" } }),
	["mat_elder_veyl_root"] = item({ id = "mat_elder_veyl_root", displayName = "Elder Veyl Root", itemType = Enums.ItemType.BossMaterial, rarity = Enums.Rarity.Mythical, description = "Living root from the Guardian of the Sapheart.", tags = { "Boss:elder_veyl" } }),

	-- -------------------------------------------------------------------------
	-- Consumables
	-- -------------------------------------------------------------------------
	["con_medkit"] = item({
		id = "con_medkit", displayName = "Field Medkit", itemType = C, stackSize = 20,
		consumable = { effects = { heal = 55, healOverTime = 0 }, cooldown = 6 },
		description = "Restores health immediately.",
	}),
	["con_stim"] = item({
		id = "con_stim", displayName = "Combat Stim", itemType = C, stackSize = 20, rarity = Enums.Rarity.Rare,
		consumable = { effects = { staminaRegen = 40, movementSpeed = 0.15, duration = 20 }, cooldown = 20 },
		description = "Restores stamina and increases movement speed briefly.",
	}),
	["con_ration"] = item({
		id = "con_ration", displayName = "Field Ration", itemType = Enums.ItemType.Food, stackSize = 30,
		consumable = { effects = { hunger = 35, staminaRegen = 0.25, duration = 300 }, cooldown = 5 },
		description = "Restores hunger and improves stamina recovery.",
	}),
	["con_water"] = item({
		id = "con_water", displayName = "Purified Water", itemType = Enums.ItemType.Water, stackSize = 30,
		consumable = { effects = { thirst = 40, heatResistance = 0.2, duration = 300 }, cooldown = 5 },
		description = "Restores thirst and grants minor heat resistance.",
	}),
	["con_heat_salve"] = item({
		id = "con_heat_salve", displayName = "Heat Salve", itemType = C, stackSize = 10, rarity = Enums.Rarity.Rare,
		consumable = { effects = { heatResistance = 0.6, duration = 600 }, cooldown = 30 },
		description = "Grants strong heat resistance. Required for Cinderfall expeditions.",
	}),
	["con_cold_salve"] = item({
		id = "con_cold_salve", displayName = "Cold Salve", itemType = C, stackSize = 10, rarity = Enums.Rarity.Rare,
		consumable = { effects = { coldResistance = 0.6, duration = 600 }, cooldown = 30 },
		description = "Grants strong cold resistance. Required for Frostveil expeditions.",
	}),
	["con_antidote"] = item({
		id = "con_antidote", displayName = "Antidote", itemType = C, stackSize = 10,
		consumable = { effects = { cleanse = Enums.StatusEffect.Contamination, contaminationResistance = 0.5, duration = 300 }, cooldown = 20 },
		description = "Cleanses contamination and grants temporary resistance.",
	}),
	["con_oxygen_canister"] = item({
		id = "con_oxygen_canister", displayName = "Oxygen Canister", itemType = C, stackSize = 10,
		consumable = { effects = { oxygen = 100, duration = 0 }, cooldown = 10 },
		description = "Refills oxygen while diving.",
	}),
	["con_repair_kit"] = item({
		id = "con_repair_kit", displayName = "Repair Kit", itemType = C, stackSize = 10,
		consumable = { effects = { repairWeapon = 40, repairBoat = 120 }, cooldown = 15 },
		description = "Restores weapon and boat durability.",
	}),
	["con_ammo_pack"] = item({
		id = "con_ammo_pack", displayName = "Ammo Pack", itemType = C, stackSize = 20,
		consumable = { effects = { refillReserve = 0.5 }, cooldown = 25 },
		description = "Restores half of the reserve ammunition pool.",
	}),

	-- -------------------------------------------------------------------------
	-- Blueprints
	-- -------------------------------------------------------------------------
	["bp_ar_ranger"] = item({ id = "bp_ar_ranger", displayName = "Ranger Blueprint", itemType = B, stackSize = 1, description = "Blueprint required to craft the Ranger." }),
	["bp_smg_wasp"] = item({ id = "bp_smg_wasp", displayName = "Wasp Blueprint", itemType = B, stackSize = 1, description = "Blueprint required to craft the Wasp." }),
	["bp_sg_breach"] = item({ id = "bp_sg_breach", displayName = "Breach Blueprint", itemType = B, stackSize = 1, description = "Blueprint required to craft the Breach." }),
	["bp_me_wildclaw"] = item({ id = "bp_me_wildclaw", displayName = "Wildclaw Blueprint", itemType = B, stackSize = 1, description = "Blueprint required to craft the Wildclaw." }),
	["bp_boat_skiff"] = item({ id = "bp_boat_skiff", displayName = "Skiff Blueprint", itemType = B, stackSize = 1, description = "Blueprint required to craft a Skiff." }),
	["bp_module_experimental"] = item({ id = "bp_module_experimental", displayName = "Experimental Module Blueprint", itemType = B, stackSize = 1, rarity = Enums.Rarity.Epic, description = "Blueprint required to craft experimental modules." }),

	-- -------------------------------------------------------------------------
	-- Protective equipment
	-- -------------------------------------------------------------------------
	["eq_heat_vest"] = item({ id = "eq_heat_vest", displayName = "Thermal Vest", itemType = E, stackSize = 1, rarity = Enums.Rarity.Rare, description = "Mitigates environmental heat in Cinderfall." }),
	["eq_cold_cloak"] = item({ id = "eq_cold_cloak", displayName = "Frost Cloak", itemType = E, stackSize = 1, rarity = Enums.Rarity.Rare, description = "Mitigates environmental cold in Frostveil." }),
	["eq_hazard_suit"] = item({ id = "eq_hazard_suit", displayName = "Hazard Suit", itemType = E, stackSize = 1, rarity = Enums.Rarity.Epic, description = "Mitigates contamination in Umbra Expanse." }),
	["eq_dive_gear"] = item({ id = "eq_dive_gear", displayName = "Dive Gear", itemType = E, stackSize = 1, rarity = Enums.Rarity.Rare, description = "Extends underwater exploration time." }),
	["eq_void_anchor"] = item({ id = "eq_void_anchor", displayName = "Void Anchor", itemType = E, stackSize = 1, rarity = Enums.Rarity.Epic, description = "Stabilises movement inside Null Horizon anomalies." }),

	-- -------------------------------------------------------------------------
	-- Boats
	-- -------------------------------------------------------------------------
	["boat_raft"] = item({ id = "boat_raft", displayName = "Raft", itemType = Enums.ItemType.Boat, stackSize = 3, description = "Basic raft. Slow but recoverable." }),
	["boat_skiff"] = item({ id = "boat_skiff", displayName = "Skiff", itemType = Enums.ItemType.Boat, stackSize = 3, rarity = Enums.Rarity.Rare, description = "Fast coastal skiff with modest durability." }),
	["boat_cutter"] = item({ id = "boat_cutter", displayName = "Deep Cutter", itemType = Enums.ItemType.Boat, stackSize = 2, rarity = Enums.Rarity.Epic, description = "Armoured hull for rougher water." }),
	["boat_submersible"] = item({ id = "boat_submersible", displayName = "Submersible", itemType = Enums.ItemType.Boat, stackSize = 1, rarity = Enums.Rarity.Legendary, description = "Supports underwater exploration and trench resources." }),

	-- -------------------------------------------------------------------------
	-- Companion eggs and quest items
	-- -------------------------------------------------------------------------
	["egg_forest"] = item({ id = "egg_forest", displayName = "Verdant Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, description = "A warm egg found in a forest nest." }),
	["egg_volcanic"] = item({ id = "egg_volcanic", displayName = "Ember Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Rare, description = "An egg warmed by geothermal vents." }),
	["egg_frozen"] = item({ id = "egg_frozen", displayName = "Glacial Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Rare, description = "An egg preserved in ice." }),
	["egg_umbra"] = item({ id = "egg_umbra", displayName = "Umbra Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Epic, description = "An egg that seems to absorb the light around it." }),
	["egg_solar"] = item({ id = "egg_solar", displayName = "Solar Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Epic, description = "An egg that glows faintly in daylight." }),
	["egg_abyssal"] = item({ id = "egg_abyssal", displayName = "Abyssal Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Epic, description = "An egg recovered from the deep stations." }),
	["egg_void"] = item({ id = "egg_void", displayName = "Void Egg", itemType = Enums.ItemType.CompanionEgg, stackSize = 20, rarity = Enums.Rarity.Legendary, description = "An egg that flickers out of view." }),
	["quest_field_notes"] = item({ id = "quest_field_notes", displayName = "Field Notes", itemType = Enums.ItemType.QuestItem, stackSize = 1, description = "Notes left behind by a missing research team." }),
	["quest_biolab_keycard"] = item({ id = "quest_biolab_keycard", displayName = "Biolab Keycard", itemType = Enums.ItemType.QuestItem, stackSize = 1, description = "Opens the Overgrowth Biolab lower levels." }),

	-- -------------------------------------------------------------------------
	-- Cosmetics
	-- -------------------------------------------------------------------------
	["cos_haven_banner"] = item({ id = "cos_haven_banner", displayName = "Haven Banner", itemType = Enums.ItemType.Cosmetic, stackSize = 1, description = "Cosmetic banner for the player's outpost." }),
}

local Item = Registry.new("Item", entries, { "id", "displayName", "itemType" })

function Item.ByType(itemType: string): { ItemDef }
	return Item:Filter(function(def)
		return def.itemType == itemType
	end)
end

function Item.Cores(): { ItemDef }
	return Item:Filter(function(def)
		return def.itemType == Enums.ItemType.BeastCore
	end)
end

function Item.CoreCategory(itemId: string): string?
	local def = Item:Get(itemId)
	if not def or not def.tags then
		return nil
	end
	for _, tag in def.tags do
		local category = string.match(tag, "^Core%:(.+)$")
		if category then
			return category
		end
	end
	return nil
end

function Item.IsSap(itemId: string): boolean
	local def = Item:Get(itemId)
	return def ~= nil and def.itemType == Enums.ItemType.Sap
end

function Item.ValidateAll(): { string }
	local problems = Registry.Validate(Item)
	for _, def in Item:List() do
		if not Enums.ItemType[def.itemType] then
			table.insert(problems, string.format("[Item] %s has unknown itemType %q", def.id, tostring(def.itemType)))
		end
		if not Enums.IsValidRarity(def.rarity) then
			table.insert(problems, string.format("[Item] %s has invalid rarity %q", def.id, tostring(def.rarity)))
		end
		if def.stackSize <= 0 then
			table.insert(problems, string.format("[Item] %s has a non-positive stack size", def.id))
		end
	end
	return problems
end

Item.Registry = Item
return Item
