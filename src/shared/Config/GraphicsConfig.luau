--!strict
--[[
	GraphicsConfig.luau
	Graphics presets from Auto to Ultra, plus per-platform defaults and the
	automatic quality controller used when the preset is set to Auto.

	Every setting is a plain, serialisable value so it can be stored in the
	player's settings and applied by the client GraphicsService without any
	special-casing.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Graphics = {}

export type GraphicsSettings = {
	preset: string,
	renderDistanceStuds: number,
	shadowQuality: number, -- 0 = off .. 4 = ultra
	textureQuality: number, -- 0 = low .. 3 = ultra
	particleDensity: number, -- 0..1
	foliageDensity: number, -- 0..1
	waterQuality: number, -- 0..3
	antiAliasing: boolean,
	bloom: boolean,
	depthOfField: boolean,
	motionBlur: boolean,
	volumetricFog: boolean,
	screenSpaceReflections: boolean,
	frameRateCap: number, -- 30 | 60 | 120 | 0 = uncapped
	resolutionScale: number, -- 0.5 .. 1.0
	-- Mobile-only toggles (ignored on desktop)
	mobileFoliage: boolean,
	mobileShadows: boolean,
}

local function settings(
	preset: string,
	renderDistance: number,
	shadow: number,
	texture: number,
	particle: number,
	foliage: number,
	water: number,
	post: boolean,
	frameRateCap: number,
	resolutionScale: number
): GraphicsSettings
	return {
		preset = preset,
		renderDistanceStuds = renderDistance,
		shadowQuality = shadow,
		textureQuality = texture,
		particleDensity = particle,
		foliageDensity = foliage,
		waterQuality = water,
		antiAliasing = post,
		bloom = post,
		depthOfField = post,
		motionBlur = false,
		volumetricFog = post,
		screenSpaceReflections = post,
		frameRateCap = frameRateCap,
		resolutionScale = resolutionScale,
		mobileFoliage = false,
		mobileShadows = false,
	}
end

Graphics.Presets = {
	[Enums.GraphicsPreset.VeryLow] = settings("VeryLow", 600, 0, 0, 0.25, 0.2, 0, false, 30, 0.6),
	[Enums.GraphicsPreset.Low] = settings("Low", 1000, 1, 1, 0.4, 0.35, 1, false, 30, 0.75),
	[Enums.GraphicsPreset.Medium] = settings("Medium", 1600, 2, 2, 0.6, 0.55, 2, true, 60, 0.85),
	[Enums.GraphicsPreset.High] = settings("High", 2400, 3, 3, 0.85, 0.8, 3, true, 60, 1.0),
	[Enums.GraphicsPreset.Ultra] = settings("Ultra", 3600, 4, 3, 1.0, 1.0, 3, true, 120, 1.0),
}

-- Auto starts at Medium and is adjusted by the controller below.
Graphics.Presets[Enums.GraphicsPreset.Auto] = settings("Auto", 1600, 2, 2, 0.6, 0.55, 2, true, 60, 0.85)

Graphics.PlatformDefaults = {
	PC = Enums.GraphicsPreset.Auto,
	Mobile = Enums.GraphicsPreset.Low,
	Console = Enums.GraphicsPreset.Medium,
	Unknown = Enums.GraphicsPreset.Medium,
}

Graphics.Auto = {
	sampleSeconds = Limits.Performance.AutoAdjustSampleSeconds,
	downThreshold = Limits.Performance.AutoAdjustDownThreshold,
	upThreshold = Limits.Performance.AutoAdjustUpThreshold,
	minAcceptableFps = Limits.Performance.MinAcceptableFps,
	-- Auto never raises quality while a boss encounter is active so the
	-- adjustment cannot stutter through a mechanic.
	pauseDuringBoss = true,
	pauseDuringClanWar = true,
}

function Graphics.Default(platform: string?): GraphicsSettings
	local preset = Graphics.PlatformDefaults[platform or "Unknown"] or Enums.GraphicsPreset.Medium
	return Graphics.Presets[preset]
end

function Graphics.Get(preset: string): GraphicsSettings
	return Graphics.Presets[preset] or Graphics.Presets[Enums.GraphicsPreset.Medium]
end

-- Clamps an arbitrary table into a valid settings table. Used when loading
-- settings from storage so a corrupt or hand-edited save cannot crash the game.
function Graphics.Sanitise(raw: { [string]: any }?): GraphicsSettings
	local base = Graphics.Presets[Enums.GraphicsPreset.Medium]
	if type(raw) ~= "table" then
		return base
	end
	local preset = raw.preset
	if type(preset) ~= "string" or Graphics.Presets[preset] == nil then
		preset = Enums.GraphicsPreset.Medium
	end
	local out = Graphics.Presets[preset]
	local function numberField(key: string, minimum: number, maximum: number, fallback: number): number
		local value = raw[key]
		if type(value) ~= "number" or value ~= value then
			return fallback
		end
		return math.clamp(value, minimum, maximum)
	end
	local function boolField(key: string, fallback: boolean): boolean
		local value = raw[key]
		if type(value) ~= "boolean" then
			return fallback
		end
		return value
	end
	return {
		preset = preset,
		renderDistanceStuds = numberField("renderDistanceStuds", 300, 5000, out.renderDistanceStuds),
		shadowQuality = math.floor(numberField("shadowQuality", 0, 4, out.shadowQuality)),
		textureQuality = math.floor(numberField("textureQuality", 0, 3, out.textureQuality)),
		particleDensity = numberField("particleDensity", 0, 1, out.particleDensity),
		foliageDensity = numberField("foliageDensity", 0, 1, out.foliageDensity),
		waterQuality = math.floor(numberField("waterQuality", 0, 3, out.waterQuality)),
		antiAliasing = boolField("antiAliasing", out.antiAliasing),
		bloom = boolField("bloom", out.bloom),
		depthOfField = boolField("depthOfField", out.depthOfField),
		motionBlur = boolField("motionBlur", out.motionBlur),
		volumetricFog = boolField("volumetricFog", out.volumetricFog),
		screenSpaceReflections = boolField("screenSpaceReflections", out.screenSpaceReflections),
		frameRateCap = numberField("frameRateCap", 0, 240, out.frameRateCap),
		resolutionScale = numberField("resolutionScale", 0.5, 1, out.resolutionScale),
		mobileFoliage = boolField("mobileFoliage", out.mobileFoliage),
		mobileShadows = boolField("mobileShadows", out.mobileShadows),
	}
end

-- The Auto controller: given an average frame rate, step the preset up or down.
function Graphics.AutoStep(currentPreset: string, averageFps: number): string
	if currentPreset == Enums.GraphicsPreset.Auto then
		currentPreset = Enums.GraphicsPreset.Medium
	end
	local index = 1
	for position, preset in ipairs(Enums.GraphicsPresetOrder) do
		if preset == currentPreset then
			index = position
			break
		end
	end
	if averageFps < Graphics.Auto.downThreshold then
		return Enums.GraphicsPresetOrder[math.max(2, index - 1)]
	elseif averageFps > Graphics.Auto.upThreshold then
		return Enums.GraphicsPresetOrder[math.min(#Enums.GraphicsPresetOrder, index + 1)]
	end
	return currentPreset
end

function Graphics.ValidateAll(): { string }
	local problems = {}
	for _, preset in ipairs(Enums.GraphicsPresetOrder) do
		local def = Graphics.Presets[preset]
		if not def then
			table.insert(problems, string.format("[Graphics] preset %s is not defined", preset))
			continue
		end
		if def.renderDistanceStuds <= 0 then
			table.insert(problems, string.format("[Graphics] %s has a non-positive render distance", preset))
		end
		if def.resolutionScale < 0.5 or def.resolutionScale > 1 then
			table.insert(problems, string.format("[Graphics] %s has an out-of-range resolution scale", preset))
		end
		if def.shadowQuality < 0 or def.shadowQuality > 4 then
			table.insert(problems, string.format("[Graphics] %s has an invalid shadow quality", preset))
		end
	end
	-- Presets must get monotonically richer.
	for index = 3, #Enums.GraphicsPresetOrder do
		local lower = Graphics.Presets[Enums.GraphicsPresetOrder[index - 1]]
		local higher = Graphics.Presets[Enums.GraphicsPresetOrder[index]]
		if lower and higher and higher.renderDistanceStuds < lower.renderDistanceStuds then
			table.insert(problems, string.format("[Graphics] %s has a shorter render distance than %s", Enums.GraphicsPresetOrder[index], Enums.GraphicsPresetOrder[index - 1]))
		end
	end
	local sanitised = Graphics.Sanitise({ preset = "NotAPreset", renderDistanceStuds = 999999, resolutionScale = -4 })
	if sanitised.preset ~= Enums.GraphicsPreset.Medium then
		table.insert(problems, "[Graphics] Sanitise does not fall back to Medium")
	end
	if sanitised.renderDistanceStuds > 5000 or sanitised.resolutionScale < 0.5 then
		table.insert(problems, "[Graphics] Sanitise does not clamp values")
	end
	return problems
end

return Graphics
