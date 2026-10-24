--!strict
--[[
	WorldEventConfig.luau
	Regional world events and the ROOTFALL world dungeon event.

	Events are per-server by default. Every event declares eligibility, start
	conditions, duration, announcements, objectives, rewards, cleanup, failure
	handling and reset behaviour. Repeated triggers can never duplicate rewards
	or spawn unlimited enemies: the server tracks one active instance per event
	id and honours the cooldown.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type EventObjective = {
	id: string,
	name: string,
	kind: string, -- Eliminate | Defend | Collect | Escort | Survive | Extract
	target: number,
	description: string,
}

export type WorldEventDef = {
	id: string,
	displayName: string,
	regionId: string,
	announcementText: string,
	minPlayers: number,
	minLevel: number?,
	durationSeconds: number,
	cooldownSeconds: number,
	objectives: { EventObjective },
	spawnPlan: { [string]: number }?,
	rewardTableId: string?,
	bonusRewards: { [string]: number }?,
	environmentChange: { [string]: any }?,
	failureHandling: string,
	resetBehaviour: string,
	audio: { [string]: string },
	description: string,
}

local function event(def: WorldEventDef): WorldEventDef
	def.durationSeconds = def.durationSeconds or 600
	def.cooldownSeconds = def.cooldownSeconds or 1800
	def.minPlayers = def.minPlayers or 1
	return def
end

local entries: { [string]: WorldEventDef } = {
	["event_beast_migration"] = event({
		id = "event_beast_migration",
		displayName = "Aggressive Beast Migration",
		regionId = Enums.RegionId.VerdantReach,
		announcementText = "A migration is moving through Verdant Reach. Expect heavy contact.",
		minPlayers = 1,
		minLevel = 3,
		durationSeconds = 900,
		cooldownSeconds = 1800,
		objectives = {
			{ id = "thin_the_herd", name = "Thin the Herd", kind = "Eliminate", target = 40, description = "Defeat migrating beasts." },
			{ id = "hold_the_corridor", name = "Hold the Corridor", kind = "Survive", target = 300, description = "Hold the wildlife corridor for five minutes." },
		},
		spawnPlan = { forest_pack_hunter = 18, forest_brute = 8, forest_stalker = 14, forest_apex = 1 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { research_sample = 5, hide_apex = 2 },
		environmentChange = { migrationTraffic = true },
		failureHandling = "Event ends after its duration; no player penalty.",
		resetBehaviour = "All event spawns are despawned and the cooldown starts.",
		audio = { announce = "event_migration_announce", active = "event_migration_loop", complete = "event_migration_complete" },
		description = "Aggressive beast migration across the forest corridors.",
	}),
	["event_volcanic_eruption"] = event({
		id = "event_volcanic_eruption",
		displayName = "Volcanic Eruption",
		regionId = Enums.RegionId.Cinderfall,
		announcementText = "Seismic activity is rising. Cinderfall is about to erupt.",
		minPlayers = 1,
		minLevel = 18,
		durationSeconds = 720,
		cooldownSeconds = 2400,
		objectives = {
			{ id = "survive_ashfall", name = "Survive the Ashfall", kind = "Survive", target = 420, description = "Endure the eruption with heat protection." },
			{ id = "collect_ember", name = "Collect Ember Cores", kind = "Collect", target = 25, description = "Collect ember material during the eruption." },
		},
		spawnPlan = { cinder_emberhound = 16, cinder_magma_beetle = 10 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_ember_ash = 12, core_resonance = 1 },
		environmentChange = { ashfall = true, heatMultiplier = 1.6, lavaFountains = true },
		failureHandling = "Players defeated during the eruption respawn at Haven Overlook.",
		resetBehaviour = "Ash clears, hazards return to baseline, event spawns despawn.",
		audio = { announce = "event_eruption_announce", active = "event_eruption_loop", complete = "event_eruption_complete" },
		description = "Volcanic eruption with dangerous creature migration.",
	}),
	["event_whiteout_migration"] = event({
		id = "event_whiteout_migration",
		displayName = "Whiteout Migration",
		regionId = Enums.RegionId.Frostveil,
		announcementText = "A whiteout is closing in. Something is moving with it.",
		minPlayers = 1,
		minLevel = 26,
		durationSeconds = 780,
		cooldownSeconds = 2100,
		objectives = {
			{ id = "navigate_whiteout", name = "Navigate the Whiteout", kind = "Survive", target = 360, description = "Survive reduced visibility and cold." },
			{ id = "cull_pack", name = "Cull the Pack", kind = "Eliminate", target = 30, description = "Defeat migrating frost creatures." },
		},
		spawnPlan = { frost_snowstalker = 20, frost_glacier_worm = 6 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_glacial_ice = 12, core_apex = 1 },
		environmentChange = { blizzard = true, visibilityReduction = 0.6, coldMultiplier = 1.6 },
		failureHandling = "Event ends after its duration; no player penalty.",
		resetBehaviour = "Blizzard clears and event spawns despawn.",
		audio = { announce = "event_whiteout_announce", active = "event_whiteout_loop", complete = "event_whiteout_complete" },
		description = "A blizzard-driven migration across the frozen wastes.",
	}),
	["event_containment_failure"] = event({
		id = "event_containment_failure",
		displayName = "Containment Failure",
		regionId = Enums.RegionId.UmbraExpanse,
		announcementText = "Warning: containment integrity has failed.",
		minPlayers = 2,
		minLevel = 34,
		durationSeconds = 660,
		cooldownSeconds = 2400,
		objectives = {
			{ id = "seal_breaches", name = "Seal the Breaches", kind = "Collect", target = 12, description = "Close containment breaches." },
			{ id = "eliminate_escaped", name = "Eliminate Escapees", kind = "Eliminate", target = 35, description = "Defeat escaped subjects." },
		},
		spawnPlan = { umbra_shadebeast = 18, umbra_machine_sentinel = 8 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_umbral_resin = 12, core_apex = 1 },
		environmentChange = { contamination = true, darkness = 0.8 },
		failureHandling = "Event ends after its duration; remaining breaches reset.",
		resetBehaviour = "Facility resets to its sealed state.",
		audio = { announce = "event_containment_announce", active = "event_containment_loop", complete = "event_containment_complete" },
		description = "Containment failure at the Blacksites.",
	}),
	["event_solar_anomaly"] = event({
		id = "event_solar_anomaly",
		displayName = "Solar Anomaly",
		regionId = Enums.RegionId.SolaraBasin,
		announcementText = "Helios readings are spiking. A solar anomaly is forming.",
		minPlayers = 2,
		minLevel = 42,
		durationSeconds = 600,
		cooldownSeconds = 2700,
		objectives = {
			{ id = "stabilise_arrays", name = "Stabilise the Arrays", kind = "Collect", target = 15, description = "Stabilise solar arrays during the anomaly." },
			{ id = "defeat_constructs", name = "Defeat Rogue Constructs", kind = "Eliminate", target = 28, description = "Defeat activated constructs." },
		},
		spawnPlan = { solar_luminal = 14, solar_gilded_sentinel = 10 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_solar_alloy = 12, core_apex = 1 },
		environmentChange = { solarFlare = true, brightnessBoost = 0.5 },
		failureHandling = "Event ends after its duration; no player penalty.",
		resetBehaviour = "Light levels return to normal and constructs despawn.",
		audio = { announce = "event_solar_announce", active = "event_solar_loop", complete = "event_solar_complete" },
		description = "A solar anomaly activates the ancient stations.",
	}),
	["event_deep_sea_migration"] = event({
		id = "event_deep_sea_migration",
		displayName = "Deep-Sea Migration",
		regionId = Enums.RegionId.PelagicFrontier,
		announcementText = "Sonar contacts are rising from the trench.",
		minPlayers = 2,
		minLevel = 36,
		durationSeconds = 720,
		cooldownSeconds = 2400,
		objectives = {
			{ id = "escort_divers", name = "Escort the Divers", kind = "Escort", target = 3, description = "Escort research divers through the migration." },
			{ id = "collect_samples", name = "Collect Deep Samples", kind = "Collect", target = 20, description = "Collect samples during the migration." },
		},
		spawnPlan = { pelagic_reefstalker = 22 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_abyssal_pearl = 4, core_apex = 1 },
		environmentChange = { tideRise = true, currentStrength = 1.5 },
		failureHandling = "Event ends after its duration; divers return safely.",
		resetBehaviour = "Tide normalises and migration spawns despawn.",
		audio = { announce = "event_deepsea_announce", active = "event_deepsea_loop", complete = "event_deepsea_complete" },
		description = "A deep-sea migration rises toward the frontier.",
	}),
	["event_unstable_rift"] = event({
		id = "event_unstable_rift",
		displayName = "Unstable Rift Activity",
		regionId = Enums.RegionId.NullHorizon,
		announcementText = "Rift stability is failing. Local space is rearranging itself.",
		minPlayers = 2,
		minLevel = 55,
		durationSeconds = 600,
		cooldownSeconds = 2700,
		objectives = {
			{ id = "close_rifts", name = "Close the Rifts", kind = "Collect", target = 10, description = "Close unstable rifts." },
			{ id = "survive_anomalies", name = "Survive the Anomalies", kind = "Survive", target = 300, description = "Survive shifting gravity and geometry." },
		},
		spawnPlan = { null_riftwalker = 12, null_fractured_echo = 14 },
		rewardTableId = "rewards_beast_elite",
		bonusRewards = { mat_void_essence = 12, core_anomaly = 1 },
		environmentChange = { gravityAnomalies = true, geometryShifts = true },
		failureHandling = "Event ends after its duration; rifts collapse harmlessly.",
		resetBehaviour = "Geometry restores to the authored layout.",
		audio = { announce = "event_rift_announce", active = "event_rift_loop", complete = "event_rift_complete" },
		description = "Unstable rift activity rearranges Null Horizon.",
	}),
	["event_rootfall"] = event({
		id = "event_rootfall",
		displayName = "ROOTFALL: The World Below",
		regionId = Enums.RegionId.VerdantReach,
		announcementText = "The Root Gate is opening. ROOTFALL begins.",
		minPlayers = 3,
		minLevel = 45,
		durationSeconds = 3600,
		cooldownSeconds = Limits.Resource.SpecialRespawnSeconds,
		objectives = {
			{ id = "descend", name = "Overgrown Descent", kind = "Survive", target = 1, description = "Reach the Root Wardens." },
			{ id = "wardens", name = "Root Wardens", kind = "Eliminate", target = 5, description = "Defeat the elite guardians." },
			{ id = "sapheart", name = "Sapheart Chamber", kind = "Extract", target = 3, description = "Extract concentrated World Tree Sap." },
			{ id = "elder_veyl", name = "Elder Veyl", kind = "Eliminate", target = 1, description = "Defeat the Guardian of the Sapheart." },
		},
		spawnPlan = { forest_apex = 3, forest_brute = 10, forest_burrower = 12 },
		rewardTableId = "rewards_elder_veyl",
		bonusRewards = { world_tree_sap = 3 },
		environmentChange = { underground = true, unstableEnergy = true },
		failureHandling = "A failed run ends the instance; no permanent progression is lost.",
		resetBehaviour = "The Sapheart chamber reseals and the entrance goes on cooldown.",
		audio = { announce = "event_rootfall_announce", active = "event_rootfall_loop", complete = "event_rootfall_complete" },
		description = "The world dungeon event beneath the surface.",
	}),
}

local WorldEvent = Registry.new("WorldEvent", entries, { "id", "displayName", "regionId" })

function WorldEvent.ByRegion(regionId: string): { WorldEventDef }
	return WorldEvent:Filter(function(def)
		return def.regionId == regionId
	end)
end

function WorldEvent.TotalSpawnCount(eventId: string): number
	local def = WorldEvent:Get(eventId)
	if not def or not def.spawnPlan then
		return 0
	end
	local total = 0
	for _, count in def.spawnPlan do
		total += count
	end
	return total
end

function WorldEvent.ValidateAll(): { string }
	local problems = Registry.Validate(WorldEvent)
	for _, regionId in Enums.RegionOrder do
		if #WorldEvent.ByRegion(regionId) == 0 then
			table.insert(problems, string.format("[WorldEvent] region %s has no event", regionId))
		end
	end
	if not WorldEvent:Has("event_rootfall") then
		table.insert(problems, "[WorldEvent] the ROOTFALL world dungeon event is missing")
	end
	for _, def in WorldEvent:List() do
		if #def.objectives == 0 then
			table.insert(problems, string.format("[WorldEvent] %s has no objectives", def.id))
		end
		if def.cooldownSeconds <= 0 then
			table.insert(problems, string.format("[WorldEvent] %s has no cooldown, which permits reward farming", def.id))
		end
		if not def.resetBehaviour or def.resetBehaviour == "" then
			table.insert(problems, string.format("[WorldEvent] %s has no reset behaviour", def.id))
		end
	end
	return problems
end

WorldEvent.Registry = WorldEvent
return WorldEvent
