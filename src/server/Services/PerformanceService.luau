--!strict
--[[
	PerformanceService.luau
	Watches server and client performance and applies the degradation ladder
	defined in PerformanceConfig before the experience becomes unplayable.

	The ladder always preserves core systems: damage, movement, ammunition and
	resource respawn timers are never disabled. Non-essential simulation
	(remote beasts, crowd, decorative effects) is what gets reduced first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.Utilities.Logger)
local Performance = require(Shared.Config.PerformanceConfig)

local PerformanceService = {
	Name = "PerformanceService",
}

export type Budget = {
	scale: number,
	stage: string,
	heartbeatRate: number,
	simplifiedRadiusStuds: number,
	reducedVfx: boolean,
}

local budgets: { [Player]: Budget } = {}
local services: any = nil
local stage = "Full"
local frameSamples: { number } = {}

function PerformanceService.Init(svc: any)
	services = svc
end

function PerformanceService.Start(svc: any)
	services = svc
	task.spawn(function()
		while true do
			task.wait(Performance.Watchdog.sampleWindowSeconds)
			PerformanceService.Sample()
		end
	end)
end

function PerformanceService.Sample()
	table.insert(frameSamples, 1 / math.max(1, game:GetService("RunService").Heartbeat:Wait()))
	if #frameSamples > Performance.Watchdog.sampleCount then
		table.remove(frameSamples, 1)
	end
	if #frameSamples < Performance.Watchdog.sampleCount then
		return
	end
	local total = 0
	for _, sample in frameSamples do
		total += sample
	end
	local average = total / #frameSamples
	local health = Performance.EvaluateHealth(1 / average, 0.5, 0)
	local previous = stage
	stage = health.stage
	if previous ~= stage then
		Logger.Warn("PerformanceService", string.format("stage %s -> %s", previous, stage))
		PerformanceService.PushAll()
	end
end

-- Clients report their own framerate; the server applies the matching stage.
function PerformanceService.ReportClient(player: Player, fps: number, memoryMb: number, preset: string?)
	local budget = Performance.ClientBudget(fps)
	budgets[player] = {
		scale = budget.scale,
		stage = budget.stage,
		heartbeatRate = budget.heartbeatRate,
		simplifiedRadiusStuds = Performance.Budgets.simplifiedBehaviourRadiusStuds,
		reducedVfx = budget.reducedVfx,
	}
	services.NetworkService.Fire(player, Remotes.PerformanceStateUpdated.name, {
		stage = budget.stage,
		scale = budget.scale,
		reducedVfx = budget.reducedVfx,
	})
	if fps < Performance.Watchdog.clientLowFpsThreshold then
		Logger.Debug("PerformanceService", string.format("%s is at %d fps (preset %s)", tostring(player.Name), fps, tostring(preset)))
	end
	_ = memoryMb
end

function PerformanceService.PushAll()
	for _, player in game:GetService("Players"):GetPlayers() do
		services.NetworkService.Fire(player, Remotes.PerformanceStateUpdated.name, { stage = stage })
	end
end

function PerformanceService.BudgetFor(player: Player): Budget
	return budgets[player] or {
		scale = 1,
		stage = stage,
		heartbeatRate = 60,
		simplifiedRadiusStuds = Performance.Budgets.simplifiedBehaviourRadiusStuds,
		reducedVfx = false,
	}
end

function PerformanceService.Stage(): string
	return stage
end

function PerformanceService.OnPlayerRemoving(player: Player)
	budgets[player] = nil
end

return PerformanceService
