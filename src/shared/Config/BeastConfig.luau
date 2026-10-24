--!strict
--[[
	BeastConfig.luau
	Creature registry: archetypes, stats, habitats, behaviour, loot, ranks and
	tiers, companion eligibility and spawn rules.

	Beasts occupy habitats but roam, hunt, flee, investigate noises, defend
	territories and react to world events. Distant creatures run a simplified
	behaviour budget (see Limits.Performance) so large regions stay cheap.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type BeastDef = {
	id: string,
	displayName: string,
	archetype: string,
	element: string,
	minRank: string,
	maxRank: string,
	minTier: number,
	maxTier: number,
	health: number,
	damage: number,
	moveSpeed: number,
	detectionRadius: number,
	attackRange: number,
	attackCooldown: number,
	aggression: number, -- 0..1
	fleeBelowHealthFraction: number?,
	regions: { string },
	habitats: { string },
	packSize: { number }?,
	lootTableId: string,
	companionEligible: boolean,
	companionSpeciesId: string?,
	tameDifficulty: number?,
	weakness: { [string]: number }?,
	statusOnHit: string?,
	spawnWeight: number,
	maxAlivePerRegion: number,
	dayNight: string?,
	sounds: { [string]: string },
	animations: { [string]: string },
	description: string,
}

local function beast(def: BeastDef): BeastDef
	def.maxAlivePerRegion = def.maxAlivePerRegion or 12
	def.spawnWeight = def.spawnWeight or 10
	def.companionEligible = def.companionEligible or false
	return def
end

local entries: { [string]: BeastDef } = {
	["forest_stalker"] = beast({
		id = "forest_stalker",
		displayName = "Thicket Stalker",
		archetype = Enums.BeastArchetype.Stalker,
		element = Enums.Element.Forest,
		minRank = "C", maxRank = "B", minTier = 1, maxTier = 3,
		health = 900, damage = 55, moveSpeed = 24, detectionRadius = 90, attackRange = 10, attackCooldown = 1.6,
		aggression = 0.6, fleeBelowHealthFraction = 0.15,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "ForestFloor", "Undergrowth" },
		packSize = { 1, 3 },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_thicket_stalker", tameDifficulty = 0.6,
		weakness = { [Enums.DamageType.Fire] = 1.4 },
		spawnWeight = 30,
		sounds = { idle = "beast_stalker_idle", alert = "beast_stalker_alert", attack = "beast_stalker_attack", death = "beast_stalker_death" },
		animations = { idle = "stalker_idle", move = "stalker_move", attack = "stalker_attack", death = "stalker_death" },
		description = "A lean ambush predator that circles before it commits.",
	}),
	["forest_brute"] = beast({
		id = "forest_brute",
		displayName = "Rootback Brute",
		archetype = Enums.BeastArchetype.Brute,
		element = Enums.Element.Forest,
		minRank = "B", maxRank = "A", minTier = 2, maxTier = 4,
		health = 2600, damage = 130, moveSpeed = 14, detectionRadius = 110, attackRange = 12, attackCooldown = 2.4,
		aggression = 0.7,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "GiantTreeRoots", "Clearings" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_rootback_brute", tameDifficulty = 0.8,
		weakness = { [Enums.DamageType.Fire] = 1.3 },
		spawnWeight = 16,
		sounds = { idle = "beast_brute_idle", alert = "beast_brute_alert", attack = "beast_brute_attack", death = "beast_brute_death" },
		animations = { idle = "brute_idle", move = "brute_move", attack = "brute_attack", death = "brute_death" },
		description = "Slow, heavy and armoured with living bark.",
	}),
	["forest_spitter"] = beast({
		id = "forest_spitter",
		displayName = "Spore Spitter",
		archetype = Enums.BeastArchetype.Spitter,
		element = Enums.Element.Forest,
		minRank = "C", maxRank = "B", minTier = 1, maxTier = 3,
		health = 700, damage = 70, moveSpeed = 16, detectionRadius = 140, attackRange = 90, attackCooldown = 2.6,
		aggression = 0.55, fleeBelowHealthFraction = 0.25,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "BioluminescentGrove", "CaveMouth" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_spore_spitter", tameDifficulty = 0.65,
		statusOnHit = Enums.StatusEffect.Corrosion,
		spawnWeight = 22,
		sounds = { idle = "beast_spitter_idle", attack = "beast_spitter_attack", death = "beast_spitter_death" },
		animations = { idle = "spitter_idle", attack = "spitter_attack", death = "spitter_death" },
		description = "Ranged creature that fires corrosive spores.",
	}),
	["forest_flyer"] = beast({
		id = "forest_flyer",
		displayName = "Canopy Glider",
		archetype = Enums.BeastArchetype.Flyer,
		element = Enums.Element.Forest,
		minRank = "C", maxRank = "A", minTier = 1, maxTier = 4,
		health = 600, damage = 60, moveSpeed = 34, detectionRadius = 130, attackRange = 14, attackCooldown = 1.8,
		aggression = 0.5, fleeBelowHealthFraction = 0.3,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "Canopy", "Cliffs" },
		packSize = { 2, 4 },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_canopy_glider", tameDifficulty = 0.7,
		spawnWeight = 18,
		sounds = { idle = "beast_flyer_idle", attack = "beast_flyer_attack", death = "beast_flyer_death" },
		animations = { move = "flyer_move", attack = "flyer_attack", death = "flyer_death" },
		description = "Dives from the canopy, then climbs away to reposition.",
	}),
	["forest_apex"] = beast({
		id = "forest_apex",
		displayName = "Verdant Apex",
		archetype = Enums.BeastArchetype.Apex,
		element = Enums.Element.Forest,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 22000, damage = 320, moveSpeed = 22, detectionRadius = 200, attackRange = 16, attackCooldown = 2.0,
		aggression = 0.9,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "DeepWilderness", "Landmark" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_verdant_apex", tameDifficulty = 0.95,
		weakness = { [Enums.DamageType.Fire] = 1.25 },
		spawnWeight = 3, maxAlivePerRegion = 3,
		sounds = { idle = "beast_apex_idle", roar = "beast_apex_roar", attack = "beast_apex_attack", death = "beast_apex_death" },
		animations = { idle = "apex_idle", move = "apex_move", attack = "apex_attack", death = "apex_death" },
		description = "Elite territory holder. Dangerous alone, deadly in a migration.",
	}),
	["forest_pack_hunter"] = beast({
		id = "forest_pack_hunter",
		displayName = "Thornfang",
		archetype = Enums.BeastArchetype.PackHunter,
		element = Enums.Element.Forest,
		minRank = "C", maxRank = "A", minTier = 1, maxTier = 4,
		health = 800, damage = 65, moveSpeed = 28, detectionRadius = 160, attackRange = 10, attackCooldown = 1.4,
		aggression = 0.8, fleeBelowHealthFraction = 0.1,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "WildlifeCorridor", "ForestFloor" },
		packSize = { 3, 6 },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_thornfang", tameDifficulty = 0.75,
		spawnWeight = 24,
		sounds = { idle = "beast_thornfang_idle", alert = "beast_thornfang_alert", attack = "beast_thornfang_attack", death = "beast_thornfang_death" },
		animations = { move = "thornfang_move", attack = "thornfang_attack", death = "thornfang_death" },
		description = "Hunts in coordinated packs and calls for help.",
	}),
	["forest_burrower"] = beast({
		id = "forest_burrower",
		displayName = "Root Borer",
		archetype = Enums.BeastArchetype.Burrower,
		element = Enums.Element.Forest,
		minRank = "C", maxRank = "B", minTier = 1, maxTier = 3,
		health = 1100, damage = 80, moveSpeed = 20, detectionRadius = 100, attackRange = 12, attackCooldown = 2.2,
		aggression = 0.6,
		regions = { Enums.RegionId.VerdantReach },
		habitats = { "RootNetworks", "Caves" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_root_borer", tameDifficulty = 0.7,
		spawnWeight = 14,
		sounds = { idle = "beast_borer_idle", attack = "beast_borer_attack", death = "beast_borer_death" },
		animations = { move = "borer_move", attack = "borer_attack", death = "borer_death" },
		description = "Tunnels under the roots and surfaces beneath your feet.",
	}),
	["cinder_emberhound"] = beast({
		id = "cinder_emberhound",
		displayName = "Emberhound",
		archetype = Enums.BeastArchetype.PackHunter,
		element = Enums.Element.Fire,
		minRank = "B", maxRank = "S", minTier = 2, maxTier = 5,
		health = 1800, damage = 120, moveSpeed = 30, detectionRadius = 150, attackRange = 10, attackCooldown = 1.5,
		aggression = 0.85,
		regions = { Enums.RegionId.Cinderfall },
		habitats = { "AshPlains", "LavaChannels" },
		packSize = { 2, 5 },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_emberhound", tameDifficulty = 0.8,
		statusOnHit = Enums.StatusEffect.Burn,
		weakness = { [Enums.DamageType.Ice] = 1.5, [Enums.DamageType.Water] = 1.4 },
		spawnWeight = 20,
		sounds = { idle = "beast_emberhound_idle", attack = "beast_emberhound_attack", death = "beast_emberhound_death" },
		animations = { move = "emberhound_move", attack = "emberhound_attack", death = "emberhound_death" },
		description = "Fire-adapted pack hunter that leaves burning footprints.",
	}),
	["frost_snowstalker"] = beast({
		id = "frost_snowstalker",
		displayName = "Snowstalker",
		archetype = Enums.BeastArchetype.Stalker,
		element = Enums.Element.Ice,
		minRank = "B", maxRank = "S", minTier = 2, maxTier = 5,
		health = 2000, damage = 140, moveSpeed = 26, detectionRadius = 130, attackRange = 12, attackCooldown = 1.7,
		aggression = 0.75,
		regions = { Enums.RegionId.Frostveil },
		habitats = { "Snowfields", "Glaciers" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_snowstalker", tameDifficulty = 0.8,
		statusOnHit = Enums.StatusEffect.Chill,
		weakness = { [Enums.DamageType.Fire] = 1.5 },
		spawnWeight = 20,
		sounds = { idle = "beast_snowstalker_idle", attack = "beast_snowstalker_attack", death = "beast_snowstalker_death" },
		animations = { move = "snowstalker_move", attack = "snowstalker_attack", death = "snowstalker_death" },
		description = "White camouflage predator that hunts through blizzards.",
	}),
	["umbra_shadebeast"] = beast({
		id = "umbra_shadebeast",
		displayName = "Shadebeast",
		archetype = Enums.BeastArchetype.Corrupted,
		element = Enums.Element.Dark,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 4200, damage = 180, moveSpeed = 28, detectionRadius = 170, attackRange = 12, attackCooldown = 1.6,
		aggression = 0.85,
		regions = { Enums.RegionId.UmbraExpanse },
		habitats = { "ShadowedValleys", "ContaminatedZones" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_shadebeast", tameDifficulty = 0.9,
		weakness = { [Enums.DamageType.Light] = 1.6 },
		spawnWeight = 12,
		sounds = { idle = "beast_shade_idle", attack = "beast_shade_attack", death = "beast_shade_death" },
		animations = { move = "shade_move", attack = "shade_attack", death = "shade_death" },
		description = "A corrupted creature that flickers between sight and shadow.",
	}),
	["umbra_machine_sentinel"] = beast({
		id = "umbra_machine_sentinel",
		displayName = "Blacksite Sentinel",
		archetype = Enums.BeastArchetype.Machine,
		element = Enums.Element.Dark,
		minRank = "A", maxRank = "S", minTier = 3, maxTier = 5,
		health = 5200, damage = 200, moveSpeed = 18, detectionRadius = 220, attackRange = 140, attackCooldown = 2.0,
		aggression = 0.8,
		regions = { Enums.RegionId.UmbraExpanse },
		habitats = { "MilitaryInstallations", "Facilities" },
		lootTableId = "rewards_beast_elite",
		companionEligible = false,
		weakness = { [Enums.DamageType.Energy] = 1.6, [Enums.DamageType.Sonic] = 1.3 },
		spawnWeight = 10,
		sounds = { idle = "machine_sentinel_idle", alert = "machine_sentinel_alert", attack = "machine_sentinel_attack", death = "machine_sentinel_death" },
		animations = { idle = "sentinel_idle", attack = "sentinel_attack", death = "sentinel_death" },
		description = "Automated defender. Vulnerable to EMP charges and energy damage.",
	}),
	["solar_luminal"] = beast({
		id = "solar_luminal",
		displayName = "Luminal Wisp",
		archetype = Enums.BeastArchetype.Flyer,
		element = Enums.Element.Light,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 2600, damage = 160, moveSpeed = 30, detectionRadius = 160, attackRange = 60, attackCooldown = 1.8,
		aggression = 0.65,
		regions = { Enums.RegionId.SolaraBasin },
		habitats = { "RadiantPlains", "SolarFacilities" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_luminal_wisp", tameDifficulty = 0.85,
		weakness = { [Enums.DamageType.Dark] = 1.5 },
		spawnWeight = 12,
		sounds = { idle = "beast_luminal_idle", attack = "beast_luminal_attack", death = "beast_luminal_death" },
		animations = { move = "luminal_move", attack = "luminal_attack", death = "luminal_death" },
		description = "A graceful radiant creature that attacks with focused light.",
	}),
	["pelagic_reefstalker"] = beast({
		id = "pelagic_reefstalker",
		displayName = "Reefstalker",
		archetype = Enums.BeastArchetype.Aquatic,
		element = Enums.Element.Water,
		minRank = "B", maxRank = "S", minTier = 2, maxTier = 5,
		health = 2400, damage = 150, moveSpeed = 22, detectionRadius = 140, attackRange = 12, attackCooldown = 1.8,
		aggression = 0.7,
		regions = { Enums.RegionId.PelagicFrontier },
		habitats = { "ShallowReefs", "FloodedCities" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_reefstalker", tameDifficulty = 0.8,
		statusOnHit = Enums.StatusEffect.Drenched,
		weakness = { [Enums.DamageType.Energy] = 1.4 },
		spawnWeight = 18,
		sounds = { idle = "beast_reefstalker_idle", attack = "beast_reefstalker_attack", death = "beast_reefstalker_death" },
		animations = { move = "reefstalker_move", attack = "reefstalker_attack", death = "reefstalker_death" },
		description = "Amphibious predator that fights on the shoreline and underwater.",
	}),
	["null_riftwalker"] = beast({
		id = "null_riftwalker",
		displayName = "Riftwalker",
		archetype = Enums.BeastArchetype.Elite,
		element = Enums.Element.Void,
		minRank = "S", maxRank = "X", minTier = 4, maxTier = 5,
		health = 9000, damage = 260, moveSpeed = 26, detectionRadius = 200, attackRange = 40, attackCooldown = 1.9,
		aggression = 0.9,
		regions = { Enums.RegionId.NullHorizon },
		habitats = { "FloatingTerrain", "RiftFormations" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_riftwalker", tameDifficulty = 0.95,
		weakness = { [Enums.DamageType.Light] = 1.3 },
		spawnWeight = 6,
		sounds = { idle = "beast_riftwalker_idle", attack = "beast_riftwalker_attack", death = "beast_riftwalker_death" },
		animations = { move = "riftwalker_move", attack = "riftwalker_attack", death = "riftwalker_death" },
		description = "Steps between short rifts. Always leaves a traceable spatial footprint.",
	}),
	["cinder_magma_beetle"] = beast({
		id = "cinder_magma_beetle",
		displayName = "Magma Beetle",
		archetype = Enums.BeastArchetype.Brute,
		element = Enums.Element.Fire,
		minRank = "B", maxRank = "A", minTier = 2, maxTier = 4,
		health = 3200, damage = 110, moveSpeed = 12, detectionRadius = 90, attackRange = 10, attackCooldown = 2.6,
		aggression = 0.5,
		regions = { Enums.RegionId.Cinderfall },
		habitats = { "LavaChannels", "GeothermalStructures" },
		lootTableId = "rewards_beast_common",
		companionEligible = true, companionSpeciesId = "comp_magma_beetle", tameDifficulty = 0.75,
		weakness = { [Enums.DamageType.Water] = 1.5 },
		spawnWeight = 14,
		sounds = { idle = "beast_beetle_idle", attack = "beast_beetle_attack", death = "beast_beetle_death" },
		animations = { move = "beetle_move", attack = "beetle_attack", death = "beetle_death" },
		description = "Armoured grazer that becomes dangerous when the herd migrates.",
	}),
	["frost_glacier_worm"] = beast({
		id = "frost_glacier_worm",
		displayName = "Glacier Worm",
		archetype = Enums.BeastArchetype.Burrower,
		element = Enums.Element.Ice,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 6800, damage = 220, moveSpeed = 16, detectionRadius = 150, attackRange = 18, attackCooldown = 2.4,
		aggression = 0.8,
		regions = { Enums.RegionId.Frostveil },
		habitats = { "IceCaves", "Glaciers" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_glacier_worm", tameDifficulty = 0.9,
		weakness = { [Enums.DamageType.Fire] = 1.6 },
		spawnWeight = 8,
		sounds = { idle = "beast_worm_idle", attack = "beast_worm_attack", death = "beast_worm_death" },
		animations = { move = "worm_burrow", attack = "worm_attack", death = "worm_death" },
		description = "Breaches through ice sheets to ambush anything crossing a glacier.",
	}),
	["null_fractured_echo"] = beast({
		id = "null_fractured_echo",
		displayName = "Fractured Echo",
		archetype = Enums.BeastArchetype.Corrupted,
		element = Enums.Element.Void,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 3800, damage = 190, moveSpeed = 24, detectionRadius = 180, attackRange = 30, attackCooldown = 1.7,
		aggression = 0.85,
		regions = { Enums.RegionId.NullHorizon },
		habitats = { "DistortedStructures", "RiftFormations" },
		lootTableId = "rewards_beast_elite",
		companionEligible = true, companionSpeciesId = "comp_fractured_echo", tameDifficulty = 0.92,
		spawnWeight = 8,
		sounds = { idle = "beast_echo_idle", attack = "beast_echo_attack", death = "beast_echo_death" },
		animations = { move = "echo_move", attack = "echo_attack", death = "echo_death" },
		description = "A partially unmade creature whose silhouette never quite matches its body.",
	}),
	["solar_gilded_sentinel"] = beast({
		id = "solar_gilded_sentinel",
		displayName = "Gilded Sentinel",
		archetype = Enums.BeastArchetype.Machine,
		element = Enums.Element.Light,
		minRank = "A", maxRank = "SS", minTier = 3, maxTier = 5,
		health = 5600, damage = 210, moveSpeed = 16, detectionRadius = 240, attackRange = 160, attackCooldown = 2.2,
		aggression = 0.75,
		regions = { Enums.RegionId.SolaraBasin },
		habitats = { "SolarFacilities", "RadiantPlains" },
		lootTableId = "rewards_beast_elite",
		companionEligible = false,
		weakness = { [Enums.DamageType.Energy] = 1.5 },
		spawnWeight = 10,
		sounds = { idle = "machine_gilded_idle", alert = "machine_gilded_alert", attack = "machine_gilded_attack", death = "machine_gilded_death" },
		animations = { idle = "gilded_idle", attack = "gilded_attack", death = "gilded_death" },
		description = "Ancient but functional photonic defense construct.",
	}),
}

local Beast = Registry.new("Beast", entries, { "id", "displayName", "archetype" })

function Beast.ByRegion(regionId: string): { BeastDef }
	return Beast:Filter(function(def)
		return table.find(def.regions, regionId) ~= nil
	end)
end

function Beast.ByArchetype(archetype: string): { BeastDef }
	return Beast:Filter(function(def)
		return def.archetype == archetype
	end)
end

function Beast.RollSpecies(regionId: string, random: () -> number): BeastDef?
	local candidates = Beast.ByRegion(regionId)
	if #candidates == 0 then
		return nil
	end
	local total = 0
	for _, def in candidates do
		total += def.spawnWeight
	end
	local roll = random() * total
	local cumulative = 0
	for _, def in candidates do
		cumulative += def.spawnWeight
		if roll <= cumulative then
			return def
		end
	end
	return candidates[#candidates]
end

-- Beast respawn timers are intentionally faster than bosses.
function Beast.RespawnSeconds(beastId: string): number
	local def = Beast:Get(beastId)
	if not def then
		return 60
	end
	if def.archetype == Enums.BeastArchetype.Apex or def.archetype == Enums.BeastArchetype.Elite then
		return 600
	end
	return 90
end

function Beast.IsCompanionEligible(beastId: string): boolean
	local def = Beast:Get(beastId)
	return def ~= nil and def.companionEligible
end

function Beast.DamageMultiplier(beastId: string, damageType: string): number
	local def = Beast:Get(beastId)
	if not def or not def.weakness then
		return 1
	end
	return def.weakness[damageType] or 1
end

function Beast.ValidateAll(): { string }
	local problems = Registry.Validate(Beast)
	for _, def in Beast:List() do
		if not Enums.BeastArchetype[def.archetype] then
			table.insert(problems, string.format("[Beast] %s has unknown archetype %q", def.id, tostring(def.archetype)))
		end
		if not Enums.IsValidRank(def.minRank) or not Enums.IsValidRank(def.maxRank) then
			table.insert(problems, string.format("[Beast] %s has an invalid rank range", def.id))
		end
		if not Enums.IsValidTier(def.minTier) or not Enums.IsValidTier(def.maxTier) or def.maxTier < def.minTier then
			table.insert(problems, string.format("[Beast] %s has an invalid tier range", def.id))
		end
		if #def.regions == 0 then
			table.insert(problems, string.format("[Beast] %s has no regions", def.id))
		end
		if def.companionEligible and not def.companionSpeciesId then
			table.insert(problems, string.format("[Beast] %s is companion eligible but has no companion species", def.id))
		end
		if def.health <= 0 or def.damage <= 0 then
			table.insert(problems, string.format("[Beast] %s has invalid combat stats", def.id))
		end
	end
	-- Every region must have at least one creature.
	for _, regionId in Enums.RegionOrder do
		if #Beast.ByRegion(regionId) == 0 then
			table.insert(problems, string.format("[Beast] region %s has no creatures", regionId))
		end
	end
	return problems
end

Beast.Registry = Beast
return Beast
