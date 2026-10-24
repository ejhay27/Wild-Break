--!strict
--[[
	BossData.luau
	Seven regional world bosses, seven dungeon bosses and Elder Veyl.

	Every boss declares explicit phases, attacks, telegraphs, weak points,
	defense states, resistances, rewards, defeat handling and safeguards.
	Nothing about a boss is implied: if a behaviour is not declared here the
	encounter will not perform it.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

export type BossAttack = {
	id: string,
	name: string,
	kind: string, -- Melee | Projectile | Charge | Zone | Summon | Beam | Buff | Ultimate | Special
	telegraph: number,
	windup: number,
	active: number,
	recovery: number,
	cooldown: number,
	damage: number?,
	damageType: string?,
	range: number?,
	radius: number?,
	projectileSpeed: number?,
	count: number?,
	statusEffect: string?,
	statusDuration: number?,
	interruptible: boolean?,
	minPhase: number?,
	weight: number?,
	mechanic: string?,
	audio: string?,
	vfx: string?,
}

export type WeakPointDef = {
	id: string,
	name: string,
	attachment: string, -- logical socket name resolved by the model/placeholder
	exposedPhases: { number },
	multiplier: number,
	breaksArmor: boolean?,
	vulnerabilityWindowSeconds: number?,
}

export type BossPhaseDef = {
	index: number,
	name: string,
	-- Phase begins when health fraction drops to or below this value.
	healthThreshold: number,
	defenseState: string,
	incomingDamageMultiplier: number,
	crowdControlResistance: number,
	shield: { capacity: number, regenerates: boolean, regenPerSecond: number? }?,
	armor: { value: number }?,
	attacks: { BossAttack },
	weakPoints: { WeakPointDef }?,
	arenaChange: string?,
	onEnter: { [string]: any }?,
	mechanic: string?,
	timeoutSeconds: number?,
}

export type BossDef = {
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
	aggroRadius: number,
	leashRadius: number,
	resistances: { [string]: number },
	phases: { BossPhaseDef },
	weakPoints: { WeakPointDef },
	rewardTableId: string,
	respawnSeconds: number?,
	encounterTimeoutSeconds: number?,
	intro: { duration: number, cinematic: string?, audio: string? },
	death: { duration: number, sequence: string, audio: string? },
	audio: { [string]: string },
	vfx: { [string]: string },
	special: { [string]: any }?,
	safeguards: { [string]: any },
	description: string,
}

local function attack(def: BossAttack): BossAttack
	def.telegraph = def.telegraph or 0.8
	def.windup = def.windup or 0.5
	def.active = def.active or 0.4
	def.recovery = def.recovery or 1.0
	def.interruptible = def.interruptible ~= false
	def.weight = def.weight or 1
	return def
end

local function boss(def: BossDef): BossDef
	def.aggroRadius = def.aggroRadius or Limits.Boss.AggroRadiusStuds
	def.leashRadius = def.leashRadius or Limits.Boss.LeashRadiusStuds
	def.encounterTimeoutSeconds = def.encounterTimeoutSeconds or Limits.Boss.EncounterTimeoutSeconds
	def.safeguards = def.safeguards or {}
	return def
end

local B: { [string]: BossDef } = {}

-- ===========================================================================
-- WORLD BOSS 1 - THORNMAW, THE ANCIENT DEVOURER (Verdant Reach)
-- ===========================================================================
B["thornmaw"] = boss({
	id = "thornmaw",
	displayName = "Thornmaw",
	title = "The Ancient Devourer",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.VerdantReach,
	element = Enums.Element.Forest,
	rank = "S",
	tier = 3,
	baseHealth = 260000,
	baseDamage = 320,
	moveSpeed = 18,
	aggroRadius = 340,
	leashRadius = 560,
	resistances = { [Enums.DamageType.Bio] = 0.5, [Enums.DamageType.Fire] = 1.4, [Enums.DamageType.Physical] = 0.9 },
	phases = {
		{
			index = 1,
			name = "Predator",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.2,
			attacks = {
				attack({
					id = "charge", name = "Root Charge", kind = "Charge", telegraph = 1.1, windup = 0.6, active = 1.1,
					recovery = 1.6, cooldown = 14, damage = 340, damageType = Enums.DamageType.Physical, range = 180, radius = 16,
					statusEffect = Enums.StatusEffect.Staggered, statusDuration = 2, weight = 2, audio = "boss_thornmaw_charge", vfx = "fx_thornmaw_charge",
				}),
				attack({
					id = "sweep", name = "Bark Sweep", kind = "Melee", telegraph = 0.8, windup = 0.4, active = 0.5,
					recovery = 1.1, cooldown = 7, damage = 240, damageType = Enums.DamageType.Physical, range = 40, radius = 30,
					statusEffect = Enums.StatusEffect.Staggered, statusDuration = 1.5, weight = 3, audio = "boss_thornmaw_sweep", vfx = "fx_thornmaw_sweep",
				}),
				attack({
					id = "slam", name = "Ground Slam", kind = "Melee", telegraph = 1.0, windup = 0.7, active = 0.4,
					recovery = 1.4, cooldown = 10, damage = 380, damageType = Enums.DamageType.Physical, range = 60, radius = 34,
					statusEffect = Enums.StatusEffect.Staggered, statusDuration = 2, weight = 2, audio = "boss_thornmaw_slam", vfx = "fx_thornmaw_slam",
				}),
				attack({
					id = "root_strike", name = "Root Strike", kind = "Zone", telegraph = 1.3, windup = 0.8, active = 1.2,
					recovery = 1.5, cooldown = 12, damage = 180, damageType = Enums.DamageType.Physical, range = 140, radius = 22,
					count = 4, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 1.5, weight = 2, audio = "boss_thornmaw_roots", vfx = "fx_thornmaw_roots",
				}),
			},
			weakPoints = {
				{ id = "wp_leg", name = "Rooted Leg", attachment = "LegSocket", exposedPhases = { 1, 2, 3 }, multiplier = 1.6 },
			},
		},
		{
			index = 2,
			name = "Absorption",
			healthThreshold = 0.66,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.8,
			crowdControlResistance = 0.35,
			mechanic = "Thornmaw absorbs energy from surrounding growths. Destroy the growths to stop regeneration.",
			onEnter = { spawnGrowths = 4, growthHealth = 12000, regenPerSecondPerGrowth = 900, arenaChange = "growths_active" },
			attacks = {
				attack({
					id = "spore_breath", name = "Spore Breath", kind = "Projectile", telegraph = 1.0, windup = 0.6, active = 1.0,
					recovery = 1.3, cooldown = 11, damage = 210, damageType = Enums.DamageType.Bio, range = 160, radius = 18,
					projectileSpeed = 90, count = 3, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 6, weight = 2,
					audio = "boss_thornmaw_spore", vfx = "fx_thornmaw_spore",
				}),
				attack({
					id = "slam", name = "Ground Slam", kind = "Melee", telegraph = 1.0, windup = 0.7, active = 0.4,
					recovery = 1.4, cooldown = 9, damage = 400, damageType = Enums.DamageType.Physical, range = 60, radius = 34, weight = 2,
					audio = "boss_thornmaw_slam", vfx = "fx_thornmaw_slam",
				}),
				attack({
					id = "absorb", name = "Absorb Growth", kind = "Buff", telegraph = 1.6, windup = 1.2, active = 2.0,
					recovery = 1.0, cooldown = 18, damage = 0, weight = 1, interruptible = true, mechanic = "Heals per living growth.",
					audio = "boss_thornmaw_absorb", vfx = "fx_thornmaw_absorb",
				}),
			},
			weakPoints = {
				{ id = "wp_leg", name = "Rooted Leg", attachment = "LegSocket", exposedPhases = { 1, 2, 3 }, multiplier = 1.6 },
				{ id = "wp_growth", name = "Nutrient Growth", attachment = "GrowthSocket", exposedPhases = { 2 }, multiplier = 2.2, breaksArmor = true },
			},
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Root Armor",
			healthThreshold = 0.33,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.55,
			crowdControlResistance = 0.5,
			armor = { value = 40000 },
			arenaChange = "roots_close_in",
			mechanic = "Root armor must be broken during telegraphed vulnerability windows to reach the exposed core.",
			attacks = {
				attack({
					id = "root_storm", name = "Root Storm", kind = "Zone", telegraph = 1.5, windup = 1.0, active = 2.4,
					recovery = 1.8, cooldown = 16, damage = 260, damageType = Enums.DamageType.Physical, range = 200, radius = 26,
					count = 8, weight = 2, audio = "boss_thornmaw_storm", vfx = "fx_thornmaw_storm",
				}),
				attack({
					id = "devour", name = "Devour", kind = "Melee", telegraph = 1.2, windup = 0.9, active = 0.6,
					recovery = 2.0, cooldown = 15, damage = 620, damageType = Enums.DamageType.Physical, range = 46, radius = 30, weight = 1,
					audio = "boss_thornmaw_devour", vfx = "fx_thornmaw_devour",
				}),
				attack({
					id = "vulnerable", name = "Exhausted Roar", kind = "Buff", telegraph = 1.0, windup = 0.6, active = 1.0,
					recovery = 6.0, cooldown = 26, damage = 0, weight = 1, interruptible = false,
					mechanic = "Opens a 6 second vulnerability window with exposed weak points.",
					audio = "boss_thornmaw_roar", vfx = "fx_thornmaw_vulnerable",
				}),
			},
			weakPoints = {
				{ id = "wp_core", name = "Exposed Core", attachment = "CoreSocket", exposedPhases = { 3 }, multiplier = 2.6, vulnerabilityWindowSeconds = 6 },
				{ id = "wp_leg", name = "Rooted Leg", attachment = "LegSocket", exposedPhases = { 1, 2, 3 }, multiplier = 1.4 },
			},
			timeoutSeconds = 20,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_thornmaw",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 5, cinematic = "cin_thornmaw_intro", audio = "boss_thornmaw_intro" },
	death = { duration = 8, sequence = "collapse_into_roots", audio = "boss_thornmaw_death" },
	audio = { intro = "boss_thornmaw_intro", phase = "boss_thornmaw_phase", death = "boss_thornmaw_death", hit = "boss_thornmaw_hit", vulnerable = "boss_thornmaw_vulnerable" },
	vfx = { body = "fx_thornmaw_body", armor = "fx_thornmaw_armor", vulnerable = "fx_thornmaw_vulnerable" },
	safeguards = {
		maxRegenFractionOfMaxHealth = 0.25,
		regenStopsWhenGrowthsDestroyed = true,
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
	},
	description = "A colossal forest predator covered in roots, bark-like armor, biological growths and mineralised structures.",
})

-- ===========================================================================
-- WORLD BOSS 2 - PYR AXIS, THE ECLIPSE WYRM (Cinderfall)
-- ===========================================================================
B["pyraxis"] = boss({
	id = "pyraxis",
	displayName = "Pyr axis",
	title = "The Eclipse Wyrm",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.Cinderfall,
	element = Enums.Element.Fire,
	rank = "SS",
	tier = 4,
	baseHealth = 340000,
	baseDamage = 380,
	moveSpeed = 34,
	aggroRadius = 420,
	leashRadius = 700,
	resistances = { [Enums.DamageType.Fire] = 0.35, [Enums.DamageType.Ice] = 1.8, [Enums.DamageType.Water] = 1.6 },
	phases = {
		{
			index = 1,
			name = "Wyrm Form",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			attacks = {
				attack({
					id = "fire_bolt", name = "Fire Bolt", kind = "Projectile", telegraph = 0.9, windup = 0.5, active = 0.8,
					recovery = 1.0, cooldown = 6, damage = 220, damageType = Enums.DamageType.Fire, range = 260, radius = 10,
					projectileSpeed = 160, count = 3, statusEffect = Enums.StatusEffect.Burn, statusDuration = 4, weight = 3,
					audio = "boss_pyraxis_bolt", vfx = "fx_pyraxis_bolt",
				}),
				attack({
					id = "aerial_charge", name = "Aerial Charge", kind = "Charge", telegraph = 1.3, windup = 0.7, active = 1.2,
					recovery = 1.6, cooldown = 13, damage = 420, damageType = Enums.DamageType.Fire, range = 300, radius = 20, weight = 2,
					audio = "boss_pyraxis_charge", vfx = "fx_pyraxis_charge",
				}),
				attack({
					id = "ground_eruption", name = "Ground Eruption", kind = "Zone", telegraph = 1.4, windup = 0.9, active = 1.6,
					recovery = 1.4, cooldown = 12, damage = 300, damageType = Enums.DamageType.Fire, range = 200, radius = 24,
					count = 5, statusEffect = Enums.StatusEffect.Burn, statusDuration = 5, weight = 2,
					audio = "boss_pyraxis_eruption", vfx = "fx_pyraxis_eruption",
				}),
				attack({
					id = "wing_sweep", name = "Wing Sweep", kind = "Melee", telegraph = 1.0, windup = 0.5, active = 0.6,
					recovery = 1.2, cooldown = 9, damage = 330, damageType = Enums.DamageType.Physical, range = 70, radius = 44, weight = 2,
					audio = "boss_pyraxis_sweep", vfx = "fx_pyraxis_sweep",
				}),
			},
			weakPoints = {
				{ id = "wp_wing", name = "Wing Membrane", attachment = "WingSocket", exposedPhases = { 1, 2 }, multiplier = 1.8 },
			},
		},
		{
			index = 2,
			name = "Heat Shield",
			healthThreshold = Limits.BossSpecial.PyraxisStage2Threshold,
			defenseState = Enums.DefenseState.Shielded,
			incomingDamageMultiplier = 0.85,
			crowdControlResistance = 0.4,
			shield = { capacity = Limits.BossSpecial.PyraxisHeatShieldCapacity, regenerates = false },
			mechanic = "A heat shield surrounds the wyrm. Touching it applies burn damage over time.",
			onEnter = { enableHeatShield = true, burnDamagePerSecond = Limits.BossSpecial.PyraxisBurnDamagePerSecond, burnDuration = Limits.BossSpecial.PyraxisBurnDurationSeconds },
			attacks = {
				attack({
					id = "fire_storm", name = "Firestorm", kind = "Zone", telegraph = 1.6, windup = 1.0, active = 3.0,
					recovery = 1.8, cooldown = 18, damage = 340, damageType = Enums.DamageType.Fire, range = 240, radius = 40,
					count = 6, statusEffect = Enums.StatusEffect.Burn, statusDuration = 6, weight = 2,
					audio = "boss_pyraxis_firestorm", vfx = "fx_pyraxis_firestorm",
				}),
				attack({
					id = "magma_dive", name = "Magma Dive", kind = "Charge", telegraph = 1.4, windup = 0.8, active = 1.4,
					recovery = 1.8, cooldown = 15, damage = 520, damageType = Enums.DamageType.Fire, range = 320, radius = 30, weight = 2,
					audio = "boss_pyraxis_dive", vfx = "fx_pyraxis_dive",
				}),
				attack({
					id = "shield_vent", name = "Shield Vent", kind = "Buff", telegraph = 1.2, windup = 0.7, active = 1.0,
					recovery = 5.0, cooldown = 24, damage = 0, weight = 1, interruptible = false,
					mechanic = "Vents the shield, creating a 5 second vulnerability window.",
					audio = "boss_pyraxis_vent", vfx = "fx_pyraxis_vent",
				}),
			},
			weakPoints = {
				{ id = "wp_wing", name = "Wing Membrane", attachment = "WingSocket", exposedPhases = { 1, 2 }, multiplier = 1.8 },
				{ id = "wp_vent", name = "Ventral Vent", attachment = "VentSocket", exposedPhases = { 2 }, multiplier = 2.4, vulnerabilityWindowSeconds = 5 },
			},
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Cocoon",
			healthThreshold = Limits.BossSpecial.PyraxisStage3Threshold,
			defenseState = Enums.DefenseState.Cocooned,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 1.0,
			shield = { capacity = Limits.BossSpecial.PyraxisBaselineShieldCapacity * Limits.BossSpecial.PyraxisCocoonShieldMultiplier, regenerates = false },
			mechanic = "Break the cocoon shield before the transformation countdown expires to prevent the final form.",
			onEnter = {
				enableCocoon = true,
				cocoonShieldCapacity = Limits.BossSpecial.PyraxisBaselineShieldCapacity * Limits.BossSpecial.PyraxisCocoonShieldMultiplier,
				transformationCountdownSeconds = Limits.BossSpecial.PyraxisCocoonTransformationSeconds,
			},
			attacks = {
				attack({
					id = "cocoon_pulse", name = "Cocoon Pulse", kind = "Zone", telegraph = 1.2, windup = 0.6, active = 1.0,
					recovery = 1.2, cooldown = 8, damage = 180, damageType = Enums.DamageType.Fire, range = 120, radius = 50, weight = 1,
					audio = "boss_pyraxis_pulse", vfx = "fx_pyraxis_pulse",
				}),
			},
			weakPoints = {
				{ id = "wp_cocoon", name = "Cocoon Seam", attachment = "CocoonSocket", exposedPhases = { 3 }, multiplier = 1.0 },
			},
			timeoutSeconds = Limits.BossSpecial.PyraxisCocoonTransformationSeconds + 5,
		},
		{
			index = 4,
			name = "Eclipse Final Form",
			healthThreshold = -1,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.75,
			crowdControlResistance = 0.6,
			arenaChange = "ashfall_darkened_sky",
			mechanic = "Two gigantic wings darken Cinderfall. Wing and core weak points open after specific attacks.",
			attacks = {
				attack({
					id = "wide_sweep", name = "Eclipse Sweep", kind = "Melee", telegraph = 1.2, windup = 0.6, active = 0.8,
					recovery = 1.4, cooldown = 10, damage = 520, damageType = Enums.DamageType.Physical, range = 120, radius = 80, weight = 3,
					audio = "boss_pyraxis_wide_sweep", vfx = "fx_pyraxis_wide_sweep",
				}),
				attack({
					id = "aerial_dive", name = "Eclipse Dive", kind = "Charge", telegraph = 1.4, windup = 0.8, active = 1.3,
					recovery = 1.6, cooldown = 12, damage = 640, damageType = Enums.DamageType.Fire, range = 360, radius = 40, weight = 2,
					audio = "boss_pyraxis_dive", vfx = "fx_pyraxis_dive",
				}),
				attack({
					id = "firestorm_final", name = "Eclipse Firestorm", kind = "Zone", telegraph = 1.8, windup = 1.2, active = 4.0,
					recovery = 2.0, cooldown = 20, damage = 420, damageType = Enums.DamageType.Fire, range = 300, radius = 54,
					count = 8, statusEffect = Enums.StatusEffect.Burn, statusDuration = 6, weight = 1,
					audio = "boss_pyraxis_firestorm", vfx = "fx_pyraxis_firestorm",
				}),
				attack({
					id = "infernal_ultimate", name = "Infernal Eclipse", kind = "Ultimate", telegraph = 3.0, windup = 2.0, active = 2.5,
					recovery = 3.0, cooldown = 45, damage = 900, damageType = Enums.DamageType.Fire, range = 400, radius = 120, weight = 1,
					mechanic = "Long telegraph, clear audio warning, arena-wide fire. Survivability through movement, cover or shields.",
					audio = "boss_pyraxis_ultimate", vfx = "fx_pyraxis_ultimate",
				}),
				attack({
					id = "wing_opening", name = "Wing Opening", kind = "Buff", telegraph = 1.0, windup = 0.6, active = 1.0,
					recovery = 6.0, cooldown = 28, damage = 0, weight = 1, interruptible = false,
					mechanic = "Opens wing weak points for 6 seconds.",
					audio = "boss_pyraxis_vent", vfx = "fx_pyraxis_vulnerable",
				}),
			},
			weakPoints = {
				{ id = "wp_wing", name = "Eclipse Wing", attachment = "WingSocket", exposedPhases = { 4 }, multiplier = 2.0, vulnerabilityWindowSeconds = 6 },
				{ id = "wp_core", name = "Eclipse Core", attachment = "CoreSocket", exposedPhases = { 4 }, multiplier = 2.2, vulnerabilityWindowSeconds = 6 },
			},
			timeoutSeconds = 20,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_pyraxis",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 6, cinematic = "cin_pyraxis_intro", audio = "boss_pyraxis_intro" },
	death = { duration = 9, sequence = "falls_from_sky", audio = "boss_pyraxis_death" },
	audio = { intro = "boss_pyraxis_intro", phase = "boss_pyraxis_phase", death = "boss_pyraxis_death", cocoon = "boss_pyraxis_cocoon", transform = "boss_pyraxis_transform", ultimate = "boss_pyraxis_ultimate" },
	vfx = { body = "fx_pyraxis_body", shield = "fx_pyraxis_heat_shield", cocoon = "fx_pyraxis_cocoon", wings = "fx_pyraxis_wings" },
	special = {
		type = "PyraxisCocoon",
		baselineShieldCapacity = Limits.BossSpecial.PyraxisBaselineShieldCapacity,
		cocoonShieldMultiplier = Limits.BossSpecial.PyraxisCocoonShieldMultiplier,
		cocoonShieldCapacity = Limits.BossSpecial.PyraxisBaselineShieldCapacity * Limits.BossSpecial.PyraxisCocoonShieldMultiplier,
		transformationCountdownSeconds = Limits.BossSpecial.PyraxisCocoonTransformationSeconds,
		heatShieldCapacity = Limits.BossSpecial.PyraxisHeatShieldCapacity,
		burnDamagePerSecond = Limits.BossSpecial.PyraxisBurnDamagePerSecond,
		burnDurationSeconds = Limits.BossSpecial.PyraxisBurnDurationSeconds,
		finalFormDamageScale = Limits.BossSpecial.PyraxisFinalFormDamageScale,
		finalFormPhaseIndex = 4,
		cocoonPhaseIndex = 3,
	},
	safeguards = {
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
		cocoonTimeoutSeconds = Limits.BossSpecial.PyraxisCocoonTransformationSeconds + 10,
		neverLoopForms = true,
		maxTransformations = 1,
	},
	description = "A unique flying fire boss. Three stages, a heat shield, a cocoon transformation and an evolved final form.",
})

-- ===========================================================================
-- WORLD BOSS 3 - GLACIERON, THE WHITEOUT KING (Frostveil)
-- ===========================================================================
B["glacieron"] = boss({
	id = "glacieron",
	displayName = "Glacieron",
	title = "The Whiteout King",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.Frostveil,
	element = Enums.Element.Ice,
	rank = "S",
	tier = 4,
	baseHealth = 300000,
	baseDamage = 360,
	moveSpeed = 20,
	aggroRadius = 360,
	leashRadius = 600,
	resistances = { [Enums.DamageType.Ice] = 0.4, [Enums.DamageType.Fire] = 1.5, [Enums.DamageType.Physical] = 0.95 },
	phases = {
		{
			index = 1,
			name = "Charging Beast",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.2,
			attacks = {
				attack({
					id = "charge", name = "Glacial Charge", kind = "Charge", telegraph = 1.2, windup = 0.7, active = 1.3,
					recovery = 1.6, cooldown = 13, damage = 400, damageType = Enums.DamageType.Physical, range = 220, radius = 22, weight = 2,
					audio = "boss_glacieron_charge", vfx = "fx_glacieron_charge",
				}),
				attack({
					id = "ice_shard", name = "Ice Shard Volley", kind = "Projectile", telegraph = 0.9, windup = 0.5, active = 0.9,
					recovery = 1.1, cooldown = 7, damage = 200, damageType = Enums.DamageType.Ice, range = 240, radius = 8,
					projectileSpeed = 200, count = 5, statusEffect = Enums.StatusEffect.Chill, statusDuration = 3, weight = 3,
					audio = "boss_glacieron_shard", vfx = "fx_glacieron_shard",
				}),
				attack({
					id = "sweep", name = "Frozen Sweep", kind = "Melee", telegraph = 0.9, windup = 0.4, active = 0.5,
					recovery = 1.2, cooldown = 8, damage = 280, damageType = Enums.DamageType.Ice, range = 50, radius = 40, weight = 2,
					audio = "boss_glacieron_sweep", vfx = "fx_glacieron_sweep",
				}),
			},
			weakPoints = { { id = "wp_shoulder", name = "Crystal Shoulder", attachment = "ShoulderSocket", exposedPhases = { 1, 2 }, multiplier = 1.7 } },
		},
		{
			index = 2,
			name = "Crystalline Armor",
			healthThreshold = 0.7,
			defenseState = Enums.DefenseState.Armored,
			incomingDamageMultiplier = 0.6,
			crowdControlResistance = 0.4,
			armor = { value = 45000 },
			mechanic = "Crystalline armor must be broken section by section to create openings.",
			attacks = {
				attack({
					id = "armor_slam", name = "Armored Slam", kind = "Melee", telegraph = 1.1, windup = 0.8, active = 0.5,
					recovery = 1.5, cooldown = 10, damage = 460, damageType = Enums.DamageType.Physical, range = 60, radius = 36, weight = 2,
					audio = "boss_glacieron_slam", vfx = "fx_glacieron_slam",
				}),
				attack({
					id = "frost_nova", name = "Frost Nova", kind = "Zone", telegraph = 1.5, windup = 1.0, active = 1.4,
					recovery = 1.6, cooldown = 14, damage = 320, damageType = Enums.DamageType.Ice, range = 180, radius = 60,
					statusEffect = Enums.StatusEffect.Chill, statusDuration = 4, weight = 2,
					audio = "boss_glacieron_nova", vfx = "fx_glacieron_nova",
				}),
			},
			weakPoints = {
				{ id = "wp_armor_back", name = "Back Plates", attachment = "BackPlateSocket", exposedPhases = { 2 }, multiplier = 2.2, breaksArmor = true },
				{ id = "wp_armor_leg", name = "Leg Plates", attachment = "LegPlateSocket", exposedPhases = { 2 }, multiplier = 2.0, breaksArmor = true },
			},
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Whiteout",
			healthThreshold = 0.45,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.85,
			crowdControlResistance = 0.5,
			arenaChange = "blizzard",
			mechanic = "A blizzard reduces visibility. Audio cues, silhouettes and high-contrast telegraphs keep the fight readable.",
			onEnter = { blizzard = true, visibilityReduction = 0.55, telegraphContrastBoost = true },
			attacks = {
				attack({
					id = "blizzard_ambush", name = "Whiteout Ambush", kind = "Charge", telegraph = 1.4, windup = 0.9, active = 1.2,
					recovery = 1.7, cooldown = 12, damage = 500, damageType = Enums.DamageType.Ice, range = 260, radius = 26, weight = 2,
					audio = "boss_glacieron_ambush", vfx = "fx_glacieron_ambush",
				}),
				attack({
					id = "ice_prison", name = "Ice Prison", kind = "Zone", telegraph = 1.3, windup = 0.8, active = 1.2,
					recovery = 1.5, cooldown = 15, damage = 240, damageType = Enums.DamageType.Ice, range = 200, radius = 30,
					count = 3, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 2.5, weight = 2,
					audio = "boss_glacieron_prison", vfx = "fx_glacieron_prison",
				}),
			},
			weakPoints = { { id = "wp_shoulder", name = "Crystal Shoulder", attachment = "ShoulderSocket", exposedPhases = { 1, 2, 3 }, multiplier = 1.5 } },
			timeoutSeconds = 20,
		},
		{
			index = 4,
			name = "Core Exposure",
			healthThreshold = 0.18,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.35,
			crowdControlResistance = 0.3,
			mechanic = "After a massive ice attack the boss exposes its core. This is the kill window.",
			attacks = {
				attack({
					id = "absolute_zero", name = "Absolute Zero", kind = "Ultimate", telegraph = 3.2, windup = 2.0, active = 2.0,
					recovery = 7.0, cooldown = 40, damage = 820, damageType = Enums.DamageType.Ice, range = 320, radius = 140, weight = 1,
					audio = "boss_glacieron_ultimate", vfx = "fx_glacieron_ultimate",
				}),
				attack({
					id = "core_window", name = "Core Exposure", kind = "Buff", telegraph = 0.8, windup = 0.5, active = 1.0,
					recovery = 7.0, cooldown = 30, damage = 0, weight = 1, interruptible = false,
					mechanic = "Opens the core for 7 seconds.",
					audio = "boss_glacieron_vulnerable", vfx = "fx_glacieron_vulnerable",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Frozen Core", attachment = "CoreSocket", exposedPhases = { 4 }, multiplier = 3.0, vulnerabilityWindowSeconds = 7 } },
			timeoutSeconds = 20,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_glacieron",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 5, cinematic = "cin_glacieron_intro", audio = "boss_glacieron_intro" },
	death = { duration = 8, sequence = "shatters_into_snow", audio = "boss_glacieron_death" },
	audio = { intro = "boss_glacieron_intro", phase = "boss_glacieron_phase", death = "boss_glacieron_death", ultimate = "boss_glacieron_ultimate", vulnerable = "boss_glacieron_vulnerable" },
	vfx = { body = "fx_glacieron_body", armor = "fx_glacieron_armor", blizzard = "fx_glacieron_blizzard" },
	safeguards = { phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds, telegraphsVisibleInBlizzard = true },
	description = "A colossal ice-adapted creature that weaponises the blizzard around it.",
})

-- ===========================================================================
-- WORLD BOSS 4 - NOCTYRA, THE BLACK VEIL (Umbra Expanse)
-- ===========================================================================
B["noctyra"] = boss({
	id = "noctyra",
	displayName = "Noctyra",
	title = "The Black Veil",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.UmbraExpanse,
	element = Enums.Element.Dark,
	rank = "SS",
	tier = 4,
	baseHealth = 280000,
	baseDamage = 340,
	moveSpeed = 30,
	aggroRadius = 380,
	leashRadius = 620,
	resistances = { [Enums.DamageType.Dark] = 0.45, [Enums.DamageType.Light] = 1.7, [Enums.DamageType.Energy] = 1.1 },
	phases = {
		{
			index = 1,
			name = "Shadow Strikes",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			attacks = {
				attack({
					id = "shadow_dash", name = "Shadow Dash", kind = "Charge", telegraph = 0.8, windup = 0.4, active = 0.7,
					recovery = 1.0, cooldown = 7, damage = 300, damageType = Enums.DamageType.Dark, range = 180, radius = 18, weight = 3,
					audio = "boss_noctyra_dash", vfx = "fx_noctyra_dash",
				}),
				attack({
					id = "veil_slash", name = "Veil Slash", kind = "Melee", telegraph = 0.7, windup = 0.35, active = 0.4,
					recovery = 0.9, cooldown = 5, damage = 240, damageType = Enums.DamageType.Dark, range = 40, radius = 30, weight = 3,
					audio = "boss_noctyra_slash", vfx = "fx_noctyra_slash",
				}),
			},
			weakPoints = { { id = "wp_mask", name = "Veil Mask", attachment = "MaskSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 1.6 } },
		},
		{
			index = 2,
			name = "False Bodies",
			healthThreshold = 0.7,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.9,
			crowdControlResistance = 0.4,
			mechanic = "Noctyra creates decoys. The real body is identifiable through consistent behaviour tells: it is the only copy that telegraphs before attacking, and Hunter's Mark always reveals the true body.",
			onEnter = { spawnDecoys = 3, decoyHealth = 8000, realBodyTell = "telegraphs_before_attacking" },
			attacks = {
				attack({
					id = "decoy_call", name = "Call of the Veil", kind = "Summon", telegraph = 1.2, windup = 0.8, active = 1.0,
					recovery = 1.2, cooldown = 22, damage = 0, count = 3, weight = 1, interruptible = true,
					audio = "boss_noctyra_decoy", vfx = "fx_noctyra_decoy",
				}),
				attack({
					id = "shadow_dash", name = "Shadow Dash", kind = "Charge", telegraph = 0.8, windup = 0.4, active = 0.7,
					recovery = 1.0, cooldown = 8, damage = 320, damageType = Enums.DamageType.Dark, range = 180, radius = 18, weight = 2,
					audio = "boss_noctyra_dash", vfx = "fx_noctyra_dash",
				}),
			},
			weakPoints = { { id = "wp_mask", name = "Veil Mask", attachment = "MaskSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 1.6 } },
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Darkened Arena",
			healthThreshold = 0.42,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.8,
			crowdControlResistance = 0.45,
			arenaChange = "darkness_zones",
			onEnter = { darkenArena = true, darknessIntensity = 0.7, telegraphVisibility = "always" },
			mechanic = "Portions of the arena darken. Attack telegraphs and enemy silhouettes stay visible: darkness never hides critical information.",
			attacks = {
				attack({
					id = "ambush", name = "Concealed Ambush", kind = "Melee", telegraph = 1.1, windup = 0.5, active = 0.5,
					recovery = 1.3, cooldown = 10, damage = 420, damageType = Enums.DamageType.Dark, range = 60, radius = 26, weight = 2,
					audio = "boss_noctyra_ambush", vfx = "fx_noctyra_ambush",
				}),
				attack({
					id = "shadow_bolt", name = "Shadow Bolt", kind = "Projectile", telegraph = 0.9, windup = 0.5, active = 0.8,
					recovery = 1.0, cooldown = 6, damage = 260, damageType = Enums.DamageType.Dark, range = 240, radius = 9,
					projectileSpeed = 180, count = 4, weight = 2,
					audio = "boss_noctyra_bolt", vfx = "fx_noctyra_bolt",
				}),
			},
			weakPoints = { { id = "wp_mask", name = "Veil Mask", attachment = "MaskSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 1.6 } },
			timeoutSeconds = 20,
		},
		{
			index = 4,
			name = "Exposed Core",
			healthThreshold = 0.15,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.5,
			mechanic = "The core is exposed but Noctyra moves aggressively to protect it. Punish the recovery windows.",
			attacks = {
				attack({
					id = "core_guard", name = "Protective Frenzy", kind = "Melee", telegraph = 0.6, windup = 0.3, active = 0.4,
					recovery = 1.6, cooldown = 6, damage = 380, damageType = Enums.DamageType.Dark, range = 44, radius = 32, weight = 3,
					audio = "boss_noctyra_frenzy", vfx = "fx_noctyra_frenzy",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Veiled Core", attachment = "CoreSocket", exposedPhases = { 4 }, multiplier = 2.8 } },
			timeoutSeconds = 20,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_noctyra",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 5, cinematic = "cin_noctyra_intro", audio = "boss_noctyra_intro" },
	death = { duration = 7, sequence = "dissolves_into_shadow", audio = "boss_noctyra_death" },
	audio = { intro = "boss_noctyra_intro", phase = "boss_noctyra_phase", death = "boss_noctyra_death", decoy = "boss_noctyra_decoy", vulnerable = "boss_noctyra_vulnerable" },
	vfx = { body = "fx_noctyra_body", decoy = "fx_noctyra_decoy", darkness = "fx_noctyra_darkness" },
	safeguards = {
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
		decoysNeverDamageWithoutTelegraph = true,
		trueBodyAlwaysMarkable = true,
		telegraphsVisibleInDarkness = true,
	},
	description = "A shadow-based boss of concealment, false bodies and corrupted energy.",
})

-- ===========================================================================
-- WORLD BOSS 5 - THE LIGHT SAMURAI (Solara Basin)
-- ===========================================================================
B["light_samurai"] = boss({
	id = "light_samurai",
	displayName = "Aurion",
	title = "The Sunheart Colossus",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.SolaraBasin,
	element = Enums.Element.Light,
	rank = "X",
	tier = 5,
	baseHealth = 420000,
	baseDamage = 420,
	moveSpeed = 26,
	aggroRadius = 400,
	leashRadius = 640,
	resistances = { [Enums.DamageType.Light] = 0.5, [Enums.DamageType.Dark] = 1.5, [Enums.DamageType.Physical] = 1.0 },
	phases = {
		{
			index = 1,
			name = "Samurai Form",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.3,
			attacks = {
				attack({
					id = "sword_combo", name = "Radiant Combo", kind = "Melee", telegraph = 0.8, windup = 0.4, active = 0.9,
					recovery = 1.4, cooldown = 8, damage = 260, damageType = Enums.DamageType.Light, range = 36, radius = 24, weight = 3,
					audio = "boss_samurai_combo", vfx = "fx_samurai_combo",
				}),
				attack({
					id = "quick_dash", name = "Sunstep", kind = "Charge", telegraph = 0.6, windup = 0.3, active = 0.5,
					recovery = 0.9, cooldown = 6, damage = 240, damageType = Enums.DamageType.Light, range = 140, radius = 14, weight = 2,
					audio = "boss_samurai_dash", vfx = "fx_samurai_dash",
				}),
				attack({
					id = "parry_stance", name = "Parry Stance", kind = "Buff", telegraph = 0.5, windup = 0.4, active = 1.5,
					recovery = 1.8, cooldown = 16, damage = 0, weight = 1, interruptible = false,
					mechanic = "Attacks during the stance are parried and punished; the recovery window is the opening.",
					audio = "boss_samurai_parry", vfx = "fx_samurai_parry",
				}),
				attack({
					id = "heavy_strike", name = "Judgement Strike", kind = "Melee", telegraph = 1.4, windup = 1.0, active = 0.6,
					recovery = 2.0, cooldown = 14, damage = 520, damageType = Enums.DamageType.Light, range = 50, radius = 34, weight = 1,
					audio = "boss_samurai_heavy", vfx = "fx_samurai_heavy",
				}),
				attack({
					id = "blade_wave", name = "Ranged Blade Wave", kind = "Projectile", telegraph = 1.0, windup = 0.5, active = 0.8,
					recovery = 1.1, cooldown = 10, damage = 220, damageType = Enums.DamageType.Light, range = 200, radius = 12,
					projectileSpeed = 190, count = 2, weight = 2,
					audio = "boss_samurai_wave", vfx = "fx_samurai_wave",
				}),
			},
			weakPoints = { { id = "wp_katana", name = "Katana Edge", attachment = "KatanaSocket", exposedPhases = { 1 }, multiplier = 1.8, vulnerabilityWindowSeconds = 1.8 } },
		},
		{
			index = 2,
			name = "Six-Winged Angel",
			healthThreshold = Limits.BossSpecial.LightSamuraiStage2Threshold,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.9,
			crowdControlResistance = 0.4,
			onEnter = { transform = "six_winged", wingCount = 6, cinematic = "cin_samurai_transform_1" },
			attacks = {
				attack({
					id = "blade_projectiles", name = "Radiant Volley", kind = "Projectile", telegraph = 1.0, windup = 0.5, active = 1.0,
					recovery = 1.2, cooldown = 9, damage = 240, damageType = Enums.DamageType.Light, range = 260, radius = 10,
					projectileSpeed = 210, count = 5, weight = 3,
					audio = "boss_samurai_volley", vfx = "fx_samurai_volley",
				}),
				attack({
					id = "wide_light", name = "Dawn Sweep", kind = "Melee", telegraph = 1.1, windup = 0.6, active = 0.7,
					recovery = 1.3, cooldown = 10, damage = 380, damageType = Enums.DamageType.Light, range = 80, radius = 50, weight = 2,
					audio = "boss_samurai_sweep", vfx = "fx_samurai_sweep",
				}),
				attack({
					id = "aerial_dive", name = "Wing Dive", kind = "Charge", telegraph = 1.3, windup = 0.7, active = 1.0,
					recovery = 1.5, cooldown = 13, damage = 480, damageType = Enums.DamageType.Light, range = 260, radius = 28, weight = 2,
					audio = "boss_samurai_dive", vfx = "fx_samurai_dive",
				}),
			},
			weakPoints = { { id = "wp_wing", name = "Radiant Wing", attachment = "WingSocket", exposedPhases = { 2, 3 }, multiplier = 2.0 } },
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Eight-Winged Transcendence",
			healthThreshold = Limits.BossSpecial.LightSamuraiStage3Threshold,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.85,
			crowdControlResistance = 0.5,
			onEnter = { transform = "eight_winged", wingCount = 8, cinematic = "cin_samurai_transform_2", speedIncrease = 0.25 },
			attacks = {
				attack({
					id = "fast_combo", name = "Transcendent Combo", kind = "Melee", telegraph = 0.7, windup = 0.3, active = 1.2,
					recovery = 1.2, cooldown = 8, damage = 300, damageType = Enums.DamageType.Light, range = 44, radius = 30, weight = 3,
					audio = "boss_samurai_combo_fast", vfx = "fx_samurai_combo",
				}),
				attack({
					id = "multi_light", name = "Radiant Cross", kind = "Zone", telegraph = 1.3, windup = 0.8, active = 1.6,
					recovery = 1.6, cooldown = 14, damage = 340, damageType = Enums.DamageType.Light, range = 240, radius = 26,
					count = 4, weight = 2,
					audio = "boss_samurai_cross", vfx = "fx_samurai_cross",
				}),
				attack({
					id = "wing_storm", name = "Wing Storm", kind = "Zone", telegraph = 1.5, windup = 1.0, active = 2.2,
					recovery = 1.8, cooldown = 18, damage = 380, damageType = Enums.DamageType.Light, range = 260, radius = 70, weight = 1,
					audio = "boss_samurai_wing_storm", vfx = "fx_samurai_wing_storm",
				}),
			},
			weakPoints = { { id = "wp_wing", name = "Transcendent Wing", attachment = "WingSocket", exposedPhases = { 2, 3 }, multiplier = 2.0 } },
			timeoutSeconds = 20,
		},
		{
			index = 4,
			name = "Final Detonation",
			healthThreshold = Limits.BossSpecial.LightSamuraiStage4Threshold,
			defenseState = Enums.DefenseState.Invulnerable,
			incomingDamageMultiplier = 0,
			crowdControlResistance = 1.0,
			onEnter = { beginDetonation = true, countdownSeconds = Limits.BossSpecial.LightSamuraiDetonationSeconds },
			mechanic = "The boss charges a massive celestial explosion. Survive it and the boss is defeated automatically; no additional damage is required.",
			attacks = {
				attack({
					id = "detonation", name = "Celestial Detonation", kind = "Ultimate", telegraph = Limits.BossSpecial.LightSamuraiDetonationSeconds,
					windup = Limits.BossSpecial.LightSamuraiDetonationSeconds - 2, active = 2.0, recovery = 3.0, cooldown = 0,
					damage = Limits.BossSpecial.LightSamuraiDetonationDamage, damageType = Enums.DamageType.Light,
					range = Limits.BossSpecial.LightSamuraiDetonationRadiusStuds, radius = Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
					weight = 1, interruptible = false,
					audio = "boss_samurai_detonation", vfx = "fx_samurai_detonation",
				}),
			},
			timeoutSeconds = Limits.BossSpecial.LightSamuraiDetonationSeconds + 15,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_light_samurai",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 6, cinematic = "cin_samurai_intro", audio = "boss_samurai_intro" },
	death = { duration = 12, sequence = "celestial_aftermath", audio = "boss_samurai_death" },
	audio = {
		intro = "boss_samurai_intro", phase = "boss_samurai_phase", death = "boss_samurai_death",
		detonation = "boss_samurai_detonation", transform = "boss_samurai_transform",
	},
	vfx = { body = "fx_samurai_body", wings = "fx_samurai_wings", detonation = "fx_samurai_detonation" },
	special = {
		type = "LightSamuraiFinalDetonation",
		stage2Threshold = Limits.BossSpecial.LightSamuraiStage2Threshold,
		stage3Threshold = Limits.BossSpecial.LightSamuraiStage3Threshold,
		stage4Threshold = Limits.BossSpecial.LightSamuraiStage4Threshold,
		detonationSeconds = Limits.BossSpecial.LightSamuraiDetonationSeconds,
		detonationRadiusStuds = Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
		detonationDamage = Limits.BossSpecial.LightSamuraiDetonationDamage,
		survivorsAutoDefeatBoss = true,
		maxTransformations = 2,
	},
	safeguards = {
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
		detonationAlwaysResolves = true,
		rewardDistributionOnce = true,
		detonationKillsBossOnSurvival = true,
	},
	description = "A celestial samurai that transforms into a six-winged angel, then an eight-winged celestial warrior, and finally detonates at 5% health.",
})

-- ===========================================================================
-- WORLD BOSS 6 - ABYSSALITH, THE DEEPWATER SOVEREIGN (Pelagic Frontier)
-- ===========================================================================
B["abyssalith"] = boss({
	id = "abyssalith",
	displayName = "Abyssalith",
	title = "The Deepwater Sovereign",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.PelagicFrontier,
	element = Enums.Element.Water,
	rank = "SS",
	tier = 4,
	baseHealth = 320000,
	baseDamage = 370,
	moveSpeed = 22,
	aggroRadius = 400,
	leashRadius = 660,
	resistances = { [Enums.DamageType.Water] = 0.4, [Enums.DamageType.Energy] = 1.3, [Enums.DamageType.Fire] = 1.2 },
	phases = {
		{
			index = 1,
			name = "Shoreline Assault",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.25,
			attacks = {
				attack({
					id = "shore_charge", name = "Tidal Charge", kind = "Charge", telegraph = 1.2, windup = 0.7, active = 1.2,
					recovery = 1.6, cooldown = 13, damage = 400, damageType = Enums.DamageType.Water, range = 200, radius = 24, weight = 2,
					audio = "boss_abyssalith_charge", vfx = "fx_abyssalith_charge",
				}),
				attack({
					id = "water_bolt", name = "Pressure Bolt", kind = "Projectile", telegraph = 0.9, windup = 0.5, active = 0.9,
					recovery = 1.1, cooldown = 7, damage = 230, damageType = Enums.DamageType.Water, range = 260, radius = 10,
					projectileSpeed = 170, count = 4, statusEffect = Enums.StatusEffect.Drenched, statusDuration = 6, weight = 3,
					audio = "boss_abyssalith_bolt", vfx = "fx_abyssalith_bolt",
				}),
				attack({
					id = "tail_sweep", name = "Tail Sweep", kind = "Melee", telegraph = 0.9, windup = 0.4, active = 0.5,
					recovery = 1.2, cooldown = 8, damage = 280, damageType = Enums.DamageType.Physical, range = 60, radius = 44, weight = 2,
					audio = "boss_abyssalith_sweep", vfx = "fx_abyssalith_sweep",
				}),
			},
			weakPoints = { { id = "wp_gill", name = "Gill Plate", attachment = "GillSocket", exposedPhases = { 1, 2 }, multiplier = 1.7 } },
		},
		{
			index = 2,
			name = "Rising Tide",
			healthThreshold = 0.68,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.9,
			crowdControlResistance = 0.4,
			arenaChange = "rising_water",
			onEnter = { raiseWaterLevel = true, waterLevelDelta = 12, enableSwimming = true },
			mechanic = "Rising water and currents change the available routes. Reposition using traversal tools.",
			attacks = {
				attack({
					id = "whirlpool", name = "Whirlpool", kind = "Zone", telegraph = 1.5, windup = 1.0, active = 3.0,
					recovery = 1.8, cooldown = 18, damage = 300, damageType = Enums.DamageType.Water, range = 220, radius = 46, weight = 2,
					audio = "boss_abyssalith_whirlpool", vfx = "fx_abyssalith_whirlpool",
				}),
				attack({
					id = "current_burst", name = "Current Burst", kind = "Projectile", telegraph = 1.1, windup = 0.6, active = 1.2,
					recovery = 1.4, cooldown = 12, damage = 260, damageType = Enums.DamageType.Water, range = 240, radius = 18,
					projectileSpeed = 140, count = 3, statusEffect = Enums.StatusEffect.Slowed, statusDuration = 3, weight = 2,
					audio = "boss_abyssalith_current", vfx = "fx_abyssalith_current",
				}),
			},
			weakPoints = { { id = "wp_gill", name = "Gill Plate", attachment = "GillSocket", exposedPhases = { 1, 2 }, multiplier = 1.7 } },
			timeoutSeconds = 20,
		},
		{
			index = 3,
			name = "Submerged Hunter",
			healthThreshold = 0.4,
			defenseState = Enums.DefenseState.Phased,
			incomingDamageMultiplier = 0.7,
			crowdControlResistance = 0.6,
			mechanic = "The boss submerges and attacks from changing directions. Audio cues, visible water displacement and the scout drone reveal its position.",
			onEnter = { submerge = true, maxAbsentSeconds = 6, surfaceCue = "water_displacement" },
			attacks = {
				attack({
					id = "breach", name = "Breach", kind = "Charge", telegraph = 1.6, windup = 1.0, active = 1.1,
					recovery = 1.7, cooldown = 12, damage = 560, damageType = Enums.DamageType.Physical, range = 220, radius = 30, weight = 2,
					audio = "boss_abyssalith_breach", vfx = "fx_abyssalith_breach",
				}),
				attack({
					id = "depth_charge", name = "Depth Charge", kind = "Zone", telegraph = 1.4, windup = 0.9, active = 1.5,
					recovery = 1.5, cooldown = 14, damage = 340, damageType = Enums.DamageType.Water, range = 200, radius = 34, count = 3, weight = 2,
					audio = "boss_abyssalith_depth", vfx = "fx_abyssalith_depth",
				}),
			},
			timeoutSeconds = 22,
		},
		{
			index = 4,
			name = "Exposed Core",
			healthThreshold = 0.16,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.3,
			crowdControlResistance = 0.35,
			mechanic = "After its major attack the boss surfaces and exposes a vulnerable core section.",
			attacks = {
				attack({
					id = "tidal_wave", name = "Tidal Wave", kind = "Ultimate", telegraph = 2.6, windup = 1.8, active = 2.0,
					recovery = 7.0, cooldown = 38, damage = 700, damageType = Enums.DamageType.Water, range = 320, radius = 120, weight = 1,
					audio = "boss_abyssalith_ultimate", vfx = "fx_abyssalith_ultimate",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Sovereign Core", attachment = "CoreSocket", exposedPhases = { 4 }, multiplier = 2.8, vulnerabilityWindowSeconds = 7 } },
			timeoutSeconds = 20,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_abyssalith",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 6, cinematic = "cin_abyssalith_intro", audio = "boss_abyssalith_intro" },
	death = { duration = 8, sequence = "sinks_beneath_the_waves", audio = "boss_abyssalith_death" },
	audio = { intro = "boss_abyssalith_intro", phase = "boss_abyssalith_phase", death = "boss_abyssalith_death", submerge = "boss_abyssalith_submerge", vulnerable = "boss_abyssalith_vulnerable" },
	vfx = { body = "fx_abyssalith_body", water = "fx_abyssalith_water", core = "fx_abyssalith_core" },
	safeguards = {
		phaseTransitionTimeoutSeconds = Limits.Boss.PhaseTransitionMaxSeconds,
		maxAbsentSeconds = 6,
		alwaysReturnsToSurface = true,
	},
	description = "A gigantic aquatic predator who fights across land, water and changing tide conditions.",
})

-- ===========================================================================
-- WORLD BOSS 7 - PARALLAX, THE UNMADE (Null Horizon)
-- ===========================================================================
B["parallax"] = boss({
	id = "parallax",
	displayName = "Parallax",
	title = "The Unmade",
	kind = Enums.BossKind.WorldBoss,
	regionId = Enums.RegionId.NullHorizon,
	element = Enums.Element.Void,
	rank = "X",
	tier = 5,
	baseHealth = 380000,
	baseDamage = 400,
	moveSpeed = 28,
	aggroRadius = 420,
	leashRadius = 700,
	resistances = { [Enums.DamageType.Void] = 0.5, [Enums.DamageType.Physical] = 1.1, [Enums.DamageType.Light] = 1.2 },
	phases = {
		{
			index = 1,
			name = "Flickering Form",
			healthThreshold = 1.0,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 1.0,
			crowdControlResistance = 0.3,
			mechanic = "Parallax flickers between physical and distorted states. The glitch is a mechanic, never a bug: a damageable target always exists.",
			onEnter = { glitchEnabled = true, maxGlitchSeconds = Limits.BossSpecial.ParallaxMaxGlitchSeconds },
			attacks = {
				attack({
					id = "rift_tear", name = "Spatial Rift", kind = "Zone", telegraph = 1.2, windup = 0.7, active = 1.4,
					recovery = 1.4, cooldown = 12, damage = 300, damageType = Enums.DamageType.Void, range = 200, radius = 26, count = 3, weight = 2,
					audio = "boss_parallax_rift", vfx = "fx_parallax_rift",
				}),
				attack({
					id = "teleport_strike", name = "Distorted Strike", kind = "Melee", telegraph = 0.9, windup = 0.5, active = 0.5,
					recovery = 1.1, cooldown = 8, damage = 340, damageType = Enums.DamageType.Void, range = 70, radius = 30, weight = 2,
					audio = "boss_parallax_strike", vfx = "fx_parallax_strike",
				}),
				attack({
					id = "distorted_bolt", name = "Distorted Bolt", kind = "Projectile", telegraph = 0.9, windup = 0.5, active = 0.9,
					recovery = 1.0, cooldown = 7, damage = 250, damageType = Enums.DamageType.Void, range = 240, radius = 10,
					projectileSpeed = 210, count = 4, weight = 2,
					audio = "boss_parallax_bolt", vfx = "fx_parallax_bolt",
				}),
				attack({
					id = "core_window", name = "Core Flare", kind = "Buff", telegraph = 1.0, windup = 0.6, active = 1.0,
					recovery = 5.0, cooldown = 24, damage = 0, weight = 1, interruptible = false,
					mechanic = "Exposes the core for five seconds.",
					audio = "boss_parallax_vulnerable", vfx = "fx_parallax_vulnerable",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Unstable Core", attachment = "CoreSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 2.0, vulnerabilityWindowSeconds = 5 } },
			timeoutSeconds = Limits.BossSpecial.ParallaxPhaseTimeoutSeconds,
		},
		{
			index = 2,
			name = "False Copies",
			healthThreshold = Limits.BossSpecial.ParallaxStage2Threshold,
			defenseState = Enums.DefenseState.Normal,
			incomingDamageMultiplier = 0.9,
			crowdControlResistance = 0.45,
			onEnter = { spawnCopies = 3, copyHealth = 12000, trueBodyTell = "only_true_body_telegraphs_and_is_markable" },
			mechanic = "Only one copy is real. The true body telegraphs before attacking, tracks with Hunter's Mark, and leaves stable spatial footprints.",
			attacks = {
				attack({
					id = "copy_call", name = "Fracture Call", kind = "Summon", telegraph = 1.2, windup = 0.8, active = 1.0,
					recovery = 1.2, cooldown = 24, damage = 0, count = 3, weight = 1, interruptible = true,
					audio = "boss_parallax_copies", vfx = "fx_parallax_copies",
				}),
				attack({
					id = "rift_tear", name = "Spatial Rift", kind = "Zone", telegraph = 1.2, windup = 0.7, active = 1.4,
					recovery = 1.4, cooldown = 13, damage = 320, damageType = Enums.DamageType.Void, range = 200, radius = 28, count = 3, weight = 2,
					audio = "boss_parallax_rift", vfx = "fx_parallax_rift",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Unstable Core", attachment = "CoreSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 2.0, vulnerabilityWindowSeconds = 5 } },
			timeoutSeconds = Limits.BossSpecial.ParallaxPhaseTimeoutSeconds,
		},
		{
			index = 3,
			name = "Fractured Reality",
			healthThreshold = Limits.BossSpecial.ParallaxStage3Threshold,
			defenseState = Enums.DefenseState.Phased,
			incomingDamageMultiplier = 0.75,
			crowdControlResistance = 0.6,
			arenaChange = "reality_fractures",
			onEnter = { fractureArena = true, gravityAnomalies = true, maxAbsentSeconds = Limits.BossSpecial.ParallaxMaxAbsentSeconds },
			mechanic = "Reality fractures spread, gravity shifts and the boss may briefly vanish. It can never remain absent for long and always returns to a valid position.",
			attacks = {
				attack({
					id = "gravity_shift", name = "Gravity Shift", kind = "Zone", telegraph = 1.6, windup = 1.0, active = 3.0,
					recovery = 1.8, cooldown = 20, damage = 300, damageType = Enums.DamageType.Void, range = 240, radius = 60, weight = 2,
					audio = "boss_parallax_gravity", vfx = "fx_parallax_gravity",
				}),
				attack({
					id = "vanish", name = "Unmake Step", kind = "Buff", telegraph = 0.8, windup = 0.5, active = 0.6,
					recovery = 1.4, cooldown = 16, damage = 0, weight = 1, interruptible = false,
					mechanic = string.format("Disappears for at most %d seconds, then reappears at a validated position.", Limits.BossSpecial.ParallaxMaxAbsentSeconds),
					audio = "boss_parallax_vanish", vfx = "fx_parallax_vanish",
				}),
				attack({
					id = "core_window", name = "Core Flare", kind = "Buff", telegraph = 1.0, windup = 0.6, active = 1.0,
					recovery = 5.0, cooldown = 22, damage = 0, weight = 1, interruptible = false,
					audio = "boss_parallax_vulnerable", vfx = "fx_parallax_vulnerable",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Unstable Core", attachment = "CoreSocket", exposedPhases = { 1, 2, 3, 4 }, multiplier = 2.0, vulnerabilityWindowSeconds = 5 } },
			timeoutSeconds = Limits.BossSpecial.ParallaxPhaseTimeoutSeconds,
		},
		{
			index = 4,
			name = "Unstable Collapse",
			healthThreshold = Limits.BossSpecial.ParallaxStage4Threshold,
			defenseState = Enums.DefenseState.Vulnerable,
			incomingDamageMultiplier = 1.4,
			crowdControlResistance = 0.4,
			mechanic = "The core becomes vulnerable during defined windows. Identify the exposed core and finish the encounter.",
			attacks = {
				attack({
					id = "collapse_wave", name = "Collapse Wave", kind = "Zone", telegraph = 1.4, windup = 0.9, active = 2.0,
					recovery = 1.6, cooldown = 14, damage = 380, damageType = Enums.DamageType.Void, range = 220, radius = 44, weight = 2,
					audio = "boss_parallax_collapse", vfx = "fx_parallax_collapse",
				}),
				attack({
					id = "core_window", name = "Core Exposure", kind = "Buff", telegraph = 0.9, windup = 0.5, active = 1.0,
					recovery = 6.0, cooldown = 18, damage = 0, weight = 1, interruptible = false,
					audio = "boss_parallax_vulnerable", vfx = "fx_parallax_vulnerable",
				}),
			},
			weakPoints = { { id = "wp_core", name = "Collapsing Core", attachment = "CoreSocket", exposedPhases = { 4 }, multiplier = 3.0, vulnerabilityWindowSeconds = Limits.BossSpecial.ParallaxMinVulnerableWindowSeconds } },
			timeoutSeconds = Limits.BossSpecial.ParallaxPhaseTimeoutSeconds,
		},
	},
	weakPoints = {},
	rewardTableId = "rewards_parallax",
	respawnSeconds = Limits.Boss.RespawnSeconds,
	intro = { duration = 6, cinematic = "cin_parallax_intro", audio = "boss_parallax_intro" },
	death = { duration = 9, sequence = "unravels_into_nothing", audio = "boss_parallax_death" },
	audio = { intro = "boss_parallax_intro", phase = "boss_parallax_phase", death = "boss_parallax_death", glitch = "boss_parallax_glitch", vulnerable = "boss_parallax_vulnerable" },
	vfx = { body = "fx_parallax_body", glitch = "fx_parallax_glitch", rift = "fx_parallax_rift", core = "fx_parallax_core" },
	special = {
		type = "ParallaxSafeguards",
		maxAbsentSeconds = Limits.BossSpecial.ParallaxMaxAbsentSeconds,
		maxGlitchSeconds = Limits.BossSpecial.ParallaxMaxGlitchSeconds,
		teleportMaxStuds = Limits.BossSpecial.ParallaxTeleportMaxStuds,
		phaseTimeoutSeconds = Limits.BossSpecial.ParallaxPhaseTimeoutSeconds,
		minVulnerableWindowSeconds = Limits.BossSpecial.ParallaxMinVulnerableWindowSeconds,
		alwaysDamageable = true,
	},
	safeguards = {
		alwaysDamageable = true,
		neverPermanentlyInvulnerable = true,
		glitchNeverRemovesOnlyHitbox = true,
		teleportsResolveToValidPositions = true,
		phaseTransitionsHaveTimeouts = true,
		deathStateAlwaysReachable = true,
		rewardDistributionOnce = true,
	},
	description = "A reality-glitching boss. Its glitching is an intentional mechanic and it is ALWAYS defeatable.",
})

return B
