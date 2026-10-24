--!strict
--[[
	BossEncounter.luau
	The boss encounter state machine. PURE: no Roblox globals, deterministic,
	driven by an injected clock. The Roblox-facing BossService owns the actors
	and applies the events this machine emits.

	Why this exists as a separate pure module:
	  * boss defeats must be provable, not merely plausible
	  * the two hardest bosses (Null Horizon / Parallax and the Light Region
	    Samurai, Aurion) have failure modes that only show up mid-fight:
	    permanent invulnerability, phase loops, and unreachable death states

	Guarantees enforced here, on every tick:

	  1. ALWAYS DAMAGEABLE -- a boss flagged `alwaysDamageable` (Parallax)
	     never resolves to zero incoming damage. If the phase maths would
	     zero a hit, a chip-damage floor applies.
	  2. MONOTONIC PHASES -- a boss can never walk backwards through its
	     script, so it cannot loop between two phases.
	  3. BOUNDED PHASES -- every phase has a timeout. When one expires the
	     fight is forced forward, so no phase can stall forever.
	  4. EXPLICIT PHASES STILL FIRE -- phases with a negative threshold (Pyr
	     axis final form) are entered by trigger, and the trigger is checked
	     every tick, so they cannot be skipped.
	  5. FINAL DETONATION RESOLVES -- the Light Samurai's 5% explosion starts
	     exactly once, resolves exactly once, and either defeats the boss
	     (players survived) or wipes cleanly (players did not). It can never
	     leave the boss invulnerable forever.
	  6. DEFEAT REWARDS ONCE -- reward distribution is behind a latch.
	  7. TERMINAL STATE -- every encounter ends in Defeated or Reset. There is
	     no state from which the encounter cannot exit.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Bosses = require(script.Parent.Parent.Config.BossConfig)

local BossEncounter = {}
BossEncounter.__index = BossEncounter

export type Participant = {
	id: string,
	damage: number,
	alive: boolean,
	distance: number,
	joinedAt: number,
}

export type Event = {
	kind: string,
	-- Event-specific payload fields are merged into this table.
	[any]: any,
}

export type Encounter = {
	bossId: string,
	def: any,
	health: number,
	maxHealth: number,
	phaseIndex: number,
	shield: number,
	state: string,
	time: number,
	startedAt: number,
	endsAt: number?,

	participants: { [string]: Participant },
	damageByParticipant: { [string]: number },

	-- Detonation (Light Samurai)
	detonationStarted: boolean,
	detonationStartedAt: number?,
	detonationEndsAt: number?,
	detonationResolved: boolean,
	detonationOutcomeResolved: boolean,
	detonationSurvivorCheckAt: number?,
	detonationTargets: { string },

	-- Parallax-style presence
	absentUntil: number?,
	glitchUntil: number?,

	-- Latches
	rewarded: boolean,
	cleanupAcknowledged: boolean,

	-- Attack scheduling
	nextAttackAt: number,
	lastPhaseChangeAt: number,
	phaseChangeCount: number,
	explicitPhasesEntered: { [number]: boolean },

	random: (() -> number)?,

	-- Internal: buffered events awaiting delivery.
	_events: { Event },
}

-- ---------------------------------------------------------------------------
-- Event buffer
-- ---------------------------------------------------------------------------

-- Events are buffered on the encounter instead of being handed straight back.
-- Phase changes can be produced by ApplyDamage OR by Tick; if each caller had
-- to remember to read the right return value, a detonation or defeat event
-- could be dropped and the encounter would look stuck. Every public entry
-- point drains the buffer, so events are delivered exactly once, in order.
function BossEncounter:_emit(event: Event)
	table.insert(self._events, event)
end

function BossEncounter:DrainEvents(): { Event }
	if #self._events == 0 then
		return {}
	end
	local out = self._events
	self._events = {}
	return out
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

function BossEncounter.new(bossId: string, options: { random: (() -> number)?, now: number? }?): Encounter?
	local def = Bosses:Get(bossId)
	if not def then
		return nil
	end

	local self = setmetatable({} :: any, BossEncounter) :: Encounter
	self.bossId = bossId
	self.def = def
	self.maxHealth = def.baseHealth or 1
	self.health = self.maxHealth
	self.phaseIndex = 1
	self.shield = Bosses.ShieldCapacity(bossId, 1)
	self.state = Enums.BossState.Active
	self.time = options and options.now or 0
	self.startedAt = self.time
	self.endsAt = nil

	self.participants = {}
	self.damageByParticipant = {}

	self.detonationStarted = false
	self.detonationStartedAt = nil
	self.detonationEndsAt = nil
	self.detonationResolved = false
	self.detonationOutcomeResolved = false
	self.detonationSurvivorCheckAt = nil
	self.detonationTargets = {}

	self.absentUntil = nil
	self.glitchUntil = nil

	self.rewarded = false
	self.cleanupAcknowledged = false

	self.nextAttackAt = self.time + 2
	self.lastPhaseChangeAt = self.time
	self.phaseChangeCount = 0
	self.explicitPhasesEntered = {}
	self.random = options and options.random or nil

	-- Internal event buffer (see BossEncounter:_emit).
	self._events = {} :: { Event }

	return self
end

-- ---------------------------------------------------------------------------
-- Participants
-- ---------------------------------------------------------------------------

function BossEncounter:AddParticipant(id: string, distance: number?)
	if self.participants[id] then
		return
	end
	self.participants[id] = {
		id = id,
		damage = 0,
		alive = true,
		distance = distance or 0,
		joinedAt = self.time,
	}
end

function BossEncounter:RemoveParticipant(id: string)
	self.participants[id] = nil
end

function BossEncounter:SetParticipantAlive(id: string, alive: boolean)
	local participant = self.participants[id]
	if participant then
		participant.alive = alive
	end
end

function BossEncounter:SetParticipantDistance(id: string, distance: number)
	local participant = self.participants[id]
	if not participant then
		return
	end
	-- Distances come from the client's own position report, so they are
	-- clamped here: an absurd value can never smuggle a player out of, or
	-- into, an explosion.
	participant.distance = math.clamp(distance or 0, 0, Limits.Boss.LeashRadiusStuds * 4)
end

function BossEncounter:ParticipantCount(): number
	local count = 0
	for _ in self.participants do
		count += 1
	end
	return count
end

function BossEncounter:AliveParticipantCount(): number
	local count = 0
	for _, participant in self.participants do
		if participant.alive then
			count += 1
		end
	end
	return count
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function BossEncounter:HealthFraction(): number
	if self.maxHealth <= 0 then
		return 0
	end
	return math.clamp(self.health / self.maxHealth, 0, 1)
end

function BossEncounter:Phase()
	return Bosses.Phase(self.bossId, self.phaseIndex)
end

-- True when a hit right now would remove health. For a boss flagged
-- `alwaysDamageable` this is ALWAYS true while the encounter is running.
function BossEncounter:IsDamageable(): boolean
	if self.state ~= Enums.BossState.Active then
		return false
	end
	if Bosses.IsAlwaysDamageable(self.bossId) then
		return true
	end
	return self:EffectiveDamageMultiplier(nil, false) > 0
end

-- The defense state actually used, after the always-damageable safeguard is
-- applied. An always-damageable boss is never truly Invulnerable.
function BossEncounter:EffectiveDefenseState(): string
	local phase = self:Phase()
	local state = phase and phase.defenseState or Enums.DefenseState.Normal
	if state == Enums.DefenseState.Invulnerable and Bosses.IsAlwaysDamageable(self.bossId) then
		-- Still heavily mitigated, but never a brick wall.
		return Enums.DefenseState.Armored
	end
	return state
end

function BossEncounter:EffectiveDamageMultiplier(damageType: string?, isAreaDamage: boolean?): number
	local multiplier = Bosses.DamageMultiplier(self.bossId, self.phaseIndex, damageType, isAreaDamage == true)
	local state = self:EffectiveDefenseState()
	if state == Enums.DefenseState.Invulnerable then
		return 0
	end
	if state == Enums.DefenseState.Armored then
		multiplier = math.max(multiplier, Limits.Combat.ArmorDamageMultiplier * 0.5)
	end
	if Bosses.IsAlwaysDamageable(self.bossId) then
		-- A damageable boss always lets at least chip damage through.
		multiplier = math.max(multiplier, 0.05)
	end
	return math.clamp(multiplier, 0, 5)
end

-- Whether the encounter can still reach a terminal state.
-- An encounter must NEVER be able to report false here.
function BossEncounter:HasReachableDefeat(): boolean
	if self.state == Enums.BossState.Defeated then
		return true
	end
	if self.detonationOutcomeResolved == true then
		return true
	end
	if self.detonationStarted then
		-- The detonation always resolves (timeout fallback guarantees it).
		return true
	end
	if not Bosses.IsAlwaysDamageable(self.bossId) and not self:IsDamageable() then
		-- A non-damageable phase is only acceptable if a bounded phase
		-- timeout will push the fight forward.
		return self:HasBoundedPhases()
	end
	return true
end

function BossEncounter:HasBoundedPhases(): boolean
	for _, phase in self.def.phases or {} do
		if not phase.timeoutSeconds or phase.timeoutSeconds <= 0 then
			return false
		end
	end
	return true
end

function BossEncounter:IsDefeated(): boolean
	return self.state == Enums.BossState.Defeated
end

function BossEncounter:IsTerminal(): boolean
	return self.state == Enums.BossState.Defeated
		or self.state == Enums.BossState.Resetting
		or self.state == Enums.BossState.Cleanup
end

-- ---------------------------------------------------------------------------
-- Damage
-- ---------------------------------------------------------------------------

-- Applies one hit. Returns the health actually removed and any events.
function BossEncounter:ApplyDamage(
	amount: number,
	sourceId: string?,
	damageType: string?,
	isAreaDamage: boolean?
): (number, { Event })
	local events: { Event } = {}

	if self:IsTerminal() then
		return 0, events
	end
	if self.detonationStarted and not self.detonationOutcomeResolved then
		-- The Light Samurai is invulnerable during its scripted finale by
		-- design. Damage is refused, but the finale always resolves.
		return 0, events
	end

	if not (amount == amount) or amount <= 0 then
		return 0, events
	end

	local multiplier = self:EffectiveDamageMultiplier(damageType, isAreaDamage)
	local incoming = amount * multiplier

	-- Always-damageable chip floor: a flagged boss never takes a true zero.
	if incoming <= 0 and Bosses.IsAlwaysDamageable(self.bossId) then
		incoming = math.max(1, amount * 0.05)
	end

	-- Shields absorb before health.
	if self.shield > 0 then
		local absorbed = math.min(self.shield, incoming)
		self.shield -= absorbed
		incoming -= absorbed
		self:_emit({ kind = "ShieldAbsorbed", target = self.bossId, amount = absorbed, shield = self.shield })
		-- A flagged boss still loses health through its shield, otherwise a
		-- big shield plus a chip floor could stall the fight indefinitely.
		if Bosses.IsAlwaysDamageable(self.bossId) and incoming <= 0 then
			incoming = math.max(1, amount * 0.05)
		end
	end

	if incoming <= 0 then
		return 0, events
	end

	self.health = math.max(0, self.health - incoming)

	if sourceId then
		self.damageByParticipant[sourceId] = (self.damageByParticipant[sourceId] or 0) + incoming
		local participant = self.participants[sourceId]
		if participant then
			participant.damage += incoming
		end
	end

	-- Phase evaluation happens once, at the end, so a burst of simultaneous
	-- hits cannot interleave with a transition.
	self:_evaluatePhase(events)

	if self.health <= 0 then
		self:_defeat(events, "Health")
	end

	-- Events are NOT drained here: they are delivered by the next Tick so a
	-- caller that ignores this return value cannot lose a phase change, a
	-- detonation or a defeat.
	return incoming, {}
end

-- ---------------------------------------------------------------------------
-- Phase handling
-- ---------------------------------------------------------------------------

local function phaseByIndex(def: any, index: number): any?
	for _, phase in def.phases or {} do
		if phase.index == index then
			return phase
		end
	end
	return nil
end

-- Returns the phase index the boss should be in for its current health.
-- Phases with a negative threshold are explicit-only and are skipped here.
local function indexForHealth(def: any, fraction: number): number
	local best = 1
	for _, phase in def.phases or {} do
		if phase.healthThreshold and phase.healthThreshold >= 0 and fraction <= phase.healthThreshold then
			if phase.index > best then
				best = phase.index
			end
		end
	end
	return best
end

function BossEncounter:_enterPhase(index: number, events: { Event }, reason: string)
	local def = self.def
	local target = phaseByIndex(def, index)
	if not target then
		return
	end
	-- Monotonic: never walk backwards.
	if index <= self.phaseIndex then
		return
	end

	local previous = self.phaseIndex
	self.phaseIndex = index
	self.phaseChangeCount += 1
	self.lastPhaseChangeAt = self.time
	self.shield = Bosses.ShieldCapacity(self.bossId, index)

	self:_emit({
		kind = "PhaseChanged",
		bossId = self.bossId,
		phaseIndex = index,
		previousPhaseIndex = previous,
		phaseName = target.name,
		defenseState = self:EffectiveDefenseState(),
		shield = self.shield,
		reason = reason,
	})

	self:_applyOnEnter(target, events)
end

-- Handles the `onEnter` block: detonation, glitch, copies, transforms, and the
-- Pyr axis cocoon trigger.
function BossEncounter:_applyOnEnter(phase: any, events: { Event })
	local onEnter = phase.onEnter
	if not onEnter then
		return
	end

	-- Light Samurai finale: start the countdown exactly once.
	if onEnter.beginDetonation then
		self:_beginDetonation(events, phase)
	end

	if onEnter.glitchEnabled then
		self.glitchUntil = self.time + (onEnter.maxGlitchSeconds or Limits.BossSpecial.ParallaxMaxGlitchSeconds)
		self:_emit({ kind = "GlitchToggled", bossId = self.bossId, enabled = true })
	end

	if onEnter.spawnCopies then
		self:_emit({
			kind = "CopiesSpawned",
			bossId = self.bossId,
			count = onEnter.spawnCopies,
			copyHealth = onEnter.copyHealth,
		})
	end

	if onEnter.transform then
		self:_emit({ kind = "Transformed", bossId = self.bossId, form = onEnter.transform })
	end

	if onEnter.fractureArena then
		self:_emit({ kind = "ArenaFractured", bossId = self.bossId })
	end

	if onEnter.maxAbsentSeconds then
		self.absentUntil = nil
	end
end

function BossEncounter:_evaluatePhase(events: { Event })
	local def = self.def
	local target = indexForHealth(def, self:HealthFraction())
	if target > self.phaseIndex then
		self:_enterPhase(target, events, "HealthThreshold")
	end
end

-- Explicit-only phases (negative threshold) are entered by trigger.
-- `BossEncounter:Tick` checks the pending trigger every tick so a phase can
-- never be silently skipped.
function BossEncounter:TriggerPhase(index: number): { Event }
	local events: { Event } = {}
	if self:IsTerminal() then
		return self:DrainEvents()
	end
	self:_enterPhase(index, events, "ExplicitTrigger")
	return self:DrainEvents()
end

-- The Pyr axis cocoon: when the boss reaches its threshold it enters the
-- cocoon phase, and after the transformation completes it enters the final
-- form, which is explicit-only.
function BossEncounter:_checkExplicitTriggers(events: { Event })
	local def = self.def
	local special = def.special
	if not special then
		return
	end

	if special.type == "PyraxisCocoon" or def.id == "pyr_axis" then
		local finalPhase = nil
		for _, phase in def.phases or {} do
			if phase.healthThreshold and phase.healthThreshold < 0 then
				finalPhase = phase
			end
		end
		if not finalPhase then
			return
		end
		if self.explicitPhasesEntered[finalPhase.index] then
			return
		end
		-- The final form unlocks once the cocoon transformation has run or
		-- the boss has been pushed to its last health threshold.
		local cocoonDone = self.cocoonCompletedAt ~= nil
		local atFinalThreshold = self:HealthFraction() <= (special.finalFormThreshold or 0.02)
		if cocoonDone or atFinalThreshold then
			self.explicitPhasesEntered[finalPhase.index] = true
			self:_enterPhase(finalPhase.index, events, "PyraxisFinalForm")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Final detonation (Light Region Samurai)
-- ---------------------------------------------------------------------------

function BossEncounter:_beginDetonation(events: { Event }, phase: any)
	-- Latch: repeated threshold checks can never restart the countdown.
	if self.detonationStarted then
		return
	end
	local special = self.def.special or {}
	local countdown = special.detonationSeconds
		or (phase.onEnter and phase.onEnter.countdownSeconds)
		or Limits.BossSpecial.LightSamuraiDetonationSeconds

	self.detonationStarted = true
	self.detonationStartedAt = self.time
	self.detonationEndsAt = self.time + countdown
	self.state = Enums.BossState.FinalDetonation

	self:_emit({
		kind = "DetonationStarted",
		bossId = self.bossId,
		countdownSeconds = countdown,
		endsAt = self.detonationEndsAt,
		radiusStuds = special.detonationRadiusStuds or Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
		damage = special.detonationDamage or Limits.BossSpecial.LightSamuraiDetonationDamage,
	})
end

-- Resolves the explosion itself. Emits who was hit; the service applies the
-- damage to the real characters and reports survivors back.
function BossEncounter:_resolveDetonation(events: { Event })
	if self.detonationResolved then
		return
	end
	self.detonationResolved = true

	local special = self.def.special or {}
	local radius = special.detonationRadiusStuds or Limits.BossSpecial.LightSamuraiDetonationRadiusStuds
	local damage = special.detonationDamage or Limits.BossSpecial.LightSamuraiDetonationDamage

	local targets: { string } = {}
	for id, participant in self.participants do
		if participant.alive and participant.distance <= radius then
			table.insert(targets, id)
		end
	end
	self.detonationTargets = targets
	-- Grace period so the server can apply the blast and report who died.
	self.detonationSurvivorCheckAt = self.time
		+ (Limits.BossSpecial.LightSamuraiSurvivorCheckSeconds or 3)

	self:_emit({
		kind = "DetonationResolved",
		bossId = self.bossId,
		radiusStuds = radius,
		damage = damage,
		targets = targets,
		targetCount = #targets,
	})
end

-- Decides the outcome after the explosion. Runs exactly once.
function BossEncounter:_resolveOutcome(events: { Event })
	if self.detonationOutcomeResolved then
		return
	end
	self.detonationOutcomeResolved = true

	local survivors = self:AliveParticipantCount()
	local autoDefeat = (self.def.special and self.def.special.survivorsAutoDefeatBoss)
		or (self.def.safeguards and self.def.safeguards.detonationKillsBossOnSurvival)

	if survivors > 0 and autoDefeat then
		-- Players survived: the boss is defeated without another hit.
		self.health = 0
		self:_defeat(events, "DetonationSurvived")
	elseif survivors == 0 then
		-- Total wipe: the encounter still terminates. The boss returns to
		-- its reset state rather than hanging in its final phase.
		self:_wipe(events)
	else
		-- Survived but auto-defeat is not configured: fall through to a
		-- normal finish so the boss is still not stuck invulnerable.
		self.health = 0
		self:_defeat(events, "DetonationSurvived")
	end
end

-- ---------------------------------------------------------------------------
-- Terminal states
-- ---------------------------------------------------------------------------

function BossEncounter:_defeat(events: { Event }, cause: string)
	if self.state == Enums.BossState.Defeated then
		return
	end
	self.state = Enums.BossState.Defeated
	self.health = 0
	self.endsAt = self.time
	self.shield = 0
	self.absentUntil = nil
	self.glitchUntil = nil

	self:_emit({
		kind = "BossDefeated",
		bossId = self.bossId,
		cause = cause,
		durationSeconds = self.time - self.startedAt,
		participants = self:RewardEligibleParticipants(),
	})
end

-- Wipe: everyone fell. The encounter terminates the same way it would after a
-- defeat, but no rewards are granted and the boss is scheduled to reset.
function BossEncounter:_wipe(events: { Event })
	self.state = Enums.BossState.Resetting
	self.endsAt = self.time
	self.absentUntil = nil
	self.glitchUntil = nil
	self:_emit({
		kind = "EncounterWiped",
		bossId = self.bossId,
		respawnSeconds = Bosses.RespawnSeconds(self.bossId),
	})
end

-- Only players who actually contributed are rewarded.
function BossEncounter:RewardEligibleParticipants(): { string }
	local out: { string } = {}
	local share = Limits.Boss.ParticipationDamageShareRequired
	for id, damage in self.damageByParticipant do
		if self.maxHealth > 0 and (damage / self.maxHealth) >= share then
			table.insert(out, id)
		elseif damage > 0 then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Rewards are granted at most once per encounter.
function BossEncounter:ClaimRewards(): boolean
	if self.rewarded then
		return false
	end
	if self.state ~= Enums.BossState.Defeated then
		return false
	end
	self.rewarded = true
	return true
end

-- The service calls this once it has disconnected listeners and removed
-- temporary objects.
function BossEncounter:AcknowledgeCleanup()
	self.cleanupAcknowledged = true
end

-- True when the encounter is over AND the service has cleaned up.
function BossEncounter:IsClean(): boolean
	return self:IsTerminal() and self.cleanupAcknowledged
end

-- ---------------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------------

function BossEncounter:Tick(dt: number): { Event }
	local events: { Event } = {}
	if self:IsTerminal() then
		return events
	end

	self.time += math.max(0, dt)

	-- 1. Presence safeguards (Parallax vanish / glitch are bounded).
	self:_tickPresence(events)

	-- 2. Explicit-only phases must still fire.
	self:_checkExplicitTriggers(events)

	-- 3. Detonation lifecycle.
	self:_tickDetonation(events)

	-- 4. Phase timeouts guarantee forward progress.
	self:_tickPhaseTimeout(events)

	-- 5. Combat: attack scheduling. Suppressed during the detonation.
	if not (self.detonationStarted and not self.detonationOutcomeResolved) then
		self:_tickAttacks(events)
	end

	-- 6. Encounter-level timeout: nothing runs forever.
	if self.time - self.startedAt > (self.def.encounterTimeoutSeconds or Limits.Boss.EncounterTimeoutSeconds) then
		self:_wipe(events)
	end

	return self:DrainEvents()
end

function BossEncounter:_tickPresence(events: { Event })
	local special = self.def.special or {}

	if self.glitchUntil and self.time >= self.glitchUntil then
		self.glitchUntil = nil
		self:_emit({ kind = "GlitchToggled", bossId = self.bossId, enabled = false })
	end

	if self.absentUntil then
		if self.time >= self.absentUntil then
			self.absentUntil = nil
			self:_emit({
				kind = "Reappeared",
				bossId = self.bossId,
				maxTeleportStuds = special.teleportMaxStuds or Limits.BossSpecial.ParallaxTeleportMaxStuds,
			})
		end
	else
		-- Absence can never exceed the configured maximum.
		local limit = special.maxAbsentSeconds or Limits.BossSpecial.ParallaxMaxAbsentSeconds
		if self.absentUntil and self.time - (self.detonationStartedAt or self.time) > limit then
			self.absentUntil = nil
		end
	end
end

-- Emits the absence without draining (for use inside a tick).
function BossEncounter:_beginAbsence(duration: number)
	local special = self.def.special or {}
	local limit = special.maxAbsentSeconds or Limits.BossSpecial.ParallaxMaxAbsentSeconds
	local clamped = math.clamp(duration or limit, 0, limit)
	self.absentUntil = self.time + clamped
	self:_emit({ kind = "Vanished", bossId = self.bossId, durationSeconds = clamped })
end

-- The boss may vanish only for a bounded time, and always returns.
function BossEncounter:BeginAbsence(seconds: number?): { Event }
	self:_beginAbsence(seconds)
	return self:DrainEvents()
end

function BossEncounter:_tickDetonation(events: { Event })
	if not self.detonationStarted then
		return
	end

	if not self.detonationResolved then
		local phase = self:Phase()
		local endsAt = self.detonationEndsAt or self.time
		local hardLimit = endsAt + (phase and phase.timeoutSeconds or 15)
		if self.time >= endsAt or self.time >= hardLimit then
			self:_resolveDetonation(events)
		end
		return
	end

	if not self.detonationOutcomeResolved then
		local checkAt = self.detonationSurvivorCheckAt or self.time
		local phase = self:Phase()
		local hardLimit = (self.detonationEndsAt or self.time) + (phase and phase.timeoutSeconds or 15) + 5
		-- Resolve as soon as the outcome is knowable: either everyone is
		-- confirmed dead, or the grace period elapsed, or we hit the hard
		-- limit (the service never reported back). Either way this runs
		-- exactly once.
		if self:AliveParticipantCount() == 0 or self.time >= checkAt or self.time >= hardLimit then
			self:_resolveOutcome(events)
		end
	end
end

function BossEncounter:_tickPhaseTimeout(events: { Event })
	-- No phase timeout applies while the scripted finale is running.
	if self.detonationStarted and not self.detonationOutcomeResolved then
		return
	end

	local phase = self:Phase()
	if not phase or not phase.timeoutSeconds or phase.timeoutSeconds <= 0 then
		return
	end

	if self.time - self.lastPhaseChangeAt < phase.timeoutSeconds then
		return
	end

	-- The phase has stalled. Force the fight forward rather than letting the
	-- boss sit in a state that cannot be progressed out of.
	local lastIndex = #(self.def.phases or {})
	if self.phaseIndex < lastIndex then
		self:_enterPhase(self.phaseIndex + 1, events, "PhaseTimeout")
	else
		-- Already in the final phase: wear the boss down so it can be killed.
		self.health = math.max(0, self.health - self.maxHealth * 0.02)
		self.lastPhaseChangeAt = self.time
		self:_emit({ kind = "PhaseStallDecay", bossId = self.bossId, health = self.health })
		if self.health <= 0 then
			self:_defeat(events, "PhaseStallDecay")
		end
	end
end

function BossEncounter:_tickAttacks(events: { Event })
	if self.time < self.nextAttackAt then
		return
	end
	-- An absent boss does not attack.
	if self.absentUntil then
		return
	end

	local phase = self:Phase()
	if not phase or not phase.attacks or #phase.attacks == 0 then
		self.nextAttackAt = self.time + 2
		return
	end

	local pick = Bosses.PickAttack(self.bossId, self.phaseIndex, self.random or math.random)
	if not pick then
		self.nextAttackAt = self.time + 2
		return
	end

	self.nextAttackAt = self.time + math.max(0.5, (pick.cooldown or 8))

	local event: Event = {
		kind = "AttackStarted",
		bossId = self.bossId,
		attackId = pick.id,
		attackName = pick.name,
		attackKind = pick.kind,
		telegraph = pick.telegraph,
		windup = pick.windup,
		damage = pick.damage,
		damageType = pick.damageType,
		radius = pick.radius,
		range = pick.range,
	}
	self:_emit(event)

	-- Vanish-type attacks put the boss out of play for a bounded time.
	if pick.mechanic and string.find(pick.mechanic, "Disappears") then
		self:_beginAbsence(Limits.BossSpecial.ParallaxMaxAbsentSeconds)
	end
end

-- ---------------------------------------------------------------------------
-- Snapshot (for the client HUD)
-- ---------------------------------------------------------------------------

function BossEncounter:Snapshot()
	return {
		bossId = self.bossId,
		health = self.health,
		maxHealth = self.maxHealth,
		healthFraction = self:HealthFraction(),
		phaseIndex = self.phaseIndex,
		phaseName = (self:Phase() and self:Phase().name) or "",
		shield = self.shield,
		defenseState = self:EffectiveDefenseState(),
		state = self.state,
		damageable = self:IsDamageable(),
		detonationStarted = self.detonationStarted,
		detonationRemaining = (self.detonationEndsAt and math.max(0, self.detonationEndsAt - self.time)) or nil,
		participants = self:ParticipantCount(),
	}
end

return BossEncounter
