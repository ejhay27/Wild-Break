--!strict
--[[
	DungeonBossData.luau
	The seven regional dungeon bosses plus Elder Veyl, Guardian of the
	Sapheart (ROOTFALL: THE WORLD BELOW).

	Each of these is a distinct encounter, not a renamed ordinary enemy.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

export type DungeonAttack = {
	id: string, name: string, kind: string,
	telegraph: number?, windup: number?, active: number?, recovery: number?, cooldown: number?,
	damage: number?, damageType: string?, range: number?, radius: number?,
	projectileSpeed: number?, count: number?,
	statusEffect: string?, statusDuration: number?,
	interruptible: boolean?, minPhase: number?, weight: number?,
	mechanic: string?, audio: string?, vfx: string?,
}

export type DungeonBossDef = {
	id: string,
	displayName: string,
	title: string,
	kind: string,
	regionId: string?,
	dungeonId: string?,
	element: string,
	rank: string,
	tier: number,
	baseHealth: number,
	baseDamage: number,
	moveSpeed: number,
	resistances: { [string]: number },
	phases: {
		index: number,
		name: string,
		healthThreshold: number,
		defenseState: string,
		incomingDamageMultiplier: number,
		crowdControlResistance: number,
		armor: { value: number }?,
		shield: { capacity: number, regenerates: boolean }?,
		attacks: { DungeonAttack },
		weakPoints: { { id: string, name: string, attachment: string, exposedPhases: { number }, multiplier: number, vulnerabilityWindowSeconds: number? } }?,
		mechanic: string?,
		onEnter: { [string]: any }?,
	} ,
	rewardTableId: string,
	respawnSeconds: number?,
	intro: { duration: number, cinematic: string?, audio: string? },
	death: { duration: number, sequence: string, audio: string? },
	audio: { [string]: string },
	vfx: { [string]: string },
	special: { [string]: any }?,
	safeguards: { [string]: any },
	description: string,
}

local function att(def: DungeonAttack): DungeonAttack
	def.telegraph = def.telegraph or 0.8
	def.windup = def.windup or 0.5
	def.active = def.active or 0.4
	def.recovery = def.recovery or 1.0
	def.interruptible = def.interruptible ~= false
	def.weight = def.weight or 1
	return def
end

local function dboss(def: DungeonBossDef): DungeonBossDef
	def.respawnSeconds = def.respawnSeconds or Limits.Boss.DungeonBossRespawnSeconds
	def.safeguards = def.safeguards or {}
	return def
end

local D: { [string]: DungeonBossDef } = {}

-- ===========================================================================
-- DUNGEON BOSS 1 - THE ROOTBOUND PROTOTYPE (Overgrowth Biolab)
-- ===========================================================================
D["rootbound_prototype"] = dboss({
	id = "rootbound_prototype",
	displayName = "The Rootbound Prototype",
	title = "Biolab Specimen Prime",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.VerdantReach,
	dungeonId = "dungeon_overgrowth_biolab",
	element = Enums.Element.Forest,
	rank = "A",
	tier = 3,
	baseHealth = 150000,
	baseDamage = 260,
	moveSpeed = 16,
	resistances = { [Enums.DamageType.Bio] = 0.55, [Enums.DamageType.Fire] = 1.5 },
	phases = {
		{
			index = 1,
			name = "Contained Specimen",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.2,
			attacks = {
				att({ id = "tendril_whip", name = "Tendril Whip", kind = "Melee", damage = 220, damageType = Enums.DamageType.Physical, range = 44, radius = 26, cooldown = 7, weight = 3, audio = "dboss_rootbound_whip", vfx = "fx_rootbound_whip" }),
				att({ id = "spore_burst", name = "Spore Burst", kind = "Projectile", damage = 170, damageType = Enums.DamageType.Bio, range = 180, radius = 12, projectileSpeed = 130, count = 4, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 5, cooldown = 9, weight = 2, audio = "dboss_rootbound_spore", vfx = "fx_rootbound_spore" }),
			},
		},
		{
			index = 2,
			name = "Growth Cascade",
			healthThreshold = 0.6,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.7,
			crowdControlResistance = 0.35,
			armor = { value = 22000 },
			mechanic = "Root armor plates can be broken. Destroying a plate stuns the prototype briefly.",
			onEnter = { spawnArmorPlates = 3, plateHealth = 9000 },
			attacks = {
				att({ id = "growth_slam", name = "Growth Slam", kind = "Melee", damage = 340, damageType = Enums.DamageType.Physical, range = 50, radius = 30, cooldown = 10, weight = 2, audio = "dboss_rootbound_slam", vfx = "fx_rootbound_slam" }),
				att({ id = "root_cage", name = "Root Cage", kind = "Zone", damage = 200, damageType = Enums.DamageType.Physical, range = 160, radius = 22, count = 3, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 2, cooldown = 12, weight = 2, audio = "dboss_rootbound_cage", vfx = "fx_rootbound_cage" }),
			},
			weakPoints = { { id = "wp_plate", name = "Root Armor Plate", attachment = "PlateSocket", exposedPhases = { 2 }, multiplier = 2.4 } },
		},
		{
			index = 3,
			name = "Prototype Overload",
			healthThreshold = 0.25,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.3,
			mechanic = "The containment core is exposed. Heavy damage window with frequent area attacks.",
			attacks = {
				att({ id = "overload_nova", name = "Overload Nova", kind = "Zone", damage = 320, damageType = Enums.DamageType.Bio, range = 200, radius = 50, cooldown = 12, weight = 2, audio = "dboss_rootbound_nova", vfx = "fx_rootbound_nova" }),
				att({ id = "core_window", name = "Core Exposure", kind = "Buff", damage = 0, recovery = 5, cooldown = 20, weight = 1, interruptible = false, mechanic = "Opens the core for 5 seconds.", audio = "dboss_rootbound_vulnerable", vfx = "fx_rootbound_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Containment Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.8, vulnerabilityWindowSeconds = 5 } },
		},
	},
	rewardTableId = "rewards_rootbound_prototype",
	intro = { duration = 4, cinematic = "cin_rootbound_intro", audio = "dboss_rootbound_intro" },
	death = { duration = 6, sequence = "withers_into_compost", audio = "dboss_rootbound_death" },
	audio = { intro = "dboss_rootbound_intro", phase = "dboss_rootbound_phase", death = "dboss_rootbound_death" },
	vfx = { body = "fx_rootbound_body", armor = "fx_rootbound_armor" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds },
	description = "A plant-machine hybrid grown inside the Overgrowth Biolab.",
})

-- ===========================================================================
-- DUNGEON BOSS 2 - MAGMAFORGED ALPHA (Cinderfall)
-- ===========================================================================
D["magmaforged_alpha"] = dboss({
	id = "magmaforged_alpha",
	displayName = "Magmaforged Alpha",
	title = "Forge Warden",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.Cinderfall,
	dungeonId = "dungeon_geothermal_complex",
	element = Enums.Element.Fire,
	rank = "A",
	tier = 3,
	baseHealth = 165000,
	baseDamage = 290,
	moveSpeed = 18,
	resistances = { [Enums.DamageType.Fire] = 0.45, [Enums.DamageType.Ice] = 1.8, [Enums.DamageType.Water] = 1.6 },
	phases = {
		{
			index = 1,
			name = "Forge Heat",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			attacks = {
				att({ id = "molten_swing", name = "Molten Swing", kind = "Melee", damage = 260, damageType = Enums.DamageType.Fire, range = 42, radius = 26, statusEffect = Enums.StatusEffect.Burn, statusDuration = 4, cooldown = 7, weight = 3, audio = "dboss_magma_swing", vfx = "fx_magma_swing" }),
				att({ id = "lava_spit", name = "Lava Spit", kind = "Projectile", damage = 200, damageType = Enums.DamageType.Fire, range = 190, radius = 14, projectileSpeed = 140, count = 3, cooldown = 9, weight = 2, audio = "dboss_magma_spit", vfx = "fx_magma_spit" }),
			},
		},
		{
			index = 2,
			name = "Molten Armor",
			healthThreshold = 0.62,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.65,
			crowdControlResistance = 0.4,
			armor = { value = 26000 },
			mechanic = "Molten armor is quenched by ice and water damage, which then makes it brittle and breakable.",
			onEnter = { quenchElements = { "Ice", "Water" }, brittleAfterQuench = true },
			attacks = {
				att({ id = "forge_stomp", name = "Forge Stomp", kind = "Melee", damage = 360, damageType = Enums.DamageType.Fire, range = 54, radius = 34, cooldown = 10, weight = 2, audio = "dboss_magma_stomp", vfx = "fx_magma_stomp" }),
				att({ id = "magma_pool", name = "Magma Pool", kind = "Zone", damage = 240, damageType = Enums.DamageType.Fire, range = 180, radius = 28, count = 3, statusEffect = Enums.StatusEffect.Burn, statusDuration = 5, cooldown = 12, weight = 2, audio = "dboss_magma_pool", vfx = "fx_magma_pool" }),
			},
			weakPoints = { { id = "wp_forge", name = "Forge Vent", attachment = "ForgeSocket", exposedPhases = { 2 }, multiplier = 2.3 } },
		},
		{
			index = 3,
			name = "Alpha Overheat",
			healthThreshold = 0.28,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.35,
			crowdControlResistance = 0.3,
			attacks = {
				att({ id = "overheat_burst", name = "Overheat Burst", kind = "Ultimate", telegraph = 2.4, damage = 520, damageType = Enums.DamageType.Fire, range = 240, radius = 90, cooldown = 26, weight = 1, audio = "dboss_magma_overheat", vfx = "fx_magma_overheat" }),
				att({ id = "core_window", name = "Vent Open", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_magma_vulnerable", vfx = "fx_magma_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Alpha Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.6, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_magmaforged_alpha",
	intro = { duration = 4, cinematic = "cin_magma_intro", audio = "dboss_magma_intro" },
	death = { duration = 6, sequence = "cools_into_slag", audio = "dboss_magma_death" },
	audio = { intro = "dboss_magma_intro", phase = "dboss_magma_phase", death = "dboss_magma_death" },
	vfx = { body = "fx_magma_body", armor = "fx_magma_armor" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds },
	description = "A forge-born alpha whose molten armor must be quenched before it can be broken.",
})

-- ===========================================================================
-- DUNGEON BOSS 3 - PROJECT PERMAFROST (Cryostasis Laboratory)
-- ===========================================================================
D["project_permafrost"] = dboss({
	id = "project_permafrost",
	displayName = "Project Permafrost",
	title = "Cryostasis Anomaly",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.Frostveil,
	dungeonId = "dungeon_cryostasis_lab",
	element = Enums.Element.Ice,
	rank = "A",
	tier = 3,
	baseHealth = 158000,
	baseDamage = 270,
	moveSpeed = 15,
	resistances = { [Enums.DamageType.Ice] = 0.45, [Enums.DamageType.Fire] = 1.7 },
	phases = {
		{
			index = 1,
			name = "Thaw Cycle",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.2,
			attacks = {
				att({ id = "cryo_blast", name = "Cryo Blast", kind = "Projectile", damage = 190, damageType = Enums.DamageType.Ice, range = 200, radius = 12, projectileSpeed = 180, count = 4, statusEffect = Enums.StatusEffect.Chill, statusDuration = 3, cooldown = 8, weight = 3, audio = "dboss_permafrost_blast", vfx = "fx_permafrost_blast" }),
				att({ id = "frozen_grasp", name = "Frozen Grasp", kind = "Melee", damage = 250, damageType = Enums.DamageType.Ice, range = 40, radius = 24, statusEffect = Enums.StatusEffect.Chill, statusDuration = 3, cooldown = 7, weight = 2, audio = "dboss_permafrost_grasp", vfx = "fx_permafrost_grasp" }),
			},
		},
		{
			index = 2,
			name = "Containment Failure",
			healthThreshold = 0.6,
			defenseState = Enums.DefenseState.Shielded,
			incomingDamageMultiplier = 0.8,
			crowdControlResistance = 0.4,
			shield = { capacity = 40000, regenerates = false },
			mechanic = "A cryo shield must be broken before the boss takes full damage.",
			attacks = {
				att({ id = "frost_nova", name = "Frost Nova", kind = "Zone", damage = 280, damageType = Enums.DamageType.Ice, range = 170, radius = 48, statusEffect = Enums.StatusEffect.Chill, statusDuration = 4, cooldown = 12, weight = 2, audio = "dboss_permafrost_nova", vfx = "fx_permafrost_nova" }),
				att({ id = "ice_prison", name = "Cryo Cell", kind = "Zone", damage = 210, damageType = Enums.DamageType.Ice, range = 160, radius = 20, count = 3, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 2.5, cooldown = 13, weight = 2, audio = "dboss_permafrost_cell", vfx = "fx_permafrost_cell" }),
			},
			weakPoints = { { id = "wp_cell", name = "Cryo Cell", attachment = "CellSocket", exposedPhases = { 2 }, multiplier = 2.2 } },
		},
		{
			index = 3,
			name = "Absolute Containment",
			healthThreshold = 0.25,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.45,
			crowdControlResistance = 0.3,
			attacks = {
				att({ id = "flash_freeze", name = "Flash Freeze", kind = "Ultimate", telegraph = 2.6, damage = 460, damageType = Enums.DamageType.Ice, range = 220, radius = 100, cooldown = 28, weight = 1, audio = "dboss_permafrost_ultimate", vfx = "fx_permafrost_ultimate" }),
				att({ id = "core_window", name = "Core Thaw", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_permafrost_vulnerable", vfx = "fx_permafrost_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Thawed Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.9, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_project_permafrost",
	intro = { duration = 4, cinematic = "cin_permafrost_intro", audio = "dboss_permafrost_intro" },
	death = { duration = 6, sequence = "shatters_into_frost", audio = "dboss_permafrost_death" },
	audio = { intro = "dboss_permafrost_intro", phase = "dboss_permafrost_phase", death = "dboss_permafrost_death" },
	vfx = { body = "fx_permafrost_body", shield = "fx_permafrost_shield" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds },
	description = "A cryostasis experiment that never reached a stable state.",
})

-- ===========================================================================
-- DUNGEON BOSS 4 - SUBJECT ZERO (Blacksite Containment Facility)
-- ===========================================================================
D["subject_zero"] = dboss({
	id = "subject_zero",
	displayName = "Subject Zero",
	title = "Containment Breach",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.UmbraExpanse,
	dungeonId = "dungeon_blacksite_containment",
	element = Enums.Element.Dark,
	rank = "S",
	tier = 4,
	baseHealth = 175000,
	baseDamage = 300,
	moveSpeed = 26,
	resistances = { [Enums.DamageType.Dark] = 0.5, [Enums.DamageType.Light] = 1.6 },
	phases = {
		{
			index = 1,
			name = "Observation",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			attacks = {
				att({ id = "lunge", name = "Silent Lunge", kind = "Charge", damage = 280, damageType = Enums.DamageType.Dark, range = 150, radius = 16, cooldown = 7, weight = 3, audio = "dboss_zero_lunge", vfx = "fx_zero_lunge" }),
				att({ id = "shadow_slash", name = "Shadow Slash", kind = "Melee", damage = 230, damageType = Enums.DamageType.Dark, range = 38, radius = 24, cooldown = 6, weight = 3, audio = "dboss_zero_slash", vfx = "fx_zero_slash" }),
			},
		},
		{
			index = 2,
			name = "Concealment",
			healthThreshold = 0.65,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.85,
			crowdControlResistance = 0.4,
			mechanic = "Subject Zero cloaks and strikes from concealment. Sensor gadgets and motion tracking reveal it; telegraphs stay visible in darkness.",
			onEnter = { cloak = true, revealableBy = { "motion_sensor", "scout_drone" }, telegraphVisibility = "always" },
			attacks = {
				att({ id = "cloak_ambush", name = "Cloaked Ambush", kind = "Melee", damage = 340, damageType = Enums.DamageType.Dark, range = 50, radius = 22, cooldown = 9, weight = 2, audio = "dboss_zero_ambush", vfx = "fx_zero_ambush" }),
				att({ id = "dark_pulse", name = "Dark Pulse", kind = "Zone", damage = 230, damageType = Enums.DamageType.Dark, range = 150, radius = 40, cooldown = 11, weight = 2, audio = "dboss_zero_pulse", vfx = "fx_zero_pulse" }),
			},
			weakPoints = { { id = "wp_eye", name = "Tracking Eye", attachment = "EyeSocket", exposedPhases = { 2 }, multiplier = 2.2 } },
		},
		{
			index = 3,
			name = "Full Release",
			healthThreshold = 0.3,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.35,
			attacks = {
				att({ id = "release_wave", name = "Release Wave", kind = "Ultimate", telegraph = 2.4, damage = 480, damageType = Enums.DamageType.Dark, range = 220, radius = 95, cooldown = 26, weight = 1, audio = "dboss_zero_ultimate", vfx = "fx_zero_ultimate" }),
				att({ id = "core_window", name = "Exposure", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_zero_vulnerable", vfx = "fx_zero_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Unstable Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.8, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_subject_zero",
	intro = { duration = 4, cinematic = "cin_zero_intro", audio = "dboss_zero_intro" },
	death = { duration = 6, sequence = "collapses_into_shadow", audio = "dboss_zero_death" },
	audio = { intro = "dboss_zero_intro", phase = "dboss_zero_phase", death = "dboss_zero_death" },
	vfx = { body = "fx_zero_body", cloak = "fx_zero_cloak" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds, telegraphsVisibleInDarkness = true },
	description = "An escaped containment subject that fights through concealment.",
})

-- ===========================================================================
-- DUNGEON BOSS 5 - THE RADIANT SENTINEL (Helios Energy Research Station)
-- ===========================================================================
D["radiant_sentinel"] = dboss({
	id = "radiant_sentinel",
	displayName = "The Radiant Sentinel",
	title = "Helios Gatekeeper",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.SolaraBasin,
	dungeonId = "dungeon_helios_station",
	element = Enums.Element.Light,
	rank = "S",
	tier = 4,
	baseHealth = 190000,
	baseDamage = 310,
	moveSpeed = 20,
	resistances = { [Enums.DamageType.Light] = 0.5, [Enums.DamageType.Dark] = 1.6 },
	phases = {
		{
			index = 1,
			name = "Rotating Facets",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Shielded,
			incomingDamageMultiplier = 0.8,
			crowdControlResistance = 0.35,
			shield = { capacity = 45000, regenerates = false },
			mechanic = "Rotating shield facets expose a vulnerable emitter on a fixed rhythm.",
			attacks = {
				att({ id = "light_lance", name = "Light Lance", kind = "Beam", damage = 260, damageType = Enums.DamageType.Light, range = 240, radius = 12, cooldown = 9, weight = 3, audio = "dboss_sentinel_lance", vfx = "fx_sentinel_lance" }),
				att({ id = "solar_flare", name = "Solar Flare", kind = "Zone", damage = 220, damageType = Enums.DamageType.Light, range = 180, radius = 34, cooldown = 11, weight = 2, audio = "dboss_sentinel_flare", vfx = "fx_sentinel_flare" }),
			},
			weakPoints = { { id = "wp_emitter", name = "Shield Emitter", attachment = "EmitterSocket", exposedPhases = { 1 }, multiplier = 2.5 } },
		},
		{
			index = 2,
			name = "Emitter Cascade",
			healthThreshold = 0.58,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.75,
			crowdControlResistance = 0.45,
			armor = { value = 28000 },
			attacks = {
				att({ id = "prism_burst", name = "Prism Burst", kind = "Projectile", damage = 240, damageType = Enums.DamageType.Light, range = 220, radius = 12, projectileSpeed = 200, count = 6, cooldown = 10, weight = 2, audio = "dboss_sentinel_prism", vfx = "fx_sentinel_prism" }),
				att({ id = "purge_sweep", name = "Purge Sweep", kind = "Melee", damage = 340, damageType = Enums.DamageType.Light, range = 70, radius = 46, cooldown = 12, weight = 2, audio = "dboss_sentinel_sweep", vfx = "fx_sentinel_sweep" }),
			},
			weakPoints = { { id = "wp_prism", name = "Prism Array", attachment = "PrismSocket", exposedPhases = { 2 }, multiplier = 2.4 } },
		},
		{
			index = 3,
			name = "Core Overload",
			healthThreshold = 0.26,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.3,
			attacks = {
				att({ id = "helios_burst", name = "Helios Burst", kind = "Ultimate", telegraph = 2.6, damage = 500, damageType = Enums.DamageType.Light, range = 240, radius = 100, cooldown = 26, weight = 1, audio = "dboss_sentinel_ultimate", vfx = "fx_sentinel_ultimate" }),
				att({ id = "core_window", name = "Core Vent", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_sentinel_vulnerable", vfx = "fx_sentinel_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Helios Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.8, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_radiant_sentinel",
	intro = { duration = 4, cinematic = "cin_sentinel_intro", audio = "dboss_sentinel_intro" },
	death = { duration = 6, sequence = "folds_into_light", audio = "dboss_sentinel_death" },
	audio = { intro = "dboss_sentinel_intro", phase = "dboss_sentinel_phase", death = "dboss_sentinel_death" },
	vfx = { body = "fx_sentinel_body", shield = "fx_sentinel_shield" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds },
	description = "A photonic construct that guards the Helios research station.",
})

-- ===========================================================================
-- DUNGEON BOSS 6 - TRENCHBORN LEVIATHAN (Abyssal Research Station)
-- ===========================================================================
D["trenchborn_leviathan"] = dboss({
	id = "trenchborn_leviathan",
	displayName = "Trenchborn Leviathan",
	title = "Deep Station Terror",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.PelagicFrontier,
	dungeonId = "dungeon_abyssal_station",
	element = Enums.Element.Water,
	rank = "S",
	tier = 4,
	baseHealth = 185000,
	baseDamage = 300,
	moveSpeed = 24,
	resistances = { [Enums.DamageType.Water] = 0.5, [Enums.DamageType.Energy] = 1.3 },
	phases = {
		{
			index = 1,
			name = "Station Flood",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			onEnter = { floodArena = true, enableSwimming = true },
			attacks = {
				att({ id = "tail_lash", name = "Tail Lash", kind = "Melee", damage = 270, damageType = Enums.DamageType.Physical, range = 56, radius = 40, cooldown = 8, weight = 3, audio = "dboss_leviathan_lash", vfx = "fx_leviathan_lash" }),
				att({ id = "pressure_jet", name = "Pressure Jet", kind = "Projectile", damage = 210, damageType = Enums.DamageType.Water, range = 200, radius = 12, projectileSpeed = 180, count = 4, cooldown = 9, weight = 2, audio = "dboss_leviathan_jet", vfx = "fx_leviathan_jet" }),
			},
		},
		{
			index = 2,
			name = "Depth Pressure",
			healthThreshold = 0.6,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.7,
			crowdControlResistance = 0.4,
			armor = { value = 24000 },
			mechanic = "Pressure plates crack under sustained damage, exposing the leviathan's flank.",
			attacks = {
				att({ id = "crush", name = "Pressure Crush", kind = "Melee", damage = 380, damageType = Enums.DamageType.Physical, range = 60, radius = 36, cooldown = 11, weight = 2, audio = "dboss_leviathan_crush", vfx = "fx_leviathan_crush" }),
				att({ id = "vortex", name = "Drain Vortex", kind = "Zone", damage = 250, damageType = Enums.DamageType.Water, range = 180, radius = 44, cooldown = 13, weight = 2, audio = "dboss_leviathan_vortex", vfx = "fx_leviathan_vortex" }),
			},
			weakPoints = { { id = "wp_flank", name = "Cracked Flank", attachment = "FlankSocket", exposedPhases = { 2 }, multiplier = 2.3 } },
		},
		{
			index = 3,
			name = "Surfaced Fury",
			healthThreshold = 0.26,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.3,
			attacks = {
				att({ id = "tidal_crash", name = "Tidal Crash", kind = "Ultimate", telegraph = 2.6, damage = 520, damageType = Enums.DamageType.Water, range = 240, radius = 100, cooldown = 26, weight = 1, audio = "dboss_leviathan_ultimate", vfx = "fx_leviathan_ultimate" }),
				att({ id = "core_window", name = "Gill Exposure", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_leviathan_vulnerable", vfx = "fx_leviathan_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Exposed Gill Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.8, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_trenchborn_leviathan",
	intro = { duration = 4, cinematic = "cin_leviathan_intro", audio = "dboss_leviathan_intro" },
	death = { duration = 6, sequence = "sinks_into_the_trench", audio = "dboss_leviathan_death" },
	audio = { intro = "dboss_leviathan_intro", phase = "dboss_leviathan_phase", death = "dboss_leviathan_death" },
	vfx = { body = "fx_leviathan_body", water = "fx_leviathan_water" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds, maxAbsentSeconds = 6 },
	description = "A deep station terror that floods its own arena.",
})

-- ===========================================================================
-- DUNGEON BOSS 7 - THE FRACTURED ARCHITECT (Nullpoint Anomaly Complex)
-- ===========================================================================
D["fractured_architect"] = dboss({
	id = "fractured_architect",
	displayName = "The Fractured Architect",
	title = "Builder of Broken Space",
	kind = Enums.BossKind.DungeonBoss,
	regionId = Enums.RegionId.NullHorizon,
	dungeonId = "dungeon_nullpoint_complex",
	element = Enums.Element.Void,
	rank = "SS",
	tier = 5,
	baseHealth = 205000,
	baseDamage = 330,
	moveSpeed = 22,
	resistances = { [Enums.DamageType.Void] = 0.5, [Enums.DamageType.Physical] = 1.15 },
	phases = {
		{
			index = 1,
			name = "Blueprint",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.3,
			mechanic = "The Architect builds walls and platforms. Routes change but the arena always remains solvable.",
			onEnter = { buildGeometry = true, maxStructures = 12 },
			attacks = {
				att({ id = "wall_push", name = "Rising Wall", kind = "Zone", damage = 260, damageType = Enums.DamageType.Void, range = 180, radius = 24, cooldown = 10, weight = 2, audio = "dboss_architect_wall", vfx = "fx_architect_wall" }),
				att({ id = "void_bolt", name = "Void Bolt", kind = "Projectile", damage = 210, damageType = Enums.DamageType.Void, range = 220, radius = 10, projectileSpeed = 200, count = 4, cooldown = 8, weight = 3, audio = "dboss_architect_bolt", vfx = "fx_architect_bolt" }),
			},
		},
		{
			index = 2,
			name = "Impossible Angles",
			healthThreshold = 0.62,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.7,
			crowdControlResistance = 0.45,
			armor = { value = 30000 },
			mechanic = "Gravity plates rotate. Movement, positioning and cover all change on a timer.",
			onEnter = { rotateGravity = true, gravityIntervalSeconds = 18 },
			attacks = {
				att({ id = "shift_maze", name = "Shifting Maze", kind = "Zone", damage = 240, damageType = Enums.DamageType.Void, range = 200, radius = 30, count = 3, cooldown = 12, weight = 2, audio = "dboss_architect_maze", vfx = "fx_architect_maze" }),
				att({ id = "collapse_strike", name = "Collapse Strike", kind = "Melee", damage = 400, damageType = Enums.DamageType.Void, range = 60, radius = 36, cooldown = 11, weight = 2, audio = "dboss_architect_strike", vfx = "fx_architect_strike" }),
			},
			weakPoints = { { id = "wp_pillar", name = "Anchor Pillar", attachment = "PillarSocket", exposedPhases = { 2 }, multiplier = 2.4 } },
		},
		{
			index = 3,
			name = "Blueprint Collapse",
			healthThreshold = 0.28,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.45,
			crowdControlResistance = 0.35,
			attacks = {
				att({ id = "unmake_field", name = "Unmake Field", kind = "Ultimate", telegraph = 2.6, damage = 520, damageType = Enums.DamageType.Void, range = 240, radius = 100, cooldown = 26, weight = 1, audio = "dboss_architect_ultimate", vfx = "fx_architect_ultimate" }),
				att({ id = "core_window", name = "Core Exposure", kind = "Buff", damage = 0, recovery = 6, cooldown = 20, weight = 1, interruptible = false, audio = "dboss_architect_vulnerable", vfx = "fx_architect_vulnerable" }),
			},
			weakPoints = { { id = "wp_core", name = "Architect Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.9, vulnerabilityWindowSeconds = 6 } },
		},
	},
	rewardTableId = "rewards_fractured_architect",
	intro = { duration = 4, cinematic = "cin_architect_intro", audio = "dboss_architect_intro" },
	death = { duration = 6, sequence = "unbuilds_itself", audio = "dboss_architect_death" },
	audio = { intro = "dboss_architect_intro", phase = "dboss_architect_phase", death = "dboss_architect_death" },
	vfx = { body = "fx_architect_body", rift = "fx_architect_rift" },
	special = { type = "GeometryBuilder", maxStructures = 12, alwaysLeavesARoute = true },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds, arenaAlwaysTraversable = true },
	description = "A construct that reshapes its own arena while it fights.",
})

-- ===========================================================================
-- WORLD DUNGEON BOSS - ELDER VEYL, GUARDIAN OF THE SAPHEART (ROOTFALL)
-- ===========================================================================
D["elder_veyl"] = dboss({
	id = "elder_veyl",
	displayName = "Elder Veyl",
	title = "Guardian of the Sapheart",
	kind = Enums.BossKind.WorldDungeonBoss,
	regionId = Enums.RegionId.VerdantReach,
	dungeonId = "dungeon_rootfall",
	element = Enums.Element.Forest,
	rank = "SS",
	tier = 5,
	baseHealth = 450000,
	baseDamage = 400,
	moveSpeed = 17,
	resistances = { [Enums.DamageType.Bio] = 0.5, [Enums.DamageType.Fire] = 1.4, [Enums.DamageType.Physical] = 0.95 },
	phases = {
		{
			index = 1,
			name = "Root Sentinel",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.3,
			attacks = {
				att({ id = "root_sweep", name = "Ancient Sweep", kind = "Melee", damage = 320, damageType = Enums.DamageType.Physical, range = 60, radius = 40, cooldown = 9, weight = 3, audio = "dboss_veyl_sweep", vfx = "fx_veyl_sweep" }),
				att({ id = "ground_impact", name = "Ground Impact", kind = "Zone", damage = 280, damageType = Enums.DamageType.Physical, range = 180, radius = 30, count = 3, cooldown = 11, weight = 2, audio = "dboss_veyl_impact", vfx = "fx_veyl_impact" }),
				att({ id = "summon_rootlings", name = "Call Rootlings", kind = "Summon", damage = 0, count = 6, cooldown = 22, weight = 1, interruptible = true, audio = "dboss_veyl_summon", vfx = "fx_veyl_summon" }),
			},
		},
		{
			index = 2,
			name = "Sapheart Exposed",
			healthThreshold = 0.66,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.9,
			crowdControlResistance = 0.4,
			mechanic = "The chamber changes and the Sapheart is exposed. Players must channel extraction while handling environmental mechanics.",
			onEnter = { exposeSapheart = true, sapChannels = 3, channelSeconds = 8 },
			attacks = {
				att({ id = "sap_burst", name = "Sap Burst", kind = "Zone", damage = 300, damageType = Enums.DamageType.Bio, range = 200, radius = 36, cooldown = 12, weight = 2, audio = "dboss_veyl_sap", vfx = "fx_veyl_sap" }),
				att({ id = "root_grasp", name = "Root Grasp", kind = "Zone", damage = 240, damageType = Enums.DamageType.Physical, range = 170, radius = 22, count = 4, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 2, cooldown = 13, weight = 2, audio = "dboss_veyl_grasp", vfx = "fx_veyl_grasp" }),
			},
			weakPoints = { { id = "wp_sapheart", name = "Sapheart Channel", attachment = "SapheartSocket", exposedPhases = { 2 }, multiplier = 2.2 } },
		},
		{
			index = 3,
			name = "Unstable Surge",
			healthThreshold = 0.33,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.7,
			crowdControlResistance = 0.5,
			armor = { value = 50000 },
			mechanic = "The guardian surges with unstable energy. Attack weak points and coordinate to break the armor.",
			attacks = {
				att({ id = "surge_nova", name = "Unstable Surge", kind = "Ultimate", telegraph = 2.8, damage = 640, damageType = Enums.DamageType.Energy, range = 260, radius = 110, cooldown = 28, weight = 1, audio = "dboss_veyl_surge", vfx = "fx_veyl_surge" }),
				att({ id = "root_storm", name = "Root Storm", kind = "Zone", damage = 320, damageType = Enums.DamageType.Physical, range = 220, radius = 28, count = 6, cooldown = 14, weight = 2, audio = "dboss_veyl_storm", vfx = "fx_veyl_storm" }),
			},
			weakPoints = {
				{ id = "wp_armor_a", name = "Mineral Shoulder", attachment = "ShoulderASocket", exposedPhases = { 3 }, multiplier = 2.4 },
				{ id = "wp_armor_b", name = "Mineral Spine", attachment = "SpineSocket", exposedPhases = { 3 }, multiplier = 2.4 },
			},
		},
		{
			index = 4,
			name = "Final Sequence",
			healthThreshold = 0.12,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.5,
			crowdControlResistance = 0.3,
			mechanic = "A demanding final sequence: the guardian channels a destabilising pulse and simultaneous weak points must be destroyed inside the window.",
			onEnter = { finalSequence = true, requiredSimultaneousWeakPoints = 2, windowSeconds = 20 },
			attacks = {
				att({ id = "final_pulse", name = "Destabilising Pulse", kind = "Ultimate", telegraph = 3.0, damage = 700, damageType = Enums.DamageType.Energy, range = 280, radius = 130, cooldown = 30, weight = 1, audio = "dboss_veyl_final", vfx = "fx_veyl_final" }),
				att({ id = "core_window", name = "Final Exposure", kind = "Buff", damage = 0, recovery = 8, cooldown = 18, weight = 1, interruptible = false, audio = "dboss_veyl_vulnerable", vfx = "fx_veyl_vulnerable" }),
			},
			weakPoints = {
				{ id = "wp_final_a", name = "Root Heart A", attachment = "HeartASocket", exposedPhases = { 4 }, multiplier = 3.0, vulnerabilityWindowSeconds = 8 },
				{ id = "wp_final_b", name = "Root Heart B", attachment = "HeartBSocket", exposedPhases = { 4 }, multiplier = 3.0, vulnerabilityWindowSeconds = 8 },
			},
		},
	},
	rewardTableId = "rewards_elder_veyl",
	respawnSeconds = Limits.Resource.SpecialRespawnSeconds,
	intro = { duration = 7, cinematic = "cin_veyl_intro", audio = "dboss_veyl_intro" },
	death = { duration = 10, sequence = "returns_to_the_roots", audio = "dboss_veyl_death" },
	audio = { intro = "dboss_veyl_intro", phase = "dboss_veyl_phase", death = "dboss_veyl_death", sapheart = "dboss_veyl_sapheart" },
	vfx = { body = "fx_veyl_body", armor = "fx_veyl_armor", sapheart = "fx_veyl_sapheart" },
	special = { type = "RootfallGuardian", sapChannels = 3, controlledSapYield = true },
	safeguards = {
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
		sapYieldRequiresParticipation = true,
		rewardDistributionOnce = true,
	},
	description = "A colossal guardian of ancient roots, mineral armor and unstable energy. The final encounter of ROOTFALL.",
})

return D
