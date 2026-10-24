--!strict
--[[
	PerformanceConfig.luau
	Every performance budget and the degradation ladder.

	The ladder always preserves core systems: damage, movement, ammunition and
	resource respawn timers are NEVER disabled. Non-essential simulation
	(distant beasts, decorative effects, crowd) is reduced first.

	Pure data plus pure functions: no Roblox globals, so the behaviour is
	unit-testable headlessly.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Performance = {}

-- Ordered from healthiest to most degraded. `Performance.Watchdog` moves down
-- this list when framerates fall and back up when they recover.
Performance.StageOrder = {
	Enums.PerformanceStage.Ultra,
	Enums.PerformanceStage.High,
	Enums.PerformanceStage.Medium,
	Enums.PerformanceStage.Low,
	Enums.PerformanceStage.Minimal,
}

Performance.Budgets = {
	simplifiedBehaviourRadiusStuds = 420,
	maxActiveBeastsPerRegion = Limits.Performance.MaxActiveBeastsPerRegion,
	beastSimRadiusStuds = Limits.Performance.BeastSimRadiusStuds,
	maxParticlesPerEffect = Limits.Performance.MaxParticlesPerEffect,
	effectCleanupIntervalSeconds = Limits.Performance.EffectCleanupIntervalSeconds,
	maxActiveSoundsPerCategory = Limits.Performance.MaxActiveSoundsPerCategory,
	maxConcurrentTweens = Limits.Performance.MaxConcurrentTweens,
}

-- Per-stage multipliers applied to the budgets above.
Performance.Stages = {
	[Enums.PerformanceStage.Ultra] = {
		scale = 1.0,
		heartbeatRate = 60,
		reducedVfx = false,
		beastScale = 1.0,
		simRadiusScale = 1.0,
		particleScale = 1.0,
	},
	[Enums.PerformanceStage.High] = {
		scale = 0.8,
		heartbeatRate = 60,
		reducedVfx = false,
		beastScale = 0.8,
		simRadiusScale = 0.9,
		particleScale = 0.7,
	},
	[Enums.PerformanceStage.Medium] = {
		scale = 0.6,
		heartbeatRate = 30,
		reducedVfx = false,
		beastScale = 0.6,
		simRadiusScale = 0.75,
		particleScale = 0.45,
	},
	[Enums.PerformanceStage.Low] = {
		scale = 0.4,
		heartbeatRate = 20,
		reducedVfx = true,
		beastScale = 0.35,
		simRadiusScale = 0.6,
		particleScale = 0.25,
	},
	[Enums.PerformanceStage.Minimal] = {
		scale = 0.25,
		heartbeatRate = 12,
		reducedVfx = true,
		beastScale = 0.2,
		simRadiusScale = 0.45,
		particleScale = 0.1,
	},
}

-- Server-side watchdog sampling.
Performance.Watchdog = {
	sampleWindowSeconds = 2,
	sampleCount = 8,
	clientLowFpsThreshold = 30,
	-- Below this the server steps the ladder down; above the up threshold it
	-- steps back up. The gap prevents flapping.
	downThresholdFps = Limits.Performance.AutoAdjustDownThreshold,
	upThresholdFps = Limits.Performance.AutoAdjustUpThreshold,
	autoAdjustSampleSeconds = Limits.Performance.AutoAdjustSampleSeconds,
}

export type Budget = {
	stage: string,
	scale: number,
	heartbeatRate: number,
	reducedVfx: boolean,
	beastScale: number,
	simRadiusScale: number,
	particleScale: number,
}

-- Maps a measured framerate onto a degradation stage.
function Performance.StageForFps(fps: number): string
	if not (fps == fps) or fps <= 0 then
		return Enums.PerformanceStage.Minimal
	end
	if fps >= 58 then
		return Enums.PerformanceStage.Ultra
	elseif fps >= 48 then
		return Enums.PerformanceStage.High
	elseif fps >= Limits.Performance.MinAcceptableFps then
		return Enums.PerformanceStage.Medium
	elseif fps >= 22 then
		return Enums.PerformanceStage.Low
	end
	return Enums.PerformanceStage.Minimal
end

-- The full budget for a given framerate.
function Performance.ClientBudget(fps: number): Budget
	local stage = Performance.StageForFps(fps)
	local def = Performance.Stages[stage] or Performance.Stages[Enums.PerformanceStage.Medium]
	return {
		stage = stage,
		scale = def.scale,
		heartbeatRate = def.heartbeatRate,
		reducedVfx = def.reducedVfx,
		beastScale = def.beastScale,
		simRadiusScale = def.simRadiusScale,
		particleScale = def.particleScale,
	}
end

-- Server health evaluation. Returns the stage the server should run at plus
-- the measurements that produced it, so operators can see why.
function Performance.EvaluateHealth(
	fps: number,
	memoryFraction: number,
	activeEntities: number
): { stage: string, fps: number, memoryPressure: boolean, entities: number, throttled: boolean }
	local stage = Performance.StageForFps(fps)
	local memoryPressure = memoryFraction >= 0.85
	if memoryPressure then
		-- Memory pressure can only ever make the stage more conservative.
		local index = table.find(Performance.StageOrder, stage) or #Performance.StageOrder
		index = math.min(#Performance.StageOrder, index + 1)
		stage = Performance.StageOrder[index]
	end
	return {
		stage = stage,
		fps = fps,
		memoryPressure = memoryPressure,
		entities = activeEntities,
		throttled = stage ~= Enums.PerformanceStage.Ultra,
	}
end

-- Moves one step down the ladder (never past Minimal).
function Performance.StepDown(stage: string): string
	local index = table.find(Performance.StageOrder, stage) or 1
	return Performance.StageOrder[math.min(#Performance.StageOrder, index + 1)]
end

-- Moves one step up the ladder (never past Ultra).
function Performance.StepUp(stage: string): string
	local index = table.find(Performance.StageOrder, stage) or #Performance.StageOrder
	return Performance.StageOrder[math.max(1, index - 1)]
end

-- Core systems are never disabled, at any stage. This is asserted by the
-- config spec so a future tuning change cannot quietly break it.
Performance.CoreSystemsAlwaysEnabled = {
	damage = true,
	movement = true,
	ammunition = true,
	resourceRespawnTimers = true,
}

function Performance.ValidateAll(): { string }
	local problems = {}

	for _, stage in Performance.StageOrder do
		if not Performance.Stages[stage] then
			table.insert(problems, string.format("stage %s has no budget", tostring(stage)))
		end
	end

	for stage, def in Performance.Stages do
		if def.scale <= 0 or def.scale > 1 then
			table.insert(problems, string.format("stage %s scale out of range: %s", tostring(stage), tostring(def.scale)))
		end
		if def.heartbeatRate < 10 then
			table.insert(
				problems,
				string.format("stage %s heartbeat too low: %s", tostring(stage), tostring(def.heartbeatRate))
			)
		end
		for key, always in Performance.CoreSystemsAlwaysEnabled do
			if not always then
				table.insert(problems, string.format("core system %s must never be disabled", key))
			end
		end
	end

	-- The ladder must be monotonically degrading.
	for index = 2, #Performance.StageOrder do
		local healthy = Performance.Stages[Performance.StageOrder[index - 1]]
		local degraded = Performance.Stages[Performance.StageOrder[index]]
		if healthy and degraded and degraded.scale >= healthy.scale then
			table.insert(
				problems,
				string.format(
					"stage %s must be stricter than %s",
					Performance.StageOrder[index],
					Performance.StageOrder[index - 1]
				)
			)
		end
	end

	if Performance.Watchdog.downThresholdFps >= Performance.Watchdog.upThresholdFps then
		table.insert(problems, "watchdog down threshold must be below the up threshold to avoid flapping")
	end

	return problems
end

return Performance
