--!strict
--[[
	MeleeData.luau
	The ten WILDBREAK melee weapons.

	Every weapon has a distinct combat identity expressed through its combo
	timings, hit windows, recovery, reach, stagger/interrupt power and special
	rule. None of them are a generic sword: the framework supports fast combo
	weapons, heavy stagger weapons, precision counters, defensive parry tools,
	beast-oriented bleeds, gravity control and spatial anomalies.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)

export type ComboStep = {
	index: number,
	name: string,
	damageMultiplier: number,
	reach: number,
	-- Hit window opens at `windup` seconds and stays open for `window`.
	windup: number,
	window: number,
	recovery: number,
	staggerPower: number,
	interruptPower: number,
	hitbox: string, -- "Arc" | "Thrust" | "Slam" | "Spin" | "Wave"
	arcDegrees: number?,
	movement: number?, -- forward lunge studs
	statusEffect: string?,
}

export type MeleeDef = {
	id: string,
	displayName: string,
	kind: string,
	class: string,
	rarity: string,
	baseDamage: number,
	combo: { ComboStep },
	reach: number,
	mobility: number,
	damageType: string,
	weakPointMultiplier: number,
	canBlock: boolean,
	canParry: boolean,
	parryWindow: number,
	blockReduction: number,
	heavyAttackIndex: number?,
	special: string,
	attachmentSlots: { string },
	coreCompatibility: { string },
	unlockLevel: number,
	identity: string,
	description: string,
}

local function step(def: ComboStep): ComboStep
	return def
end

local function melee(def: MeleeDef): MeleeDef
	def.kind = Enums.WeaponKind.Melee
	def.class = "Melee"
	return def
end

local entries: { [string]: MeleeDef } = {
	["me_riftblade"] = melee({
		id = "me_riftblade",
		displayName = "Riftblade",
		rarity = Enums.Rarity.Rare,
		baseDamage = 62,
		combo = {
			step({
				index = 1, name = "Rift Slash", damageMultiplier = 1.0, reach = 8, windup = 0.14, window = 0.16, recovery = 0.24,
				staggerPower = 12, interruptPower = 6, hitbox = "Arc", arcDegrees = 110, movement = 3,
			}),
			step({
				index = 2, name = "Twin Cut", damageMultiplier = 1.05, reach = 8, windup = 0.12, window = 0.15, recovery = 0.22,
				staggerPower = 12, interruptPower = 6, hitbox = "Arc", arcDegrees = 130, movement = 3,
			}),
			step({
				index = 3, name = "Rift Lunge", damageMultiplier = 1.45, reach = 11, windup = 0.2, window = 0.18, recovery = 0.36,
				staggerPower = 24, interruptPower = 14, hitbox = "Thrust", movement = 8, statusEffect = Enums.StatusEffect.Marked,
			}),
		},
		reach = 8,
		mobility = 1.06,
		damageType = Enums.DamageType.Energy,
		weakPointMultiplier = 1.8,
		canBlock = true,
		canParry = true,
		parryWindow = 0.22,
		blockReduction = 0.45,
		heavyAttackIndex = 3,
		special = "Perfect parry opens a rift: the next hit deals 60% bonus damage and ignores armor.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild", "Resonance" },
		unlockLevel = 4,
		identity = "Fast combo weapon",
		description = "Light energy blade. Builds speed, ends with a lunging rift thrust.",
	}),
	["me_breaker"] = melee({
		id = "me_breaker",
		displayName = "Breaker",
		rarity = Enums.Rarity.Common,
		baseDamage = 96,
		combo = {
			step({
				index = 1, name = "Overhead", damageMultiplier = 1.0, reach = 9, windup = 0.32, window = 0.2, recovery = 0.5,
				staggerPower = 45, interruptPower = 26, hitbox = "Slam", movement = 2,
			}),
			step({
				index = 2, name = "Follow Slam", damageMultiplier = 1.2, reach = 9, windup = 0.3, window = 0.2, recovery = 0.55,
				staggerPower = 55, interruptPower = 32, hitbox = "Slam", movement = 2,
			}),
			step({
				index = 3, name = "Earthbreaker", damageMultiplier = 1.9, reach = 12, windup = 0.55, window = 0.24, recovery = 0.8,
				staggerPower = 90, interruptPower = 60, hitbox = "Slam", movement = 1, statusEffect = Enums.StatusEffect.Stunned,
			}),
		},
		reach = 9,
		mobility = 0.88,
		damageType = Enums.DamageType.Physical,
		weakPointMultiplier = 1.4,
		canBlock = true,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0.6,
		heavyAttackIndex = 3,
		special = "Slam attacks break shields 3x faster and stun beasts below 25% health.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild" },
		unlockLevel = 1,
		identity = "Heavy stagger weapon",
		description = "Industrial wrecking maul. Slow, immense, and excellent at interrupting.",
	}),
	["me_talonstrike"] = melee({
		id = "me_talonstrike",
		displayName = "Talonstrike",
		rarity = Enums.Rarity.Epic,
		baseDamage = 70,
		combo = {
			step({
				index = 1, name = "Talon Jab", damageMultiplier = 0.9, reach = 7, windup = 0.1, window = 0.14, recovery = 0.2,
				staggerPower = 10, interruptPower = 8, hitbox = "Thrust", movement = 2,
			}),
			step({
				index = 2, name = "Feather Cut", damageMultiplier = 0.95, reach = 7, windup = 0.1, window = 0.14, recovery = 0.2,
				staggerPower = 10, interruptPower = 8, hitbox = "Arc", arcDegrees = 90, movement = 2,
			}),
			step({
				index = 3, name = "Counter Rake", damageMultiplier = 1.6, reach = 8, windup = 0.12, window = 0.2, recovery = 0.3,
				staggerPower = 20, interruptPower = 18, hitbox = "Arc", arcDegrees = 140, movement = 4,
			}),
		},
		reach = 7,
		mobility = 1.1,
		damageType = Enums.DamageType.Physical,
		weakPointMultiplier = 2.4,
		canBlock = true,
		canParry = true,
		parryWindow = 0.28,
		blockReduction = 0.35,
		heavyAttackIndex = 3,
		special = "Counterattack: damage dealt within 1 second of a successful parry is doubled and counts as a weak-point hit.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild", "Resonance", "Apex" },
		unlockLevel = 14,
		identity = "Precision counterattack weapon",
		description = "Beast-talon gauntlets. Punishes telegraphed attacks harder than any firearm.",
	}),
	["me_shockmaul"] = melee({
		id = "me_shockmaul",
		displayName = "Shockmaul",
		rarity = Enums.Rarity.Epic,
		baseDamage = 78,
		combo = {
			step({
				index = 1, name = "Arc Swing", damageMultiplier = 1.0, reach = 9, windup = 0.22, window = 0.18, recovery = 0.38,
				staggerPower = 30, interruptPower = 22, hitbox = "Arc", arcDegrees = 150, movement = 2, statusEffect = Enums.StatusEffect.Shock,
			}),
			step({
				index = 2, name = "Ground Charge", damageMultiplier = 1.3, reach = 13, windup = 0.34, window = 0.2, recovery = 0.5,
				staggerPower = 48, interruptPower = 34, hitbox = "Slam", movement = 5, statusEffect = Enums.StatusEffect.Shock,
			}),
			step({
				index = 3, name = "Discharge", damageMultiplier = 1.75, reach = 12, windup = 0.42, window = 0.22, recovery = 0.62,
				staggerPower = 70, interruptPower = 55, hitbox = "Wave", arcDegrees = 200, statusEffect = Enums.StatusEffect.Stunned,
			}),
		},
		reach = 9,
		mobility = 0.94,
		damageType = Enums.DamageType.Energy,
		weakPointMultiplier = 1.5,
		canBlock = true,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0.5,
		heavyAttackIndex = 3,
		special = "Shock chains to two nearby targets for 50% damage and disables machines briefly.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Resonance", "Apex" },
		unlockLevel = 17,
		identity = "Electrical disruption weapon",
		description = "Capacitor maul. Every swing discharges into the pack around you.",
	}),
	["me_ironfang"] = melee({
		id = "me_ironfang",
		displayName = "Ironfang",
		rarity = Enums.Rarity.Rare,
		baseDamage = 66,
		combo = {
			step({
				index = 1, name = "Bite", damageMultiplier = 1.0, reach = 7, windup = 0.16, window = 0.16, recovery = 0.26,
				staggerPower = 16, interruptPower = 10, hitbox = "Thrust", movement = 3, statusEffect = Enums.StatusEffect.Corrosion,
			}),
			step({
				index = 2, name = "Rend", damageMultiplier = 1.15, reach = 8, windup = 0.15, window = 0.16, recovery = 0.28,
				staggerPower = 18, interruptPower = 12, hitbox = "Arc", arcDegrees = 120, movement = 3, statusEffect = Enums.StatusEffect.Corrosion,
			}),
			step({
				index = 3, name = "Savage Spin", damageMultiplier = 1.5, reach = 9, windup = 0.28, window = 0.26, recovery = 0.44,
				staggerPower = 32, interruptPower = 20, hitbox = "Spin", arcDegrees = 360, movement = 4, statusEffect = Enums.StatusEffect.Corrosion,
			}),
		},
		reach = 7,
		mobility = 1.04,
		damageType = Enums.DamageType.Bio,
		weakPointMultiplier = 1.7,
		canBlock = false,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0,
		heavyAttackIndex = 3,
		special = "Beast-oriented: deals 30% bonus damage to beasts and harvests 1 extra material on kill.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild", "Apex" },
		unlockLevel = 8,
		identity = "Beast-oriented bleed weapon",
		description = "Forged from an apex predator's jaw. Tears, corrodes and harvests.",
	}),
	["me_aegis_edge"] = melee({
		id = "me_aegis_edge",
		displayName = "Aegis Edge",
		rarity = Enums.Rarity.Legendary,
		baseDamage = 60,
		combo = {
			step({
				index = 1, name = "Guard Cut", damageMultiplier = 0.95, reach = 8, windup = 0.16, window = 0.16, recovery = 0.24,
				staggerPower = 18, interruptPower = 12, hitbox = "Arc", arcDegrees = 100, movement = 1,
			}),
			step({
				index = 2, name = "Shield Bash", damageMultiplier = 1.2, reach = 6, windup = 0.2, window = 0.18, recovery = 0.34,
				staggerPower = 60, interruptPower = 40, hitbox = "Slam", movement = 4, statusEffect = Enums.StatusEffect.Stunned,
			}),
			step({
				index = 3, name = "Bulwark Sweep", damageMultiplier = 1.4, reach = 10, windup = 0.3, window = 0.22, recovery = 0.5,
				staggerPower = 45, interruptPower = 30, hitbox = "Arc", arcDegrees = 180, movement = 2,
			}),
		},
		reach = 8,
		mobility = 0.9,
		damageType = Enums.DamageType.Physical,
		weakPointMultiplier = 1.3,
		canBlock = true,
		canParry = true,
		parryWindow = 0.3,
		blockReduction = 0.75,
		heavyAttackIndex = 2,
		special = "Blocking for 1 second grants a 4 second Shielded state absorbing up to 250 damage for you and nearby allies.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild", "Apex" },
		unlockLevel = 26,
		identity = "Defensive weapon",
		description = "Riot-grade blade and shield. Holds a corridor for a whole squad.",
	}),
	["me_wildclaw"] = melee({
		id = "me_wildclaw",
		displayName = "Wildclaw",
		rarity = Enums.Rarity.Common,
		baseDamage = 38,
		combo = {
			step({
				index = 1, name = "Claw Rake", damageMultiplier = 1.0, reach = 6, windup = 0.08, window = 0.12, recovery = 0.16,
				staggerPower = 8, interruptPower = 5, hitbox = "Arc", arcDegrees = 100, movement = 2,
			}),
			step({
				index = 2, name = "Double Slash", damageMultiplier = 1.0, reach = 6, windup = 0.08, window = 0.12, recovery = 0.16,
				staggerPower = 8, interruptPower = 5, hitbox = "Arc", arcDegrees = 110, movement = 2,
			}),
			step({
				index = 3, name = "Frenzy", damageMultiplier = 1.1, reach = 6, windup = 0.08, window = 0.12, recovery = 0.18,
				staggerPower = 10, interruptPower = 6, hitbox = "Arc", arcDegrees = 120, movement = 3,
			}),
			step({
				index = 4, name = "Pounce", damageMultiplier = 1.5, reach = 10, windup = 0.18, window = 0.2, recovery = 0.32,
				staggerPower = 26, interruptPower = 16, hitbox = "Thrust", movement = 9,
			}),
		},
		reach = 6,
		mobility = 1.14,
		damageType = Enums.DamageType.Physical,
		weakPointMultiplier = 1.9,
		canBlock = false,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0,
		heavyAttackIndex = 4,
		special = "Attack speed increases 6% per consecutive hit, up to 40%, resetting after 2 seconds without a hit.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Wild" },
		unlockLevel = 2,
		identity = "Fast multi-hit weapon",
		description = "Improvised beast-claw gloves. Weak per hit, relentless in combination.",
	}),
	["me_pulse_baton"] = melee({
		id = "me_pulse_baton",
		displayName = "Pulse Baton",
		rarity = Enums.Rarity.Rare,
		baseDamage = 54,
		combo = {
			step({
				index = 1, name = "Jab", damageMultiplier = 1.0, reach = 7, windup = 0.12, window = 0.14, recovery = 0.22,
				staggerPower = 22, interruptPower = 26, hitbox = "Thrust", movement = 2, statusEffect = Enums.StatusEffect.Shock,
			}),
			step({
				index = 2, name = "Reverse Strike", damageMultiplier = 1.05, reach = 7, windup = 0.12, window = 0.14, recovery = 0.24,
				staggerPower = 24, interruptPower = 28, hitbox = "Arc", arcDegrees = 100, movement = 2, statusEffect = Enums.StatusEffect.Shock,
			}),
			step({
				index = 3, name = "Pulse Burst", damageMultiplier = 1.5, reach = 11, windup = 0.3, window = 0.2, recovery = 0.46,
				staggerPower = 60, interruptPower = 70, hitbox = "Wave", arcDegrees = 180, statusEffect = Enums.StatusEffect.Stunned,
			}),
		},
		reach = 7,
		mobility = 1.05,
		damageType = Enums.DamageType.Energy,
		weakPointMultiplier = 1.4,
		canBlock = true,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0.4,
		heavyAttackIndex = 3,
		special = "Interrupts eligible beast and machine casts. Interrupted targets take 25% more damage for 4 seconds.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Resonance" },
		unlockLevel = 11,
		identity = "Disruption / interrupt weapon",
		description = "Security baton. Cancels attack windups and opens punishment windows.",
	}),
	["me_gravhammer"] = melee({
		id = "me_gravhammer",
		displayName = "Gravhammer",
		rarity = Enums.Rarity.Legendary,
		baseDamage = 104,
		combo = {
			step({
				index = 1, name = "Gravity Lift", damageMultiplier = 1.0, reach = 10, windup = 0.36, window = 0.2, recovery = 0.52,
				staggerPower = 50, interruptPower = 30, hitbox = "Slam", movement = 1, statusEffect = Enums.StatusEffect.Slowed,
			}),
			step({
				index = 2, name = "Collapse Slam", damageMultiplier = 1.55, reach = 12, windup = 0.48, window = 0.24, recovery = 0.7,
				staggerPower = 80, interruptPower = 48, hitbox = "Slam", movement = 3, statusEffect = Enums.StatusEffect.Rooted,
			}),
			step({
				index = 3, name = "Singularity Drop", damageMultiplier = 2.2, reach = 16, windup = 0.7, window = 0.3, recovery = 0.95,
				staggerPower = 120, interruptPower = 80, hitbox = "Wave", arcDegrees = 360, statusEffect = Enums.StatusEffect.Rooted,
			}),
		},
		reach = 10,
		mobility = 0.82,
		damageType = Enums.DamageType.Physical,
		weakPointMultiplier = 1.35,
		canBlock = true,
		canParry = false,
		parryWindow = 0,
		blockReduction = 0.65,
		heavyAttackIndex = 3,
		special = "Creates a 3 second gravity well that pulls beasts inward and makes their weak points easier to hit.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Apex", "Anomaly" },
		unlockLevel = 33,
		identity = "Gravity control weapon",
		description = "Mass-driver hammer. Bends the battlefield toward its impact point.",
	}),
	["me_voidreaper"] = melee({
		id = "me_voidreaper",
		displayName = "Voidreaper",
		rarity = Enums.Rarity.Mythical,
		baseDamage = 88,
		combo = {
			step({
				index = 1, name = "Null Cut", damageMultiplier = 1.0, reach = 9, windup = 0.18, window = 0.16, recovery = 0.3,
				staggerPower = 28, interruptPower = 20, hitbox = "Arc", arcDegrees = 130, movement = 3, statusEffect = Enums.StatusEffect.VoidInstability,
			}),
			step({
				index = 2, name = "Rift Step", damageMultiplier = 1.2, reach = 9, windup = 0.16, window = 0.16, recovery = 0.3,
				staggerPower = 30, interruptPower = 22, hitbox = "Arc", arcDegrees = 150, movement = 6, statusEffect = Enums.StatusEffect.VoidInstability,
			}),
			step({
				index = 3, name = "Unmake", damageMultiplier = 2.0, reach = 13, windup = 0.5, window = 0.26, recovery = 0.72,
				staggerPower = 90, interruptPower = 65, hitbox = "Wave", arcDegrees = 240, statusEffect = Enums.StatusEffect.VoidInstability,
			}),
		},
		reach = 9,
		mobility = 1.0,
		damageType = Enums.DamageType.Void,
		weakPointMultiplier = 2.0,
		canBlock = true,
		canParry = true,
		parryWindow = 0.2,
		blockReduction = 0.4,
		heavyAttackIndex = 3,
		special = "Unmake ignores 50% of armor and applies Void Instability, which detonates for 120 damage when the target dies.",
		attachmentSlots = { "Module" },
		coreCompatibility = { "Anomaly" },
		unlockLevel = 44,
		identity = "Spatial anomaly weapon",
		description = "A blade that removes space between the swing and the wound.",
	}),
}

return entries
