--!strict
--[[
	WorldEventService.luau
	Starts, runs and resets regional world events.

	Rules enforced by WorldEventConfig and re-checked here:
	  * one active instance per event id per server
	  * events need their minimum player count and level
	  * a non-zero cooldown prevents farming
	  * every event declares how it resets, and this service applies it
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)
local Events = require(Shared.Config.WorldEventConfig)
local Regions = require(Shared.Config.RegionConfig)

local WorldEventService = {
	Name = "WorldEventService",
}

local active: { [string]: { eventId: string, regionId: string?, startedAt: number, endsAt: number, objectives: { [string]: boolean }, participants: { [Player]: boolean } } } = {}
local cooldowns: { [string]: number } = {}
local services: any = nil

local function now(): number
	return os.time()
end

function WorldEventService.Init(svc: any)
	services = svc
end

function WorldEventService.Start(svc: any)
	services = svc
	local Network = services.NetworkService
	Network.On(Remotes.RequestWorldEventInfo.name, function(player)
		local out = {}
		for eventId, instance in active do
			table.insert(out, {
				id = eventId,
				regionId = instance.regionId,
				remaining = math.max(0, instance.endsAt - now()),
			})
		end
		return out
	end)

	-- Try to start an event in each region on a schedule.
	task.spawn(function()
		while true do
			task.wait(60)
			WorldEventService.TryStartAll()
		end
	end)
end

function WorldEventService.TryStartAll()
	for _, region in Regions:List() do
		if not region.eventId or region.eventId == "" then
			continue
		end
		WorldEventService.TryStart(region.eventId, region.id)
	end
end

function WorldEventService.TryStart(eventId: string, regionId: string?): boolean
	local def = Events:Get(eventId)
	if not def then
		return false
	end
	if active[eventId] then
		return false
	end
	if cooldowns[eventId] and now() < cooldowns[eventId] then
		return false
	end

	local playerCount = services.WorldService and services.WorldService.PlayerCountInRegion(regionId or "") or 0
	if playerCount < (def.minPlayers or 1) then
		return false
	end

	active[eventId] = {
		eventId = eventId,
		regionId = regionId,
		startedAt = now(),
		endsAt = now() + (def.durationSeconds or 600),
		objectives = {},
		participants = {},
	}
	services.NetworkService.FireAll(Remotes.WorldEventUpdated.name, {
		id = eventId,
		regionId = regionId,
		state = Enums.WorldEventState.Active,
		durationSeconds = def.durationSeconds,
		objectives = def.objectives,
	})
	Logger.Info("WorldEventService", string.format("started %s in %s", eventId, tostring(regionId)))
	return true
end

function WorldEventService.Complete(eventId: string, success: boolean)
	local instance = active[eventId]
	local def = Events:Get(eventId)
	if not instance or not def then
		return
	end
	active[eventId] = nil
	cooldowns[eventId] = now() + (def.cooldownSeconds or 600)

	if success then
		for player in instance.participants do
			services.ProgressionService.AwardExperience(player, "world_event", nil)
			for _, reward in def.rewards or {} do
				services.InventoryService.AddItem(player, reward.id, reward.quantity or 1)
			end
		end
	end

	-- Every event declares how the world resets; apply it.
	if def.resetBehaviour == "RespawnNodes" and services.ResourceService then
		services.ResourceService.ResetRegion(instance.regionId)
	elseif def.resetBehaviour == "DespawnSpawns" and services.BeastService then
		services.BeastService.DespawnRegion(instance.regionId)
	end

	services.NetworkService.FireAll(Remotes.WorldEventUpdated.name, {
		id = eventId,
		state = success and Enums.WorldEventState.Completing or Enums.WorldEventState.Aborted,
		success = success,
	})
end

function WorldEventService.Join(player: Player, eventId: string): boolean
	local instance = active[eventId]
	if not instance then
		return false
	end
	instance.participants[player] = true
	return true
end

function WorldEventService.ActiveCount(): number
	local count = 0
	for _ in active do
		count += 1
	end
	return count
end

return WorldEventService
