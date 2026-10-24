--!strict
--[[
	BossConfig.luau
	Public boss registry and the shared encounter maths.

	The registry merges the world bosses (BossData) with the dungeon bosses
	and the Rootfall guardian (DungeonBossData). All phase resolution,
	shield arithmetic and safeguard handling is done here so that no boss
	script ever recomputes the same rule differently.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)
local WorldBosses = require(script.Parent.BossData)
local DungeonBosses = require(script.Parent.DungeonBossData)

local entries: { [string]: any } = {}
for id, def in WorldBosses do
	entries[id] = def
end
for id, def in DungeonBosses do
	entries[id] = def
end

local Boss = Registry.new("Boss", entries, { "id", "displayName", "kind" })

function Boss.WorldBosses(): { any }
	return Boss:Filter(function(def)
		return def.kind == Enums.BossKind.WorldBoss
	end)
end

function Boss.DungeonBosses(): { any }
	return Boss:Filter(function(def)
		return def.kind == Enums.BossKind.DungeonBoss
	end)
end

function Boss.WorldDungeonBosses(): { any }
	return Boss:Filter(function(def)
		return def.kind == Enums.BossKind.WorldDungeonBoss
	end)
end

function Boss.ByRegion(regionId: string): { any }
	return Boss:Filter(function(def)
		return def.regionId == regionId
	end)
end

-- Returns the phase index that should be active for a given health fraction.
-- Phases are ordered from highest threshold to lowest; the last matching
-- threshold wins. A threshold of -1 means "only entered explicitly"
-- (used by the Pyr axis final form).
-- The regional world boss, if the region has one.
function Boss.WorldBossForRegion(regionId: string): any?
	for _, def in Boss:List() do
		if def.kind == Enums.BossKind.WorldBoss and def.regionId == regionId then
			return def
		end
	end
	return nil
end

function Boss.PhaseIndexForHealth(bossId: string, healthFraction: number): number
	local def = Boss:Get(bossId)
	if not def then
		return 1
	end
	local best = 1
	for _, phase in def.phases do
		if healthFraction <= phase.healthThreshold or phase.healthThreshold < 0 then
			-- Do not auto-enter explicit-only phases.
			if phase.healthThreshold >= 0 and phase.index > best then
				best = phase.index
			end
		end
	end
	return best
end

function Boss.Phase(bossId: string, phaseIndex: number): any?
	local def = Boss:Get(bossId)
	if not def then
		return nil
	end
	for _, phase in def.phases do
		if phase.index == phaseIndex then
			return phase
		end
	end
	return nil
end

function Boss.PhaseCount(bossId: string): number
	local def = Boss:Get(bossId)
	return def and #def.phases or 0
end

-- Effective damage multiplier for a hit, including phase resistance,
-- elemental resistance and defense state rules.
function Boss.DamageMultiplier(bossId: string, phaseIndex: number, damageType: string, isAreaDamage: boolean): number
	local def = Boss:Get(bossId)
	if not def then
		return 1
	end
	local phase = Boss.Phase(bossId, phaseIndex)
	local multiplier = phase and phase.incomingDamageMultiplier or 1

	if phase and phase.defenseState == Enums.DefenseState.Invulnerable then
		return 0
	elseif phase and phase.defenseState == Enums.DefenseState.Armored then
		multiplier *= Limits.Combat.ArmorDamageMultiplier
	elseif phase and phase.defenseState == Enums.DefenseState.Vulnerable then
		multiplier *= 1.15
	elseif phase and phase.defenseState == Enums.DefenseState.Phased then
		multiplier *= 0.9
	end

	local resistance = def.resistances and def.resistances[damageType]
	if resistance then
		multiplier *= resistance
	end

	if isAreaDamage then
		multiplier *= 0.75
	end

	return math.clamp(multiplier, 0, 5)
end

-- Shield capacity for a phase. Pyr axis cocoon uses the explicit baseline
-- multiplied by the configured multiplier - never a multiple of remaining
-- health.
function Boss.ShieldCapacity(bossId: string, phaseIndex: number): number
	local phase = Boss.Phase(bossId, phaseIndex)
	if not phase or not phase.shield then
		return 0
	end
	return phase.shield.capacity
end

function Boss.HasWeakPointInPhase(bossId: string, phaseIndex: number, weakPointId: string): boolean
	local def = Boss:Get(bossId)
	if not def then
		return false
	end
	local phase = Boss.Phase(bossId, phaseIndex)
	if phase and phase.weakPoints then
		for _, weakPoint in phase.weakPoints do
			if weakPoint.id == weakPointId and table.find(weakPoint.exposedPhases, phaseIndex) then
				return true
			end
		end
	end
	for _, weakPoint in def.weakPoints or {} do
		if weakPoint.id == weakPointId then
			return true
		end
	end
	return false
end

function Boss.WeakPointsForPhase(bossId: string, phaseIndex: number): { any }
	local phase = Boss.Phase(bossId, phaseIndex)
	if not phase then
		return {}
	end
	return phase.weakPoints or {}
end

-- Picks an attack using the phase weights. `random` is injected for tests.
function Boss.PickAttack(bossId: string, phaseIndex: number, random: () -> number): any?
	local phase = Boss.Phase(bossId, phaseIndex)
	if not phase or not phase.attacks or #phase.attacks == 0 then
		return nil
	end
	local total = 0
	for _, entry in phase.attacks do
		total += entry.weight or 1
	end
	local roll = random() * total
	local cumulative = 0
	for _, entry in phase.attacks do
		cumulative += entry.weight or 1
		if roll <= cumulative then
			return entry
		end
	end
	return phase.attacks[#phase.attacks]
end

function Boss.RespawnSeconds(bossId: string): number
	local def = Boss:Get(bossId)
	if not def then
		return Limits.Boss.RespawnSeconds
	end
	return def.respawnSeconds or Limits.Boss.RespawnSeconds
end

function Boss.IsAlwaysDamageable(bossId: string): boolean
	local def = Boss:Get(bossId)
	if not def or not def.safeguards then
		return false
	end
	return def.safeguards.alwaysDamageable == true or def.safeguards.neverPermanentlyInvulnerable == true
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

function Boss.ValidateAll(): { string }
	local problems = Registry.Validate(Boss)

	local world = Boss.WorldBosses()
	if #world ~= 7 then
		table.insert(problems, string.format("[Boss] expected 7 world bosses, found %d", #world))
	end
	local dungeon = Boss.DungeonBosses()
	if #dungeon ~= 7 then
		table.insert(problems, string.format("[Boss] expected 7 dungeon bosses, found %d", #dungeon))
	end
	if not Boss:Has("elder_veyl") then
		table.insert(problems, "[Boss] Elder Veyl (ROOTFALL final boss) is missing")
	end

	-- One world boss per region.
	local byRegion: { [string]: string } = {}
	for _, def in world do
		if not def.regionId then
			table.insert(problems, string.format("[Boss] world boss %s has no region", def.id))
		elseif byRegion[def.regionId] then
			table.insert(problems, string.format("[Boss] region %s has two world bosses", def.regionId))
		else
			byRegion[def.regionId] = def.id
		end
	end
	for _, regionId in Enums.RegionOrder do
		if not byRegion[regionId] then
			table.insert(problems, string.format("[Boss] region %s has no world boss", regionId))
		end
	end

	for _, def in Boss:List() do
		if #def.phases < 2 then
			table.insert(problems, string.format("[Boss] %s needs at least two phases", def.id))
		end
		local previous = math.huge
		for _, phase in def.phases do
			if phase.healthThreshold >= 0 and phase.healthThreshold > previous then
				table.insert(problems, string.format("[Boss] %s phase thresholds are not descending", def.id))
			end
			if phase.healthThreshold >= 0 then
				previous = phase.healthThreshold
			end
			if not Enums.DefenseState[phase.defenseState] then
				table.insert(problems, string.format("[Boss] %s phase %d has unknown defense state %q", def.id, phase.index, tostring(phase.defenseState)))
			end
			if not phase.attacks or #phase.attacks == 0 then
				table.insert(problems, string.format("[Boss] %s phase %d has no attacks", def.id, phase.index))
			end
			for _, entry in phase.attacks or {} do
				if (entry.telegraph or 0) < 0.2 then
					table.insert(problems, string.format("[Boss] %s attack %s telegraph is too short to be readable", def.id, entry.id))
				end
			end
		end
	end

	-- Pyr axis specific assertions.
	local pyraxis = Boss:Get("pyraxis")
	if pyraxis then
		local expected = Limits.BossSpecial.PyraxisBaselineShieldCapacity * Limits.BossSpecial.PyraxisCocoonShieldMultiplier
		local cocoonPhase = Boss.Phase("pyraxis", pyraxis.special.cocoonPhaseIndex)
		if not cocoonPhase or not cocoonPhase.shield or cocoonPhase.shield.capacity ~= expected then
			table.insert(
				problems,
				string.format("[Boss] Pyr axis cocoon shield must be %d (baseline x multiplier), found %s", expected, tostring(cocoonPhase and cocoonPhase.shield and cocoonPhase.shield.capacity))
			)
		end
		if pyraxis.special.finalFormPhaseIndex ~= 4 then
			table.insert(problems, "[Boss] Pyr axis final form must be phase 4")
		end
	end

	-- Light Samurai specific assertions.
	local samurai = Boss:Get("light_samurai")
	if samurai then
		if #samurai.phases ~= 4 then
			table.insert(problems, string.format("[Boss] Light Samurai must have 4 stages, found %d", #samurai.phases))
		end
		local finalPhase = Boss.Phase("light_samurai", 4)
		if not finalPhase or finalPhase.defenseState ~= Enums.DefenseState.Invulnerable then
			table.insert(problems, "[Boss] Light Samurai stage 4 must be an invulnerable detonation phase")
		end
		if not samurai.special or samurai.special.survivorsAutoDefeatBoss ~= true then
			table.insert(problems, "[Boss] Light Samurai survival must automatically defeat the boss")
		end
	end

	-- Parallax specific assertions.
	local parallax = Boss:Get("parallax")
	if parallax then
		if parallax.safeguards.alwaysDamageable ~= true or parallax.safeguards.neverPermanentlyInvulnerable ~= true then
			table.insert(problems, "[Boss] Parallax must always be damageable and never permanently invulnerable")
		end
		if parallax.safeguards.deathStateAlwaysReachable ~= true then
			table.insert(problems, "[Boss] Parallax death state must always be reachable")
		end
		if parallax.safeguards.rewardDistributionOnce ~= true then
			table.insert(problems, "[Boss] Parallax rewards must be distributed exactly once")
		end
	end

	return problems
end

Boss.Registry = Boss
return Boss
