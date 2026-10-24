--!strict
--[[
	Limits.luau
	Central tuning constants. Nothing else in the game may hardcode a cooldown,
	a respawn timer, a capacity or a rate limit: everything reads from here so
	balance passes are a single-file change and so the automated tests can
	assert the documented rules (for example the 180 second resource respawn).
]]

local Limits = {}

-- Resource gathering -------------------------------------------------------
Limits.Resource = {
	OrdinaryRespawnSeconds = 180, -- EXACT three minute rule for trees / common ore
	RareRespawnSeconds = 900,
	SpecialRespawnSeconds = 3600,
	HarvestRangeStuds = 14,
	HarvestAngleTolerance = math.rad(75),
	MinHarvestSeconds = 0.35,
	MaxConcurrentHarvestsPerPlayer = 1,
	HarvestReservationSeconds = 12,
	RespawnClearRadiusStuds = 6, -- nodes never respawn on top of a player
	MaxNodesSimulatedAtOnce = 320,
	DormantCheckIntervalSeconds = 5,
}

-- Combat -------------------------------------------------------------------
Limits.Combat = {
	MaxFireRangeStuds = 1200,
	MaxMeleeRangeStuds = 12,
	MaxDamagePerHit = 250000,
	ServerTickRateHz = 30,
	FireRequestRatePerSecond = 30,
	ReloadMinSeconds = 0.35,
	HeadshotMultiplier = 2.0,
	WeakPointMultiplier = 1.75,
	ArmorDamageMultiplier = 0.55,
	-- Area damage is deliberately weaker per target than a direct hit.
	AreaDamageMultiplier = 0.75,
	ArmorConstant = 220,
	ShieldDamageMultiplier = 1.0,
	CritChanceBase = 0.05,
	CritMultiplier = 1.5,
	FalloffStartRatio = 0.6,
	FalloffMinMultiplier = 0.35,
	DamageNumberLifetime = 1.1,
	MaxStatusEffectsPerTarget = 12,
	CombatLogEntriesPerTarget = 40,
}

-- Ultimate -----------------------------------------------------------------
Limits.Ultimate = {
	MaxCharge = 100,
	BaseChargePerDamage = 0.055,
	WeakPointChargeBonus = 0.06,
	KillCharge = 6,
	AssistCharge = 3,
	ObjectiveCharge = 12,
	CombatTickCharge = 0.35,
	CombatTickSeconds = 1.0,
	IdleDecayPerSecond = 0,
	ActivationGraceSeconds = 1.2,
	TypicalCooldownSeconds = 45,
	MaxActiveUltimateSeconds = 12,
	SelfDamageChargeFactor = 0, -- self damage never grants charge
	InvalidTargetChargeFactor = 0,
}

-- Abilities ----------------------------------------------------------------
Limits.Ability = {
	SlotCount = 4,
	MinCooldownSeconds = 3,
	MaxCooldownSeconds = 180,
	MaxRangeStuds = 160,
	GlobalActivationCooldownSeconds = 0.35,
	DuplicateCastWindowSeconds = 0.2,
}

-- Gadgets ------------------------------------------------------------------
Limits.Gadget = {
	ReusableSlots = 2,
	ConsumableSlots = 3,
	MaxStackPerConsumable = 20,
	MaxDeployedPerPlayer = 4,
	MaxDeployedPerServer = 48,
	DeployRangeStuds = 60,
	BaseCooldownSeconds = 20,
}

-- Inventory ----------------------------------------------------------------
Limits.Inventory = {
	DefaultSlots = 60,
	MaxSlots = 200,
	DefaultStashSlots = 80,
	MaxStashSlots = 240,
	MaxDistinctStacks = 400,
	DefaultStackSize = 999,
	OreStackSize = 999,
	WeaponSlots = 12,
	MaxEquippedWeapons = 3,
	MaxTradesPerMinute = 6,
}

-- Persistence --------------------------------------------------------------
Limits.Persistence = {
	SchemaVersion = 4,
	AutoSaveSeconds = 120,
	SaveRetryAttempts = 4,
	SaveRetryBaseSeconds = 2,
	SaveRetryMaxSeconds = 30,
	SessionLockSeconds = 180,
	LoadTimeoutSeconds = 20,
	MaxDataSizeBytes = 200_000,
	BudgetWarnMicros = 0.65,
}

-- Networking ---------------------------------------------------------------
Limits.Networking = {
	DefaultRatePerSecond = 30,
	ViolationsBeforeKick = 12,
	MaxUnscheduledArguments = 8,
	MaxRequestsPerSecond = 30,
	BurstAllowance = 12,
	MaxPayloadArguments = 12,
	MaxStringArgumentLength = 512,
	MaxPositionMagnitude = 1e6,
	MaxDistanceValidationStuds = 1400,
}

-- Progression --------------------------------------------------------------
Limits.Progression = {
	MaxPlayerLevel = 120,
	BaseExperienceForLevel = 120,
	ExperienceGrowth = 1.085,
	MaxResearchRank = 25,
	MaxAbilityTier = 5,
	DailyRewardCooldownSeconds = 82800,
}

-- Companions ---------------------------------------------------------------
Limits.Companion = {
	MaxActiveOpenWorld = 3,
	MaxActiveDungeon = 1,
	MaxStoredCompanions = 40,
	MaxStoredEggs = 20,
	MaxLevel = 60,
	FollowDistanceStuds = 8,
	CombatLeashStuds = 90,
	TameHealthThreshold = 0.3,
	TameMinSeconds = 6,
	TameMaxSeconds = 20,
	SimplifiedBehaviourDistanceStuds = 220,
}

-- Bosses -------------------------------------------------------------------
Limits.Boss = {
	RespawnSeconds = 600, -- ten minute open-world boss reset
	DungeonBossRespawnSeconds = 600,
	EncounterTimeoutSeconds = 1800,
	AbandonResetSeconds = 120,
	MaxParticipants = 32,
	ParticipationDamageShareRequired = 0.02,
	MinParticipantsForRewardScaling = 1,
	RewardCooldownSeconds = 600,
	PhaseTransitionMaxSeconds = 12,
	SafeSpawnDistanceStuds = 220,
	AggroRadiusStuds = 320,
	LeashRadiusStuds = 520,
	DespawnAfterNoPlayersSeconds = 120,
}

Limits.BossSpecial = {
	-- Pyr axis: cocoon shield is explicitly 5x the configured BASELINE shield
	-- capacity. Never 5x remaining health.
	PyraxisCocoonShieldMultiplier = 5,
	PyraxisCocoonTransformationSeconds = 45,
	PyraxisBaselineShieldCapacity = 12000,
	PyraxisHeatShieldCapacity = 9000,
	PyraxisStage2Threshold = 0.5,
	PyraxisStage3Threshold = 0.1,
	PyraxisBurnDamagePerSecond = 12,
	PyraxisBurnDurationSeconds = 4,
	PyraxisFinalFormDamageScale = 1.35,

	-- Light Samurai: staged transformation thresholds.
	LightSamuraiStage2Threshold = 0.5,
	LightSamuraiStage3Threshold = 0.25,
	LightSamuraiStage4Threshold = 0.05,
	LightSamuraiDetonationSeconds = 12,
	LightSamuraiDetonationRadiusStuds = 260,
	LightSamuraiDetonationDamage = 9000,
	-- Grace period after the explosion for the server to apply the damage and
	-- report who actually died, before the outcome is decided.
	LightSamuraiSurvivorCheckSeconds = 3,

	-- Parallax safeguards.
	ParallaxMaxAbsentSeconds = 6,
	ParallaxMaxGlitchSeconds = 3.5,
	ParallaxTeleportMaxStuds = 220,
	ParallaxPhaseTimeoutSeconds = 14,
	ParallaxStage2Threshold = 0.66,
	ParallaxStage3Threshold = 0.38,
	ParallaxStage4Threshold = 0.15,
	ParallaxMinVulnerableWindowSeconds = 5,
}

-- Regions / hazards --------------------------------------------------------
Limits.Hazard = {
	TickSeconds = 1.0,
	HeatDamagePerSecond = 4,
	ColdDamagePerSecond = 4,
	ContaminationDamagePerSecond = 5,
	VoidAnomalyDamagePerSecond = 6,
	UnderwaterOxygenDrainPerSecond = 3.2,
	ProtectionMitigationMax = 0.9,
	SafeZoneGraceSeconds = 2,
}

Limits.Region = {
	DiscoveryRadiusStuds = 260,
	AmbienceUpdateSeconds = 4,
	CrossRegionTravelWarningDistanceStuds = 900,
}

-- Clan wars ----------------------------------------------------------------
Limits.ClanWar = {
	MaxTotalPlayers = 30,
	SupportedConfigurations = {
		{ teams = 2, perTeam = 1 },
		{ teams = 2, perTeam = 5 },
		{ teams = 2, perTeam = 10 },
		{ teams = 2, perTeam = 15 },
		{ teams = 3, perTeam = 10 },
	},
	QueueTimeoutSeconds = 300,
	MatchDurationSeconds = 900,
	ScoreLimit = 1000,
	MaxActiveMatches = 4,
	DisconnectGraceSeconds = 120,
	RejoinWindowSeconds = 180,
}

Limits.Clan = {
	MaxNameLength = 24,
	MinNameLength = 3,
	MaxMembers = 200,
	MaxInvitesOutstanding = 50,
	InviteExpirySeconds = 600,
	MaxOfficers = 12,
}

-- Deployment / movement ----------------------------------------------------
Limits.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 30,
	CrouchSpeed = 9,
	SwimSpeed = 14,
	GlideForwardSpeed = 58,
	GlideMaxSpeed = 96,
	GlideMinSpeed = 26,
	GlideDescentSpeed = 34,
	GlideTurnSpeed = 2.4,
	GlidePitchMin = math.rad(-70),
	GlidePitchMax = math.rad(35),
	GlideMaxDurationSeconds = 45,
	GlideLandingGraceSeconds = 2.5, -- no fall damage right after a glide landing
	DodgeSpeed = 62,
	DodgeDurationSeconds = 0.32,
	DodgeCooldownSeconds = 1.6,
	SlideDurationSeconds = 0.65,
	SlideCooldownSeconds = 0.9,
	VaultMaxHeightStuds = 6,
	ClimbSpeed = 11,
	MaxTeleportDistancePerSecond = 220, -- server anti-teleport validation
	PositionValidationIntervalSeconds = 0.5,
	MaxFallDamageSpeed = 140,
	FallDamagePerSpeedUnit = 0.9,
	AerialDashCooldownSeconds = 6,
	GrappleCooldownSeconds = 9,
	PhaseBlinkCooldownSeconds = 14,
	PhaseBlinkMaxDistanceStuds = 90,
}

-- Boats --------------------------------------------------------------------
Limits.Boat = {
	MaxBoatsPerPlayer = 3,
	MaxSpeedStudsPerSecond = 90,
	Acceleration = 26,
	TurnSpeed = 1.6,
	Durability = 400,
	DockRangeStuds = 24,
	RecoveryAfterSeconds = 30,
}

-- Performance --------------------------------------------------------------
Limits.Performance = {
	TargetFps = 60,
	MinAcceptableFps = 30,
	AutoAdjustSampleSeconds = 6,
	AutoAdjustDownThreshold = 42,
	AutoAdjustUpThreshold = 57,
	MaxActiveBeastsPerRegion = 60,
	MaxActiveNodesPerRegion = 400,
	BeastSimRadiusStuds = 420,
	MaxParticlesPerEffect = 220,
	EffectCleanupIntervalSeconds = 2,
	MaxActiveSoundsPerCategory = 24,
	MaxConcurrentTweens = 120,
}

-- Survival / defeat --------------------------------------------------------
Limits.Survival = {
	MaxHealth = 100,
	BaseHealthRegenPerSecond = 0,
	HealthRegenDelaySeconds = 6,
	ExpeditionLossRatio = 0.15, -- light, configurable penalty on unbanked resources
	ExpeditionLossMaxStacks = 8,
	RespawnDelaySeconds = 5,
	RespawnAtHaven = true,
	HungerDrainPerMinute = 0.35,
	ThirstDrainPerMinute = 0.55,
	StaminaMax = 100,
	StaminaDrainSprintPerSecond = 12,
	StaminaRegenPerSecond = 16,
}

-- Crafting -----------------------------------------------------------------
Limits.Crafting = {
	MaxConcurrentPerPlayer = 1,
	DefaultCraftSeconds = 1.5,
	MaxRecipeOutput = 99,
	QueueTimeoutSeconds = 30,
}

-- Audio --------------------------------------------------------------------
Limits.Audio = {
	MaxConcurrentSounds = 48,
	MaxSoundsPerEmitter = 4,
	DefaultRollOffMaxDistance = 220,
	MinRetriggerSeconds = 0.04,
}

Limits.Squad = {
	MaxSize = 4,
	InviteTimeoutSeconds = 60,
	LeaderReassignOnLeave = true,
}

return Limits
