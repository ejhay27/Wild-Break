--!strict
--[[
	StatusEffects.luau
	Buffs, debuffs and damage-over-time effects.

	Pure logic with an injected clock so the server (and the tests) control
	time instead of calling os.clock() or waiting on Roblox signals.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Status = {}

export type StatusEffectDef = {
	id: string,
	displayName: string,
	kind: string, -- Buff | Debuff | DamageOverTime
	stacking: string, -- Refresh | Stack | Independent
	maxStacks: number,
	defaultDuration: number,
	damagePerSecond: number?,
	damageType: string?,
	-- Stat modifiers applied while the effect is active.
	modifiers: { [string]: number }?,
	tickSeconds: number?,
	-- Control loss effects are resisted by bosses.
	crowdControl: boolean,
	description: string,
}

local function effect(
	id: string,
	displayName: string,
	kind: string,
	stacking: string,
	maxStacks: number,
	duration: number,
	crowdControl: boolean,
	description: string,
	extra: { [string]: any }?
): StatusEffectDef
	local def: StatusEffectDef = {
		id = id,
		displayName = displayName,
		kind = kind,
		stacking = stacking,
		maxStacks = maxStacks,
		defaultDuration = duration,
		damagePerSecond = nil,
		damageType = nil,
		modifiers = nil,
		tickSeconds = nil,
		crowdControl = crowdControl,
		description = description,
	}
	if extra then
		for key, value in extra do
			(def :: any)[key] = value
		end
	end
	return def
end

local entries: { [string]: StatusEffectDef } = {
	[Enums.StatusEffect.Burn] = effect("Burn", "Burning", "DamageOverTime", "Refresh", 3, 4, false, "Fire damage over time.", {
		damagePerSecond = 8,
		damageType = Enums.DamageType.Fire,
		tickSeconds = 0.5,
	}),
	[Enums.StatusEffect.Chill] = effect("Chill", "Chilled", "Debuff", "Refresh", 1, 5, false, "Slowed movement and reload.", {
		modifiers = { moveSpeed = -0.25, reloadSpeed = -0.2 },
	}),
	[Enums.StatusEffect.Shock] = effect("Shock", "Shocked", "Debuff", "Refresh", 1, 2, true, "Briefly interrupts actions.", {
		modifiers = { moveSpeed = -0.6 },
	}),
	[Enums.StatusEffect.Corrosion] = effect("Corrosion", "Corroded", "DamageOverTime", "Stack", 5, 6, false, "Armour-shredding damage over time.", {
		damagePerSecond = 5,
		damageType = Enums.DamageType.Bio,
		tickSeconds = 0.5,
		modifiers = { armor = -0.08 },
	}),
	[Enums.StatusEffect.Marked] = effect("Marked", "Marked", "Debuff", "Refresh", 1, 8, false, "Takes extra damage from all sources.", {
		modifiers = { incomingDamage = 0.15 },
	}),
	[Enums.StatusEffect.Slowed] = effect("Slowed", "Slowed", "Debuff", "Refresh", 3, 3, false, "Reduced movement speed.", {
		modifiers = { moveSpeed = -0.15 },
	}),
	[Enums.StatusEffect.Rooted] = effect("Rooted", "Rooted", "Debuff", "Refresh", 1, 2.5, true, "Cannot move.", {
		modifiers = { moveSpeed = -1 },
	}),
	[Enums.StatusEffect.Stunned] = effect("Stunned", "Stunned", "Debuff", "Refresh", 1, 1.5, true, "Cannot act.", {
		modifiers = { moveSpeed = -1, actionSpeed = -1 },
	}),
	[Enums.StatusEffect.Staggered] = effect("Staggered", "Staggered", "Debuff", "Refresh", 1, 1.2, true, "Interrupts the current action.", {
		modifiers = { actionSpeed = -0.5 },
	}),
	[Enums.StatusEffect.Weakened] = effect("Weakened", "Weakened", "Debuff", "Refresh", 2, 6, false, "Deals less damage.", {
		modifiers = { outgoingDamage = -0.2 },
	}),
	[Enums.StatusEffect.Shielded] = effect("Shielded", "Shielded", "Buff", "Refresh", 1, 8, false, "Absorbs incoming damage.", {
		modifiers = { shield = 150 },
	}),
	[Enums.StatusEffect.Regeneration] = effect("Regeneration", "Regenerating", "Buff", "Refresh", 3, 10, false, "Restores health over time.", {
		modifiers = { healthPerSecond = 6 },
		tickSeconds = 0.5,
	}),
	[Enums.StatusEffect.Hastened] = effect("Hastened", "Hastened", "Buff", "Refresh", 2, 8, false, "Faster movement and actions.", {
		modifiers = { moveSpeed = 0.2, actionSpeed = 0.15 },
	}),
	[Enums.StatusEffect.VoidInstability] = effect("VoidInstability", "Void Instability", "DamageOverTime", "Stack", 4, 5, false, "Unstable void damage that worsens with stacks.", {
		damagePerSecond = 6,
		damageType = Enums.DamageType.Void,
		tickSeconds = 0.5,
	}),
	[Enums.StatusEffect.Heatstroke] = effect("Heatstroke", "Heatstroke", "DamageOverTime", "Stack", 3, 12, false, "Suffered in extreme heat without protection.", {
		damagePerSecond = 3,
		damageType = Enums.DamageType.Fire,
		tickSeconds = 1,
		modifiers = { staminaRegen = -0.4 },
	}),
	[Enums.StatusEffect.Frostbite] = effect("Frostbite", "Frostbite", "DamageOverTime", "Stack", 3, 12, false, "Suffered in extreme cold without protection.", {
		damagePerSecond = 3,
		damageType = Enums.DamageType.Ice,
		tickSeconds = 1,
		modifiers = { staminaRegen = -0.4, reloadSpeed = -0.25 },
	}),
	[Enums.StatusEffect.Contamination] = effect("Contamination", "Contaminated", "DamageOverTime", "Stack", 4, 10, false, "Toxic contamination.", {
		damagePerSecond = 4,
		damageType = Enums.DamageType.Bio,
		tickSeconds = 1,
	}),
	[Enums.StatusEffect.Irradiated] = effect("Irradiated", "Irradiated", "DamageOverTime", "Refresh", 2, 15, false, "Radiation sickness.", {
		damagePerSecond = 2.5,
		damageType = Enums.DamageType.Energy,
		tickSeconds = 1,
	}),
	[Enums.StatusEffect.Drenched] = effect("Drenched", "Drenched", "Debuff", "Refresh", 1, 10, false, "Wet: extinguishes burning and conducts shock.", {
		modifiers = { fireResistance = 0.4, shockResistance = -0.4 },
	}),
}

function Status.Get(id: string): StatusEffectDef?
	return entries[id]
end

function Status.List(): { StatusEffectDef }
	local out = {}
	for _, def in entries do
		table.insert(out, def)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

export type ActiveEffect = {
	id: string,
	stacks: number,
	expiresAt: number,
	nextTickAt: number?,
	magnitude: number,
	sourceId: string?,
}

export type EffectState = {
	active: { ActiveEffect },
}

function Status.New(): EffectState
	return { active = {} }
end

local function find(effectState: EffectState, id: string): ActiveEffect?
	for _, entry in effectState.active do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Applies an effect. Bosses resist crowd control through
-- `crowdControlResistance` (0..1).
function Status.Apply(effectState: EffectState, id: string, now: number, options: {
	duration: number?,
	magnitude: number?,
	sourceId: string?,
	crowdControlResistance: number?,
}?): boolean
	local def = entries[id]
	if not def then
		return false
	end
	local options_ = options or {}
	local duration = options_.duration or def.defaultDuration
	if def.crowdControl then
		local resistance = math.clamp(options_.crowdControlResistance or 0, 0, 1)
		if resistance >= 1 then
			return false
		end
		duration *= 1 - resistance
	end
	if duration <= 0 then
		return false
	end

	local existing = find(effectState, id)
	if existing then
		if def.stacking == "Refresh" then
			existing.expiresAt = math.max(existing.expiresAt, now + duration)
			existing.magnitude = math.max(existing.magnitude, options_.magnitude or 1)
			return true
		elseif def.stacking == "Stack" then
			existing.stacks = math.min(def.maxStacks, existing.stacks + 1)
			existing.expiresAt = math.max(existing.expiresAt, now + duration)
			return true
		end
		-- Independent: fall through and add a new instance.
	end

	if #effectState.active >= Limits.Combat.MaxStatusEffectsPerTarget then
		-- Drop the effect closest to expiring rather than refusing silently.
		local weakestIndex, weakestTime = 1, math.huge
		for index, entry in effectState.active do
			if entry.expiresAt < weakestTime then
				weakestIndex, weakestTime = index, entry.expiresAt
			end
		end
		table.remove(effectState.active, weakestIndex)
	end

	table.insert(effectState.active, {
		id = id,
		stacks = 1,
		expiresAt = now + duration,
		nextTickAt = def.tickSeconds and (now + def.tickSeconds) or nil,
		magnitude = options_.magnitude or 1,
		sourceId = options_.sourceId,
	})
	return true
end

function Status.Has(effectState: EffectState, id: string): boolean
	return find(effectState, id) ~= nil
end

function Status.StacksOf(effectState: EffectState, id: string): number
	local entry = find(effectState, id)
	return entry and entry.stacks or 0
end

function Status.Remove(effectState: EffectState, id: string): boolean
	for index, entry in effectState.active do
		if entry.id == id then
			table.remove(effectState.active, index)
			return true
		end
	end
	return false
end

-- Sums every modifier of a given stat across all active effects.
function Status.Modifier(effectState: EffectState, stat: string, now: number?): number
	local total = 0
	for _, entry in effectState.active do
		if now and entry.expiresAt <= now then
			continue
		end
		local def = entries[entry.id]
		if def and def.modifiers and def.modifiers[stat] then
			total += def.modifiers[stat] * entry.magnitude * (def.stacking == "Stack" and entry.stacks or 1)
		end
	end
	return total
end

-- Advances the clock. Returns the damage to apply this tick and the ids that
-- expired, so the caller applies damage through DamagePipeline rather than
-- mutating health here.
function Status.Tick(effectState: EffectState, now: number): { damage: { { id: string, damageType: string, amount: number } }, expired: { string } }
	local damage = {}
	local expired = {}
	local index = 1
	while index <= #effectState.active do
		local entry = effectState.active[index]
		if entry.expiresAt <= now then
			table.insert(expired, entry.id)
			table.remove(effectState.active, index)
			continue
		end
		local def = entries[entry.id]
		if def and def.damagePerSecond and def.tickSeconds then
			if not entry.nextTickAt then
				entry.nextTickAt = now + def.tickSeconds
			elseif now >= entry.nextTickAt then
				local stacks = def.stacking == "Stack" and entry.stacks or 1
				table.insert(damage, {
					id = entry.id,
					damageType = def.damageType or Enums.DamageType.True,
					amount = def.damagePerSecond * def.tickSeconds * entry.magnitude * stacks,
				})
				entry.nextTickAt = now + def.tickSeconds
			end
		end
		index += 1
	end
	return { damage = damage, expired = expired }
end

function Status.ValidateAll(): { string }
	local problems = {}
	for _, def in Status.List() do
		if def.maxStacks < 1 then
			table.insert(problems, string.format("[Status] %s needs at least one stack", def.id))
		end
		if def.defaultDuration <= 0 then
			table.insert(problems, string.format("[Status] %s needs a positive duration", def.id))
		end
		if def.kind == "DamageOverTime" and not (def.damagePerSecond and def.damagePerSecond > 0) then
			table.insert(problems, string.format("[Status] damage over time %s has no damage", def.id))
		end
		if def.tickSeconds and def.tickSeconds <= 0 then
			table.insert(problems, string.format("[Status] %s has an invalid tick rate", def.id))
		end
		if def.stacking ~= "Refresh" and def.stacking ~= "Stack" and def.stacking ~= "Independent" then
			table.insert(problems, string.format("[Status] %s has an unknown stacking rule", def.id))
		end
	end

	local state = Status.New()
	Status.Apply(state, Enums.StatusEffect.Burn, 0)
	if Status.StacksOf(state, Enums.StatusEffect.Burn) ~= 1 then
		table.insert(problems, "[Status] applying an effect did not register")
	end
	Status.Apply(state, Enums.StatusEffect.Burn, 1)
	if Status.StacksOf(state, Enums.StatusEffect.Burn) ~= 1 then
		table.insert(problems, "[Status] a refresh effect stacked instead of refreshing")
	end
	local first = state.active[1]
	if not first or first.expiresAt < 4 then
		table.insert(problems, "[Status] refreshing did not extend the duration")
	end

	local stacked = Status.New()
	Status.Apply(stacked, Enums.StatusEffect.Corrosion, 0)
	Status.Apply(stacked, Enums.StatusEffect.Corrosion, 0)
	if Status.StacksOf(stacked, Enums.StatusEffect.Corrosion) ~= 2 then
		table.insert(problems, "[Status] a stacking effect did not stack")
	end
	for _ = 1, 20 do
		Status.Apply(stacked, Enums.StatusEffect.Corrosion, 0)
	end
	if Status.StacksOf(stacked, Enums.StatusEffect.Corrosion) > entries[Enums.StatusEffect.Corrosion].maxStacks then
		table.insert(problems, "[Status] a stacking effect exceeded its stack cap")
	end

	-- Damage over time ticks.
	local dot = Status.New()
	Status.Apply(dot, Enums.StatusEffect.Burn, 0)
	local before = Status.Tick(dot, 0.4)
	if #before.damage ~= 0 then
		table.insert(problems, "[Status] damage over time ticked too early")
	end
	local after = Status.Tick(dot, 0.6)
	if #after.damage ~= 1 then
		table.insert(problems, "[Status] damage over time did not tick")
	elseif after.damage[1].amount <= 0 then
		table.insert(problems, "[Status] damage over time dealt no damage")
	end
	local expiry = Status.Tick(dot, 100)
	if #expiry.expired ~= 1 then
		table.insert(problems, "[Status] effects do not expire")
	end

	-- Crowd control resistance.
	local boss = Status.New()
	if Status.Apply(boss, Enums.StatusEffect.Stunned, 0, { crowdControlResistance = 1 }) then
		table.insert(problems, "[Status] full crowd control resistance was ignored")
	end
	if not Status.Apply(boss, Enums.StatusEffect.Stunned, 0, { crowdControlResistance = 0.5 }) then
		table.insert(problems, "[Status] partial crowd control resistance rejected the effect entirely")
	end

	-- Modifier aggregation.
	local buffs = Status.New()
	Status.Apply(buffs, Enums.StatusEffect.Hastened, 0)
	if Status.Modifier(buffs, "moveSpeed", 0) <= 0 then
		table.insert(problems, "[Status] buff modifiers are not aggregated")
	end

	-- Effect cap.
	local capped = Status.New()
	for _ = 1, Limits.Combat.MaxStatusEffectsPerTarget + 20 do
		Status.Apply(capped, Enums.StatusEffect.Burn, 0)
		Status.Apply(capped, Enums.StatusEffect.Chill, 0)
	end
	if #capped.active > Limits.Combat.MaxStatusEffectsPerTarget then
		table.insert(problems, "[Status] the active effect cap was exceeded")
	end

	return problems
end

return Status
