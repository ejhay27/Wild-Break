--!strict
--[[
	Boss encounter spec.

	Behavioural tests for the two bosses whose failure modes only appear
	mid-fight:

	  * Null Horizon / Parallax, the Unmade
	      - glitching is a mechanic, never permanent immunity
	      - at least one damageable condition always exists
	      - phases are bounded, monotonic and cannot loop
	      - defeat is reachable and rewards are granted once

	  * Light Region Samurai / Aurion, the Sunheart Colossus
	      - the 5% HP threshold starts the detonation exactly once
	      - the explosion resolves exactly once
	      - survivors defeat the boss automatically, with no extra damage
	      - a total wipe still terminates the encounter
	      - the boss can never stay invulnerable in its final phase

	These tests drive the real state machine (src/shared/Combat/
	BossEncounter), not the configuration tables.
]]

local Test = require("../harness/Harness")

local BossEncounter = require("@shared/Combat/BossEncounter")
local Bosses = require("@shared/Config/BossConfig")
local Enums = require("@shared/Constants/Enums")
local Limits = require("@shared/Constants/Limits")

-- Deterministic "random" that always picks the first attack.
local function fixedRandom()
	return 0
end

local function newEncounter(bossId: string)
	return BossEncounter.new(bossId, { random = fixedRandom, now = 0 })
end

-- Runs `seconds` worth of 0.25s ticks, collecting every event.
local function run(encounter, seconds: number)
	local events = {}
	local steps = math.ceil(seconds / 0.25)
	for _ = 1, steps do
		for _, event in encounter:Tick(0.25) do
			table.insert(events, event)
		end
	end
	return events
end

local function countEvents(events, kind: string): number
	local n = 0
	for _, event in events do
		if event.kind == kind then
			n += 1
		end
	end
	return n
end

local function findEvent(events, kind: string)
	for _, event in events do
		if event.kind == kind then
			return event
		end
	end
	return nil
end

-- ===========================================================================
-- Null Horizon / Parallax, the Unmade
-- ===========================================================================

Test.describe("Null Horizon / Parallax", function()
	Test.it("exists in the boss registry", function()
		Test.truthy(Bosses:Get("parallax"), "parallax is not registered")
		Test.eq(Bosses:Get("parallax").displayName, "Parallax")
	end)

	Test.it("is flagged always damageable", function()
		Test.truthy(Bosses.IsAlwaysDamageable("parallax"), "Parallax must never be immune to all damage")
	end)

	Test.it("is damageable in every phase", function()
		local encounter = newEncounter("parallax")
		Test.truthy(encounter, "could not build the encounter")
		if not encounter then
			return
		end
		local phaseCount = Bosses.PhaseCount("parallax")
		Test.gte(phaseCount, 2, "Parallax must have multiple phases")

		for index = 1, phaseCount do
			encounter.phaseIndex = index
			Test.truthy(
				encounter:IsDamageable(),
				string.format("Parallax is not damageable in phase %d", index)
			)
			Test.truthy(
				encounter:EffectiveDamageMultiplier(nil, false) > 0,
				string.format("Parallax damage multiplier is zero in phase %d", index)
			)
		end
	end)

	Test.it("glitch windows are bounded", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		-- Force the phase-1 glitch onEnter to run.
		encounter:_applyOnEnter({ onEnter = { glitchEnabled = true, maxGlitchSeconds = 3.5 } }, {})
		Test.truthy(encounter.glitchUntil ~= nil, "glitch window did not start")

		local events = run(encounter, 5)
		Test.truthy(findEvent(events, "GlitchToggled") ~= nil, "glitch never toggled off")
		Test.eq(encounter.glitchUntil, nil, "glitch window outlived its maximum")
	end)

	Test.it("absence is bounded and always ends", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		-- Ask for an absurdly long absence; it must be clamped.
		encounter:BeginAbsence(9999)
		Test.lte(
			(encounter.absentUntil or 0) - encounter.time,
			Limits.BossSpecial.ParallaxMaxAbsentSeconds,
			"absence exceeded the configured maximum"
		)

		local events = run(encounter, Limits.BossSpecial.ParallaxMaxAbsentSeconds + 2)
		Test.truthy(findEvent(events, "Reappeared") ~= nil, "Parallax never reappeared")
		Test.eq(encounter.absentUntil, nil, "Parallax is still absent")
	end)

	Test.it("phase transitions are monotonic", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:_enterPhase(3, {}, "Test")
		Test.eq(encounter.phaseIndex, 3)
		-- A backwards move must be refused even if health healed.
		encounter.health = encounter.maxHealth
		encounter:_enterPhase(1, {}, "Test")
		Test.eq(encounter.phaseIndex, 3, "the boss walked backwards through its script")
	end)

	Test.it("every phase is bounded by a timeout", function()
		local def = Bosses:Get("parallax")
		for _, phase in def.phases do
			Test.truthy(
				phase.timeoutSeconds and phase.timeoutSeconds > 0,
				string.format("phase %d has no timeout", phase.index)
			)
		end
	end)

	Test.it("a stalled phase is forced forward", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local startPhase = encounter.phaseIndex
		-- No damage at all: only the timeout can move this fight along.
		local events = run(encounter, Limits.BossSpecial.ParallaxPhaseTimeoutSeconds + 2)
		Test.truthy(
			encounter.phaseIndex > startPhase,
			"a stalled Parallax phase never advanced"
		)
		Test.gte(countEvents(events, "PhaseChanged"), 1, "no phase change was emitted")
	end)

	Test.it("shield absorption still lets a flagged boss take chip damage", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter.shield = 1e9
		local removed, _ = encounter:ApplyDamage(1000, "p1", nil, false)
		Test.gte(removed, 1, "a huge shield blocked 100% of damage on an always-damageable boss")
	end)

	Test.it("can be driven from full health to defeat", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter:AddParticipant("p2", 40)

		local guard = 0
		while not encounter:IsTerminal() and guard < 20000 do
			guard += 1
			encounter:ApplyDamage(2000, "p1", nil, false)
			encounter:Tick(0.25)
		end

		Test.truthy(encounter:IsDefeated(), "Parallax could not be defeated")
		Test.eq(encounter.health, 0, "defeated Parallax still has health")
		Test.lt(guard, 20000, "defeating Parallax did not converge")
	end)

	Test.it("rewards are granted exactly once", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local guard = 0
		while not encounter:IsDefeated() and guard < 20000 do
			guard += 1
			encounter:ApplyDamage(5000, "p1", nil, false)
			encounter:Tick(0.25)
		end
		Test.truthy(encounter:IsDefeated(), "Parallax was not defeated")

		Test.truthy(encounter:ClaimRewards(), "first reward claim was refused")
		Test.falsy(encounter:ClaimRewards(), "rewards were granted twice")
		Test.falsy(encounter:ClaimRewards(), "rewards were granted three times")
	end)

	Test.it("cleanup is acknowledged and the encounter goes quiet", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local guard = 0
		while not encounter:IsDefeated() and guard < 20000 do
			guard += 1
			encounter:ApplyDamage(5000, "p1", nil, false)
			encounter:Tick(0.25)
		end
		encounter:AcknowledgeCleanup()
		Test.truthy(encounter:IsClean(), "defeated encounter did not become clean")

		-- A defeated boss emits nothing further.
		local events = run(encounter, 5)
		Test.eq(#events, 0, "a defeated boss is still emitting events")
	end)

	Test.it("damage after defeat is ignored", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local guard = 0
		while not encounter:IsDefeated() and guard < 20000 do
			guard += 1
			encounter:ApplyDamage(5000, "p1", nil, false)
			encounter:Tick(0.25)
		end
		local removed, events = encounter:ApplyDamage(999999, "p1", nil, false)
		Test.eq(removed, 0, "a dead boss took damage")
		Test.eq(#events, 0, "a dead boss emitted damage events")
	end)

	Test.it("simultaneous hits and phase changes do not corrupt state", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		-- Interleave large hits that cross several thresholds at once.
		for _ = 1, 400 do
			encounter:ApplyDamage(3000, "p1", nil, false)
			encounter:ApplyDamage(3000, "p2", nil, true)
			encounter:Tick(0.25)
			if encounter:IsTerminal() then
				break
			end
		end
		Test.gte(encounter.health, 0, "health went negative")
		Test.lte(encounter.health, encounter.maxHealth, "health exceeded maximum")
		Test.gte(encounter.phaseIndex, 1, "phase index underflowed")
		Test.lte(encounter.phaseIndex, Bosses.PhaseCount("parallax"), "phase index overflowed")
	end)

	Test.it("declares a reachable defeat condition at every point", function()
		local encounter = newEncounter("parallax")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local guard = 0
		while not encounter:IsTerminal() do
			guard += 1
			Test.truthy(encounter:HasReachableDefeat(), "Parallax lost its defeat condition mid-fight")
			encounter:ApplyDamage(4000, "p1", nil, false)
			encounter:Tick(0.25)
			if guard > 20000 then
				Test.fail("encounter did not terminate")
			end
		end
	end)
end)

-- ===========================================================================
-- Light Region Samurai / Aurion, the Sunheart Colossus
-- ===========================================================================

Test.describe("Light Region Samurai / Aurion", function()
	Test.it("exists in the boss registry", function()
		Test.truthy(Bosses:Get("light_samurai"), "light_samurai is not registered")
		Test.eq(Bosses:Get("light_samurai").displayName, "Aurion")
	end)

	Test.it("declares the 5% detonation threshold", function()
		Test.near(Limits.BossSpecial.LightSamuraiStage4Threshold, 0.05, 1e-9)
		local def = Bosses:Get("light_samurai")
		local finalPhase = Bosses.Phase("light_samurai", 4)
		Test.truthy(finalPhase, "no final phase defined")
		if finalPhase then
			Test.near(finalPhase.healthThreshold, 0.05, 1e-9)
			Test.eq(finalPhase.defenseState, Enums.DefenseState.Invulnerable)
			Test.truthy(finalPhase.onEnter, "final phase has no onEnter")
			Test.truthy(finalPhase.onEnter.beginDetonation, "final phase does not start the detonation")
		end
		Test.truthy(def.special, "no special block")
		Test.truthy(def.special.survivorsAutoDefeatBoss, "survivors must auto-defeat the boss")
	end)

	Test.it("progresses through all four stages as health falls", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)

		local seen = {}
		local guard = 0
		while not encounter:IsTerminal() and guard < 40000 do
			guard += 1
			encounter:ApplyDamage(1500, "p1", nil, false)
			encounter:Tick(0.25)
			seen[encounter.phaseIndex] = true
		end

		Test.truthy(seen[1], "never saw stage 1")
		Test.truthy(seen[2], "never reached stage 2 (six-winged)")
		Test.truthy(seen[3], "never reached stage 3 (eight-winged)")
		Test.truthy(seen[4], "never reached stage 4 (final detonation)")
	end)

	Test.it("enters the detonation exactly once", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)

		local events = {}
		local guard = 0
		while not encounter:IsTerminal() and guard < 40000 do
			guard += 1
			encounter:ApplyDamage(1500, "p1", nil, false)
			for _, event in encounter:Tick(0.25) do
				table.insert(events, event)
			end
		end

		Test.eq(countEvents(events, "DetonationStarted"), 1, "the detonation started more than once")
		Test.eq(countEvents(events, "DetonationResolved"), 1, "the explosion resolved more than once")
		Test.eq(countEvents(events, "BossDefeated"), 1, "the boss was defeated more than once")
	end)

	Test.it("the 5% threshold triggers the countdown, not repeated damage", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)

		-- Drop straight to 4% and let the finale play out untouched.
		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})
		Test.eq(encounter.phaseIndex, 4, "did not enter the final phase at 4%")
		Test.truthy(encounter.detonationStarted, "the countdown did not start")

		-- Hammer it with damage during the finale: none may land.
		local healthBefore = encounter.health
		for _ = 1, 200 do
			encounter:ApplyDamage(99999, "p1", nil, false)
		end
		Test.eq(encounter.health, healthBefore, "the boss took damage during its scripted finale")

		-- But the countdown still runs and the fight still ends.
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 5)
		Test.truthy(findEvent(events, "DetonationResolved") ~= nil, "the explosion never resolved")
	end)

	Test.it("survivors defeat the boss automatically", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter:AddParticipant("p2", 100)

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})

		-- Nobody dies: the detonation damage is reported but both survive.
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 6)

		local resolved = findEvent(events, "DetonationResolved")
		Test.truthy(resolved, "the explosion never resolved")
		if resolved then
			Test.eq(resolved.targetCount, 2, "both participants are in range and should be hit")
			Test.near(
				resolved.damage,
				Limits.BossSpecial.LightSamuraiDetonationDamage,
				1e-6,
				"detonation damage does not match config"
			)
			Test.near(
				resolved.radiusStuds,
				Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
				1e-6,
				"detonation radius does not match config"
			)
		end

		Test.truthy(encounter:IsDefeated(), "survivors did not defeat the boss automatically")
		Test.eq(encounter.health, 0, "an auto-defeated boss still has health")

		local defeated = findEvent(events, "BossDefeated")
		Test.truthy(defeated, "no defeat event was emitted")
		if defeated then
			Test.eq(defeated.cause, "DetonationSurvived", "defeat cause should be the survived detonation")
		end
	end)

	Test.it("a participant outside the blast radius is not hit", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("near", 50)
		encounter:AddParticipant("far", Limits.BossSpecial.LightSamuraiDetonationRadiusStuds + 100)

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 6)

		local resolved = findEvent(events, "DetonationResolved")
		Test.truthy(resolved, "the explosion never resolved")
		if resolved then
			Test.eq(resolved.targetCount, 1, "only the in-range participant should be hit")
			Test.eq(resolved.targets[1], "near")
		end
		Test.truthy(encounter:IsDefeated(), "survivors did not defeat the boss")
	end)

	Test.it("an absurd distance report cannot smuggle a player out of the blast", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 0)
		-- A malicious client reports a nonsense distance.
		encounter:SetParticipantDistance("p1", 1e12)
		Test.lte(
			encounter.participants["p1"].distance,
			Limits.Boss.LeashRadiusStuds * 4,
			"distance was not clamped"
		)
	end)

	Test.it("a total wipe still terminates the encounter", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})

		-- Run up to the moment the explosion resolves.
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 1)
		Test.truthy(findEvent(events, "DetonationResolved") ~= nil, "the explosion never resolved")

		-- Everyone in the blast dies.
		encounter:SetParticipantAlive("p1", false)
		Test.eq(encounter:AliveParticipantCount(), 0)

		local after = run(encounter, 3)
		Test.truthy(encounter:IsTerminal(), "a total wipe left the encounter running")
		Test.falsy(encounter:IsDefeated(), "a wipe must not count as a defeat")
		Test.truthy(findEvent(after, "EncounterWiped") ~= nil, "no wipe event was emitted")
		Test.falsy(encounter:ClaimRewards(), "a wiped encounter granted rewards")
	end)

	Test.it("never stays invulnerable in its final phase", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})

		-- Regardless of what the service does, the encounter must end.
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 30)
		Test.truthy(encounter:IsTerminal(), "the boss is stuck in its final phase forever")
		Test.truthy(
			findEvent(events, "DetonationResolved") ~= nil,
			"the final phase ended without resolving the explosion"
		)
	end)

	Test.it("duplicate events cannot restart the finale", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter.health = encounter.maxHealth * 0.04

		-- Re-entering the phase repeatedly must not replay the countdown.
		for _ = 1, 10 do
			encounter:_evaluatePhase({})
		end
		Test.eq(encounter.detonationStarted, true)
		local firstEndsAt = encounter.detonationEndsAt
		Test.truthy(firstEndsAt ~= nil)

		for _ = 1, 10 do
			encounter:_beginDetonation({}, Bosses.Phase("light_samurai", 4))
		end
		Test.eq(encounter.detonationEndsAt, firstEndsAt, "the countdown was reset")
	end)

	Test.it("rewards are granted once and only to contributors", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("carry", 10)
		encounter:AddParticipant("leech", 10)

		local guard = 0
		while encounter.phaseIndex < 4 and guard < 40000 do
			guard += 1
			encounter:ApplyDamage(1500, "carry", nil, false)
			encounter:Tick(0.25)
		end
		Test.eq(encounter.phaseIndex, 4, "never reached the final phase")

		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 6)
		Test.truthy(encounter:IsDefeated(), "the boss was not defeated")

		local eligible = encounter:RewardEligibleParticipants()
		Test.truthy(table.find(eligible, "carry") ~= nil, "the contributor was not rewarded")
		Test.eq(table.find(eligible, "leech"), nil, "a player who dealt no damage was rewarded")

		Test.truthy(encounter:ClaimRewards(), "first claim refused")
		Test.falsy(encounter:ClaimRewards(), "rewards granted twice")
	end)

	Test.it("a snapshot reports the state the HUD needs", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		local snapshot = encounter:Snapshot()
		Test.eq(snapshot.bossId, "light_samurai")
		Test.eq(snapshot.healthFraction, 1)
		Test.eq(snapshot.phaseIndex, 1)
		Test.truthy(snapshot.damageable, "a fresh encounter should be damageable")

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})
		local late = encounter:Snapshot()
		Test.eq(late.phaseIndex, 4)
		Test.falsy(late.damageable, "the finale should not be damageable")
		Test.truthy(late.detonationStarted)
		Test.truthy(late.detonationRemaining ~= nil, "no countdown for the HUD")
	end)
end)
-- ===========================================================================
-- Participant distance integrity
--
-- A participant's distance must be MEASURED. It must never default to zero,
-- because zero means "standing on top of the boss", which silently puts that
-- player inside every attack radius -- including the Light Samurai's final
-- detonation. These tests lock that rule down.
-- ===========================================================================

Test.describe("Participant distance integrity", function()
	Test.it("a participant added without a distance is not assumed to be at the boss", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1")
		Test.gt(
			encounter.participants["p1"].distance,
			Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
			"a freshly added participant must start outside the blast radius, not on top of the boss"
		)
		Test.falsy(encounter:HasKnownPosition("p1"), "an unmeasured participant must be flagged as unknown")
	end)

	Test.it("an unmeasured participant is not hit by the detonation", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		-- p1 has never had a position resolved by the server.
		encounter:AddParticipant("p1")
		encounter:AddParticipant("measured", Limits.BossSpecial.LightSamuraiDetonationRadiusStuds + 500)

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 6)

		local resolved = findEvent(events, "DetonationResolved")
		Test.truthy(resolved, "the explosion never resolved")
		if resolved then
			Test.eq(resolved.targetCount, 0, "a player with no measured position must not be assumed to be in the blast")
		end
		-- Everyone survived, so the boss still falls over. The encounter must
		-- not hang just because nobody was caught in the radius.
		Test.truthy(encounter:IsDefeated(), "the boss did not resolve after the detonation")
	end)

	Test.it("losing the position measurement marks the distance unknown again", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		Test.truthy(encounter:HasKnownPosition("p1"), "a measured participant should be known")

		-- The server can no longer locate the character (streamed out, respawning).
		encounter:SetParticipantDistance("p1", nil)
		Test.falsy(encounter:HasKnownPosition("p1"), "the participant should be unknown again")
		Test.gt(
			encounter.participants["p1"].distance,
			Limits.BossSpecial.LightSamuraiDetonationRadiusStuds,
			"an unknown distance must be far away, never zero"
		)
	end)

	Test.it("a downed player is not an active survivor", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter:AddParticipant("p2", 10)
		Test.eq(encounter:AliveParticipantCount(), 2, "both players start alive")

		-- Downed is not alive: the survivor check must not count them.
		encounter:SetParticipantAlive("p1", false)
		Test.eq(encounter:AliveParticipantCount(), 1, "a downed player must not count as a survivor")

		encounter:SetParticipantAlive("p2", false)
		Test.eq(encounter:AliveParticipantCount(), 0, "no survivors should be reported after a total wipe")
	end)

	Test.it("a total wipe after the detonation terminates the encounter", function()
		local encounter = newEncounter("light_samurai")
		if not encounter then
			return
		end
		encounter:AddParticipant("p1", 10)
		encounter:SetParticipantAlive("p1", false)

		encounter.health = encounter.maxHealth * 0.04
		encounter:_evaluatePhase({})
		local events = run(encounter, Limits.BossSpecial.LightSamuraiDetonationSeconds + 6)

		local wiped = findEvent(events, "EncounterWiped")
		Test.truthy(wiped, "a wipe must emit EncounterWiped so the boss is not left hanging")
		Test.truthy(encounter:IsTerminal(), "the encounter must terminate on a wipe")
	end)
end)


-- ===========================================================================
-- Cross-boss invariants
-- ===========================================================================

Test.describe("All bosses", function()
	Test.it("every world boss can be constructed", function()
		for _, def in Bosses.WorldBosses() do
			local encounter = newEncounter(def.id)
			Test.truthy(encounter, string.format("could not build an encounter for %s", def.id))
		end
	end)

	Test.it("no boss can report an unreachable defeat at full health", function()
		for _, def in Bosses.WorldBosses() do
			local encounter = newEncounter(def.id)
			if encounter then
				encounter:AddParticipant("p1", 10)
				Test.truthy(
					encounter:HasReachableDefeat(),
					string.format("%s starts with no reachable defeat condition", def.id)
				)
			end
		end
	end)

	Test.it("every world boss terminates when simply attacked", function()
		for _, def in Bosses.WorldBosses() do
			local encounter = newEncounter(def.id)
			if not encounter then
				Test.fail(string.format("no encounter for %s", def.id))
			else
				encounter:AddParticipant("p1", 10)
				local guard = 0
				while not encounter:IsTerminal() and guard < 60000 do
					guard += 1
					encounter:ApplyDamage(4000, "p1", nil, false)
					encounter:Tick(0.25)
				end
				Test.truthy(
					encounter:IsTerminal(),
					string.format("%s never terminated (%d iterations)", def.id, guard)
				)
			end
		end
	end)
end)

Test.Finish()

return true
