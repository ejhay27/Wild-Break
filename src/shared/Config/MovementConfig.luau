--!strict
--[[
	MovementConfig.luau
	Stamina, traversal skills, the Quick Drop glide and fall damage.

	The glide is a flying-squirrel style membrane glide: the player keeps
	horizontal speed by converting height into distance, can steer, can dive
	for speed and must land deliberately. It is NOT a parachute: it never
	stops a fall, never lets the player climb, and never cancels fall damage
	unless the landing is inside the configured grace window.
]]

local Registry = require(script.Parent.Registry)
local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Movement = {}

export type MovementSkillDef = {
	id: string,
	displayName: string,
	kind: string,
	unlockLevel: number,
	staminaCost: number,
	cooldownSeconds: number,
	durationSeconds: number?,
	maxCharges: number,
	-- Server-authoritative: the client requests, the server simulates.
	serverSimulated: boolean,
	cancelsFallDamage: boolean,
	description: string,
}

local entries: { [string]: MovementSkillDef } = {
	["sprint"] = {
		id = "sprint",
		displayName = "Sprint",
		kind = Enums.MovementSkill.Sprint,
		unlockLevel = 1,
		staminaCost = 9,
		cooldownSeconds = 0,
		durationSeconds = nil,
		maxCharges = 1,
		serverSimulated = false,
		cancelsFallDamage = false,
		description = "Sustained run. Drains stamina; cannot be used while overloaded.",
	},
	["crouch"] = {
		id = "crouch",
		displayName = "Crouch / Slide",
		kind = Enums.MovementSkill.Slide,
		unlockLevel = 1,
		staminaCost = 6,
		cooldownSeconds = Limits.Movement.SlideCooldownSeconds,
		durationSeconds = Limits.Movement.SlideDurationSeconds,
		maxCharges = 1,
		serverSimulated = false,
		cancelsFallDamage = false,
		description = "Sliding keeps momentum and lowers the hitbox briefly.",
	},
	["dodge"] = {
		id = "dodge",
		displayName = "Combat Dodge",
		kind = Enums.MovementSkill.Dodge,
		unlockLevel = 1,
		staminaCost = 18,
		cooldownSeconds = Limits.Movement.DodgeCooldownSeconds,
		durationSeconds = Limits.Movement.DodgeDurationSeconds,
		maxCharges = 1,
		serverSimulated = true,
		cancelsFallDamage = false,
		description = "Short i-frame dash. Costs stamina and has a real cooldown.",
	},
	["double_jump"] = {
		id = "double_jump",
		displayName = "Double Jump",
		kind = Enums.MovementSkill.DoubleJump,
		unlockLevel = 6,
		staminaCost = 12,
		cooldownSeconds = 0,
		durationSeconds = nil,
		maxCharges = 1,
		serverSimulated = false,
		cancelsFallDamage = false,
		description = "A second jump that refreshes on landing.",
	},
	["aerial_dash"] = {
		id = "aerial_dash",
		displayName = "Aerial Dash",
		kind = Enums.MovementSkill.AerialDash,
		unlockLevel = 14,
		staminaCost = 22,
		cooldownSeconds = Limits.Movement.AerialDashCooldownSeconds,
		durationSeconds = 0.35,
		maxCharges = 1,
		serverSimulated = true,
		cancelsFallDamage = false,
		description = "A burst of horizontal speed in mid-air.",
	},
	["grapple"] = {
		id = "grapple",
		displayName = "Grapple",
		kind = Enums.MovementSkill.Grapple,
		unlockLevel = 22,
		staminaCost = 26,
		cooldownSeconds = Limits.Movement.GrappleCooldownSeconds,
		durationSeconds = nil,
		maxCharges = 1,
		serverSimulated = true,
		cancelsFallDamage = false,
		description = "Pulls the player to a valid anchor point. Anchors are validated server-side.",
	},
	["phase_blink"] = {
		id = "phase_blink",
		displayName = "Phase Blink",
		kind = Enums.MovementSkill.PhaseBlink,
		unlockLevel = 30,
		staminaCost = 30,
		cooldownSeconds = Limits.Movement.PhaseBlinkCooldownSeconds,
		durationSeconds = nil,
		maxCharges = 1,
		serverSimulated = true,
		cancelsFallDamage = false,
		description = "Teleports up to the configured distance. Never moves the player out of bounds.",
	},
	["glide"] = {
		id = "glide",
		displayName = "Quick Drop Glide",
		kind = Enums.MovementSkill.Glide,
		unlockLevel = 1,
		staminaCost = 0,
		cooldownSeconds = 0,
		durationSeconds = Limits.Movement.GlideMaxDurationSeconds,
		maxCharges = 1,
		serverSimulated = false,
		cancelsFallDamage = true,
		description = "Flying-squirrel membrane glide used to enter a region from the drop ship.",
	},
}

local Registry_ = Registry.new("MovementSkill", entries, { "id", "displayName", "kind" })

function Movement.Get(id: string): MovementSkillDef?
	return Registry_:Get(id)
end

function Movement.List(): { MovementSkillDef }
	return Registry_:List()
end

function Movement.UnlockedAt(level: number): { MovementSkillDef }
	return Registry_:Filter(function(def)
		return def.unlockLevel <= level
	end)
end

function Movement.IsUnlocked(id: string, level: number): boolean
	local def = Registry_:Get(id)
	return def ~= nil and def.unlockLevel <= level
end

-- ---------------------------------------------------------------------------
-- Stamina
-- ---------------------------------------------------------------------------

Movement.Stamina = {
	max = 100,
	regenPerSecond = 14,
	regenDelaySeconds = 0.7,
	-- Below this fraction the player cannot start a costly action.
	minimumToSprint = 0.05,
	exhaustedLockSeconds = 1.2,
	-- Sprinting while overloaded is prevented by the inventory, not here.
}

function Movement.CanAfford(skillId: string, stamina: number, level: number): boolean
	if not Movement.IsUnlocked(skillId, level) then
		return false
	end
	local def = Registry_:Get(skillId)
	if not def then
		return false
	end
	return stamina >= def.staminaCost
end

-- ---------------------------------------------------------------------------
-- Glide (Quick Drop)
-- ---------------------------------------------------------------------------

Movement.Glide = {
	forwardSpeed = Limits.Movement.GlideForwardSpeed,
	maxSpeed = Limits.Movement.GlideMaxSpeed,
	minSpeed = Limits.Movement.GlideMinSpeed,
	descentSpeed = Limits.Movement.GlideDescentSpeed,
	turnSpeed = Limits.Movement.GlideTurnSpeed,
	pitchMin = Limits.Movement.GlidePitchMin,
	pitchMax = Limits.Movement.GlidePitchMax,
	maxDurationSeconds = Limits.Movement.GlideMaxDurationSeconds,
	landingGraceSeconds = Limits.Movement.GlideLandingGraceSeconds,
	-- Diving trades height for speed; pulling up trades speed for height.
	diveAcceleration = 46,
	liftPerSpeedUnit = 0.22,
	-- Minimum altitude at which the membrane can re-open.
	minimumDeployHeightStuds = 12,
	-- The glide ends on contact with the ground; it never hovers.
	endsOnGroundContact = true,
}

-- ---------------------------------------------------------------------------
-- Fall damage (server computed from a validated velocity, never client trust)
-- ---------------------------------------------------------------------------

Movement.FallDamage = {
	safeSpeed = 62,
	maxSpeed = Limits.Movement.MaxFallDamageSpeed,
	damagePerSpeedUnit = Limits.Movement.FallDamagePerSpeedUnit,
	-- Deployment landings and glide landings are forgiving on purpose.
	glideLandingGraceSeconds = Limits.Movement.GlideLandingGraceSeconds,
	waterCancelsFallDamage = true,
	maxDamageRatio = 0.85, -- falling never deals more than 85% of max health
}

function Movement.FallDamageFor(impactSpeed: number, maxHealth: number, grace: boolean?): number
	if grace then
		return 0
	end
	if impactSpeed <= Movement.FallDamage.safeSpeed then
		return 0
	end
	local over = math.min(impactSpeed, Movement.FallDamage.maxSpeed) - Movement.FallDamage.safeSpeed
	local damage = over * Movement.FallDamage.damagePerSpeedUnit
	return math.min(damage, maxHealth * Movement.FallDamage.maxDamageRatio)
end

-- ---------------------------------------------------------------------------
-- Server validation of reported positions (anti teleport / speed hacking)
-- ---------------------------------------------------------------------------

Movement.Validation = {
	maxDistancePerSecond = Limits.Movement.MaxTeleportDistancePerSecond,
	sampleIntervalSeconds = Limits.Movement.PositionValidationIntervalSeconds,
	-- How far a client position may deviate from the server simulated one
	-- before the server snaps the player back.
	maxCorrectionDistanceStuds = 14,
	graceViolations = 3,
	-- Vertical movement is validated separately so gliding and grappling are
	-- not punished by the horizontal check.
	maxVerticalDistancePerSecond = 260,
}

function Movement.IsPlausibleMove(distance: number, seconds: number, vertical: number?): boolean
	if seconds <= 0 then
		return distance <= Movement.Validation.maxCorrectionDistanceStuds
	end
	if distance / seconds > Movement.Validation.maxDistancePerSecond then
		return false
	end
	if vertical and vertical / seconds > Movement.Validation.maxVerticalDistancePerSecond then
		return false
	end
	return true
end

function Movement.ValidateAll(): { string }
	local problems = Registry.Validate(Registry_)
	if not Registry_:Has("glide") then
		table.insert(problems, "[Movement] the Quick Drop glide is missing")
	end
	local glide = Registry_:Get("glide")
	if glide and not glide.cancelsFallDamage then
		table.insert(problems, "[Movement] glide landings must be forgiving (cancelsFallDamage)")
	end
	if Movement.Glide.maxDurationSeconds <= 0 then
		table.insert(problems, "[Movement] glide needs a positive maximum duration")
	end
	if Movement.Glide.minSpeed > Movement.Glide.maxSpeed then
		table.insert(problems, "[Movement] glide minimum speed exceeds its maximum speed")
	end
	for _, def in Movement.List() do
		if def.staminaCost < 0 then
			table.insert(problems, string.format("[Movement] %s has a negative stamina cost", def.id))
		end
		if def.cooldownSeconds < 0 then
			table.insert(problems, string.format("[Movement] %s has a negative cooldown", def.id))
		end
		if def.maxCharges < 1 then
			table.insert(problems, string.format("[Movement] %s needs at least one charge", def.id))
		end
		if def.kind ~= Enums.MovementSkill.Glide and def.cancelsFallDamage then
			table.insert(problems, string.format("[Movement] %s must not cancel fall damage", def.id))
		end
		if def.kind ~= Enums.MovementSkill.Glide and not def.serverSimulated and def.kind ~= Enums.MovementSkill.Sprint and def.kind ~= Enums.MovementSkill.Slide and def.kind ~= Enums.MovementSkill.DoubleJump then
			table.insert(problems, string.format("[Movement] %s must be server simulated", def.id))
		end
	end
	if Movement.FallDamageFor(10000, 100, false) > 100 then
		table.insert(problems, "[Movement] fall damage can exceed maximum health")
	end
	if Movement.FallDamageFor(Limits.Movement.MaxFallDamageSpeed, 100, true) ~= 0 then
		table.insert(problems, "[Movement] fall damage ignores the grace window")
	end
	return problems
end

Movement.Registry = Registry_
return Movement
