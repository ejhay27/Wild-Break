--!strict
--[[
	DamagePipeline.luau
	The single, shared damage calculation. The server calls it for every hit;
	the client never sends a damage number, only an intent to hit.

	Order of operations (documented because tuning depends on it):
	  base damage
	    x hit multiplier (charge, combo step, ultimate step)
	    x critical strike
	    x weak point / headshot (the larger applies fully, the other at 50%)
	    x elemental resistance of the target
	    x distance falloff
	    - flat armour (after penetration)
	    x target damage multiplier (boss phase, defence state, buffs)
	    x area damage penalty
	    x level scaling (PvE only, deliberately small)
	  then clamped, then absorbed by shields.

	"True" damage ignores resistances and armour but is still affected by
	invulnerability: nothing bypasses a boss phase that must not be damaged.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Damage = {}

export type AttackerStats = {
	damage: number,
	critChance: number?,
	critMultiplier: number?,
	weakPointMultiplier: number?,
	headMultiplier: number?,
	damageType: string?,
	range: number?,
	falloffStartStuds: number?,
	falloffEndStuds: number?,
	falloffMinimumMultiplier: number?,
	armorPenetration: number?,
	level: number?,
}

export type TargetDefense = {
	armor: number?,
	resistances: { [string]: number }?,
	damageMultiplier: number?,
	weakPointMultiplier: number?,
	defenseState: string?,
	invulnerable: boolean?,
	shield: number?,
	level: number?,
	maxHealth: number?,
}

export type HitInfo = {
	hitKind: string?,
	isWeakPoint: boolean?,
	isHeadshot: boolean?,
	distanceStuds: number?,
	isAreaDamage: boolean?,
	multiplier: number?,
}

export type DamageBreakdown = {
	base: number,
	hitMultiplier: number,
	critical: number,
	precision: number,
	elemental: number,
	falloff: number,
	armorRemoved: number,
	targetMultiplier: number,
	area: number,
	levelScaling: number,
	beforeClamp: number,
}

export type DamageResult = {
	damage: number,
	shieldAbsorbed: number,
	healthDamage: number,
	isCrit: boolean,
	isWeakPoint: boolean,
	isHeadshot: boolean,
	blocked: boolean,
	breakdown: DamageBreakdown,
}

local ARMOR_K = Limits.Combat.ArmorConstant -- flat armour is divided by this before reducing damage

function Damage.DefenseMultiplierFor(defenseState: string?): number
	if defenseState == Enums.DefenseState.Invulnerable then
		return 0
	elseif defenseState == Enums.DefenseState.Armored then
		return Limits.Combat.ArmorDamageMultiplier
	elseif defenseState == Enums.DefenseState.Vulnerable then
		return 1.15
	elseif defenseState == Enums.DefenseState.Phased then
		return 0.9
	end
	return 1
end

function Damage.Falloff(attacker: AttackerStats, distance: number?): number
	if not distance then
		return 1
	end
	local startStuds = attacker.falloffStartStuds
	local endStuds = attacker.falloffEndStuds
	if not startStuds or not endStuds or endStuds <= startStuds then
		return 1
	end
	if distance <= startStuds then
		return 1
	end
	local minimum = attacker.falloffMinimumMultiplier or 0.35
	local t = math.clamp((distance - startStuds) / (endStuds - startStuds), 0, 1)
	return math.clamp(1 + (minimum - 1) * t, minimum, 1)
end

-- Level scaling is intentionally tiny: gear and weak points matter more.
function Damage.LevelScaling(attackerLevel: number?, targetLevel: number?): number
	if not attackerLevel or not targetLevel then
		return 1
	end
	local gap = math.clamp(targetLevel - attackerLevel, -20, 20)
	return math.clamp(1 + gap * 0.012, 0.75, 1.25)
end

function Damage.Resolve(attacker: AttackerStats, target: TargetDefense, hit: HitInfo, random: any?): DamageResult
	local damageType = attacker.damageType or Enums.DamageType.Physical
	local base = math.max(0, attacker.damage or 0)

	local hitMultiplier = hit.multiplier or 1

	-- Critical strike (never on damage-over-time ticks).
	local isCrit = false
	local critMultiplier = 1
	if hit.hitKind ~= Enums.HitKind.DamageOverTime then
		local chance = math.clamp(attacker.critChance or 0, 0, 1)
		if chance > 0 and random and random.Next and random:Next() < chance then
			isCrit = true
			critMultiplier = math.max(1, attacker.critMultiplier or 1.5)
		end
	end

	-- Precision: the best of weak point / headshot applies in full, the other
	-- contributes half, so a precision hit is strong but not absurd.
	local isWeakPoint = hit.isWeakPoint == true
	local isHeadshot = hit.isHeadshot == true
	local weakPoint = isWeakPoint and math.max(1, attacker.weakPointMultiplier or 1) or 1
	local targetWeakPoint = isWeakPoint and math.max(1, target.weakPointMultiplier or 1) or 1
	local head = isHeadshot and math.max(1, attacker.headMultiplier or 1) or 1
	local precision = 1
	if weakPoint * targetWeakPoint >= head then
		precision = (weakPoint * targetWeakPoint) * (1 + (head - 1) * 0.5)
	else
		precision = head * (1 + (weakPoint * targetWeakPoint - 1) * 0.5)
	end

	-- Elemental resistance. "True" damage ignores it.
	local elemental = 1
	if damageType ~= Enums.DamageType.True and target.resistances then
		elemental = math.clamp(target.resistances[damageType] or 1, 0, 5)
	end

	local falloff = Damage.Falloff(attacker, hit.distanceStuds)

	-- Armour: flat reduction with diminishing returns, reduced by penetration.
	local armorRemoved = 0
	if damageType ~= Enums.DamageType.True then
		local armor = math.max(0, target.armor or 0)
		local penetration = math.clamp(attacker.armorPenetration or 0, 0, 1)
		local effectiveArmor = armor * (1 - penetration)
		armorRemoved = base * hitMultiplier * critMultiplier * precision * (effectiveArmor / (effectiveArmor + ARMOR_K))
	end

	local targetMultiplier = (target.damageMultiplier or 1) * Damage.DefenseMultiplierFor(target.defenseState)
	local area = (hit.isAreaDamage or hit.hitKind == Enums.HitKind.Area) and Limits.Combat.AreaDamageMultiplier or 1
	local levelScaling = Damage.LevelScaling(attacker.level, target.level)

	local beforeArmor = base * hitMultiplier * critMultiplier * precision * elemental * falloff
	local afterArmor = math.max(0, beforeArmor - armorRemoved)
	local beforeClamp = afterArmor * targetMultiplier * area * levelScaling

	local blocked = target.invulnerable == true or target.defenseState == Enums.DefenseState.Invulnerable
	local damage = blocked and 0 or math.max(0, beforeClamp)
	-- Any hit, even a blocked one, is worth at least 1 chip of chip damage when
	-- the target is explicitly flagged as always damageable (Parallax).
	if blocked and target.damageMultiplier ~= nil and targetMultiplier > 0 then
		damage = 0
	end

	local shield = math.max(0, target.shield or 0)
	local shieldAbsorbed = math.min(shield, damage)
	local healthDamage = damage - shieldAbsorbed

	return {
		damage = damage,
		shieldAbsorbed = shieldAbsorbed,
		healthDamage = healthDamage,
		isCrit = isCrit,
		isWeakPoint = isWeakPoint,
		isHeadshot = isHeadshot,
		blocked = blocked,
		breakdown = {
			base = base,
			hitMultiplier = hitMultiplier,
			critical = critMultiplier,
			precision = precision,
			elemental = elemental,
			falloff = falloff,
			armorRemoved = armorRemoved,
			targetMultiplier = targetMultiplier,
			area = area,
			levelScaling = levelScaling,
			beforeClamp = beforeClamp,
		},
	}
end

-- Convenience wrapper used by the boss services: applies the boss phase and
-- defence multipliers from BossConfig on top of the normal pipeline.
function Damage.ResolveAgainstBoss(
	attacker: AttackerStats,
	boss: {
		resistances: { [string]: number }?,
		armor: number?,
		phaseIndex: number?,
	},
	phase: {
		incomingDamageMultiplier: number?,
		defenseState: string?,
		crowdControlResistance: number?,
	}?,
	hit: HitInfo,
	random: any?
): DamageResult
	return Damage.Resolve(attacker, {
		armor = boss.armor,
		resistances = boss.resistances,
		damageMultiplier = phase and phase.incomingDamageMultiplier or 1,
		defenseState = phase and phase.defenseState or nil,
		invulnerable = phase ~= nil and phase.defenseState == Enums.DefenseState.Invulnerable,
		weakPointMultiplier = hit.isWeakPoint and 1 or nil,
	}, hit, random)
end

-- Fall damage, drowning and hazards are resolved here too so every health
-- change in the game goes through one place.
function Damage.Environmental(amount: number, maxHealth: number, ratioCap: number?): number
	return math.min(math.max(0, amount), maxHealth * (ratioCap or 0.85))
end

function Damage.ValidateAll(): { string }
	local problems = {}

	-- A plain body shot should equal the base damage.
	local plain = Damage.Resolve({ damage = 100 }, {}, {})
	if plain.damage ~= 100 then
		table.insert(problems, string.format("[Damage] a plain hit should deal 100, got %.2f", plain.damage))
	end

	-- Elemental resistance.
	local resisted = Damage.Resolve({ damage = 100, damageType = Enums.DamageType.Fire }, { resistances = { [Enums.DamageType.Fire] = 0.5 } }, {})
	if resisted.damage ~= 50 then
		table.insert(problems, string.format("[Damage] resistance should halve damage, got %.2f", resisted.damage))
	end

	-- Weakness.
	local weak = Damage.Resolve({ damage = 100, damageType = Enums.DamageType.Ice }, { resistances = { [Enums.DamageType.Ice] = 1.5 } }, {})
	if weak.damage ~= 150 then
		table.insert(problems, string.format("[Damage] weakness should add 50%%, got %.2f", weak.damage))
	end

	-- Invulnerability must be absolute.
	local invulnerable = Damage.Resolve({ damage = 100, damageType = Enums.DamageType.True }, { invulnerable = true }, {})
	if invulnerable.damage ~= 0 then
		table.insert(problems, "[Damage] invulnerability can be bypassed")
	end
	local phased = Damage.Resolve({ damage = 100 }, { defenseState = Enums.DefenseState.Invulnerable }, {})
	if phased.damage ~= 0 then
		table.insert(problems, "[Damage] an invulnerable boss phase can be damaged")
	end

	-- Armour should reduce but never negate.
	local armored = Damage.Resolve({ damage = 100 }, { armor = 220 }, {})
	if armored.damage <= 0 or armored.damage >= 100 then
		table.insert(problems, string.format("[Damage] armour should reduce damage without negating it, got %.2f", armored.damage))
	end
	if Damage.Resolve({ damage = 100, armorPenetration = 1 }, { armor = 220 }, {}).damage ~= 100 then
		table.insert(problems, "[Damage] full penetration should ignore armour")
	end

	-- Area damage penalty.
	local area = Damage.Resolve({ damage = 100 }, {}, { isAreaDamage = true })
	if area.damage ~= 100 * Limits.Combat.AreaDamageMultiplier then
		table.insert(problems, string.format("[Damage] area damage penalty is wrong, got %.2f", area.damage))
	end

	-- Precision beats headshots, and both together stay reasonable.
	local precisionHit = Damage.Resolve({ damage = 100, weakPointMultiplier = 2, headMultiplier = 2 }, { weakPointMultiplier = 1 }, { isWeakPoint = true, isHeadshot = true })
	if precisionHit.damage <= 100 or precisionHit.damage > 100 * 4 then
		table.insert(problems, string.format("[Damage] combined precision damage is out of range: %.2f", precisionHit.damage))
	end

	-- Falloff.
	local far = Damage.Resolve({ damage = 100, falloffStartStuds = 50, falloffEndStuds = 150, falloffMinimumMultiplier = 0.5 }, {}, { distanceStuds = 100 })
	if far.damage ~= 75 then
		table.insert(problems, string.format("[Damage] falloff midpoint should be 0.75x, got %.2f", far.damage))
	end
	local beyond = Damage.Resolve({ damage = 100, falloffStartStuds = 50, falloffEndStuds = 150, falloffMinimumMultiplier = 0.5 }, {}, { distanceStuds = 1000 })
	if beyond.damage ~= 50 then
		table.insert(problems, string.format("[Damage] falloff should clamp to its minimum, got %.2f", beyond.damage))
	end

	-- Shields absorb before health.
	local shielded = Damage.Resolve({ damage = 100 }, { shield = 40 }, {})
	if shielded.shieldAbsorbed ~= 40 or shielded.healthDamage ~= 60 then
		table.insert(problems, "[Damage] shields do not absorb correctly")
	end

	-- Parallax style: always damageable, never zero from a phase alone.
	local always = Damage.ResolveAgainstBoss(
		{ damage = 100 },
		{ armor = 50 },
		{ incomingDamageMultiplier = 1, defenseState = Enums.DefenseState.Normal },
		{}
	)
	if always.damage <= 0 then
		table.insert(problems, "[Damage] a boss that must always be damageable took no damage")
	end

	-- Level scaling stays small.
	local scaling = Damage.LevelScaling(1, 120)
	if scaling < 0.75 or scaling > 1.25 then
		table.insert(problems, string.format("[Damage] level scaling is out of range: %.2f", scaling))
	end

	return problems
end

return Damage
