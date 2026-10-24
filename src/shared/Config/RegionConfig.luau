--!strict
--[[
	RegionConfig.luau
	The seven planned regions plus Haven Overlook.

	Every region has its own colour identity, lighting ecosystem, architecture,
	atmosphere, music, resources, creatures, hazards and boss. Regions are
	reachable early by exploration or travel: threat, terrain and equipment
	requirements - never invisible walls - are what gate progression.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Registry = require(script.Parent.Registry)

export type RegionDef = {
	id: string,
	displayName: string,
	element: string,
	isStartingRegion: boolean?,
	threatLevel: number, -- 1..7
	recommendedLevel: number,
	-- World placement (studs). The hub sits at the origin.
	center: { number },
	radius: number,
	-- Terrain generation parameters consumed by the server WorldBuilder.
	terrain: {
		baseHeight: number,
		amplitude: number,
		frequency: number,
		waterLevel: number?,
		hasOcean: boolean?,
		materials: { string },
	},
	lighting: {
		ambient: { number },
		outdoorAmbient: { number },
		fogColor: { number },
		fogEnd: number,
		fogStart: number?,
		brightness: number,
		clockTime: number,
		exposure: number?,
	},
	weather: { [string]: number }?,
	hazards: { string },
	landmark: { id: string, name: string },
	worldBossId: string,
	dungeonId: string,
	eventId: string,
	resourceNodes: { [string]: number },
	beastSpecies: { string },
	foliage: { [string]: number },
	music: string,
	ambience: string,
	description: string,
	colorIdentity: { number },
}

local entries: { [string]: RegionDef } = {
	["HavenOverlook"] = {
		id = "HavenOverlook",
		displayName = "Haven Overlook",
		element = Enums.Element.Forest,
		isStartingRegion = true,
		threatLevel = 0,
		recommendedLevel = 1,
		center = { 0, 190, 0 },
		radius = 320,
		terrain = {
			baseHeight = 190,
			amplitude = 18,
			frequency = 0.004,
			materials = { "Grass", "Rock" },
		},
		lighting = {
			ambient = { 0.55, 0.60, 0.62 },
			outdoorAmbient = { 0.65, 0.70, 0.72 },
			fogColor = { 0.72, 0.80, 0.82 },
			fogEnd = 2600,
			brightness = 2.4,
			clockTime = 9.5,
		},
		hazards = {},
		landmark = { id = "haven_overlook", name = "Haven Overlook" },
		worldBossId = "",
		dungeonId = "",
		eventId = "",
		resourceNodes = {},
		beastSpecies = {},
		foliage = { Tree = 40 },
		music = "music_haven",
		ambience = "amb_haven",
		description = "A safe hilltop outpost and deployment point overlooking the wilderness.",
		colorIdentity = { 0.45, 0.75, 0.60 },
	},
	["VerdantReach"] = {
		id = "VerdantReach",
		displayName = "Verdant Reach",
		element = Enums.Element.Forest,
		threatLevel = 1,
		recommendedLevel = 1,
		center = { 0, 40, 0 },
		radius = 1800,
		terrain = {
			baseHeight = 40,
			amplitude = 70,
			frequency = 0.0032,
			waterLevel = 0,
			hasOcean = true,
			materials = { "Grass", "LeafyGrass", "Mud", "Rock" },
		},
		lighting = {
			ambient = { 0.42, 0.52, 0.40 },
			outdoorAmbient = { 0.52, 0.62, 0.48 },
			fogColor = { 0.58, 0.72, 0.55 },
			fogEnd = 2200,
			fogStart = 350,
			brightness = 2.0,
			clockTime = 10.0,
		},
		weather = { Clear = 0.7, Rain = 0.25, Mist = 0.05 },
		hazards = {},
		landmark = { id = "overgrowth_biolab", name = "Overgrowth Biolab" },
		worldBossId = "thornmaw",
		dungeonId = "dungeon_overgrowth_biolab",
		eventId = "event_beast_migration",
		resourceNodes = { tree_softwood = 40, tree_hardwood = 22, stone_outcrop = 24, ore_common = 20, herb_patch = 26, fiber_bush = 26, mushroom_cluster = 18, crystal_formation = 6, cache_facility = 5, research_terminal = 5, tree_ironwood = 4, sap_deposit = 2 },
		beastSpecies = { "forest_stalker", "forest_brute", "forest_spitter", "forest_flyer", "forest_pack_hunter", "forest_burrower", "forest_apex" },
		foliage = { GiantTree = 120, Tree = 420, Bush = 600, Vine = 300, GlowPlant = 90 },
		music = "music_verdant",
		ambience = "amb_forest",
		description = "Giant trees, dense vegetation, overgrown cities, abandoned ecological research facilities and bioluminescent groves.",
		colorIdentity = { 0.30, 0.70, 0.35 },
	},
	["Cinderfall"] = {
		id = "Cinderfall",
		displayName = "Cinderfall",
		element = Enums.Element.Fire,
		threatLevel = 3,
		recommendedLevel = 18,
		center = { 3600, 30, 0 },
		radius = 1500,
		terrain = {
			baseHeight = 30,
			amplitude = 110,
			frequency = 0.0038,
			waterLevel = 0,
			hasOcean = true,
			materials = { "Basalt", "Rock", "Sand", "Asphalt" },
		},
		lighting = {
			ambient = { 0.62, 0.35, 0.22 },
			outdoorAmbient = { 0.75, 0.40, 0.25 },
			fogColor = { 0.72, 0.36, 0.20 },
			fogEnd = 1700,
			fogStart = 220,
			brightness = 2.2,
			clockTime = 16.5,
			exposure = 0.15,
		},
		weather = { Ash = 0.6, Clear = 0.3, Eruption = 0.1 },
		hazards = { Enums.HazardType.Heat, Enums.HazardType.Volcanic },
		landmark = { id = "geothermal_complex", name = "Geothermal Research Complex" },
		worldBossId = "pyraxis",
		dungeonId = "dungeon_geothermal_complex",
		eventId = "event_volcanic_eruption",
		resourceNodes = { ore_regional = 30, stone_outcrop = 16, crystal_formation = 8, cache_facility = 4 },
		beastSpecies = { "cinder_emberhound", "cinder_magma_beetle" },
		foliage = { CharredTree = 90, AshBush = 120 },
		music = "music_cinderfall",
		ambience = "amb_volcanic",
		description = "Volcanic wilderness, lava channels, ash plains, geothermal structures and heat-distorted air.",
		colorIdentity = { 0.95, 0.35, 0.15 },
	},
	["Frostveil"] = {
		id = "Frostveil",
		displayName = "Frostveil",
		element = Enums.Element.Ice,
		threatLevel = 4,
		recommendedLevel = 26,
		center = { 0, 25, -3700 },
		radius = 1500,
		terrain = {
			baseHeight = 25,
			amplitude = 95,
			frequency = 0.0030,
			waterLevel = 0,
			hasOcean = true,
			materials = { "Snow", "Ice", "Rock", "Glacier" },
		},
		lighting = {
			ambient = { 0.55, 0.65, 0.80 },
			outdoorAmbient = { 0.65, 0.75, 0.90 },
			fogColor = { 0.78, 0.85, 0.95 },
			fogEnd = 1100,
			fogStart = 120,
			brightness = 1.8,
			clockTime = 7.0,
		},
		weather = { Snow = 0.55, Blizzard = 0.25, Clear = 0.2 },
		hazards = { Enums.HazardType.Cold, Enums.HazardType.Storm },
		landmark = { id = "cryostasis_lab", name = "Cryostasis Laboratory" },
		worldBossId = "glacieron",
		dungeonId = "dungeon_cryostasis_lab",
		eventId = "event_whiteout_migration",
		resourceNodes = { ore_regional = 26, stone_outcrop = 14, crystal_formation = 10, cache_facility = 4 },
		beastSpecies = { "frost_snowstalker", "frost_glacier_worm" },
		foliage = { PineTree = 110, SnowBush = 90 },
		music = "music_frostveil",
		ambience = "amb_blizzard",
		description = "Glaciers, frozen lakes, snowfields, frozen research facilities and ice caves.",
		colorIdentity = { 0.60, 0.85, 1.0 },
	},
	["UmbraExpanse"] = {
		id = "UmbraExpanse",
		displayName = "Umbra Expanse",
		element = Enums.Element.Dark,
		threatLevel = 5,
		recommendedLevel = 34,
		center = { -3800, 25, 0 },
		radius = 1400,
		terrain = {
			baseHeight = 25,
			amplitude = 70,
			frequency = 0.0034,
			waterLevel = 0,
			hasOcean = true,
			materials = { "Ground", "Mud", "Rock", "Asphalt" },
		},
		lighting = {
			ambient = { 0.20, 0.20, 0.30 },
			outdoorAmbient = { 0.24, 0.24, 0.34 },
			fogColor = { 0.14, 0.14, 0.22 },
			fogEnd = 1300,
			fogStart = 150,
			brightness = 1.1,
			clockTime = 22.0,
		},
		weather = { Fog = 0.6, Clear = 0.4 },
		hazards = { Enums.HazardType.Contamination },
		landmark = { id = "blacksite_containment", name = "Blacksite Containment Facility" },
		worldBossId = "noctyra",
		dungeonId = "dungeon_blacksite_containment",
		eventId = "event_containment_failure",
		resourceNodes = { ore_regional = 24, mushroom_cluster = 20, cache_facility = 8, research_terminal = 6 },
		beastSpecies = { "umbra_shadebeast", "umbra_machine_sentinel" },
		foliage = { DeadTree = 120, ShadowVine = 140 },
		music = "music_umbra",
		ambience = "amb_dark",
		description = "Abandoned military installations, shadowed valleys, contaminated areas and corrupted structures.",
		colorIdentity = { 0.35, 0.30, 0.55 },
	},
	["SolaraBasin"] = {
		id = "SolaraBasin",
		displayName = "Solara Basin",
		element = Enums.Element.Light,
		threatLevel = 6,
		recommendedLevel = 42,
		center = { 0, 35, 3800 },
		radius = 1400,
		terrain = {
			baseHeight = 35,
			amplitude = 60,
			frequency = 0.0036,
			waterLevel = 0,
			hasOcean = true,
			materials = { "Sand", "Rock", "Marble" },
		},
		lighting = {
			ambient = { 0.85, 0.80, 0.60 },
			outdoorAmbient = { 0.95, 0.90, 0.70 },
			fogColor = { 1.0, 0.95, 0.78 },
			fogEnd = 2400,
			fogStart = 400,
			brightness = 3.0,
			clockTime = 12.5,
			exposure = 0.2,
		},
		weather = { Clear = 0.85, SolarAnomaly = 0.15 },
		hazards = {},
		landmark = { id = "helios_station", name = "Helios Energy Research Station" },
		worldBossId = "light_samurai",
		dungeonId = "dungeon_helios_station",
		eventId = "event_solar_anomaly",
		resourceNodes = { ore_regional = 28, crystal_formation = 14, cache_facility = 5, research_terminal = 5 },
		beastSpecies = { "solar_luminal", "solar_gilded_sentinel" },
		foliage = { PalmTree = 70, GoldenShrub = 130 },
		music = "music_solara",
		ambience = "amb_solar",
		description = "Radiant landscapes, white and gold structures, solar energy facilities and photonic minerals.",
		colorIdentity = { 1.0, 0.85, 0.35 },
	},
	["PelagicFrontier"] = {
		id = "PelagicFrontier",
		displayName = "Pelagic Frontier",
		element = Enums.Element.Water,
		threatLevel = 5,
		recommendedLevel = 36,
		center = { 3400, 10, 3400 },
		radius = 1600,
		terrain = {
			baseHeight = 10,
			amplitude = 55,
			frequency = 0.0028,
			waterLevel = 26,
			hasOcean = true,
			materials = { "Sand", "Rock", "Coral" },
		},
		lighting = {
			ambient = { 0.35, 0.55, 0.68 },
			outdoorAmbient = { 0.42, 0.62, 0.78 },
			fogColor = { 0.35, 0.60, 0.78 },
			fogEnd = 1800,
			fogStart = 200,
			brightness = 2.1,
			clockTime = 11.0,
		},
		weather = { Clear = 0.6, Rain = 0.3, Storm = 0.1 },
		hazards = { Enums.HazardType.UnderwaterPressure },
		landmark = { id = "abyssal_station", name = "Abyssal Research Station" },
		worldBossId = "abyssalith",
		dungeonId = "dungeon_abyssal_station",
		eventId = "event_deep_sea_migration",
		resourceNodes = { aquatic_node = 34, ore_regional = 18, cache_facility = 6 },
		beastSpecies = { "pelagic_reefstalker" },
		foliage = { Coral = 220, Kelp = 180 },
		music = "music_pelagic",
		ambience = "amb_ocean",
		description = "Coasts, flooded cities, underwater caves, offshore platforms and deep-sea research stations.",
		colorIdentity = { 0.20, 0.65, 0.90 },
	},
	["NullHorizon"] = {
		id = "NullHorizon",
		displayName = "Null Horizon",
		element = Enums.Element.Void,
		threatLevel = 7,
		recommendedLevel = 55,
		center = { -3600, 60, 3700 },
		radius = 1300,
		terrain = {
			baseHeight = 60,
			amplitude = 130,
			frequency = 0.0042,
			waterLevel = -80,
			hasOcean = false,
			materials = { "Rock", "Basalt", "CrackedLava" },
		},
		lighting = {
			ambient = { 0.38, 0.22, 0.55 },
			outdoorAmbient = { 0.45, 0.28, 0.65 },
			fogColor = { 0.28, 0.16, 0.45 },
			fogEnd = 1500,
			fogStart = 150,
			brightness = 1.6,
			clockTime = 3.0,
		},
		weather = { Anomaly = 0.7, Clear = 0.3 },
		hazards = { Enums.HazardType.VoidAnomaly },
		landmark = { id = "nullpoint_complex", name = "Nullpoint Anomaly Complex" },
		worldBossId = "parallax",
		dungeonId = "dungeon_nullpoint_complex",
		eventId = "event_unstable_rift",
		resourceNodes = { ore_regional = 20, crystal_formation = 16, cache_facility = 6, research_terminal = 6 },
		beastSpecies = { "null_riftwalker", "null_fractured_echo" },
		foliage = { FloatingShard = 200 },
		music = "music_null",
		ambience = "amb_void",
		description = "Spatial anomalies, floating terrain, distorted structures, unstable gravity and rift formations.",
		colorIdentity = { 0.60, 0.30, 0.95 },
	},
}

local Region = Registry.new("Region", entries, { "id", "displayName", "element" })

Region.HubId = "HavenOverlook"

function Region.Center(regionId: string): Vector3
	local def = Region:Get(regionId)
	if not def then
		return Vector3.new(0, 0, 0)
	end
	local c = def.center
	return Vector3.new(c[1], c[2], c[3])
end

function Region.IsHub(regionId: string): boolean
	return regionId == Region.HubId
end

-- Which region contains a world position? Falls back to nil over open ocean.
function Region.RegionAt(position: Vector3): string?
	for _, def in Region:List() do
		if def.id == Region.HubId then
			continue
		end
		local center = Region.Center(def.id)
		local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
		if flat.Magnitude <= def.radius then
			return def.id
		end
	end
	local hub = Region:Get(Region.HubId)
	if hub then
		local center = Region.Center(hub.id)
		local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
		if flat.Magnitude <= hub.radius then
			return hub.id
		end
	end
	return nil
end

function Region.DistanceBetween(regionA: string, regionB: string): number
	local a, b = Region:Get(regionA), Region:Get(regionB)
	if not a or not b then
		return math.huge
	end
	local ca, cb = Region.Center(regionA), Region.Center(regionB)
	return Vector3.new(ca.X - cb.X, 0, ca.Z - cb.Z):Magnitude()
end

function Region.Hazards(regionId: string): { string }
	local def = Region:Get(regionId)
	return def and def.hazards or {}
end

function Region.Threat(regionId: string): number
	local def = Region:Get(regionId)
	return def and def.threatLevel or 0
end

-- Every playable region (the hub is a safe zone, not a hunting region).
function Region.Wilderness(): { any }
	return Region:Filter(function(def)
		return not Region.IsHub(def.id)
	end)
end

function Region.ValidateAll(): { string }
	local problems = Registry.Validate(Region)
	local seenBoss: { [string]: string } = {}
	local seenDungeon: { [string]: string } = {}
	for _, def in Region:List() do
		if def.id == Region.HubId then
			continue
		end
		if not Enums.Element[def.element] then
			table.insert(problems, string.format("[Region] %s has unknown element %q", def.id, tostring(def.element)))
		end
		if not def.worldBossId or def.worldBossId == "" then
			table.insert(problems, string.format("[Region] %s has no world boss", def.id))
		elseif seenBoss[def.worldBossId] then
			table.insert(problems, string.format("[Region] world boss %s is claimed twice", def.worldBossId))
		else
			seenBoss[def.worldBossId] = def.id
		end
		if not def.dungeonId or def.dungeonId == "" then
			table.insert(problems, string.format("[Region] %s has no dungeon", def.id))
		elseif seenDungeon[def.dungeonId] then
			table.insert(problems, string.format("[Region] dungeon %s is claimed twice", def.dungeonId))
		else
			seenDungeon[def.dungeonId] = def.id
		end
		if not def.eventId or def.eventId == "" then
			table.insert(problems, string.format("[Region] %s has no regional event", def.id))
		end
		if #def.beastSpecies == 0 then
			table.insert(problems, string.format("[Region] %s has no creatures", def.id))
		end
		if not def.landmark or def.landmark.id == "" then
			table.insert(problems, string.format("[Region] %s has no landmark", def.id))
		end
		-- Regions must not overlap each other.
		for _, other in Region:List() do
			if other.id ~= def.id and other.id ~= Region.HubId then
				local distance = Region.DistanceBetween(def.id, other.id)
				if distance < (def.radius + other.radius) then
					table.insert(problems, string.format("[Region] %s and %s overlap (distance %.0f)", def.id, other.id, distance))
				end
			end
		end
	end
	return problems
end

Region.Registry = Region
return Region
