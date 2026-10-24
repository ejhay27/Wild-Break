--!strict
--[[
	CraftingConfig.luau
	Recipe registry.

	A recipe is data: the server CraftingService validates the recipe exists,
	the player knows it, the station is correct, the materials are present, and
	only then consumes materials and grants output exactly once. Concurrent
	requests for the same player are serialised so materials can never be
	spent twice.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type RecipeDef = {
	id: string,
	displayName: string,
	station: string,
	category: string,
	materials: { [string]: number },
	output: { [string]: number },
	craftSeconds: number,
	unlock: { kind: string, value: any }?,
	requiresBlueprint: string?,
	limit: number?,
	description: string,
}

local STATION = {
	Workbench = "Workbench",
	Gunsmith = "Gunsmith",
	Forge = "Forge",
	Fabricator = "Fabricator",
	Research = "Research",
	Boatyard = "Boatyard",
	Cookfire = "Cookfire",
	Anywhere = "Anywhere",
}

local function recipe(def: RecipeDef): RecipeDef
	def.craftSeconds = def.craftSeconds or Limits.Crafting.DefaultCraftSeconds
	return def
end

local entries: { [string]: RecipeDef } = {
	-- -------------------------------------------------------------------------
	-- Weapons
	-- -------------------------------------------------------------------------
	["craft_ar_ranger"] = recipe({
		id = "craft_ar_ranger",
		displayName = "Craft Ranger",
		station = STATION.Gunsmith,
		category = "Weapon",
		materials = { timber_hardwood = 8, ferrite = 12, fiber_vine = 6, energy_cell = 1 },
		output = { ar_ranger = 1 },
		craftSeconds = 6,
		requiresBlueprint = "bp_ar_ranger",
		description = "Assemble the recruit's assault rifle.",
	}),
	["craft_smg_wasp"] = recipe({
		id = "craft_smg_wasp",
		displayName = "Craft Wasp",
		station = STATION.Gunsmith,
		category = "Weapon",
		materials = { ferrite = 8, fiber_vine = 10, energy_cell = 2 },
		output = { smg_wasp = 1 },
		craftSeconds = 5,
		requiresBlueprint = "bp_smg_wasp",
		description = "Assemble the light submachine gun.",
	}),
	["craft_sg_breach"] = recipe({
		id = "craft_sg_breach",
		displayName = "Craft Breach",
		station = STATION.Gunsmith,
		category = "Weapon",
		materials = { ferrite = 14, timber_hardwood = 6, fiber_vine = 4 },
		output = { sg_breach = 1 },
		craftSeconds = 6,
		requiresBlueprint = "bp_sg_breach",
		description = "Assemble the breaching shotgun.",
	}),
	["craft_me_wildclaw"] = recipe({
		id = "craft_me_wildclaw",
		displayName = "Craft Wildclaw",
		station = STATION.Forge,
		category = "Weapon",
		materials = { bone_beast = 6, sinew_beast = 8, hide_beast = 4 },
		output = { me_wildclaw = 1 },
		craftSeconds = 4,
		requiresBlueprint = "bp_me_wildclaw",
		description = "Bind beast claws into a fast melee weapon.",
	}),
	["craft_me_breaker"] = recipe({
		id = "craft_me_breaker",
		displayName = "Craft Breaker",
		station = STATION.Forge,
		category = "Weapon",
		materials = { ferrite = 20, timber_hardwood = 6, stone_dressed = 4 },
		output = { me_breaker = 1 },
		craftSeconds = 7,
		description = "Forge an industrial wrecking maul.",
	}),

	-- -------------------------------------------------------------------------
	-- Attachments
	-- -------------------------------------------------------------------------
	["craft_optic_reflex"] = recipe({
		id = "craft_optic_reflex",
		displayName = "Reflex Sight",
		station = STATION.Gunsmith,
		category = "Attachment",
		materials = { ferrite = 4, crystal_resonant = 1 },
		output = { optic_reflex = 1 },
		description = "Simple 1x optic.",
	}),
	["craft_muzzle_brake"] = recipe({
		id = "craft_muzzle_brake",
		displayName = "Recoil Brake",
		station = STATION.Gunsmith,
		category = "Attachment",
		materials = { ferrite = 6, sinew_beast = 2 },
		output = { muzzle_brake = 1 },
		description = "Muzzle device that tames vertical climb.",
	}),
	["craft_mag_extended"] = recipe({
		id = "craft_mag_extended",
		displayName = "Extended Magazine",
		station = STATION.Gunsmith,
		category = "Attachment",
		materials = { ferrite = 8, fiber_vine = 6 },
		output = { mag_extended = 1 },
		description = "Higher capacity, slower reload.",
	}),
	["craft_grip_vertical"] = recipe({
		id = "craft_grip_vertical",
		displayName = "Vertical Grip",
		station = STATION.Gunsmith,
		category = "Attachment",
		materials = { timber_hardwood = 4, fiber_vine = 6 },
		output = { grip_vertical = 1 },
		description = "Straightforward recoil control.",
	}),
	["craft_mod_overcharger"] = recipe({
		id = "craft_mod_overcharger",
		displayName = "Overcharger Module",
		station = STATION.Fabricator,
		category = "Module",
		materials = { energy_cell = 4, crystal_resonant = 3, core_resonance = 1 },
		output = { mod_overcharger = 1 },
		craftSeconds = 10,
		requiresBlueprint = "bp_module_experimental",
		description = "Experimental module: more damage, less control.",
	}),

	-- -------------------------------------------------------------------------
	-- Gadgets
	-- -------------------------------------------------------------------------
	["craft_scout_drone"] = recipe({
		id = "craft_scout_drone",
		displayName = "Scout Drone",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { ferrite = 10, energy_cell = 3, crystal_resonant = 1 },
		output = { scout_drone = 1 },
		description = "Reusable reconnaissance drone.",
	}),
	["craft_medstation"] = recipe({
		id = "craft_medstation",
		displayName = "Medstation",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { ferrite = 8, herb_emeraldleaf = 6, energy_cell = 2 },
		output = { medstation = 1 },
		description = "Reusable area healing station.",
	}),
	["craft_shock_grenade"] = recipe({
		id = "craft_shock_grenade",
		displayName = "Shock Grenade x3",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { ferrite = 4, energy_cell = 2, crystal_resonant = 1 },
		output = { shock_grenade = 3 },
		description = "Three shock grenades.",
	}),
	["craft_smoke_capsule"] = recipe({
		id = "craft_smoke_capsule",
		displayName = "Smoke Capsule x3",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { mushroom_sporepod = 2, fiber_vine = 4, energy_cell = 1 },
		output = { smoke_capsule = 3 },
		description = "Three smoke capsules.",
	}),
	["craft_emp_charge"] = recipe({
		id = "craft_emp_charge",
		displayName = "EMP Charge x2",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { energy_cell = 4, crystal_resonant = 2, ferrite = 6 },
		output = { emp_charge = 2 },
		description = "Two EMP charges.",
	}),
	["craft_ammo_cache"] = recipe({
		id = "craft_ammo_cache",
		displayName = "Ammo Cache",
		station = STATION.Fabricator,
		category = "Gadget",
		materials = { ferrite = 12, energy_cell = 2 },
		output = { ammo_cache = 1 },
		description = "Reusable squad resupply cache.",
	}),

	-- -------------------------------------------------------------------------
	-- Consumables
	-- -------------------------------------------------------------------------
	["craft_medkit"] = recipe({
		id = "craft_medkit",
		displayName = "Field Medkit x3",
		station = STATION.Cookfire,
		category = "Consumable",
		materials = { herb_emeraldleaf = 3, fiber_vine = 2 },
		output = { con_medkit = 3 },
		description = "Three field medkits.",
	}),
	["craft_ration"] = recipe({
		id = "craft_ration",
		displayName = "Field Ration x3",
		station = STATION.Cookfire,
		category = "Consumable",
		materials = { mushroom_glowcap = 2, hide_beast = 1, herb_emeraldleaf = 1 },
		output = { con_ration = 3 },
		description = "Three field rations.",
	}),
	["craft_water"] = recipe({
		id = "craft_water",
		displayName = "Purified Water x3",
		station = STATION.Cookfire,
		category = "Consumable",
		materials = { mushroom_glowcap = 1, stone_rubble = 1 },
		output = { con_water = 3 },
		description = "Three purified waters.",
	}),
	["craft_heat_salve"] = recipe({
		id = "craft_heat_salve",
		displayName = "Heat Salve",
		station = STATION.Cookfire,
		category = "Consumable",
		materials = { herb_ashbloom = 3, mat_ember_ash = 4, con_water = 1 },
		output = { con_heat_salve = 1 },
		description = "Required for extended Cinderfall expeditions.",
	}),
	["craft_cold_salve"] = recipe({
		id = "craft_cold_salve",
		displayName = "Cold Salve",
		station = STATION.Cookfire,
		category = "Consumable",
		materials = { herb_frostlily = 3, mat_glacial_ice = 4, con_water = 1 },
		output = { con_cold_salve = 1 },
		description = "Required for extended Frostveil expeditions.",
	}),

	-- -------------------------------------------------------------------------
	-- Equipment and boats
	-- -------------------------------------------------------------------------
	["craft_heat_vest"] = recipe({
		id = "craft_heat_vest",
		displayName = "Thermal Vest",
		station = STATION.Workbench,
		category = "Equipment",
		materials = { hide_beast = 6, mat_ember_ash = 8, fiber_vine = 6 },
		output = { eq_heat_vest = 1 },
		description = "Mitigates environmental heat.",
	}),
	["craft_cold_cloak"] = recipe({
		id = "craft_cold_cloak",
		displayName = "Frost Cloak",
		station = STATION.Workbench,
		category = "Equipment",
		materials = { hide_beast = 6, mat_glacial_ice = 8, fiber_vine = 6 },
		output = { eq_cold_cloak = 1 },
		description = "Mitigates environmental cold.",
	}),
	["craft_dive_gear"] = recipe({
		id = "craft_dive_gear",
		displayName = "Dive Gear",
		station = STATION.Workbench,
		category = "Equipment",
		materials = { hide_beast = 4, mat_coral_sample = 6, energy_cell = 2 },
		output = { eq_dive_gear = 1 },
		description = "Extends underwater exploration time.",
	}),
	["craft_boat_skiff"] = recipe({
		id = "craft_boat_skiff",
		displayName = "Craft Skiff",
		station = STATION.Boatyard,
		category = "Boat",
		materials = { timber_softwood = 30, fiber_vine = 20, ferrite = 12 },
		output = { boat_skiff = 1 },
		craftSeconds = 20,
		requiresBlueprint = "bp_boat_skiff",
		description = "A fast coastal skiff.",
	}),
	["craft_boat_raft"] = recipe({
		id = "craft_boat_raft",
		displayName = "Craft Raft",
		station = STATION.Boatyard,
		category = "Boat",
		materials = { timber_softwood = 18, fiber_vine = 12 },
		output = { boat_raft = 1 },
		craftSeconds = 12,
		description = "A basic but recoverable raft.",
	}),

	-- -------------------------------------------------------------------------
	-- Evolution and advanced crafting (World Tree Sap)
	-- -------------------------------------------------------------------------
	["craft_weapon_star_legendary"] = recipe({
		id = "craft_weapon_star_legendary",
		displayName = "Legendary Star Upgrade",
		station = STATION.Gunsmith,
		category = "Evolution",
		materials = { world_tree_sap = 2, core_apex = 1, aurumite = 3 },
		output = { upgrade_star_legendary = 1 },
		craftSeconds = 15,
		limit = 6,
		description = "Adds a star to a Legendary weapon, up to its rarity maximum.",
	}),
	["craft_weapon_star_mythical"] = recipe({
		id = "craft_weapon_star_mythical",
		displayName = "Mythical Star Upgrade",
		station = STATION.Gunsmith,
		category = "Evolution",
		materials = { world_tree_sap = 4, core_apex = 2, voidshard = 3 },
		output = { upgrade_star_mythical = 1 },
		craftSeconds = 20,
		limit = 8,
		description = "Adds a star to a Mythical weapon, up to its rarity maximum.",
	}),
	["craft_sap_concentrate"] = recipe({
		id = "craft_sap_concentrate",
		displayName = "Refine Sap Concentrate",
		station = STATION.Research,
		category = "Evolution",
		materials = { world_tree_sap = 5, energy_core_high = 2, research_data = 4 },
		output = { world_tree_sap_concentrate = 1 },
		craftSeconds = 25,
		description = "Refines raw sap into concentrate for Prismatic paths.",
	}),
	["craft_core_anomaly"] = recipe({
		id = "craft_core_anomaly",
		displayName = "Synthesise Anomaly Core",
		station = STATION.Research,
		category = "Core",
		materials = { core_apex = 2, mat_void_essence = 8, world_tree_sap_concentrate = 1, research_data = 6 },
		output = { core_anomaly = 1 },
		craftSeconds = 40,
		description = "Synthesises an Anomaly Core from apex materials.",
	}),
	["craft_research_rank"] = recipe({
		id = "craft_research_rank",
		displayName = "Research Advancement",
		station = STATION.Research,
		category = "Research",
		materials = { research_data = 10, research_sample = 20, energy_cell = 4 },
		output = { research_data = 0 },
		craftSeconds = 10,
		description = "Spends research materials to advance the player's research rank.",
	}),
}

local Crafting = Registry.new("Crafting", entries, { "id", "displayName", "station" })

Crafting.Stations = STATION

function Crafting.ByStation(station: string): { RecipeDef }
	return Crafting:Filter(function(def)
		return def.station == station
	end)
end

function Crafting.ByCategory(category: string): { RecipeDef }
	return Crafting:Filter(function(def)
		return def.category == category
	end)
end

function Crafting.CanAfford(recipeId: string, inventory: { [string]: number }): boolean
	local def = Crafting:Get(recipeId)
	if not def then
		return false
	end
	for itemId, required in def.materials do
		if (inventory[itemId] or 0) < required then
			return false
		end
	end
	return true
end

function Crafting.MissingMaterials(recipeId: string, inventory: { [string]: number }): { [string]: number }
	local def = Crafting:Get(recipeId)
	if not def then
		return {}
	end
	local missing = {}
	for itemId, required in def.materials do
		local have = inventory[itemId] or 0
		if have < required then
			missing[itemId] = required - have
		end
	end
	return missing
end

function Crafting.ValidateAll(): { string }
	local problems = Registry.Validate(Crafting)
	for _, def in Crafting:List() do
		if not STATION[def.station] then
			table.insert(problems, string.format("[Crafting] %s uses unknown station %q", def.id, tostring(def.station)))
		end
		local next = next
		if next(def.materials) == nil then
			table.insert(problems, string.format("[Crafting] %s has no material cost", def.id))
		end
		if next(def.output) == nil then
			table.insert(problems, string.format("[Crafting] %s has no output", def.id))
		end
		for itemId, amount in def.output do
			if amount > Limits.Crafting.MaxRecipeOutput then
				table.insert(problems, string.format("[Crafting] %s output exceeds the cap", def.id))
			end
			if itemId == nil then
				table.insert(problems, string.format("[Crafting] %s has a nil output id", def.id))
			end
		end
	end
	return problems
end

Crafting.Registry = Crafting
return Crafting
