--!strict
--[[
	CompanionConfig.luau
	Companion species, roles, progression, evolution and forms.

	Limits (enforced on the server, see Limits.Companion):
	  * open world: three active companions per player
	  * dungeons:   one active companion per player
	  * taming is only allowed in the open world, never inside a dungeon
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type CompanionAbility = {
	id: string,
	name: string,
	kind: string, -- Attack | Heal | Buff | Scout | Harvest | Debuff
	cooldown: number,
	magnitude: number?,
	range: number?,
	description: string,
}

export type CompanionDef = {
	id: string,
	displayName: string,
	sourceBeastId: string?,
	element: string,
	roles: { string },
	rank: string,
	tier: number,
	baseHealth: number,
	baseDamage: number,
	moveSpeed: number,
	attackRange: number,
	attackCooldown: number,
	abilities: { CompanionAbility },
	evolution: {
		levels: { number },
		forms: { { id: string, name: string, minLevel: number, requiredItemId: string?, statScale: number, description: string } },
	},
	experienceCurve: number,
	eggItemId: string?,
	tameDifficulty: number?,
	scouting: { radius: number, revealsResources: boolean, revealsBeasts: boolean }?,
	sounds: { [string]: string },
	description: string,
}

local function companion(def: CompanionDef): CompanionDef
	def.experienceCurve = def.experienceCurve or 1.12
	return def
end

local entries: { [string]: CompanionDef } = {
	["comp_thicket_stalker"] = companion({
		id = "comp_thicket_stalker",
		displayName = "Thicket Stalker",
		sourceBeastId = "forest_stalker",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Exploration },
		rank = "C", tier = 2,
		baseHealth = 320, baseDamage = 34, moveSpeed = 26, attackRange = 10, attackCooldown = 1.5,
		abilities = {
			{ id = "pounce", name = "Pounce", kind = "Attack", cooldown = 8, magnitude = 2.2, range = 24, description = "Leaps at the target for heavy damage." },
			{ id = "scent_track", name = "Scent Track", kind = "Scout", cooldown = 20, description = "Highlights nearby resource nodes." },
		},
		evolution = {
			levels = { 10, 25, 45 },
			forms = {
				{ id = "thicket_stalker_juvenile", name = "Juvenile Stalker", minLevel = 1, statScale = 1.0, description = "Fast and fragile." },
				{ id = "thicket_stalker_prime", name = "Prime Stalker", minLevel = 25, requiredItemId = "core_wild", statScale = 1.6, description = "Stronger pounce, better tracking." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.6,
		scouting = { radius = 180, revealsResources = true, revealsBeasts = true },
		sounds = { idle = "comp_stalker_idle", attack = "comp_stalker_attack", death = "comp_stalker_death" },
		description = "A fast ambush companion that scouts resources.",
	}),
	["comp_rootback_brute"] = companion({
		id = "comp_rootback_brute",
		displayName = "Rootback Brute",
		sourceBeastId = "forest_brute",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Support },
		rank = "B", tier = 3,
		baseHealth = 980, baseDamage = 62, moveSpeed = 15, attackRange = 12, attackCooldown = 2.4,
		abilities = {
			{ id = "bulwark", name = "Living Bulwark", kind = "Buff", cooldown = 22, magnitude = 0.2, range = 30, description = "Reduces damage taken by nearby allies." },
			{ id = "slam", name = "Root Slam", kind = "Attack", cooldown = 12, magnitude = 2.6, range = 16, description = "Area slam that staggers." },
		},
		evolution = {
			levels = { 15, 35 },
			forms = {
				{ id = "rootback_brute_base", name = "Rootback Brute", minLevel = 1, statScale = 1.0, description = "A living wall." },
				{ id = "rootback_brute_warden", name = "Rootback Warden", minLevel = 35, requiredItemId = "core_apex", statScale = 1.7, description = "Adds a taunt and a stronger bulwark." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.8,
		sounds = { idle = "comp_brute_idle", attack = "comp_brute_attack", death = "comp_brute_death" },
		description = "A tanky frontline companion.",
	}),
	["comp_spore_spitter"] = companion({
		id = "comp_spore_spitter",
		displayName = "Spore Spitter",
		sourceBeastId = "forest_spitter",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Support },
		rank = "C", tier = 2,
		baseHealth = 420, baseDamage = 40, moveSpeed = 17, attackRange = 80, attackCooldown = 2.2,
		abilities = {
			{ id = "spore_cloud", name = "Spore Cloud", kind = "Debuff", cooldown = 14, magnitude = 0.25, range = 34, description = "Applies corrosion and weakens armour." },
			{ id = "heal_spores", name = "Healing Spores", kind = "Heal", cooldown = 20, magnitude = 18, range = 30, description = "Heals allies over time." },
		},
		evolution = {
			levels = { 12, 30 },
			forms = {
				{ id = "spore_spitter_base", name = "Spore Spitter", minLevel = 1, statScale = 1.0, description = "Ranged support." },
				{ id = "spore_spitter_bloom", name = "Bloom Spitter", minLevel = 30, requiredItemId = "core_resonance", statScale = 1.6, description = "Larger clouds, faster healing." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.65,
		sounds = { idle = "comp_spitter_idle", attack = "comp_spitter_attack", death = "comp_spitter_death" },
		description = "Ranged support companion that corrodes and heals.",
	}),
	["comp_canopy_glider"] = companion({
		id = "comp_canopy_glider",
		displayName = "Canopy Glider",
		sourceBeastId = "forest_flyer",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Exploration },
		rank = "C", tier = 2,
		baseHealth = 300, baseDamage = 26, moveSpeed = 36, attackRange = 14, attackCooldown = 1.8,
		abilities = {
			{ id = "aerial_scout", name = "Aerial Scout", kind = "Scout", cooldown = 25, description = "Reveals a wide area of the map." },
			{ id = "dive", name = "Dive Attack", kind = "Attack", cooldown = 10, magnitude = 1.8, range = 30, description = "Quick diving strike." },
		},
		evolution = {
			levels = { 12, 28 },
			forms = {
				{ id = "glider_base", name = "Canopy Glider", minLevel = 1, statScale = 1.0, description = "Excellent scouting." },
				{ id = "glider_windrider", name = "Windrider", minLevel = 28, requiredItemId = "core_wild", statScale = 1.5, description = "Faster scouting and stronger dives." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.7,
		scouting = { radius = 320, revealsResources = true, revealsBeasts = true },
		sounds = { idle = "comp_glider_idle", attack = "comp_glider_attack", death = "comp_glider_death" },
		description = "Exploration companion that reveals terrain from the air.",
	}),
	["comp_thornfang"] = companion({
		id = "comp_thornfang",
		displayName = "Thornfang",
		sourceBeastId = "forest_pack_hunter",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Combat },
		rank = "C", tier = 3,
		baseHealth = 400, baseDamage = 46, moveSpeed = 30, attackRange = 10, attackCooldown = 1.3,
		abilities = {
			{ id = "pack_call", name = "Pack Call", kind = "Buff", cooldown = 30, magnitude = 0.18, range = 40, description = "Increases ally attack speed." },
			{ id = "rend", name = "Rend", kind = "Attack", cooldown = 8, magnitude = 1.9, range = 12, description = "Bleeding strike." },
		},
		evolution = {
			levels = { 14, 32 },
			forms = {
				{ id = "thornfang_base", name = "Thornfang", minLevel = 1, statScale = 1.0, description = "Aggressive pack fighter." },
				{ id = "thornfang_alpha", name = "Thornfang Alpha", minLevel = 32, requiredItemId = "core_apex", statScale = 1.8, description = "Leads the pack: stronger buffs and damage." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.75,
		sounds = { idle = "comp_thornfang_idle", attack = "comp_thornfang_attack", death = "comp_thornfang_death" },
		description = "A fast melee companion with pack synergy.",
	}),
	["comp_root_borer"] = companion({
		id = "comp_root_borer",
		displayName = "Root Borer",
		sourceBeastId = "forest_burrower",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Exploration, Enums.CompanionRole.Support },
		rank = "C", tier = 2,
		baseHealth = 520, baseDamage = 30, moveSpeed = 20, attackRange = 10, attackCooldown = 2.0,
		abilities = {
			{ id = "harvest_burrow", name = "Burrow Harvest", kind = "Harvest", cooldown = 18, magnitude = 0.25, range = 40, description = "Increases resource yield from nearby nodes." },
			{ id = "tunnel_ambush", name = "Tunnel Ambush", kind = "Attack", cooldown = 12, magnitude = 2.0, range = 20, description = "Surfaces beneath a target." },
		},
		evolution = {
			levels = { 14, 30 },
			forms = {
				{ id = "borer_base", name = "Root Borer", minLevel = 1, statScale = 1.0, description = "Utility harvester." },
				{ id = "borer_deep", name = "Deep Borer", minLevel = 30, requiredItemId = "core_wild", statScale = 1.5, description = "Better yields and stronger ambushes." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.7,
		scouting = { radius = 150, revealsResources = true, revealsBeasts = false },
		sounds = { idle = "comp_borer_idle", attack = "comp_borer_attack", death = "comp_borer_death" },
		description = "Digging companion that improves resource gathering.",
	}),
	["comp_verdant_apex"] = companion({
		id = "comp_verdant_apex",
		displayName = "Verdant Apex",
		sourceBeastId = "forest_apex",
		element = Enums.Element.Forest,
		roles = { Enums.CompanionRole.Combat },
		rank = "S", tier = 5,
		baseHealth = 1800, baseDamage = 120, moveSpeed = 24, attackRange = 14, attackCooldown = 1.8,
		abilities = {
			{ id = "apex_roar", name = "Apex Roar", kind = "Buff", cooldown = 40, magnitude = 0.3, range = 50, description = "Significantly increases ally damage." },
			{ id = "devour", name = "Devour", kind = "Attack", cooldown = 16, magnitude = 3.2, range = 18, description = "Devastating bite." },
		},
		evolution = {
			levels = { 20, 40, 60 },
			forms = {
				{ id = "apex_base", name = "Verdant Apex", minLevel = 1, statScale = 1.0, description = "An elite companion." },
				{ id = "apex_elder", name = "Elder Apex", minLevel = 40, requiredItemId = "core_anomaly", statScale = 1.9, description = "The apex of the apex." },
			},
		},
		eggItemId = "egg_forest",
		tameDifficulty = 0.95,
		sounds = { idle = "comp_apex_idle", attack = "comp_apex_attack", death = "comp_apex_death" },
		description = "An elite combat companion reserved for endgame hunters.",
	}),
	["comp_emberhound"] = companion({
		id = "comp_emberhound",
		displayName = "Emberhound",
		sourceBeastId = "cinder_emberhound",
		element = Enums.Element.Fire,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Support },
		rank = "B", tier = 3,
		baseHealth = 620, baseDamage = 58, moveSpeed = 30, attackRange = 10, attackCooldown = 1.5,
		abilities = {
			{ id = "ember_bite", name = "Ember Bite", kind = "Attack", cooldown = 7, magnitude = 2.0, range = 12, description = "Burning bite." },
			{ id = "heat_aura", name = "Heat Aura", kind = "Buff", cooldown = 30, magnitude = 0.4, range = 26, description = "Grants heat resistance to nearby allies." },
		},
		evolution = {
			levels = { 16, 34 },
			forms = {
				{ id = "emberhound_base", name = "Emberhound", minLevel = 1, statScale = 1.0, description = "Burning pack hunter." },
				{ id = "emberhound_molten", name = "Molten Hound", minLevel = 34, requiredItemId = "core_apex", statScale = 1.7, description = "Molten coat and stronger burns." },
			},
		},
		eggItemId = "egg_volcanic",
		tameDifficulty = 0.8,
		sounds = { idle = "comp_emberhound_idle", attack = "comp_emberhound_attack", death = "comp_emberhound_death" },
		description = "Fire companion that also protects against heat.",
	}),
	["comp_snowstalker"] = companion({
		id = "comp_snowstalker",
		displayName = "Snowstalker",
		sourceBeastId = "frost_snowstalker",
		element = Enums.Element.Ice,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Support },
		rank = "B", tier = 3,
		baseHealth = 680, baseDamage = 62, moveSpeed = 27, attackRange = 12, attackCooldown = 1.6,
		abilities = {
			{ id = "frost_bite", name = "Frost Bite", kind = "Attack", cooldown = 7, magnitude = 2.0, range = 14, description = "Chilling bite." },
			{ id = "cold_aura", name = "Cold Aura", kind = "Buff", cooldown = 30, magnitude = 0.4, range = 26, description = "Grants cold resistance to nearby allies." },
		},
		evolution = {
			levels = { 16, 34 },
			forms = {
				{ id = "snowstalker_base", name = "Snowstalker", minLevel = 1, statScale = 1.0, description = "Silent cold hunter." },
				{ id = "snowstalker_glacial", name = "Glacial Stalker", minLevel = 34, requiredItemId = "core_apex", statScale = 1.7, description = "Freezing strikes and stronger aura." },
			},
		},
		eggItemId = "egg_frozen",
		tameDifficulty = 0.8,
		sounds = { idle = "comp_snowstalker_idle", attack = "comp_snowstalker_attack", death = "comp_snowstalker_death" },
		description = "Cold companion that also protects against freezing weather.",
	}),
	["comp_shadebeast"] = companion({
		id = "comp_shadebeast",
		displayName = "Shadebeast",
		sourceBeastId = "umbra_shadebeast",
		element = Enums.Element.Dark,
		roles = { Enums.CompanionRole.Combat },
		rank = "A", tier = 4,
		baseHealth = 900, baseDamage = 84, moveSpeed = 29, attackRange = 12, attackCooldown = 1.5,
		abilities = {
			{ id = "shadow_step", name = "Shadow Step", kind = "Attack", cooldown = 9, magnitude = 2.4, range = 30, description = "Strikes from concealment." },
			{ id = "veil", name = "Veil", kind = "Debuff", cooldown = 24, magnitude = 0.2, range = 34, description = "Reduces enemy accuracy." },
		},
		evolution = {
			levels = { 18, 38 },
			forms = {
				{ id = "shade_base", name = "Shadebeast", minLevel = 1, statScale = 1.0, description = "Elusive damage dealer." },
				{ id = "shade_nightfall", name = "Nightfall Shade", minLevel = 38, requiredItemId = "core_anomaly", statScale = 1.8, description = "Deeper concealment and heavier strikes." },
			},
		},
		eggItemId = "egg_umbra",
		tameDifficulty = 0.9,
		sounds = { idle = "comp_shade_idle", attack = "comp_shade_attack", death = "comp_shade_death" },
		description = "A corrupted companion that fights from the shadows.",
	}),
	["comp_luminal_wisp"] = companion({
		id = "comp_luminal_wisp",
		displayName = "Luminal Wisp",
		sourceBeastId = "solar_luminal",
		element = Enums.Element.Light,
		roles = { Enums.CompanionRole.Support, Enums.CompanionRole.Exploration },
		rank = "A", tier = 4,
		baseHealth = 520, baseDamage = 52, moveSpeed = 32, attackRange = 50, attackCooldown = 1.8,
		abilities = {
			{ id = "radiant_heal", name = "Radiant Heal", kind = "Heal", cooldown = 16, magnitude = 30, range = 34, description = "Heals allies with light." },
			{ id = "illuminate", name = "Illuminate", kind = "Scout", cooldown = 25, description = "Reveals a wide area, including hidden passages." },
		},
		evolution = {
			levels = { 18, 38 },
			forms = {
				{ id = "wisp_base", name = "Luminal Wisp", minLevel = 1, statScale = 1.0, description = "Support and scouting." },
				{ id = "wisp_dawn", name = "Dawn Wisp", minLevel = 38, requiredItemId = "core_anomaly", statScale = 1.7, description = "Stronger healing and wider illumination." },
			},
		},
		eggItemId = "egg_solar",
		tameDifficulty = 0.85,
		scouting = { radius = 300, revealsResources = true, revealsBeasts = true },
		sounds = { idle = "comp_wisp_idle", attack = "comp_wisp_attack", death = "comp_wisp_death" },
		description = "A radiant support companion that lights the way.",
	}),
	["comp_reefstalker"] = companion({
		id = "comp_reefstalker",
		displayName = "Reefstalker",
		sourceBeastId = "pelagic_reefstalker",
		element = Enums.Element.Water,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Exploration },
		rank = "B", tier = 3,
		baseHealth = 700, baseDamage = 60, moveSpeed = 24, attackRange = 12, attackCooldown = 1.7,
		abilities = {
			{ id = "tide_lash", name = "Tide Lash", kind = "Attack", cooldown = 8, magnitude = 2.1, range = 16, description = "Water-charged strike." },
			{ id = "dive_scout", name = "Dive Scout", kind = "Scout", cooldown = 24, description = "Reveals underwater resources and routes." },
		},
		evolution = {
			levels = { 16, 36 },
			forms = {
				{ id = "reefstalker_base", name = "Reefstalker", minLevel = 1, statScale = 1.0, description = "Amphibious hunter." },
				{ id = "reefstalker_abyssal", name = "Abyssal Stalker", minLevel = 36, requiredItemId = "core_apex", statScale = 1.7, description = "Better underwater performance." },
			},
		},
		eggItemId = "egg_abyssal",
		tameDifficulty = 0.8,
		scouting = { radius = 240, revealsResources = true, revealsBeasts = true },
		sounds = { idle = "comp_reefstalker_idle", attack = "comp_reefstalker_attack", death = "comp_reefstalker_death" },
		description = "Amphibious companion for coastal and underwater exploration.",
	}),
	["comp_riftwalker"] = companion({
		id = "comp_riftwalker",
		displayName = "Riftwalker",
		sourceBeastId = "null_riftwalker",
		element = Enums.Element.Void,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Exploration },
		rank = "S", tier = 5,
		baseHealth = 1100, baseDamage = 96, moveSpeed = 28, attackRange = 34, attackCooldown = 1.7,
		abilities = {
			{ id = "rift_step", name = "Rift Step", kind = "Attack", cooldown = 10, magnitude = 2.5, range = 40, description = "Attacks through a short rift." },
			{ id = "anomaly_sense", name = "Anomaly Sense", kind = "Scout", cooldown = 26, description = "Reveals anomalies and hidden caches." },
		},
		evolution = {
			levels = { 20, 42 },
			forms = {
				{ id = "riftwalker_base", name = "Riftwalker", minLevel = 1, statScale = 1.0, description = "Void-touched hunter." },
				{ id = "riftwalker_unmade", name = "Unmade Walker", minLevel = 42, requiredItemId = "core_anomaly", statScale = 1.9, description = "Longer rifts and heavier strikes." },
			},
		},
		eggItemId = "egg_void",
		tameDifficulty = 0.95,
		sounds = { idle = "comp_riftwalker_idle", attack = "comp_riftwalker_attack", death = "comp_riftwalker_death" },
		description = "A void companion that steps between short rifts.",
	}),
	["comp_magma_beetle"] = companion({
		id = "comp_magma_beetle",
		displayName = "Magma Beetle",
		sourceBeastId = "cinder_magma_beetle",
		element = Enums.Element.Fire,
		roles = { Enums.CompanionRole.Support, Enums.CompanionRole.Exploration },
		rank = "B", tier = 3,
		baseHealth = 1200, baseDamage = 34, moveSpeed = 13, attackRange = 8, attackCooldown = 2.6,
		abilities = {
			{ id = "carapace", name = "Molten Carapace", kind = "Buff", cooldown = 26, magnitude = 0.25, range = 24, description = "Shares damage reduction with the owner." },
			{ id = "ore_sniff", name = "Ore Sense", kind = "Harvest", cooldown = 20, magnitude = 0.2, range = 60, description = "Reveals nearby ore deposits." },
		},
		evolution = {
			levels = { 16, 34 },
			forms = {
				{ id = "beetle_base", name = "Magma Beetle", minLevel = 1, statScale = 1.0, description = "Slow but incredibly tough." },
				{ id = "beetle_forge", name = "Forge Beetle", minLevel = 34, requiredItemId = "core_apex", statScale = 1.6, description = "Better protection and ore sensing." },
			},
		},
		eggItemId = "egg_volcanic",
		tameDifficulty = 0.75,
		scouting = { radius = 200, revealsResources = true, revealsBeasts = false },
		sounds = { idle = "comp_beetle_idle", attack = "comp_beetle_attack", death = "comp_beetle_death" },
		description = "Armoured companion that finds ore and soaks damage.",
	}),
	["comp_glacier_worm"] = companion({
		id = "comp_glacier_worm",
		displayName = "Glacier Worm",
		sourceBeastId = "frost_glacier_worm",
		element = Enums.Element.Ice,
		roles = { Enums.CompanionRole.Combat },
		rank = "A", tier = 4,
		baseHealth = 1400, baseDamage = 92, moveSpeed = 16, attackRange = 18, attackCooldown = 2.4,
		abilities = {
			{ id = "breach", name = "Ice Breach", kind = "Attack", cooldown = 12, magnitude = 2.8, range = 26, description = "Breaches the ground for area damage." },
			{ id = "frozen_trail", name = "Frozen Trail", kind = "Debuff", cooldown = 22, magnitude = 0.35, range = 30, description = "Slows enemies that cross it." },
		},
		evolution = {
			levels = { 20, 40 },
			forms = {
				{ id = "worm_base", name = "Glacier Worm", minLevel = 1, statScale = 1.0, description = "Heavy burrowing attacker." },
				{ id = "worm_tunnel", name = "Tunnel Warden", minLevel = 40, requiredItemId = "core_anomaly", statScale = 1.8, description = "Larger breaches and longer trails." },
			},
		},
		eggItemId = "egg_frozen",
		tameDifficulty = 0.9,
		sounds = { idle = "comp_worm_idle", attack = "comp_worm_attack", death = "comp_worm_death" },
		description = "A heavy burrowing companion that controls the ground.",
	}),
	["comp_fractured_echo"] = companion({
		id = "comp_fractured_echo",
		displayName = "Fractured Echo",
		sourceBeastId = "null_fractured_echo",
		element = Enums.Element.Void,
		roles = { Enums.CompanionRole.Combat, Enums.CompanionRole.Support },
		rank = "A", tier = 4,
		baseHealth = 820, baseDamage = 78, moveSpeed = 26, attackRange = 30, attackCooldown = 1.8,
		abilities = {
			{ id = "echo_bolt", name = "Echo Bolt", kind = "Attack", cooldown = 7, magnitude = 2.2, range = 40, description = "Distorted ranged attack." },
			{ id = "phase_shift", name = "Phase Shift", kind = "Buff", cooldown = 28, magnitude = 0.2, range = 28, description = "Briefly reduces damage taken by allies." },
		},
		evolution = {
			levels = { 18, 40 },
			forms = {
				{ id = "echo_base", name = "Fractured Echo", minLevel = 1, statScale = 1.0, description = "Unstable ranged attacker." },
				{ id = "echo_parallax", name = "Parallax Echo", minLevel = 40, requiredItemId = "core_anomaly", statScale = 1.8, description = "Stronger distortion and shielding." },
			},
		},
		eggItemId = "egg_void",
		tameDifficulty = 0.92,
		sounds = { idle = "comp_echo_idle", attack = "comp_echo_attack", death = "comp_echo_death" },
		description = "A partially unmade companion whose attacks echo.",
	}),
}

local Companion = Registry.new("Companion", entries, { "id", "displayName" })

function Companion.MaxActive(inDungeon: boolean): number
	return inDungeon and Limits.Companion.MaxActiveDungeon or Limits.Companion.MaxActiveOpenWorld
end

function Companion.ExperienceForLevel(level: number, curve: number?): number
	local growth = curve or 1.12
	return math.floor(Limits.Progression.BaseExperienceForLevel * (growth ^ math.max(0, level - 1)))
end

function Companion.StatsAtLevel(speciesId: string, level: number): { health: number, damage: number }
	local def = Companion:Get(speciesId)
	if not def then
		return { health = 100, damage = 10 }
	end
	local clamped = math.clamp(math.floor(level), 1, Limits.Companion.MaxLevel)
	local scale = 1 + (clamped - 1) * 0.07
	return {
		health = math.floor(def.baseHealth * scale),
		damage = math.floor(def.baseDamage * scale),
	}
end

function Companion.FormForLevel(speciesId: string, level: number): any
	local def = Companion:Get(speciesId)
	if not def then
		return nil
	end
	local chosen = nil
	for _, form in def.evolution.forms do
		if level >= form.minLevel then
			chosen = form
		end
	end
	return chosen
end

function Companion.ByRole(role: string): { CompanionDef }
	return Companion:Filter(function(def)
		return table.find(def.roles, role) ~= nil
	end)
end

function Companion.ValidateAll(): { string }
	local problems = Registry.Validate(Companion)
	for _, def in Companion:List() do
		if #def.roles == 0 then
			table.insert(problems, string.format("[Companion] %s has no roles", def.id))
		end
		for _, role in def.roles do
			if not Enums.CompanionRole[role] then
				table.insert(problems, string.format("[Companion] %s has unknown role %q", def.id, tostring(role)))
			end
		end
		if #def.abilities == 0 then
			table.insert(problems, string.format("[Companion] %s has no abilities", def.id))
		end
		if #def.evolution.forms == 0 then
			table.insert(problems, string.format("[Companion] %s has no forms", def.id))
		end
		if not def.eggItemId then
			table.insert(problems, string.format("[Companion] %s has no egg item", def.id))
		end
	end
	return problems
end

Companion.Registry = Companion
return Companion
