--!strict
--[[
	DungeonConfig.luau
	Seven regional facilities plus ROOTFALL: THE WORLD BELOW.

	Two formats are supported:
	  * OpenWorldFacility - discovered and explored inside the shared world.
	  * MajorOperation    - private or squad based instanced activity.

	Dungeons use fixed rank and tier classifications with optional challenge
	modifiers. Enemies are NOT auto-scaled to the party's health or damage.
	One active pet per player is allowed inside; taming is not.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type DungeonStage = {
	index: number,
	id: string,
	name: string,
	objective: string,
	kind: string, -- Traversal | Encounter | Puzzle | Boss | Extraction
	eliteEncounters: number?,
	resourceNodes: { [string]: number }?,
	durationHintSeconds: number?,
}

export type DungeonDef = {
	id: string,
	displayName: string,
	regionId: string,
	format: string,
	rank: string,
	tier: number,
	recommendedLevel: number,
	recommendedPartySize: { number },
	entrance: { number },
	bossId: string,
	stages: { DungeonStage },
	eliteSpecies: { string },
	rewardTableId: string,
	resetSeconds: number,
	maxConcurrentInstances: number,
	allowsTaming: boolean,
	maxActiveCompanions: number,
	challengeModifiers: { [string]: any }?,
	ambience: string,
	lighting: { ambient: { number }, fogColor: { number }, fogEnd: number, brightness: number },
	description: string,
}

local function dungeon(def: DungeonDef): DungeonDef
	def.allowsTaming = false
	def.maxActiveCompanions = Limits.Companion.MaxActiveDungeon
	def.resetSeconds = def.resetSeconds or Limits.Boss.DungeonBossRespawnSeconds
	def.maxConcurrentInstances = def.maxConcurrentInstances or 1
	return def
end

local entries: { [string]: DungeonDef } = {
	["dungeon_overgrowth_biolab"] = dungeon({
		id = "dungeon_overgrowth_biolab",
		displayName = "Overgrowth Biolab",
		regionId = Enums.RegionId.VerdantReach,
		format = Enums.DungeonFormat.OpenWorldFacility,
		rank = "A",
		tier = 3,
		recommendedLevel = 14,
		recommendedPartySize = { 1, 4 },
		entrance = { 640, 62, -520 },
		bossId = "rootbound_prototype",
		stages = {
			{ index = 1, id = "reception", name = "Reception Atrium", objective = "Restore power to the atrium door.", kind = "Traversal", eliteEncounters = 1, resourceNodes = { cache_facility = 2 } },
			{ index = 2, id = "greenhouse", name = "Overgrown Greenhouse", objective = "Clear the specimen greenhouse.", kind = "Encounter", eliteEncounters = 2, resourceNodes = { mushroom_cluster = 6, research_terminal = 1 } },
			{ index = 3, id = "specimen_wing", name = "Specimen Wing", objective = "Reach the containment chamber.", kind = "Traversal", eliteEncounters = 2, resourceNodes = { cache_facility = 2, research_terminal = 2 } },
			{ index = 4, id = "prototype", name = "Containment Chamber", objective = "Defeat the Rootbound Prototype.", kind = "Boss" },
		},
		eliteSpecies = { "forest_brute", "forest_spitter", "forest_burrower" },
		rewardTableId = "rewards_rootbound_prototype",
		resetSeconds = Limits.Boss.DungeonBossRespawnSeconds,
		maxConcurrentInstances = 1,
		challengeModifiers = {
			{ id = "overgrowth_bloom", name = "Bloom Surge", description = "Spore density doubles and elites gain 20% health.", damageScale = 1.1, healthScale = 1.2, rewardBonus = 1 },
		},
		ambience = "amb_dungeon_biolab",
		lighting = { ambient = { 0.35, 0.48, 0.35 }, fogColor = { 0.30, 0.42, 0.32 }, fogEnd = 700, brightness = 1.4 },
		description = "An abandoned ecological research facility swallowed by the forest.",
	}),
	["dungeon_geothermal_complex"] = dungeon({
		id = "dungeon_geothermal_complex",
		displayName = "Geothermal Research Complex",
		regionId = Enums.RegionId.Cinderfall,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "A",
		tier = 4,
		recommendedLevel = 24,
		recommendedPartySize = { 2, 5 },
		entrance = { 3980, 58, 260 },
		bossId = "magmaforged_alpha",
		stages = {
			{ index = 1, id = "intake", name = "Coolant Intake", objective = "Restart the coolant pumps.", kind = "Puzzle", eliteEncounters = 1 },
			{ index = 2, id = "turbine_hall", name = "Turbine Hall", objective = "Survive the turbine hall ambush.", kind = "Encounter", eliteEncounters = 3 },
			{ index = 3, id = "forge", name = "The Forge", objective = "Defeat the Magmaforged Alpha.", kind = "Boss" },
		},
		eliteSpecies = { "cinder_emberhound", "cinder_magma_beetle" },
		rewardTableId = "rewards_magmaforged_alpha",
		ambience = "amb_dungeon_geothermal",
		lighting = { ambient = { 0.62, 0.32, 0.18 }, fogColor = { 0.70, 0.34, 0.18 }, fogEnd = 600, brightness = 1.6 },
		description = "A geothermal energy facility that lost control of its own heat.",
	}),
	["dungeon_cryostasis_lab"] = dungeon({
		id = "dungeon_cryostasis_lab",
		displayName = "Cryostasis Laboratory",
		regionId = Enums.RegionId.Frostveil,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "A",
		tier = 4,
		recommendedLevel = 32,
		recommendedPartySize = { 2, 5 },
		entrance = { 220, 44, -3520 },
		bossId = "project_permafrost",
		stages = {
			{ index = 1, id = "cold_storage", name = "Cold Storage", objective = "Thaw the access corridor.", kind = "Puzzle", eliteEncounters = 1 },
			{ index = 2, id = "cryo_ward", name = "Cryo Ward", objective = "Clear the cryo ward.", kind = "Encounter", eliteEncounters = 3 },
			{ index = 3, id = "containment", name = "Deep Containment", objective = "Defeat Project Permafrost.", kind = "Boss" },
		},
		eliteSpecies = { "frost_snowstalker", "frost_glacier_worm" },
		rewardTableId = "rewards_project_permafrost",
		ambience = "amb_dungeon_cryo",
		lighting = { ambient = { 0.50, 0.62, 0.78 }, fogColor = { 0.68, 0.78, 0.90 }, fogEnd = 550, brightness = 1.5 },
		description = "A frozen research laboratory still cycling its containment program.",
	}),
	["dungeon_blacksite_containment"] = dungeon({
		id = "dungeon_blacksite_containment",
		displayName = "Blacksite Containment Facility",
		regionId = Enums.RegionId.UmbraExpanse,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "S",
		tier = 4,
		recommendedLevel = 40,
		recommendedPartySize = { 3, 5 },
		entrance = { -3540, 40, -180 },
		bossId = "subject_zero",
		stages = {
			{ index = 1, id = "intake_block", name = "Intake Block", objective = "Bypass the containment locks.", kind = "Puzzle", eliteEncounters = 2 },
			{ index = 2, id = "cell_block", name = "Cell Block", objective = "Survive the cell block.", kind = "Encounter", eliteEncounters = 4 },
			{ index = 3, id = "zero", name = "Subject Zero", objective = "Defeat Subject Zero.", kind = "Boss" },
		},
		eliteSpecies = { "umbra_shadebeast", "umbra_machine_sentinel" },
		rewardTableId = "rewards_subject_zero",
		ambience = "amb_dungeon_blacksite",
		lighting = { ambient = { 0.18, 0.18, 0.26 }, fogColor = { 0.12, 0.12, 0.20 }, fogEnd = 520, brightness = 0.9 },
		description = "A containment facility whose subjects are no longer inside their cells.",
	}),
	["dungeon_helios_station"] = dungeon({
		id = "dungeon_helios_station",
		displayName = "Helios Energy Research Station",
		regionId = Enums.RegionId.SolaraBasin,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "S",
		tier = 5,
		recommendedLevel = 48,
		recommendedPartySize = { 3, 5 },
		entrance = { -160, 66, 3960 },
		bossId = "radiant_sentinel",
		stages = {
			{ index = 1, id = "solar_array", name = "Solar Array", objective = "Align the solar array.", kind = "Puzzle", eliteEncounters = 2 },
			{ index = 2, id = "photon_hall", name = "Photon Hall", objective = "Clear the photon hall.", kind = "Encounter", eliteEncounters = 3 },
			{ index = 3, id = "sentinel", name = "Sentinel Gate", objective = "Defeat the Radiant Sentinel.", kind = "Boss" },
		},
		eliteSpecies = { "solar_luminal", "solar_gilded_sentinel" },
		rewardTableId = "rewards_radiant_sentinel",
		ambience = "amb_dungeon_helios",
		lighting = { ambient = { 0.85, 0.80, 0.62 }, fogColor = { 1.0, 0.95, 0.80 }, fogEnd = 900, brightness = 2.6 },
		description = "An ancient but functioning solar research station.",
	}),
	["dungeon_abyssal_station"] = dungeon({
		id = "dungeon_abyssal_station",
		displayName = "Abyssal Research Station",
		regionId = Enums.RegionId.PelagicFrontier,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "S",
		tier = 5,
		recommendedLevel = 44,
		recommendedPartySize = { 3, 5 },
		entrance = { 3620, 8, 3620 },
		bossId = "trenchborn_leviathan",
		stages = {
			{ index = 1, id = "dock", name = "Flooded Dock", objective = "Restore the flood gates.", kind = "Puzzle", eliteEncounters = 2 },
			{ index = 2, id = "pressure_deck", name = "Pressure Deck", objective = "Hold the pressure deck.", kind = "Encounter", eliteEncounters = 3 },
			{ index = 3, id = "leviathan", name = "Moon Pool", objective = "Defeat the Trenchborn Leviathan.", kind = "Boss" },
		},
		eliteSpecies = { "pelagic_reefstalker" },
		rewardTableId = "rewards_trenchborn_leviathan",
		ambience = "amb_dungeon_abyssal",
		lighting = { ambient = { 0.30, 0.48, 0.62 }, fogColor = { 0.25, 0.45, 0.62 }, fogEnd = 480, brightness = 1.3 },
		description = "A deep-sea research station that is slowly losing its fight with the ocean.",
	}),
	["dungeon_nullpoint_complex"] = dungeon({
		id = "dungeon_nullpoint_complex",
		displayName = "Nullpoint Anomaly Complex",
		regionId = Enums.RegionId.NullHorizon,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "SS",
		tier = 5,
		recommendedLevel = 58,
		recommendedPartySize = { 3, 5 },
		entrance = { -3380, 92, 3520 },
		bossId = "fractured_architect",
		stages = {
			{ index = 1, id = "anchor", name = "Anchor Ring", objective = "Stabilise the anchor ring.", kind = "Puzzle", eliteEncounters = 2 },
			{ index = 2, id = "fracture_hall", name = "Fracture Hall", objective = "Cross the fracture hall.", kind = "Traversal", eliteEncounters = 3 },
			{ index = 3, id = "architect", name = "Architect Core", objective = "Defeat the Fractured Architect.", kind = "Boss" },
		},
		eliteSpecies = { "null_riftwalker", "null_fractured_echo" },
		rewardTableId = "rewards_fractured_architect",
		ambience = "amb_dungeon_nullpoint",
		lighting = { ambient = { 0.36, 0.22, 0.52 }, fogColor = { 0.26, 0.15, 0.42 }, fogEnd = 620, brightness = 1.2 },
		description = "A facility built around an anomaly it never fully understood.",
	}),
	["dungeon_rootfall"] = dungeon({
		id = "dungeon_rootfall",
		displayName = "ROOTFALL: The World Below",
		regionId = Enums.RegionId.VerdantReach,
		format = Enums.DungeonFormat.MajorOperation,
		rank = "SS",
		tier = 5,
		recommendedLevel = 50,
		recommendedPartySize = { 3, 8 },
		entrance = { -210, 18, 760 },
		bossId = "elder_veyl",
		stages = {
			{
				index = 1, id = "root_gate", name = "Root Gate", objective = "Announce the event, prepare and satisfy the entry requirements.",
				kind = "Traversal", eliteEncounters = 0, durationHintSeconds = 180,
			},
			{
				index = 2, id = "overgrown_descent", name = "Overgrown Descent",
				objective = "Traverse enormous roots, caverns and abandoned facilities.",
				kind = "Traversal", eliteEncounters = 4, resourceNodes = { sap_deposit = 4, crystal_formation = 3 }, durationHintSeconds = 420,
			},
			{
				index = 3, id = "root_wardens", name = "Root Wardens",
				objective = "Defeat the elite guardians and operate the environmental mechanisms.",
				kind = "Encounter", eliteEncounters = 5, durationHintSeconds = 420,
			},
			{
				index = 4, id = "sapheart_chamber", name = "Sapheart Chamber",
				objective = "Extract concentrated World Tree Sap while handling the chamber mechanics.",
				kind = "Extraction", eliteEncounters = 3, resourceNodes = { sapheart = 1 }, durationHintSeconds = 300,
			},
			{ index = 5, id = "elder_veyl", name = "Elder Veyl", objective = "Defeat Elder Veyl, Guardian of the Sapheart.", kind = "Boss", durationHintSeconds = 900 },
		},
		eliteSpecies = { "forest_apex", "forest_brute", "forest_burrower" },
		rewardTableId = "rewards_elder_veyl",
		resetSeconds = Limits.Resource.SpecialRespawnSeconds,
		maxConcurrentInstances = 1,
		challengeModifiers = {
			{ id = "deep_roots", name = "Deep Roots", description = "Guardians gain 25% health and deal 15% more damage.", damageScale = 1.15, healthScale = 1.25, rewardBonus = 1 },
		},
		ambience = "amb_dungeon_rootfall",
		lighting = { ambient = { 0.30, 0.42, 0.30 }, fogColor = { 0.22, 0.32, 0.24 }, fogEnd = 520, brightness = 1.1 },
		description = "A major world dungeon beneath the surface, built into the ancient roots of the World Tree.",
	}),
}

local Dungeon = Registry.new("Dungeon", entries, { "id", "displayName", "format" })

function Dungeon.ByRegion(regionId: string): { DungeonDef }
	return Dungeon:Filter(function(def)
		return def.regionId == regionId
	end)
end

function Dungeon.OpenWorld(): { DungeonDef }
	return Dungeon:Filter(function(def)
		return def.format == Enums.DungeonFormat.OpenWorldFacility
	end)
end

function Dungeon.Operations(): { DungeonDef }
	return Dungeon:Filter(function(def)
		return def.format == Enums.DungeonFormat.MajorOperation
	end)
end

function Dungeon.Stage(dungeonId: string, stageIndex: number): DungeonStage?
	local def = Dungeon:Get(dungeonId)
	if not def then
		return nil
	end
	for _, stage in def.stages do
		if stage.index == stageIndex then
			return stage
		end
	end
	return nil
end

function Dungeon.EntrancePosition(dungeonId: string): Vector3
	local def = Dungeon:Get(dungeonId)
	if not def then
		return Vector3.new(0, 0, 0)
	end
	local e = def.entrance
	return Vector3.new(e[1], e[2], e[3])
end

function Dungeon.AllowsTaming(dungeonId: string): boolean
	return false
end

function Dungeon.ValidateAll(): { string }
	local problems = Registry.Validate(Dungeon)
	if Dungeon:Count() ~= 8 then
		table.insert(problems, string.format("[Dungeon] expected 8 dungeons (7 regional + ROOTFALL), found %d", Dungeon:Count()))
	end
	for _, def in Dungeon:List() do
		if not Enums.DungeonFormat[def.format] then
			table.insert(problems, string.format("[Dungeon] %s has unknown format %q", def.id, tostring(def.format)))
		end
		if #def.stages == 0 then
			table.insert(problems, string.format("[Dungeon] %s has no stages", def.id))
		end
		local hasBoss = false
		for _, stage in def.stages do
			if stage.kind == "Boss" then
				hasBoss = true
			end
		end
		if not hasBoss then
			table.insert(problems, string.format("[Dungeon] %s has no boss stage", def.id))
		end
		if def.allowsTaming then
			table.insert(problems, string.format("[Dungeon] %s must not allow taming", def.id))
		end
		if def.maxActiveCompanions ~= Limits.Companion.MaxActiveDungeon then
			table.insert(problems, string.format("[Dungeon] %s must limit active companions to %d", def.id, Limits.Companion.MaxActiveDungeon))
		end
		if not Enums.IsValidRank(def.rank) or not Enums.IsValidTier(def.tier) then
			table.insert(problems, string.format("[Dungeon] %s has an invalid rank/tier", def.id))
		end
	end
	local rootfall = Dungeon:Get("dungeon_rootfall")
	if rootfall and #rootfall.stages ~= 5 then
		table.insert(problems, string.format("[Dungeon] ROOTFALL must have 5 stages, found %d", #rootfall.stages))
	end
	return problems
end

Dungeon.Registry = Dungeon
return Dungeon
