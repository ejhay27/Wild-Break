--!strict
--[[
	LootConfig.luau
	Reward tables for bosses, beasts, dungeons and world events.

	Rewards are rolled and granted on the SERVER only, after participation has
	been validated. A client never tells the server what it received.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Registry = require(script.Parent.Registry)

export type LootEntry = {
	kind: string, -- Item | Weapon | Core | Egg | Currency | Blueprint
	id: string?,
	rarity: string?,
	min: number,
	max: number,
	chance: number,
	weight: number?,
}

export type LootTable = {
	id: string,
	displayName: string,
	-- Granted once per eligible participant per reward window.
	guaranteed: { LootEntry }?,
	rolls: number,
	entries: { LootEntry },
	requiresParticipation: boolean,
	cooldownSeconds: number?,
	description: string,
}

local function entry(kind: string, id: string?, min: number, max: number, chance: number, rarity: string?): LootEntry
	return { kind = kind, id = id, min = min, max = max, chance = chance, rarity = rarity }
end

local entries: { [string]: LootTable } = {
	["rewards_thornmaw"] = {
		id = "rewards_thornmaw",
		displayName = "Thornmaw Rewards",
		guaranteed = {
			entry("Item", "mat_thornmaw_bark", 2, 4, 1),
			entry("Core", "core_wild", 1, 2, 1),
		},
		rolls = 3,
		entries = {
			entry("Blueprint", "bp_ar_ranger", 1, 1, 0.25),
			entry("Blueprint", "bp_me_wildclaw", 1, 1, 0.2),
			entry("Item", "timber_ironwood", 3, 6, 0.6),
			entry("Item", "hide_apex", 1, 3, 0.45),
			entry("Item", "world_tree_sap", 1, 1, 0.15),
			entry("Egg", "egg_forest", 1, 1, 0.12),
			entry("Item", "research_data", 2, 5, 0.5),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Thornmaw, the Ancient Devourer.",
	},
	["rewards_pyraxis"] = {
		id = "rewards_pyraxis",
		displayName = "Pyr axis Rewards",
		guaranteed = {
			entry("Item", "mat_pyraxis_scale", 2, 5, 1),
			entry("Core", "core_resonance", 1, 2, 1),
		},
		rolls = 3,
		entries = {
			entry("Item", "mat_obsidian_shard", 3, 6, 0.55),
			entry("Item", "infernium", 1, 3, 0.3),
			entry("Item", "core_apex", 1, 1, 0.2),
			entry("Egg", "egg_volcanic", 1, 1, 0.12),
			entry("Item", "research_data", 3, 6, 0.5),
			entry("Item", "world_tree_sap", 1, 2, 0.18),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Pyr axis. Breaking the cocoon grants the standard table; the evolved form adds an additional roll.",
	},
	["rewards_glacieron"] = {
		id = "rewards_glacieron",
		displayName = "Glacieron Rewards",
		guaranteed = {
			entry("Item", "mat_glacieron_core", 2, 4, 1),
			entry("Core", "core_apex", 1, 1, 1),
		},
		rolls = 3,
		entries = {
			entry("Item", "mat_frost_shard", 4, 8, 0.55),
			entry("Item", "cryonix", 1, 3, 0.3),
			entry("Egg", "egg_frozen", 1, 1, 0.12),
			entry("Blueprint", "bp_module_experimental", 1, 1, 0.1),
			entry("Item", "world_tree_sap", 1, 2, 0.18),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Glacieron, the Whiteout King.",
	},
	["rewards_noctyra"] = {
		id = "rewards_noctyra",
		displayName = "Noctyra Rewards",
		guaranteed = {
			entry("Item", "mat_noctyra_veil", 2, 4, 1),
			entry("Core", "core_apex", 1, 2, 1),
		},
		rolls = 3,
		entries = {
			entry("Item", "umbralith", 3, 6, 0.55),
			entry("Item", "mat_umbral_resin", 4, 8, 0.5),
			entry("Egg", "egg_umbra", 1, 1, 0.12),
			entry("Item", "world_tree_sap", 1, 2, 0.18),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Noctyra, the Black Veil.",
	},
	["rewards_light_samurai"] = {
		id = "rewards_light_samurai",
		displayName = "Sunheart Colossus Rewards",
		guaranteed = {
			entry("Item", "mat_aurion_feather", 2, 4, 1),
			entry("Core", "core_anomaly", 1, 1, 1),
		},
		rolls = 4,
		entries = {
			entry("Item", "heliosite", 4, 8, 0.6),
			entry("Item", "aurumite", 2, 4, 0.4),
			entry("Egg", "egg_solar", 1, 1, 0.12),
			entry("Item", "world_tree_sap_concentrate", 1, 1, 0.15),
			entry("Blueprint", "bp_module_experimental", 1, 1, 0.12),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for surviving and defeating Aurion, the Sunheart Colossus.",
	},
	["rewards_abyssalith"] = {
		id = "rewards_abyssalith",
		displayName = "Abyssalith Rewards",
		guaranteed = {
			entry("Item", "mat_abyssalith_plate", 2, 4, 1),
			entry("Core", "core_apex", 1, 2, 1),
		},
		rolls = 3,
		entries = {
			entry("Item", "pelagite", 4, 8, 0.55),
			entry("Item", "abyssite", 1, 3, 0.3),
			entry("Egg", "egg_abyssal", 1, 1, 0.12),
			entry("Blueprint", "bp_boat_skiff", 1, 1, 0.15),
			entry("Item", "world_tree_sap", 1, 2, 0.18),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Abyssalith, the Deepwater Sovereign.",
	},
	["rewards_parallax"] = {
		id = "rewards_parallax",
		displayName = "Parallax Rewards",
		guaranteed = {
			entry("Item", "mat_parallax_fragment", 2, 4, 1),
			entry("Core", "core_anomaly", 1, 1, 1),
		},
		rolls = 4,
		entries = {
			entry("Item", "voidshard", 3, 6, 0.6),
			entry("Item", "nullite", 1, 2, 0.25),
			entry("Item", "mat_void_essence", 4, 8, 0.5),
			entry("Egg", "egg_void", 1, 1, 0.1),
			entry("Item", "world_tree_sap_concentrate", 1, 1, 0.15),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Rewards for defeating Parallax, the Unmade.",
	},
	["rewards_rootbound_prototype"] = {
		id = "rewards_rootbound_prototype",
		displayName = "Rootbound Prototype Rewards",
		guaranteed = { entry("Item", "mat_biolab_culture", 2, 5, 1), entry("Core", "core_wild", 1, 2, 1) },
		rolls = 2,
		entries = {
			entry("Item", "research_data", 3, 6, 0.6),
			entry("Item", "mushroom_sporepod", 2, 5, 0.45),
			entry("Egg", "egg_forest", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Overgrowth Biolab dungeon rewards.",
	},
	["rewards_magmaforged_alpha"] = {
		id = "rewards_magmaforged_alpha",
		displayName = "Magmaforged Alpha Rewards",
		guaranteed = { entry("Item", "mat_ember_ash", 4, 8, 1), entry("Core", "core_resonance", 1, 2, 1) },
		rolls = 2,
		entries = {
			entry("Item", "emberite", 3, 6, 0.6),
			entry("Item", "research_data", 2, 5, 0.5),
			entry("Egg", "egg_volcanic", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Geothermal Research Complex dungeon rewards.",
	},
	["rewards_project_permafrost"] = {
		id = "rewards_project_permafrost",
		displayName = "Project Permafrost Rewards",
		guaranteed = { entry("Item", "mat_glacial_ice", 4, 8, 1), entry("Core", "core_resonance", 1, 2, 1) },
		rolls = 2,
		entries = {
			entry("Item", "glacite", 3, 6, 0.6),
			entry("Item", "research_data", 2, 5, 0.5),
			entry("Egg", "egg_frozen", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Cryostasis Laboratory dungeon rewards.",
	},
	["rewards_subject_zero"] = {
		id = "rewards_subject_zero",
		displayName = "Subject Zero Rewards",
		guaranteed = { entry("Item", "mat_umbral_resin", 3, 6, 1), entry("Core", "core_apex", 1, 1, 1) },
		rolls = 2,
		entries = {
			entry("Item", "umbralith", 2, 5, 0.55),
			entry("Item", "research_data", 3, 6, 0.55),
			entry("Egg", "egg_umbra", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Blacksite Containment Facility dungeon rewards.",
	},
	["rewards_radiant_sentinel"] = {
		id = "rewards_radiant_sentinel",
		displayName = "Radiant Sentinel Rewards",
		guaranteed = { entry("Item", "mat_solar_alloy", 3, 6, 1), entry("Core", "core_apex", 1, 1, 1) },
		rolls = 2,
		entries = {
			entry("Item", "heliosite", 2, 5, 0.55),
			entry("Item", "research_data", 3, 6, 0.55),
			entry("Egg", "egg_solar", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Helios Energy Research Station dungeon rewards.",
	},
	["rewards_trenchborn_leviathan"] = {
		id = "rewards_trenchborn_leviathan",
		displayName = "Trenchborn Leviathan Rewards",
		guaranteed = { entry("Item", "mat_abyssal_pearl", 2, 4, 1), entry("Core", "core_apex", 1, 1, 1) },
		rolls = 2,
		entries = {
			entry("Item", "pelagite", 3, 6, 0.55),
			entry("Item", "research_data", 3, 6, 0.55),
			entry("Egg", "egg_abyssal", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Abyssal Research Station dungeon rewards.",
	},
	["rewards_fractured_architect"] = {
		id = "rewards_fractured_architect",
		displayName = "Fractured Architect Rewards",
		guaranteed = { entry("Item", "mat_void_essence", 4, 8, 1), entry("Core", "core_anomaly", 1, 1, 1) },
		rolls = 3,
		entries = {
			entry("Item", "voidshard", 2, 5, 0.55),
			entry("Item", "nullite", 1, 2, 0.25),
			entry("Item", "research_data", 4, 8, 0.6),
			entry("Egg", "egg_void", 1, 1, 0.08),
		},
		requiresParticipation = true,
		cooldownSeconds = 600,
		description = "Nullpoint Anomaly Complex dungeon rewards.",
	},
	["rewards_elder_veyl"] = {
		id = "rewards_elder_veyl",
		displayName = "Elder Veyl Rewards",
		guaranteed = {
			entry("Item", "mat_elder_veyl_root", 2, 4, 1),
			entry("Item", "world_tree_sap", 3, 6, 1),
			entry("Core", "core_anomaly", 1, 1, 1),
		},
		rolls = 4,
		entries = {
			entry("Item", "world_tree_sap_concentrate", 1, 2, 0.35),
			entry("Item", "sapcrystal", 1, 3, 0.4),
			entry("Item", "core_apex", 1, 2, 0.4),
			entry("Blueprint", "bp_module_experimental", 1, 1, 0.15),
			entry("Item", "research_data", 5, 10, 0.6),
		},
		requiresParticipation = true,
		cooldownSeconds = 3600,
		description = "ROOTFALL Sapheart rewards. Sap yields are controlled by participation and encounter cooldowns.",
	},
	["rewards_beast_common"] = {
		id = "rewards_beast_common",
		displayName = "Common Beast Rewards",
		guaranteed = {},
		rolls = 2,
		entries = {
			entry("Item", "hide_beast", 1, 3, 0.8),
			entry("Item", "bone_beast", 1, 2, 0.6),
			entry("Item", "sinew_beast", 1, 2, 0.5),
			entry("Item", "crystal_resonant", 1, 1, 0.08),
		},
		requiresParticipation = true,
		description = "Standard drops from ordinary beasts.",
	},
	["rewards_beast_elite"] = {
		id = "rewards_beast_elite",
		displayName = "Elite Beast Rewards",
		guaranteed = { entry("Item", "hide_apex", 1, 2, 1) },
		rolls = 3,
		entries = {
			entry("Core", "core_wild", 1, 2, 0.5),
			entry("Core", "core_resonance", 1, 1, 0.25),
			entry("Item", "research_sample", 2, 5, 0.6),
			entry("Item", "crystal_resonant", 1, 3, 0.4),
		},
		requiresParticipation = true,
		description = "Drops from elite beasts.",
	},
}

local Loot = Registry.new("Loot", entries, { "id", "displayName" })

-- Rolls a table on the server. Returns a list of {kind, id, quantity}.
function Loot.Roll(tableId: string, random: () -> number, bonusRolls: number?): { { kind: string, id: string?, quantity: number, rarity: string? } }
	local table_ = Loot:Get(tableId)
	if not table_ then
		return {}
	end
	local out = {}

	local function add(item: LootEntry, force: boolean?)
		if not force and random() > item.chance then
			return
		end
		local quantity = item.min + math.floor(random() * (item.max - item.min + 1))
		if quantity > 0 then
			table.insert(out, { kind = item.kind, id = item.id, quantity = quantity, rarity = item.rarity })
		end
	end

	for _, guaranteed in table_.guaranteed or {} do
		add(guaranteed, true)
	end
	local rolls = (table_.rolls or 0) + (bonusRolls or 0)
	for _ = 1, rolls do
		local totalWeight = 0
		for _, candidate in table_.entries do
			totalWeight += candidate.weight or candidate.chance or 1
		end
		if totalWeight <= 0 then
			break
		end
		local roll = random() * totalWeight
		local cumulative = 0
		for _, candidate in table_.entries do
			cumulative += candidate.weight or candidate.chance or 1
			if roll <= cumulative then
				add(candidate)
				break
			end
		end
	end
	return out
end

function Loot.ValidateAll(): { string }
	local problems = Registry.Validate(Loot)
	for _, table_ in Loot:List() do
		for _, item in table_.entries do
			if item.min > item.max then
				table.insert(problems, string.format("[Loot] %s entry %s has min > max", table_.id, tostring(item.id)))
			end
			if item.chance < 0 or item.chance > 1 then
				table.insert(problems, string.format("[Loot] %s entry %s has an invalid chance", table_.id, tostring(item.id)))
			end
		end
		if table_.requiresParticipation ~= true then
			table.insert(problems, string.format("[Loot] %s must require validated participation", table_.id))
		end
	end
	return problems
end

Loot.Registry = Loot
return Loot
