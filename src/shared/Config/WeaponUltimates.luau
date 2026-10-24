--!strict
--[[
	WeaponUltimates.luau
	EVERY WILDBREAK FIREARM HAS ITS OWN SIGNATURE ULTIMATE.

	The Ultimate belongs to the weapon, not to the character. Each definition
	describes an ordered sequence of gameplay steps which the server-side
	UltimateService executes. Visual and audio keys are resolved through
	AudioConfig / the effect registry, never hardcoded asset ids.

	Step kinds understood by the executor (server/Combat/UltimateExecutor):
	  Cast      - windup / telegraph, no damage
	  Buff      - applies a temporary buff to self or nearby allies
	  Beam      - sustained beam along a direction, damage per tick
	  Wave      - expanding shockwave ring, one damage instance per target
	  Volley    - a burst of homing projectiles
	  Strike    - single heavy hit in a radius or along a pierce line
	  Zone      - persistent damaging / controlling area
	  Chain     - damage that jumps between nearby targets
	  Mark      - marks targets, revealing weak points and amplifying damage
	  Blink     - validated short teleport, then a strike
	  Summon    - temporary automated minions
	  Pull      - gravity well that drags and roots
	  Detonate  - delayed detonation at marked locations
	  Mount     - enters a mounted state with recoil/damage modifiers
]]

local Enums = require(script.Parent.Parent.Constants.Enums)

export type UltimateStep = {
	at: number,
	kind: string,
	duration: number?,
	-- Shared damage model
	damageMultiplier: number?,
	flatDamage: number?,
	damagePerTick: number?,
	tickInterval: number?,
	damageType: string?,
	-- Shape
	radius: number?,
	range: number?,
	count: number?,
	pierce: boolean?,
	arcDegrees: number?,
	-- Behaviour
	statusEffect: string?,
	statusDuration: number?,
	buff: string?,
	buffMagnitude: number?,
	autoAim: boolean?,
	effects: { string }?,
	audio: { string }?,
	screenEffect: string?,
	camera: string?,
	-- Safety
	maxDistance: number?,
}

export type UltimateDef = {
	id: string,
	weaponId: string,
	name: string,
	tagline: string,
	cooldown: number,
	chargeCost: number,
	castTime: number,
	targeting: string, -- Point | Target | Self | Direction
	range: number,
	requiresTarget: boolean,
	damageType: string,
	steps: { UltimateStep },
	ui: { accentColor: { number }, icon: string, chargingText: string },
	performance: { maxParticles: number, fallbackSteps: { number }? },
	cancelRules: { interruptedByStun: boolean, interruptedByDeath: boolean, cancelledOnSwitch: boolean },
	notes: string,
}

local function step(def: UltimateStep): UltimateStep
	return def
end

local function ult(def: UltimateDef): UltimateDef
	return def
end

local U: { [string]: UltimateDef } = {}

-- ---------------------------------------------------------------------------
-- ASSAULT RIFLES
-- ---------------------------------------------------------------------------
U["ult_ranger"] = ult({
	id = "ult_ranger",
	weaponId = "ar_ranger",
	name = "Overwatch Barrage",
	tagline = "Controlled high-speed barrage from a braced position.",
	cooldown = 44,
	chargeCost = 100,
	castTime = 0.45,
	targeting = "Direction",
	range = 340,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.45, effects = { "ult_ranger_brace" }, audio = { "ult_ranger_cast" } }),
		step({
			at = 0.45, kind = "Barrage", duration = 3.2, count = 48, damageMultiplier = 1.35, autoAim = true, range = 340,
			arcDegrees = 26, effects = { "ult_ranger_tracer" }, audio = { "ult_ranger_fire" }, screenEffect = "recoil_light",
		}),
		step({ at = 3.65, kind = "Strike", damageMultiplier = 1.1, radius = 12, range = 340, effects = { "ult_ranger_final" }, audio = { "ult_ranger_impact" } }),
	},
	ui = { accentColor = { 0.45, 0.85, 0.55 }, icon = "ult_ranger", chargingText = "OVERWATCH" },
	performance = { maxParticles = 120 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Sustained directed fire. Auto-aim only inside the declared cone; the server still raycasts every shot.",
})

U["ult_vanguard"] = ult({
	id = "ult_vanguard",
	weaponId = "ar_vanguard",
	name = "Spearhead Charge",
	tagline = "Plant a shock-plate and advance behind it, firing through the gap.",
	cooldown = 48,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Direction",
	range = 300,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_vanguard_plate" }, audio = { "ult_vanguard_cast" } }),
		step({ at = 0.5, kind = "Buff", duration = 5, buff = "DamageReduction", buffMagnitude = 0.35, effects = { "ult_vanguard_aura" }, audio = { "ult_vanguard_buff" } }),
		step({
			at = 0.6, kind = "Barrage", duration = 4.4, count = 40, damageMultiplier = 1.25, range = 300, arcDegrees = 34,
			effects = { "ult_vanguard_shot" }, audio = { "ult_vanguard_fire" },
		}),
		step({ at = 5.0, kind = "Wave", radius = 40, damageMultiplier = 0.9, statusEffect = Enums.StatusEffect.Staggered, statusDuration = 1.2, effects = { "ult_vanguard_shock" }, audio = { "ult_vanguard_impact" } }),
	},
	ui = { accentColor = { 0.35, 0.72, 0.95 }, icon = "ult_vanguard", chargingText = "SPEARHEAD" },
	performance = { maxParticles = 140 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The plate is a real object with collisions; it blocks beast charges and projectile attacks.",
})

U["ult_ravager"] = ult({
	id = "ult_ravager",
	weaponId = "ar_ravager",
	name = "Ravager's Feast",
	tagline = "Chain-fed execution that grows stronger with every consecutive hit.",
	cooldown = 52,
	chargeCost = 100,
	castTime = 0.4,
	targeting = "Target",
	range = 280,
	requiresTarget = true,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.4, effects = { "ult_ravager_roar" }, audio = { "ult_ravager_cast" } }),
		step({ at = 0.4, kind = "Chain", count = 12, damageMultiplier = 1.6, range = 90, damageType = Enums.DamageType.Physical, effects = { "ult_ravager_chain" }, audio = { "ult_ravager_chain" } }),
		step({ at = 0.9, kind = "Barrage", duration = 2.6, count = 60, damageMultiplier = 1.2, autoAim = true, range = 280, effects = { "ult_ravager_shot" }, audio = { "ult_ravager_fire" } }),
	},
	ui = { accentColor = { 0.95, 0.35, 0.25 }, icon = "ult_ravager", chargingText = "FEAST" },
	performance = { maxParticles = 160 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Each chain link increases the next link's damage by 8% on the server.",
})

U["ult_tempest"] = ult({
	id = "ult_tempest",
	weaponId = "ar_tempest",
	name = "Stormfront",
	tagline = "A rotating ring of rounds orbits the hunter while they keep moving.",
	cooldown = 50,
	chargeCost = 100,
	castTime = 0.35,
	targeting = "Self",
	range = 90,
	requiresTarget = false,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.35, effects = { "ult_tempest_summon" }, audio = { "ult_tempest_cast" } }),
		step({ at = 0.35, kind = "Zone", duration = 8, radius = 26, damagePerTick = 46, tickInterval = 0.35, effects = { "ult_tempest_storm" }, audio = { "ult_tempest_loop" } }),
		step({ at = 0.35, kind = "Buff", duration = 8, buff = "MovementSpeed", buffMagnitude = 0.25, effects = { "ult_tempest_wind" }, audio = { "ult_tempest_buff" } }),
	},
	ui = { accentColor = { 0.40, 0.85, 1.0 }, icon = "ult_tempest", chargingText = "STORMFRONT" },
	performance = { maxParticles = 180 },
	cancelRules = { interruptedByStun = false, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "The storm follows the player; every damage instance is a separate server-authoritative hit.",
})

U["ult_longshot"] = ult({
	id = "ult_longshot",
	weaponId = "ar_longshot",
	name = "Horizon Lance",
	tagline = "One impossibly long piercing shot that marks everything it passes through.",
	cooldown = 46,
	chargeCost = 100,
	castTime = 0.8,
	targeting = "Direction",
	range = 900,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.8, effects = { "ult_longshot_charge" }, audio = { "ult_longshot_cast" }, camera = "scope_in" }),
		step({ at = 0.8, kind = "Strike", damageMultiplier = 6.5, range = 900, radius = 7, pierce = true, effects = { "ult_longshot_lance" }, audio = { "ult_longshot_fire" }, screenEffect = "flash_white" }),
		step({ at = 0.95, kind = "Mark", range = 900, radius = 7, duration = 10, buffMagnitude = 0.25, effects = { "ult_longshot_mark" }, audio = { "ult_longshot_mark" } }),
	},
	ui = { accentColor = { 0.85, 0.90, 0.95 }, icon = "ult_longshot", chargingText = "HORIZON LANCE" },
	performance = { maxParticles = 90 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Pierce hits every valid target along the validated ray, applying damage falloff per body.",
})

U["ult_bulwark"] = ult({
	id = "ult_bulwark",
	weaponId = "ar_bulwark",
	name = "Aegis Volley",
	tagline = "Deploy a reflecting barrier and fire through it.",
	cooldown = 55,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Self",
	range = 220,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_bulwark_deploy" }, audio = { "ult_bulwark_cast" } }),
		step({ at = 0.5, kind = "Shield", duration = 8, buffMagnitude = 900, radius = 30, effects = { "ult_bulwark_wall" }, audio = { "ult_bulwark_wall" } }),
		step({ at = 0.7, kind = "Barrage", duration = 5, count = 54, damageMultiplier = 1.15, autoAim = true, range = 220, effects = { "ult_bulwark_shot" }, audio = { "ult_bulwark_fire" } }),
	},
	ui = { accentColor = { 0.55, 0.75, 0.95 }, icon = "ult_bulwark", chargingText = "AEGIS" },
	performance = { maxParticles = 150 },
	cancelRules = { interruptedByStun = false, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "The barrier is a server object with a health pool; it reflects eligible projectiles back at reduced damage.",
})

U["ult_wildfire"] = ult({
	id = "ult_wildfire",
	weaponId = "ar_wildfire",
	name = "Wildfire Bloom",
	tagline = "Ignite the ground, then let it burn outward in a blooming ring.",
	cooldown = 50,
	chargeCost = 100,
	castTime = 0.45,
	targeting = "Point",
	range = 260,
	requiresTarget = false,
	damageType = Enums.DamageType.Fire,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.45, effects = { "ult_wildfire_seed" }, audio = { "ult_wildfire_cast" } }),
		step({ at = 0.45, kind = "Volley", count = 8, damageMultiplier = 1.8, radius = 9, range = 260, statusEffect = Enums.StatusEffect.Burn, statusDuration = 6, effects = { "ult_wildfire_bloom" }, audio = { "ult_wildfire_burst" } }),
		step({ at = 1.1, kind = "Zone", duration = 8, radius = 38, damagePerTick = 34, tickInterval = 0.5, statusEffect = Enums.StatusEffect.Burn, statusDuration = 3, effects = { "ult_wildfire_field" }, audio = { "ult_wildfire_loop" } }),
	},
	ui = { accentColor = { 1.0, 0.55, 0.15 }, icon = "ult_wildfire", chargingText = "WILDFIRE" },
	performance = { maxParticles = 200 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Burning ground is a server zone; damage over time never stacks beyond the configured cap.",
})

U["ult_overdrive"] = ult({
	id = "ult_overdrive",
	weaponId = "ar_overdrive",
	name = "Overdrive Cascade",
	tagline = "Push the heat cycle past the red line and vent it as a cascade.",
	cooldown = 58,
	chargeCost = 100,
	castTime = 0.4,
	targeting = "Direction",
	range = 300,
	requiresTarget = false,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.4, effects = { "ult_overdrive_vent" }, audio = { "ult_overdrive_cast" } }),
		step({ at = 0.4, kind = "Buff", duration = 6, buff = "FireRate", buffMagnitude = 0.6, effects = { "ult_overdrive_aura" }, audio = { "ult_overdrive_buff" } }),
		step({ at = 0.4, kind = "Barrage", duration = 5, count = 120, damageMultiplier = 1.05, autoAim = true, range = 300, arcDegrees = 30, effects = { "ult_overdrive_shot" }, audio = { "ult_overdrive_fire" } }),
		step({ at = 5.6, kind = "Detonate", radius = 26, damageMultiplier = 3.2, effects = { "ult_overdrive_cascade" }, audio = { "ult_overdrive_impact" }, screenEffect = "flash_orange", camera = "shake_heavy" }),
	},
	ui = { accentColor = { 1.0, 0.25, 0.45 }, icon = "ult_overdrive", chargingText = "OVERDRIVE" },
	performance = { maxParticles = 220 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The cascade detonation happens even if the player is interrupted after the barrage starts.",
})

-- ---------------------------------------------------------------------------
-- SUBMACHINE GUNS
-- ---------------------------------------------------------------------------
U["ult_wasp"] = ult({
	id = "ult_wasp",
	weaponId = "smg_wasp",
	name = "Swarm Release",
	tagline = "A cloud of micro-drones stitches every beast in the room.",
	cooldown = 40,
	chargeCost = 100,
	castTime = 0.3,
	targeting = "Point",
	range = 160,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.3, effects = { "ult_wasp_release" }, audio = { "ult_wasp_cast" } }),
		step({ at = 0.3, kind = "Summon", count = 12, duration = 8, damagePerTick = 18, tickInterval = 0.4, range = 160, effects = { "ult_wasp_drone" }, audio = { "ult_wasp_loop" } }),
	},
	ui = { accentColor = { 0.95, 0.85, 0.25 }, icon = "ult_wasp", chargingText = "SWARM" },
	performance = { maxParticles = 140 },
	cancelRules = { interruptedByStun = false, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Drones are server entities with a strict lifetime and a hard cap of 12 per player.",
})

U["ult_viper"] = ult({
	id = "ult_viper",
	weaponId = "smg_viper",
	name = "Venom Lash",
	tagline = "Six rapid venom strikes that melt armour and spread corrosion.",
	cooldown = 42,
	chargeCost = 100,
	castTime = 0.3,
	targeting = "Target",
	range = 180,
	requiresTarget = true,
	damageType = Enums.DamageType.Bio,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.3, effects = { "ult_viper_ready" }, audio = { "ult_viper_cast" } }),
		step({ at = 0.3, kind = "Barrage", duration = 1.6, count = 6, damageMultiplier = 3.2, autoAim = true, range = 180, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 10, effects = { "ult_viper_lash" }, audio = { "ult_viper_strike" } }),
		step({ at = 2.0, kind = "Zone", duration = 8, radius = 18, damagePerTick = 26, tickInterval = 0.5, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 4, effects = { "ult_viper_pool" }, audio = { "ult_viper_loop" } }),
	},
	ui = { accentColor = { 0.45, 0.95, 0.35 }, icon = "ult_viper", chargingText = "VENOM LASH" },
	performance = { maxParticles = 150 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Corrosion weakens armour by a configured percentage; it never removes a boss's armored state outright.",
})

U["ult_jackal"] = ult({
	id = "ult_jackal",
	weaponId = "smg_jackal",
	name = "Pack Hunt",
	tagline = "Mark the pack, then fire one synchronised volley into every mark.",
	cooldown = 44,
	chargeCost = 100,
	castTime = 0.4,
	targeting = "Point",
	range = 200,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.4, effects = { "ult_jackal_howl" }, audio = { "ult_jackal_cast" } }),
		step({ at = 0.4, kind = "Mark", range = 200, radius = 90, duration = 8, buffMagnitude = 0.3, effects = { "ult_jackal_mark" }, audio = { "ult_jackal_mark" } }),
		step({ at = 0.9, kind = "Volley", count = 10, damageMultiplier = 2.4, range = 200, autoAim = true, effects = { "ult_jackal_shot" }, audio = { "ult_jackal_fire" } }),
	},
	ui = { accentColor = { 0.85, 0.55, 0.30 }, icon = "ult_jackal", chargingText = "PACK HUNT" },
	performance = { maxParticles = 130 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Marks are server state; clients only render them.",
})

U["ult_riptide"] = ult({
	id = "ult_riptide",
	weaponId = "smg_riptide",
	name = "Undertow",
	tagline = "A pressurised wave that drags beasts into a single killing lane.",
	cooldown = 46,
	chargeCost = 100,
	castTime = 0.45,
	targeting = "Direction",
	range = 190,
	requiresTarget = false,
	damageType = Enums.DamageType.Water,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.45, effects = { "ult_riptide_charge" }, audio = { "ult_riptide_cast" } }),
		step({ at = 0.45, kind = "Pull", duration = 2.2, radius = 34, range = 190, damagePerTick = 18, tickInterval = 0.4, statusEffect = Enums.StatusEffect.Drenched, statusDuration = 8, effects = { "ult_riptide_wave" }, audio = { "ult_riptide_wave" } }),
		step({ at = 2.6, kind = "Wave", radius = 46, damageMultiplier = 2.8, statusEffect = Enums.StatusEffect.Slowed, statusDuration = 3, effects = { "ult_riptide_crash" }, audio = { "ult_riptide_impact" }, camera = "shake_light" }),
	},
	ui = { accentColor = { 0.25, 0.70, 1.0 }, icon = "ult_riptide", chargingText = "UNDERTOW" },
	performance = { maxParticles = 170 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Pull only affects beasts and bosses flagged as pullable in their species / boss configuration.",
})

U["ult_flicker"] = ult({
	id = "ult_flicker",
	weaponId = "smg_flicker",
	name = "Phase Volley",
	tagline = "Blink between marked positions, firing a burst from each.",
	cooldown = 48,
	chargeCost = 100,
	castTime = 0.3,
	targeting = "Point",
	range = 200,
	requiresTarget = false,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.3, effects = { "ult_flicker_phase" }, audio = { "ult_flicker_cast" } }),
		step({ at = 0.3, kind = "Blink", count = 5, maxDistance = 60, damageMultiplier = 2.0, radius = 10, effects = { "ult_flicker_blink" }, audio = { "ult_flicker_blink" } }),
		step({ at = 2.4, kind = "Strike", damageMultiplier = 3.0, radius = 18, range = 60, effects = { "ult_flicker_final" }, audio = { "ult_flicker_impact" } }),
	},
	ui = { accentColor = { 0.65, 0.55, 1.0 }, icon = "ult_flicker", chargingText = "PHASE VOLLEY" },
	performance = { maxParticles = 120 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Every blink destination is validated for walkability and total distance on the server.",
})

U["ult_razorback"] = ult({
	id = "ult_razorback",
	weaponId = "smg_razorback",
	name = "Ripcut Cyclone",
	tagline = "A spinning blade-storm of rounds that shreds everything nearby.",
	cooldown = 52,
	chargeCost = 100,
	castTime = 0.4,
	targeting = "Self",
	range = 60,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.4, effects = { "ult_razorback_spinup" }, audio = { "ult_razorback_cast" } }),
		step({ at = 0.4, kind = "Zone", duration = 6, radius = 30, damagePerTick = 62, tickInterval = 0.22, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 5, effects = { "ult_razorback_cyclone" }, audio = { "ult_razorback_loop" }, camera = "shake_light" }),
		step({ at = 6.4, kind = "Wave", radius = 40, damageMultiplier = 2.2, effects = { "ult_razorback_burst" }, audio = { "ult_razorback_impact" } }),
	},
	ui = { accentColor = { 0.95, 0.30, 0.35 }, icon = "ult_razorback", chargingText = "RIPCUT" },
	performance = { maxParticles = 210 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Bleed stacks are capped per target by CombatConfig status caps.",
})

-- ---------------------------------------------------------------------------
-- SHOTGUNS
-- ---------------------------------------------------------------------------
U["ult_breach"] = ult({
	id = "ult_breach",
	weaponId = "sg_breach",
	name = "Breaching Blast",
	tagline = "A concentrated close-range shockwave that shatters shields and armour.",
	cooldown = 40,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Direction",
	range = 90,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_breach_load" }, audio = { "ult_breach_cast" } }),
		step({ at = 0.5, kind = "Wave", radius = 34, damageMultiplier = 5.5, statusEffect = Enums.StatusEffect.Weakened, statusDuration = 6, effects = { "ult_breach_blast" }, audio = { "ult_breach_impact" }, camera = "shake_medium" }),
	},
	ui = { accentColor = { 0.85, 0.60, 0.35 }, icon = "ult_breach", chargingText = "BREACH" },
	performance = { maxParticles = 160 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Deals triple damage to shields and applies a shield-break check to eligible bosses.",
})

U["ult_thunderclap"] = ult({
	id = "ult_thunderclap",
	weaponId = "sg_thunderclap",
	name = "Thunderclap",
	tagline = "A sonic detonation that staggers everything that can hear it.",
	cooldown = 44,
	chargeCost = 100,
	castTime = 0.55,
	targeting = "Self",
	range = 80,
	requiresTarget = false,
	damageType = Enums.DamageType.Sonic,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.55, effects = { "ult_thunderclap_charge" }, audio = { "ult_thunderclap_cast" } }),
		step({ at = 0.55, kind = "Wave", radius = 44, damageMultiplier = 4.2, statusEffect = Enums.StatusEffect.Stunned, statusDuration = 2.5, effects = { "ult_thunderclap_wave" }, audio = { "ult_thunderclap_impact" }, screenEffect = "flash_white", camera = "shake_heavy" }),
	},
	ui = { accentColor = { 0.90, 0.85, 0.55 }, icon = "ult_thunderclap", chargingText = "THUNDERCLAP" },
	performance = { maxParticles = 150 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Stun duration is reduced on bosses by their configured crowd-control resistance.",
})

U["ult_mauler"] = ult({
	id = "ult_mauler",
	weaponId = "sg_mauler",
	name = "Mauler's Rampage",
	tagline = "Three thunderous slams, each heavier than the last.",
	cooldown = 46,
	chargeCost = 100,
	castTime = 0.4,
	targeting = "Point",
	range = 95,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.4, effects = { "ult_mauler_ready" }, audio = { "ult_mauler_cast" } }),
		step({ at = 0.4, kind = "Strike", damageMultiplier = 3.4, radius = 20, range = 95, effects = { "ult_mauler_slam1" }, audio = { "ult_mauler_slam" }, camera = "shake_medium" }),
		step({ at = 1.2, kind = "Strike", damageMultiplier = 4.0, radius = 24, range = 95, effects = { "ult_mauler_slam2" }, audio = { "ult_mauler_slam" }, camera = "shake_medium" }),
		step({ at = 2.1, kind = "Strike", damageMultiplier = 6.0, radius = 30, range = 95, effects = { "ult_mauler_slam3" }, audio = { "ult_mauler_final" }, camera = "shake_heavy" }),
	},
	ui = { accentColor = { 0.80, 0.45, 0.30 }, icon = "ult_mauler", chargingText = "RAMPAGE" },
	performance = { maxParticles = 180 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Each slam is an independent server damage instance; dying mid-sequence stops the rest.",
})

U["ult_riot"] = ult({
	id = "ult_riot",
	weaponId = "sg_riot",
	name = "Riot Suppression",
	tagline = "A wide control field that roots and slows instead of killing.",
	cooldown = 38,
	chargeCost = 100,
	castTime = 0.45,
	targeting = "Point",
	range = 110,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.45, effects = { "ult_riot_deploy" }, audio = { "ult_riot_cast" } }),
		step({ at = 0.45, kind = "Zone", duration = 7, radius = 40, damagePerTick = 20, tickInterval = 0.5, statusEffect = Enums.StatusEffect.Rooted, statusDuration = 1.2, effects = { "ult_riot_field" }, audio = { "ult_riot_loop" } }),
	},
	ui = { accentColor = { 0.55, 0.65, 0.85 }, icon = "ult_riot", chargingText = "SUPPRESS" },
	performance = { maxParticles = 130 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Root is repeatedly refreshed but bosses gain diminishing resistance per application.",
})

U["ult_groundbreaker"] = ult({
	id = "ult_groundbreaker",
	weaponId = "sg_groundbreaker",
	name = "Groundbreaker",
	tagline = "A line of fissures erupts forward and detonates.",
	cooldown = 54,
	chargeCost = 100,
	castTime = 0.6,
	targeting = "Direction",
	range = 120,
	requiresTarget = false,
	damageType = Enums.DamageType.Explosive,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.6, effects = { "ult_groundbreaker_charge" }, audio = { "ult_groundbreaker_cast" } }),
		step({ at = 0.6, kind = "Wave", radius = 60, damageMultiplier = 4.6, range = 120, statusEffect = Enums.StatusEffect.Staggered, statusDuration = 1.5, effects = { "ult_groundbreaker_fissure" }, audio = { "ult_groundbreaker_erupt" }, camera = "shake_heavy" }),
		step({ at = 1.6, kind = "Detonate", radius = 30, damageMultiplier = 3.0, effects = { "ult_groundbreaker_detonate" }, audio = { "ult_groundbreaker_impact" } }),
	},
	ui = { accentColor = { 0.75, 0.55, 0.35 }, icon = "ult_groundbreaker", chargingText = "GROUNDBREAK" },
	performance = { maxParticles = 200 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Fissures are server-positioned volumes; terrain is never permanently modified.",
})

-- ---------------------------------------------------------------------------
-- SNIPER RIFLES
-- ---------------------------------------------------------------------------
U["ult_hawkeye"] = ult({
	id = "ult_hawkeye",
	weaponId = "sr_hawkeye",
	name = "Sky Piercer",
	tagline = "A precision penetration sequence that seeks every weak point in the line.",
	cooldown = 55,
	chargeCost = 100,
	castTime = 1.0,
	targeting = "Direction",
	range = 900,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 1.0, effects = { "ult_hawkeye_aim" }, audio = { "ult_hawkeye_cast" }, camera = "scope_in" }),
		step({ at = 1.0, kind = "Strike", damageMultiplier = 7.5, range = 900, radius = 5, pierce = true, effects = { "ult_hawkeye_shot" }, audio = { "ult_hawkeye_fire" }, screenEffect = "flash_white" }),
	},
	ui = { accentColor = { 0.70, 0.85, 0.95 }, icon = "ult_hawkeye", chargingText = "SKY PIERCER" },
	performance = { maxParticles = 100 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Every pierced target is hit with weak-point rules applied when the validated ray crosses a weak point.",
})

U["ult_deadfall"] = ult({
	id = "ult_deadfall",
	weaponId = "sr_deadfall",
	name = "Deadfall Drop",
	tagline = "Mark the ground, then drop a kinetic strike on it.",
	cooldown = 58,
	chargeCost = 100,
	castTime = 0.7,
	targeting = "Point",
	range = 900,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.7, effects = { "ult_deadfall_beacon" }, audio = { "ult_deadfall_cast" } }),
		step({ at = 0.7, kind = "Mark", range = 900, radius = 26, duration = 3, buffMagnitude = 0, effects = { "ult_deadfall_marker" }, audio = { "ult_deadfall_beacon" } }),
		step({ at = 2.6, kind = "Strike", damageMultiplier = 9.0, radius = 26, range = 900, effects = { "ult_deadfall_impact" }, audio = { "ult_deadfall_impact" }, camera = "shake_heavy" }),
	},
	ui = { accentColor = { 0.60, 0.65, 0.75 }, icon = "ult_deadfall", chargingText = "DEADFALL" },
	performance = { maxParticles = 170 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "The marker is server state: the drop resolves at the marked position even if the caster dies.",
})

U["ult_peregrine"] = ult({
	id = "ult_peregrine",
	weaponId = "sr_peregrine",
	name = "Stoop",
	tagline = "Leap, hang in the air, and fire down through the target.",
	cooldown = 50,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Point",
	range = 600,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_peregrine_leap" }, audio = { "ult_peregrine_cast" }, camera = "orbit_up" }),
		step({ at = 0.5, kind = "Blink", count = 1, maxDistance = 90, damageMultiplier = 0, effects = { "ult_peregrine_air" }, audio = { "ult_peregrine_wind" } }),
		step({ at = 1.1, kind = "Strike", damageMultiplier = 8.0, radius = 18, range = 600, effects = { "ult_peregrine_dive" }, audio = { "ult_peregrine_impact" }, camera = "dive_in" }),
		step({ at = 1.8, kind = "Wave", radius = 32, damageMultiplier = 2.0, effects = { "ult_peregrine_shock" }, audio = { "ult_peregrine_impact" } }),
	},
	ui = { accentColor = { 0.85, 0.70, 0.90 }, icon = "ult_peregrine", chargingText = "STOOP" },
	performance = { maxParticles = 140 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The airborne position is validated; the dive cannot be used to leave a boss arena or enter a locked volume.",
})

U["ult_frostline"] = ult({
	id = "ult_frostline",
	weaponId = "sr_frostline",
	name = "Coldsnap",
	tagline = "Freeze the target solid, then shatter it for massive bonus damage.",
	cooldown = 52,
	chargeCost = 100,
	castTime = 0.8,
	targeting = "Target",
	range = 880,
	requiresTarget = true,
	damageType = Enums.DamageType.Ice,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.8, effects = { "ult_frostline_charge" }, audio = { "ult_frostline_cast" }, camera = "scope_in" }),
		step({ at = 0.8, kind = "Strike", damageMultiplier = 3.0, range = 880, radius = 10, statusEffect = Enums.StatusEffect.Chill, statusDuration = 2.5, effects = { "ult_frostline_shot" }, audio = { "ult_frostline_fire" } }),
		step({ at = 1.6, kind = "Detonate", radius = 22, damageMultiplier = 7.5, effects = { "ult_frostline_shatter" }, audio = { "ult_frostline_shatter" }, screenEffect = "frost_edges", camera = "shake_medium" }),
	},
	ui = { accentColor = { 0.65, 0.90, 1.0 }, icon = "ult_frostline", chargingText = "COLDSNAP" },
	performance = { maxParticles = 160 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "If the target dies on the first hit, the shatter detonates at its last known position.",
})

U["ult_ghostmark"] = ult({
	id = "ult_ghostmark",
	weaponId = "sr_ghostmark",
	name = "Phantom Shot",
	tagline = "Fire once; the shot echoes through every marked target.",
	cooldown = 56,
	chargeCost = 100,
	castTime = 0.9,
	targeting = "Point",
	range = 1000,
	requiresTarget = false,
	damageType = Enums.DamageType.Dark,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.9, effects = { "ult_ghostmark_phase" }, audio = { "ult_ghostmark_cast" }, camera = "scope_in" }),
		step({ at = 0.9, kind = "Mark", range = 1000, radius = 120, duration = 6, buffMagnitude = 0.4, effects = { "ult_ghostmark_mark" }, audio = { "ult_ghostmark_mark" } }),
		step({ at = 1.4, kind = "Chain", count = 8, damageMultiplier = 4.5, range = 300, effects = { "ult_ghostmark_echo" }, audio = { "ult_ghostmark_echo" } }),
	},
	ui = { accentColor = { 0.35, 0.30, 0.55 }, icon = "ult_ghostmark", chargingText = "PHANTOM" },
	performance = { maxParticles = 150 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The chain only jumps between targets the server has already marked in the previous step.",
})

-- ---------------------------------------------------------------------------
-- DESIGNATED MARKSMAN RIFLES
-- ---------------------------------------------------------------------------
U["ult_tracker"] = ult({
	id = "ult_tracker",
	weaponId = "dmr_tracker",
	name = "Hunter's Sweep",
	tagline = "Sweep the cone, mark everything in it, and fire a sequenced volley.",
	cooldown = 42,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Direction",
	range = 520,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_tracker_scan" }, audio = { "ult_tracker_cast" } }),
		step({ at = 0.5, kind = "Mark", range = 520, radius = 120, duration = 10, arcDegrees = 60, buffMagnitude = 0.2, effects = { "ult_tracker_mark" }, audio = { "ult_tracker_mark" } }),
		step({ at = 1.0, kind = "Volley", count = 8, damageMultiplier = 3.0, range = 520, autoAim = true, effects = { "ult_tracker_shot" }, audio = { "ult_tracker_fire" } }),
	},
	ui = { accentColor = { 0.60, 0.90, 0.60 }, icon = "ult_tracker", chargingText = "SWEEP" },
	performance = { maxParticles = 120 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Marked weak points become visible through cover for the whole squad for the duration.",
})

U["ult_sentinel"] = ult({
	id = "ult_sentinel",
	weaponId = "dmr_sentinel",
	name = "Sentinel Protocol",
	tagline = "Deploy an autonomous sentry that fires in perfect sync with you.",
	cooldown = 48,
	chargeCost = 100,
	castTime = 0.55,
	targeting = "Point",
	range = 560,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.55, effects = { "ult_sentinel_deploy" }, audio = { "ult_sentinel_cast" } }),
		step({ at = 0.55, kind = "Summon", count = 1, duration = 14, damagePerTick = 95, tickInterval = 0.6, range = 560, effects = { "ult_sentinel_turret" }, audio = { "ult_sentinel_fire" } }),
		step({ at = 0.55, kind = "Buff", duration = 14, buff = "DamageOutput", buffMagnitude = 0.18, effects = { "ult_sentinel_link" }, audio = { "ult_sentinel_buff" } }),
	},
	ui = { accentColor = { 0.55, 0.80, 0.95 }, icon = "ult_sentinel", chargingText = "SENTINEL" },
	performance = { maxParticles = 120 },
	cancelRules = { interruptedByStun = false, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "The sentry is a server entity with a lifetime; it inherits the weapon's damage profile at 60%.",
})

U["ult_pathfinder"] = ult({
	id = "ult_pathfinder",
	weaponId = "dmr_pathfinder",
	name = "Tracer Storm",
	tagline = "Lay down burning tracer lanes that cut the battlefield into corridors.",
	cooldown = 45,
	chargeCost = 100,
	castTime = 0.45,
	targeting = "Direction",
	range = 500,
	requiresTarget = false,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.45, effects = { "ult_pathfinder_scan" }, audio = { "ult_pathfinder_cast" } }),
		step({ at = 0.45, kind = "Zone", duration = 9, radius = 18, range = 500, damagePerTick = 40, tickInterval = 0.3, effects = { "ult_pathfinder_line" }, audio = { "ult_pathfinder_loop" } }),
		step({ at = 0.45, kind = "Volley", count = 6, damageMultiplier = 2.6, range = 500, effects = { "ult_pathfinder_shot" }, audio = { "ult_pathfinder_fire" } }),
	},
	ui = { accentColor = { 0.55, 0.95, 0.85 }, icon = "ult_pathfinder", chargingText = "TRACER STORM" },
	performance = { maxParticles = 170 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Lanes are oriented volumes: entering one applies damage, leaving one stops it.",
})

U["ult_crosswind"] = ult({
	id = "ult_crosswind",
	weaponId = "dmr_crosswind",
	name = "Crosswind Cut",
	tagline = "Rounds that curve around cover and slice through weak points.",
	cooldown = 47,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Direction",
	range = 540,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_crosswind_wind" }, audio = { "ult_crosswind_cast" } }),
		step({ at = 0.5, kind = "Volley", count = 12, damageMultiplier = 2.8, range = 540, autoAim = true, effects = { "ult_crosswind_curve" }, audio = { "ult_crosswind_fire" } }),
		step({ at = 2.5, kind = "Wave", radius = 50, damageMultiplier = 2.0, effects = { "ult_crosswind_gust" }, audio = { "ult_crosswind_impact" } }),
	},
	ui = { accentColor = { 0.80, 0.95, 0.70 }, icon = "ult_crosswind", chargingText = "CROSSWIND" },
	performance = { maxParticles = 150 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Curving is a rendering flourish: hit validation still uses server-side target selection within a generous cone.",
})

-- ---------------------------------------------------------------------------
-- LIGHT MACHINE GUNS
-- ---------------------------------------------------------------------------
U["ult_atlas"] = ult({
	id = "ult_atlas",
	weaponId = "lmg_atlas",
	name = "Atlas Suppression",
	tagline = "Pin an area under continuous fire and lock beasts in place.",
	cooldown = 56,
	chargeCost = 100,
	castTime = 0.6,
	targeting = "Point",
	range = 340,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.6, effects = { "ult_atlas_brace" }, audio = { "ult_atlas_cast" } }),
		step({ at = 0.6, kind = "Zone", duration = 8, radius = 42, damagePerTick = 58, tickInterval = 0.25, statusEffect = Enums.StatusEffect.Slowed, statusDuration = 2, effects = { "ult_atlas_fire" }, audio = { "ult_atlas_loop" }, camera = "shake_light" }),
	},
	ui = { accentColor = { 0.70, 0.70, 0.75 }, icon = "ult_atlas", chargingText = "SUPPRESS" },
	performance = { maxParticles = 200 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Suppressed beasts have their accuracy and charge speed reduced by a configured amount.",
})

U["ult_siegebreaker"] = ult({
	id = "ult_siegebreaker",
	weaponId = "lmg_siegebreaker",
	name = "Siegebreaker Salvo",
	tagline = "A belt of high-explosive rounds walked across the target zone.",
	cooldown = 60,
	chargeCost = 100,
	castTime = 0.65,
	targeting = "Point",
	range = 360,
	requiresTarget = false,
	damageType = Enums.DamageType.Explosive,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.65, effects = { "ult_siegebreaker_load" }, audio = { "ult_siegebreaker_cast" } }),
		step({ at = 0.65, kind = "Volley", count = 16, damageMultiplier = 2.2, radius = 12, range = 360, effects = { "ult_siegebreaker_shell" }, audio = { "ult_siegebreaker_fire" }, camera = "shake_medium" }),
		step({ at = 3.4, kind = "Detonate", radius = 44, damageMultiplier = 3.6, effects = { "ult_siegebreaker_final" }, audio = { "ult_siegebreaker_impact" }, camera = "shake_heavy" }),
	},
	ui = { accentColor = { 0.95, 0.55, 0.25 }, icon = "ult_siegebreaker", chargingText = "SIEGE" },
	performance = { maxParticles = 220 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Splash damage is reduced against bosses by their area-damage resistance.",
})

U["ult_ironhide"] = ult({
	id = "ult_ironhide",
	weaponId = "lmg_ironhide",
	name = "Ironhide Bastion",
	tagline = "Mount the weapon, become immovable, and pour out unlimited fire.",
	cooldown = 62,
	chargeCost = 100,
	castTime = 0.7,
	targeting = "Self",
	range = 330,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.7, effects = { "ult_ironhide_mount" }, audio = { "ult_ironhide_cast" } }),
		step({ at = 0.7, kind = "Mount", duration = 10, effects = { "ult_ironhide_bastion" }, audio = { "ult_ironhide_buff" } }),
		step({ at = 0.7, kind = "Buff", duration = 10, buff = "DamageReduction", buffMagnitude = 0.4 }),
		step({ at = 0.9, kind = "Barrage", duration = 9, count = 200, damageMultiplier = 1.0, autoAim = true, range = 330, arcDegrees = 40, effects = { "ult_ironhide_fire" }, audio = { "ult_ironhide_loop" }, camera = "shake_light" }),
	},
	ui = { accentColor = { 0.75, 0.75, 0.80 }, icon = "ult_ironhide", chargingText = "BASTION" },
	performance = { maxParticles = 210 },
	cancelRules = { interruptedByStun = false, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Mounted state disables movement; the player can cancel early with the reload key.",
})

U["ult_drumfire"] = ult({
	id = "ult_drumfire",
	weaponId = "lmg_drumfire",
	name = "Drumfire Crescendo",
	tagline = "Spin up, scream louder, and finish with a wall of fire.",
	cooldown = 64,
	chargeCost = 100,
	castTime = 0.6,
	targeting = "Direction",
	range = 320,
	requiresTarget = false,
	damageType = Enums.DamageType.Fire,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.6, effects = { "ult_drumfire_spinup" }, audio = { "ult_drumfire_cast" } }),
		step({ at = 0.6, kind = "Barrage", duration = 5, count = 180, damageMultiplier = 0.85, autoAim = true, range = 320, arcDegrees = 36, effects = { "ult_drumfire_shot" }, audio = { "ult_drumfire_loop" }, camera = "shake_light" }),
		step({ at = 5.6, kind = "Wave", radius = 52, damageMultiplier = 4.0, statusEffect = Enums.StatusEffect.Burn, statusDuration = 6, effects = { "ult_drumfire_crescendo" }, audio = { "ult_drumfire_impact" }, screenEffect = "flash_orange", camera = "shake_heavy" }),
	},
	ui = { accentColor = { 1.0, 0.45, 0.20 }, icon = "ult_drumfire", chargingText = "CRESCENDO" },
	performance = { maxParticles = 220 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Fire rate ramps over the barrage; the crescendo always fires unless the caster dies before it starts.",
})

-- ---------------------------------------------------------------------------
-- PISTOLS
-- ---------------------------------------------------------------------------
U["ult_sidekick"] = ult({
	id = "ult_sidekick",
	weaponId = "pi_sidekick",
	name = "Quickdraw Fan",
	tagline = "Twelve shots, no wasted motion, all within arm's reach.",
	cooldown = 32,
	chargeCost = 100,
	castTime = 0.2,
	targeting = "Direction",
	range = 180,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.2, effects = { "ult_sidekick_draw" }, audio = { "ult_sidekick_cast" } }),
		step({ at = 0.2, kind = "Volley", count = 12, damageMultiplier = 2.4, range = 180, autoAim = true, arcDegrees = 70, effects = { "ult_sidekick_fan" }, audio = { "ult_sidekick_fire" } }),
	},
	ui = { accentColor = { 0.85, 0.85, 0.85 }, icon = "ult_sidekick", chargingText = "QUICKDRAW" },
	performance = { maxParticles = 100 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Fastest Ultimate in the roster; intentionally low total damage.",
})

U["ult_outlaw"] = ult({
	id = "ult_outlaw",
	weaponId = "pi_outlaw",
	name = "Outlaw's Reckoning",
	tagline = "One charged shot. Everything in front of you answers for it.",
	cooldown = 50,
	chargeCost = 100,
	castTime = 0.9,
	targeting = "Direction",
	range = 240,
	requiresTarget = false,
	damageType = Enums.DamageType.Physical,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.9, effects = { "ult_outlaw_charge" }, audio = { "ult_outlaw_cast" }, camera = "scope_in" }),
		step({ at = 0.9, kind = "Strike", damageMultiplier = 9.5, range = 240, radius = 6, pierce = true, effects = { "ult_outlaw_shot" }, audio = { "ult_outlaw_fire" }, screenEffect = "flash_white", camera = "shake_medium" }),
	},
	ui = { accentColor = { 0.95, 0.75, 0.35 }, icon = "ult_outlaw", chargingText = "RECKONING" },
	performance = { maxParticles = 110 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Missing the shot still consumes the Ultimate; that is the gamble.",
})

U["ult_quickdraw"] = ult({
	id = "ult_quickdraw",
	weaponId = "pi_quickdraw",
	name = "Snapfire Chain",
	tagline = "A chain of arcs that links every beast in the room together.",
	cooldown = 44,
	chargeCost = 100,
	castTime = 0.25,
	targeting = "Target",
	range = 200,
	requiresTarget = true,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.25, effects = { "ult_quickdraw_ready" }, audio = { "ult_quickdraw_cast" } }),
		step({ at = 0.25, kind = "Chain", count = 14, damageMultiplier = 1.9, range = 120, statusEffect = Enums.StatusEffect.Shock, statusDuration = 2, effects = { "ult_quickdraw_arc" }, audio = { "ult_quickdraw_chain" } }),
	},
	ui = { accentColor = { 0.55, 0.90, 1.0 }, icon = "ult_quickdraw", chargingText = "SNAP CHAIN" },
	performance = { maxParticles = 130 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Each jump loses 12% damage; the chain cannot revisit a target.",
})

U["ult_blackjack"] = ult({
	id = "ult_blackjack",
	weaponId = "pi_blackjack",
	name = "Double or Nothing",
	tagline = "Two phase rounds. If both find the same weak point, the house pays.",
	cooldown = 48,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Target",
	range = 220,
	requiresTarget = true,
	damageType = Enums.DamageType.Dark,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_blackjack_deal" }, audio = { "ult_blackjack_cast" } }),
		step({ at = 0.5, kind = "Strike", damageMultiplier = 4.5, range = 220, radius = 5, effects = { "ult_blackjack_shot1" }, audio = { "ult_blackjack_fire" } }),
		step({ at = 0.85, kind = "Strike", damageMultiplier = 4.5, range = 220, radius = 5, effects = { "ult_blackjack_shot2" }, audio = { "ult_blackjack_fire" } }),
		step({ at = 1.3, kind = "Detonate", radius = 24, damageMultiplier = 8.0, effects = { "ult_blackjack_payout" }, audio = { "ult_blackjack_impact" }, screenEffect = "flash_purple" }),
	},
	ui = { accentColor = { 0.45, 0.35, 0.75 }, icon = "ult_blackjack", chargingText = "DOUBLE OR NOTHING" },
	performance = { maxParticles = 140 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The payout detonation only triggers when both strikes hit the same weak point, decided on the server.",
})

-- ---------------------------------------------------------------------------
-- SPECIAL FIREARMS
-- ---------------------------------------------------------------------------
U["ult_arc9"] = ult({
	id = "ult_arc9",
	weaponId = "sp_arc9",
	name = "Arc Cascade",
	tagline = "A controlled energy beam that splits into cascading arcs.",
	cooldown = 55,
	chargeCost = 100,
	castTime = 0.6,
	targeting = "Direction",
	range = 420,
	requiresTarget = false,
	damageType = Enums.DamageType.Energy,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.6, effects = { "ult_arc9_charge" }, audio = { "ult_arc9_cast" } }),
		step({ at = 0.6, kind = "Beam", duration = 3.5, range = 420, radius = 9, damagePerTick = 120, tickInterval = 0.2, effects = { "ult_arc9_beam" }, audio = { "ult_arc9_beam_loop" }, camera = "shake_light" }),
		step({ at = 4.1, kind = "Chain", count = 10, damageMultiplier = 2.2, range = 160, effects = { "ult_arc9_cascade" }, audio = { "ult_arc9_cascade" } }),
	},
	ui = { accentColor = { 0.45, 0.85, 1.0 }, icon = "ult_arc9", chargingText = "ARC CASCADE" },
	performance = { maxParticles = 200 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "The beam ticks damage on everything inside the validated cylinder each tick.",
})

U["ult_howler"] = ult({
	id = "ult_howler",
	weaponId = "sp_howler",
	name = "Howling Wave",
	tagline = "A sonic wall that silences attacks and disables machines.",
	cooldown = 46,
	chargeCost = 100,
	castTime = 0.55,
	targeting = "Direction",
	range = 260,
	requiresTarget = false,
	damageType = Enums.DamageType.Sonic,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.55, effects = { "ult_howler_inhale" }, audio = { "ult_howler_cast" } }),
		step({ at = 0.55, kind = "Wave", radius = 60, range = 260, damageMultiplier = 3.8, statusEffect = Enums.StatusEffect.Stunned, statusDuration = 2, effects = { "ult_howler_wave" }, audio = { "ult_howler_impact" }, screenEffect = "distort_sonic", camera = "shake_medium" }),
		step({ at = 1.1, kind = "Zone", duration = 5, radius = 44, damagePerTick = 22, tickInterval = 0.4, statusEffect = Enums.StatusEffect.Weakened, statusDuration = 3, effects = { "ult_howler_field" }, audio = { "ult_howler_loop" } }),
	},
	ui = { accentColor = { 0.95, 0.95, 0.65 }, icon = "ult_howler", chargingText = "HOWL" },
	performance = { maxParticles = 170 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Machines and construct-type beasts lose their ability to use abilities for the stun duration.",
})

U["ult_sporeburst"] = ult({
	id = "ult_sporeburst",
	weaponId = "sp_sporeburst",
	name = "Sporebloom",
	tagline = "A blooming spore field that claims the ground for the hunter.",
	cooldown = 44,
	chargeCost = 100,
	castTime = 0.5,
	targeting = "Point",
	range = 220,
	requiresTarget = false,
	damageType = Enums.DamageType.Bio,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.5, effects = { "ult_sporeburst_pod" }, audio = { "ult_sporeburst_cast" } }),
		step({ at = 0.5, kind = "Zone", duration = 10, radius = 46, damagePerTick = 38, tickInterval = 0.5, statusEffect = Enums.StatusEffect.Corrosion, statusDuration = 5, effects = { "ult_sporeburst_bloom" }, audio = { "ult_sporeburst_loop" } }),
		step({ at = 0.5, kind = "Volley", count = 6, damageMultiplier = 2.0, radius = 14, range = 220, effects = { "ult_sporeburst_pod" }, audio = { "ult_sporeburst_burst" } }),
	},
	ui = { accentColor = { 0.55, 0.90, 0.45 }, icon = "ult_sporeburst", chargingText = "SPOREBLOOM" },
	performance = { maxParticles = 190 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = false },
	notes = "Blooms are capped per server; expired blooms always clean themselves up.",
})

U["ult_nullpoint"] = ult({
	id = "ult_nullpoint",
	weaponId = "sp_nullpoint",
	name = "Nullpoint Breach",
	tagline = "Tear the armour off an eligible beast and expose everything underneath.",
	cooldown = 58,
	chargeCost = 100,
	castTime = 0.85,
	targeting = "Target",
	range = 460,
	requiresTarget = true,
	damageType = Enums.DamageType.Void,
	steps = {
		step({ at = 0, kind = "Cast", duration = 0.85, effects = { "ult_nullpoint_charge" }, audio = { "ult_nullpoint_cast" }, camera = "scope_in" }),
		step({ at = 0.85, kind = "Strike", damageMultiplier = 5.0, range = 460, radius = 8, effects = { "ult_nullpoint_shot" }, audio = { "ult_nullpoint_fire" } }),
		step({ at = 1.1, kind = "Mark", range = 460, radius = 30, duration = 12, buffMagnitude = 0.5, effects = { "ult_nullpoint_breach" }, audio = { "ult_nullpoint_breach" } }),
		step({ at = 1.3, kind = "Detonate", radius = 26, damageMultiplier = 4.0, effects = { "ult_nullpoint_collapse" }, audio = { "ult_nullpoint_impact" }, screenEffect = "flash_void" }),
	},
	ui = { accentColor = { 0.55, 0.35, 0.95 }, icon = "ult_nullpoint", chargingText = "NULLPOINT" },
	performance = { maxParticles = 180 },
	cancelRules = { interruptedByStun = true, interruptedByDeath = true, cancelledOnSwitch = true },
	notes = "Removes the Armored defense state from eligible beasts for the configured duration. Bosses use their own explicit vulnerability rules instead.",
})

return U
