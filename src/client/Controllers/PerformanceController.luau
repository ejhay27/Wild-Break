--!strict
--[[
	PerformanceController.luau
	Measures client framerate, applies the graphics preset ladder and reports
	back so the server can scale its own simulation.

	The ladder never disables damage, movement, ammunition or resource timers.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Graphics = require(Shared.Config.GraphicsConfig)
local Performance = require(Shared.Config.PerformanceConfig)
local Logger = require(Shared.Utilities.Logger)

local PerformanceController = { Name = "PerformanceController" }

local controllers: any = nil
local frames = 0
local elapsed = 0
local averageFps = 60
local preset = "Auto"
local stage = "Ultra"
local lastReportAt = 0

function PerformanceController.Init(svc: any)
	controllers = svc
	preset = Graphics.Default(svc.NetworkController.Platform()).preset or "Auto"
end

function PerformanceController.AverageFps(): number
	return averageFps
end

function PerformanceController.Stage(): string
	return stage
end

function PerformanceController.Preset(): string
	return preset
end

function PerformanceController.SetPreset(nextPreset: string)
	local settings = Graphics.Get(nextPreset)
	preset = nextPreset
	PerformanceController.Apply(settings)
end

function PerformanceController.Apply(settings: any)
	if type(settings) ~= "table" then
		return
	end
	local lighting = game:GetService("Lighting")
	-- Quality levels are read straight from GraphicsConfig; anything the
	-- engine cannot change at runtime is ignored rather than faked.
	if settings.shadowQuality ~= nil then
		lighting.GlobalShadows = (settings.shadowQuality or 0) > 0
	end
	if settings.bloom == false then
		for _, effect in lighting:GetChildren() do
			if effect:IsA("BloomEffect") then
				effect.Enabled = false
			end
		end
	end
	if type(settings.frameRateCap) == "number" and settings.frameRateCap > 0 then
		-- Roblox exposes the frame cap through the client's FPS manager; the
		-- value is stored for the settings screen to display.
		PerformanceController.FrameCap = settings.frameRateCap
	end
end

function PerformanceController.Start()
	local Network = controllers.NetworkController
	Network.On(Remotes.PerformanceStateUpdated.name, function(payload: any)
		if type(payload) == "table" and payload.stage then
			stage = payload.stage
		end
	end)

	local Settings_ = controllers.SettingsController
	if Settings_ then
		local stored = Settings_.Get("gp_graphics_preset")
		if type(stored) == "string" then
			preset = stored
			PerformanceController.SetPreset(stored)
		end
		Settings_.OnChanged(function(id: string, value: any)
			if id == "gp_graphics_preset" and type(value) == "string" then
				PerformanceController.SetPreset(value)
			end
		end)
	end

	Logger.Info("Performance", string.format("starting at %s preset (%s)", preset, stage))
end

function PerformanceController.Render(delta: number)
	frames += 1
	elapsed += delta
	if elapsed < Performance.Watchdog.sampleWindowSeconds then
		return
	end
	averageFps = frames / elapsed
	frames = 0
	elapsed = 0

	-- Auto preset: step the ladder toward the measured framerate.
	if preset == "Auto" then
		local next = Graphics.AutoStep(preset, averageFps)
		if next ~= preset then
			preset = next
			PerformanceController.Apply(Graphics.Get(next))
		end
	end

	-- Report periodically so the server can degrade its own simulation.
	local now = os.clock()
	if now - lastReportAt >= Performance.Watchdog.autoAdjustSampleSeconds then
		lastReportAt = now
		controllers.NetworkController.Fire(Remotes.ClientPerformanceReport.name, {
			fps = averageFps,
			preset = preset,
			memoryMb = 0,
		})
	end
end

return PerformanceController
