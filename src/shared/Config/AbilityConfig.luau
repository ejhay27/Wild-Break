--!strict
--[[
	AbilityConfig.luau
	The twelve regular combat abilities and the four-slot framework.

	Regular abilities are separate from weapon Ultimates, tactical gadgets,
	movement skills and companion abilities.

	Ranks (C..X) describe an ability's classification. Tiers (1..5) describe
	its progression inside that classification: an A-Rank Tier 3 ability is
	still A-Rank, it has simply progressed. Tiers scale magnitude, cooldown
	and occasionally add a secondary effect; they never change the rank.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Registry = require(script.Parent.Registry)

export type AbilityEffect = {
	kind: string,
	magnitude: number?,
	radius: number?,
	range: number?,
	duration: number?,
	statusEffect: string?,
	damageMultiplier: number?,
	flatDamage: number?,
	damageType: string?,
	tickInterval: number?,
	targetKind: string?,
	metadata: { [string]: any }?,
}

export type TierDef = {
	cooldown: number,
	focusCost: number,
	magnitudeScale: number,
	durationScale: number,
	extra: string?,
}

export type AbilityDef = {
	id: string,
	displayName: string,
	rank: string,
	minTier: number,
	maxTier: number,
	baseRank: string,
	description: string,
	targetKind: string,
	range: number,
	duration: number,
	effects: { AbilityEffect },
	tiers: { [number]: TierDef },
	unlock: { kind: string, value: any },
	evolution: { id: string, name: string, requirement: string }?,
	audio: { [string]: string },
	vfx: { [string]: string },
	inputHint: { pc: string, mobile: string },
	bossInteraction: string?,
	performanceCost: number,
}

local function ability(def: AbilityDef): AbilityDef
	return def
end

-- Tier helper: builds the standard five tier progression.
local function tiers(cooldown1: number, cost1: number, magnitude1: number, duration1: number, extras: { string? }?): { [number]: TierDef }
	local result: { [number]: TierDef } = {}
	for tier = 1, 5 do
		local decay = (tier - 1) * 0.12
		result[tier] = {
			cooldown = math.max(3, math.floor(cooldown1 * (1 - decay) * 10) / 10),
			focusCost = math.max(0, math.floor(cost1 * (1 - decay * 0.5))),
			magnitudeScale = magnitude1 + (tier - 1) * 0.18,
			durationScale = duration1 + (tier - 1) * 0.12,
			extra = extras and extras[tier] or nil,
		}
	end
	return result
end

local entries: { [string]: AbilityDef } = {
	["aegis_field"] = ability({
		id = "aegis_field",
		displayName = "Aegis Field",
		rank = "A",
		minTier = 1,
		maxTier = 5,
		baseRank = "A",
		description = "Creates a temporary protective barrier that absorbs damage for everyone inside it.",
		targetKind = Enums.AbilityTargetKind.Point,
		range = 90,
		duration = 8,
		effects = {
			{
				kind = "Barrier", magnitude = 420, radius = 26, duration = 8,
				metadata = { absorbsDamage = true, appliesToAllies = true },
			},
		},
		tiers = tiers(34, 30, 1.0, 1.0, { nil, nil, "Grants a small shield refresh on expiry.", nil, "Allies inside also gain 10% damage reduction." }),
		unlock = { kind = "Level", value = 2 },
		evolution = { id = "aegis_field_prime", name = "Aegis Field: Bulwark Protocol", requirement = "Complete the Overgrowth Biolab operation." },
		audio = { cast = "ability_aegis_cast", active = "ability_aegis_loop", expire = "ability_aegis_expire", impact = "ability_aegis_hit" },
		vfx = { cast = "fx_aegis_cast", barrier = "fx_aegis_barrier", shatter = "fx_aegis_break" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Absorbs one telegraphed boss slam before breaking.",
		performanceCost = 2,
	}),
	["volt_surge"] = ability({
		id = "volt_surge",
		displayName = "Volt Surge",
		rank = "B",
		minTier = 1,
		maxTier = 5,
		baseRank = "B",
		description = "Releases an electrical disruption pulse that shocks and interrupts eligible targets.",
		targetKind = Enums.AbilityTargetKind.Self,
		range = 60,
		duration = 0,
		effects = {
			{
				kind = "DamagePulse", flatDamage = 180, radius = 30, damageType = Enums.DamageType.Energy,
				statusEffect = Enums.StatusEffect.Shock, duration = 2.5,
			},
			{ kind = "Interrupt", radius = 30, magnitude = 45 },
		},
		tiers = tiers(26, 25, 1.0, 1.0, { nil, nil, "Chains to three additional targets.", nil, "Shocked targets take 15% more damage." }),
		unlock = { kind = "Level", value = 3 },
		evolution = { id = "volt_surge_stormcall", name = "Volt Surge: Stormcall", requirement = "Harvest a Resonance Core from an elite beast." },
		audio = { cast = "ability_volt_cast", impact = "ability_volt_impact" },
		vfx = { cast = "fx_volt_cast", pulse = "fx_volt_pulse" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Contributes interrupt buildup; cannot cancel a phase transition.",
		performanceCost = 2,
	}),
	["hunters_mark"] = ability({
		id = "hunters_mark",
		displayName = "Hunter's Mark",
		rank = "A",
		minTier = 1,
		maxTier = 5,
		baseRank = "A",
		description = "Marks an eligible target, tracks it through terrain and reveals its weak points.",
		targetKind = Enums.AbilityTargetKind.Target,
		range = 320,
		duration = 20,
		effects = {
			{ kind = "Mark", duration = 20, magnitude = 0.25, metadata = { revealWeakPoints = true, trackThroughTerrain = true } },
		},
		tiers = tiers(20, 15, 1.0, 1.0, { nil, nil, "Marked targets take 12% more critical damage.", nil, "Mark spreads to one nearby target on kill." }),
		unlock = { kind = "Level", value = 1 },
		evolution = { id = "hunters_mark_alpha", name = "Hunter's Mark: Alpha Designation", requirement = "Defeat Thornmaw once." },
		audio = { cast = "ability_mark_cast", impact = "ability_mark_apply", expire = "ability_mark_expire" },
		vfx = { cast = "fx_mark_cast", mark = "fx_mark_target" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Reveals boss weak points during vulnerability windows only.",
		performanceCost = 1,
	}),
	["quakebreaker"] = ability({
		id = "quakebreaker",
		displayName = "Quakebreaker",
		rank = "S",
		minTier = 1,
		maxTier = 5,
		baseRank = "S",
		description = "A forward shockwave that interrupts eligible enemies and opens them up.",
		targetKind = Enums.AbilityTargetKind.Point,
		range = 140,
		duration = 0,
		effects = {
			{ kind = "Shockwave", flatDamage = 260, range = 140, radius = 40, damageType = Enums.DamageType.Physical },
			{ kind = "Interrupt", radius = 40, magnitude = 80 },
			{ kind = "ApplyStatus", statusEffect = Enums.StatusEffect.Weakened, duration = 5, magnitude = 0.2 },
		},
		tiers = tiers(38, 35, 1.0, 1.0, { nil, nil, "Widens the wave to a 60 degree cone.", nil, "Interrupted targets are stunned for 1.5 seconds." }),
		unlock = { kind = "Mission", value = "act1_first_outbreak" },
		evolution = { id = "quakebreaker_tectonic", name = "Quakebreaker: Tectonic", requirement = "Reach Research rank 8." },
		audio = { cast = "ability_quake_cast", impact = "ability_quake_impact" },
		vfx = { cast = "fx_quake_cast", wave = "fx_quake_wave" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Interrupts channeled boss attacks that are flagged interruptible.",
		performanceCost = 3,
	}),
	["bioflow"] = ability({
		id = "bioflow",
		displayName = "Bioflow",
		rank = "B",
		minTier = 1,
		maxTier = 5,
		baseRank = "B",
		description = "Accelerated regeneration that heals the hunter and nearby allies over time.",
		targetKind = Enums.AbilityTargetKind.Aura,
		range = 40,
		duration = 10,
		effects = {
			{ kind = "Regeneration", magnitude = 14, duration = 10, radius = 40, tickInterval = 1, metadata = { appliesToAllies = true } },
		},
		tiers = tiers(30, 25, 1.0, 1.0, { nil, nil, "Cleanses one damage-over-time effect on cast.", nil, "Allies also gain 8% movement speed." }),
		unlock = { kind = "Level", value = 4 },
		evolution = { id = "bioflow_bloom", name = "Bioflow: Bloom", requirement = "Discover five Verdant Reach landmarks." },
		audio = { cast = "ability_bioflow_cast", active = "ability_bioflow_loop", expire = "ability_bioflow_expire" },
		vfx = { cast = "fx_bioflow_cast", aura = "fx_bioflow_aura" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "No special interaction. Healing is capped during boss vulnerability windows.",
		performanceCost = 1,
	}),
	["grav_snare"] = ability({
		id = "grav_snare",
		displayName = "Grav Snare",
		rank = "A",
		minTier = 1,
		maxTier = 5,
		baseRank = "A",
		description = "A localized gravity field that slows, then roots, everything caught inside it.",
		targetKind = Enums.AbilityTargetKind.Point,
		range = 120,
		duration = 8,
		effects = {
			{ kind = "Zone", radius = 30, duration = 8, statusEffect = Enums.StatusEffect.Slowed, magnitude = 0.45, tickInterval = 0.5, flatDamage = 12, damageType = Enums.DamageType.Energy },
		},
		tiers = tiers(32, 30, 1.0, 1.0, { nil, nil, "Roots targets that remain for 3 seconds.", nil, "Pulls flying beasts toward the ground." }),
		unlock = { kind = "Level", value = 6 },
		evolution = { id = "grav_snare_singularity", name = "Grav Snare: Singularity", requirement = "Recover a Gravity Core from Null Horizon." },
		audio = { cast = "ability_grav_cast", active = "ability_grav_loop", expire = "ability_grav_expire" },
		vfx = { cast = "fx_grav_cast", field = "fx_grav_field" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Bosses gain diminishing resistance to repeated root applications.",
		performanceCost = 2,
	}),
	["phantom_echo"] = ability({
		id = "phantom_echo",
		displayName = "Phantom Echo",
		rank = "A",
		minTier = 1,
		maxTier = 5,
		baseRank = "A",
		description = "Creates a decoy that draws beast aggression and briefly confuses opponents.",
		targetKind = Enums.AbilityTargetKind.Point,
		range = 80,
		duration = 12,
		effects = {
			{ kind = "Decoy", duration = 12, radius = 0, magnitude = 1, metadata = { tauntsAI = true, confusesPlayers = 1.5 } },
			{ kind = "SelfBuff", duration = 6, magnitude = 0.15, metadata = { buff = "DamageReduction" } },
		},
		tiers = tiers(28, 25, 1.0, 1.0, { nil, nil, "Creates two decoys.", nil, "Decoy detonates for area damage when destroyed." }),
		unlock = { kind = "Exploration", value = "umbra_cache_01" },
		evolution = { id = "phantom_echo_legion", name = "Phantom Echo: Legion", requirement = "Defeat Noctyra." },
		audio = { cast = "ability_phantom_cast", active = "ability_phantom_loop", expire = "ability_phantom_expire" },
		vfx = { cast = "fx_phantom_cast", decoy = "fx_phantom_decoy" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Decoys cannot taunt bosses; they only distract adds.",
		performanceCost = 2,
	}),
	["kinetic_overdrive"] = ability({
		id = "kinetic_overdrive",
		displayName = "Kinetic Overdrive",
		rank = "S",
		minTier = 1,
		maxTier = 5,
		baseRank = "S",
		description = "Temporarily enhances close-range combat: melee damage, attack speed and stagger.",
		targetKind = Enums.AbilityTargetKind.Self,
		range = 0,
		duration = 12,
		effects = {
			{ kind = "SelfBuff", duration = 12, magnitude = 0.45, metadata = { buff = "MeleeDamage" } },
			{ kind = "SelfBuff", duration = 12, magnitude = 0.3, metadata = { buff = "AttackSpeed" } },
			{ kind = "SelfBuff", duration = 12, magnitude = 0.5, metadata = { buff = "StaggerPower" } },
		},
		tiers = tiers(36, 30, 1.0, 1.0, { nil, nil, "Grants 15% lifesteal on melee hits.", nil, "Melee kills extend the duration by 2 seconds." }),
		unlock = { kind = "Level", value = 10 },
		evolution = { id = "kinetic_overdrive_limitless", name = "Kinetic Overdrive: Limitless", requirement = "Complete a Rootfall Sapheart run." },
		audio = { cast = "ability_kinetic_cast", active = "ability_kinetic_loop", expire = "ability_kinetic_expire" },
		vfx = { cast = "fx_kinetic_cast", aura = "fx_kinetic_aura" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Stronger stagger contribution during vulnerability windows.",
		performanceCost = 1,
	}),
	["corebreaker"] = ability({
		id = "corebreaker",
		displayName = "Corebreaker",
		rank = "S",
		minTier = 1,
		maxTier = 5,
		baseRank = "S",
		description = "Exposes a temporary weak point on an eligible beast.",
		targetKind = Enums.AbilityTargetKind.Target,
		range = 200,
		duration = 10,
		effects = {
			{ kind = "ExposeWeakPoint", duration = 10, magnitude = 0.5, metadata = { revealsWeakPoint = true, onlyEligibleBeasts = true } },
			{ kind = "ApplyStatus", statusEffect = Enums.StatusEffect.Weakened, duration = 10, magnitude = 0.25 },
		},
		tiers = tiers(34, 30, 1.0, 1.0, { nil, nil, "Exposed weak points take 20% additional damage.", nil, "Killing an exposed beast refunds half the cooldown." }),
		unlock = { kind = "Mission", value = "act2_research_trail" },
		evolution = { id = "corebreaker_apex", name = "Corebreaker: Apex Fracture", requirement = "Install an Apex Core into any weapon." },
		audio = { cast = "ability_corebreaker_cast", impact = "ability_corebreaker_impact" },
		vfx = { cast = "fx_corebreaker_cast", weakpoint = "fx_corebreaker_point" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Bosses are only affected during declared vulnerability windows.",
		performanceCost = 2,
	}),
	["cyclone_guard"] = ability({
		id = "cyclone_guard",
		displayName = "Cyclone Guard",
		rank = "A",
		minTier = 1,
		maxTier = 5,
		baseRank = "A",
		description = "A spinning vortex that destroys or deflects eligible projectiles around the hunter.",
		targetKind = Enums.AbilityTargetKind.Aura,
		range = 30,
		duration = 8,
		effects = {
			{ kind = "ProjectileShield", radius = 30, duration = 8, magnitude = 1, metadata = { blocksProjectiles = true, deflectChance = 0.5 } },
		},
		tiers = tiers(30, 25, 1.0, 1.0, { nil, nil, "Deflected projectiles damage the attacker.", nil, "Allies inside the vortex gain 12% ranged damage reduction." }),
		unlock = { kind = "Level", value = 12 },
		evolution = { id = "cyclone_guard_tempest", name = "Cyclone Guard: Tempest", requirement = "Survive a Cinderfall eruption event." },
		audio = { cast = "ability_cyclone_cast", active = "ability_cyclone_loop", expire = "ability_cyclone_expire" },
		vfx = { cast = "fx_cyclone_cast", field = "fx_cyclone_field" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Does not block boss melee attacks; only declared projectile attacks.",
		performanceCost = 3,
	}),
	["apex_rupture"] = ability({
		id = "apex_rupture",
		displayName = "Apex Rupture",
		rank = "SS",
		minTier = 1,
		maxTier = 5,
		baseRank = "SS",
		description = "A high-impact strike with a meaningful cooldown and resource cost.",
		targetKind = Enums.AbilityTargetKind.Point,
		range = 100,
		duration = 0,
		effects = {
			{ kind = "Strike", flatDamage = 900, radius = 22, range = 100, damageType = Enums.DamageType.Physical },
			{ kind = "ApplyStatus", statusEffect = Enums.StatusEffect.Stunned, duration = 1.5 },
		},
		tiers = tiers(60, 45, 1.0, 1.0, { nil, nil, "Deals double damage to shields.", nil, "Leaves a ruptured zone that deals damage for 4 seconds." }),
		unlock = { kind = "Boss", value = "thornmaw" },
		evolution = { id = "apex_rupture_cataclysm", name = "Apex Rupture: Cataclysm", requirement = "Defeat three different world bosses." },
		audio = { cast = "ability_apex_cast", impact = "ability_apex_impact" },
		vfx = { cast = "fx_apex_cast", impact = "fx_apex_impact" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "Damage is reduced against bosses with the area-damage resistance flag.",
		performanceCost = 3,
	}),
	["wildbreak_protocol"] = ability({
		id = "wildbreak_protocol",
		displayName = "Wildbreak Protocol",
		rank = "SS",
		minTier = 1,
		maxTier = 5,
		baseRank = "SS",
		description = "A short coordinated combat benefit for the whole squad: damage, speed and cooldown recovery.",
		targetKind = Enums.AbilityTargetKind.Aura,
		range = 60,
		duration = 10,
		effects = {
			{ kind = "TeamBuff", duration = 10, radius = 60, magnitude = 0.2, metadata = { buff = "DamageOutput" } },
			{ kind = "TeamBuff", duration = 10, radius = 60, magnitude = 0.2, metadata = { buff = "MovementSpeed" } },
			{ kind = "TeamBuff", duration = 10, radius = 60, magnitude = 0.25, metadata = { buff = "CooldownRecovery" } },
		},
		tiers = tiers(75, 40, 1.0, 1.0, { nil, nil, "Also grants 10% damage reduction.", nil, "Allies gain a small Ultimate charge bonus." }),
		unlock = { kind = "Campaign", value = "act2_complete" },
		evolution = { id = "wildbreak_protocol_zero", name = "Wildbreak Protocol: Zero", requirement = "Defeat seven world bosses." },
		audio = { cast = "ability_wildbreak_cast", active = "ability_wildbreak_loop", expire = "ability_wildbreak_expire" },
		vfx = { cast = "fx_wildbreak_cast", aura = "fx_wildbreak_aura" },
		inputHint = { pc = "Q", mobile = "Ability 1" },
		bossInteraction = "This is a tactical support ability, not a second Ultimate. It never replaces a weapon Ultimate.",
		performanceCost = 2,
	}),
}

local Ability = Registry.new("Ability", entries, { "id", "displayName", "rank" })

function Ability.Tier(abilityId: string, tier: number): TierDef?
	local def = Ability:Get(abilityId)
	if not def then
		return nil
	end
	return def.tiers[math.clamp(math.floor(tier), 1, 5)]
end

function Ability.Cooldown(abilityId: string, tier: number): number
	local tierDef = Ability.Tier(abilityId, tier)
	return tierDef and tierDef.cooldown or 30
end

function Ability.FocusCost(abilityId: string, tier: number): number
	local tierDef = Ability.Tier(abilityId, tier)
	return tierDef and tierDef.focusCost or 0
end

function Ability.ScaleEffects(abilityId: string, tier: number): { AbilityEffect }
	local def = Ability:Get(abilityId)
	if not def then
		return {}
	end
	local tierDef = Ability.Tier(abilityId, tier) or (def.tiers[1] :: TierDef)
	local out = {}
	for _, effect in def.effects do
		local scaled = table.clone(effect)
		if scaled.magnitude then
			scaled.magnitude *= tierDef.magnitudeScale
		end
		if scaled.flatDamage then
			scaled.flatDamage *= tierDef.magnitudeScale
		end
		if scaled.duration then
			scaled.duration *= tierDef.durationScale
		end
		table.insert(out, scaled)
	end
	return out
end

function Ability.MaxTier(abilityId: string): number
	local def = Ability:Get(abilityId)
	return def and def.maxTier or 1
end

function Ability.ValidateAll(): { string }
	local problems = Registry.Validate(Ability)
	if Ability:Count() ~= 12 then
		table.insert(problems, string.format("[Ability] expected 12 abilities, found %d", Ability:Count()))
	end
	for _, def in Ability:List() do
		if not Enums.IsValidRank(def.rank) then
			table.insert(problems, string.format("[Ability] %s has invalid rank %q", def.id, tostring(def.rank)))
		end
		for tier = 1, 5 do
			if not def.tiers[tier] then
				table.insert(problems, string.format("[Ability] %s is missing tier %d", def.id, tier))
			end
		end
		if #def.effects == 0 then
			table.insert(problems, string.format("[Ability] %s has no effects", def.id))
		end
	end
	return problems
end

Ability.Registry = Ability
return Ability
