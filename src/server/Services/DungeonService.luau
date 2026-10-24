--!strict
--[[
	DungeonService.luau
	Dungeon instances: party assembly, stage progression and completion.

	Dungeon enemies are NOT scaled to party health or damage: the difficulty is
	fixed by DungeonConfig (rank and tier), only the rewards scale. The service
	also enforces the dungeon companion cap and disables taming inside.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Dungeons = require(Shared.Config.DungeonConfig)

local DungeonService = {
	Name = "DungeonService",
}

export type Instance_ = {
	id: string,
	dungeonId: string,
	stageIndex: number,
	state: string,
	players: { Player },
	startedAt: number,
	leader: Player?,
}

local instances: { [string]: Instance_ } = {}
local partyOf: { [Player]: string } = {}
local nextId = 0
local services: any = nil

function DungeonService.Init(svc: any)
	services = svc
end

function DungeonService.Start(svc: any)
	services = svc
	services.NetworkService.On(Remotes.RequestDungeonEntry.name, function(player, args)
		return DungeonService.RequestEntry(player, tostring(args[1]))
	end)
end

function DungeonService.RequestEntry(player: Player, dungeonId: string): boolean
	local dungeon = Dungeons:Get(dungeonId)
	if not dungeon then
		return false
	end
	local state = services.PlayerService.Get(player)
	local profile = services.PlayerService.Profile(player)
	if not state or not profile then
		return false
	end
	if profile.level < (dungeon.requiredLevel or 1) then
		services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, { accepted = false, reason = "LevelTooLow" })
		return false
	end
	if partyOf[player] then
		services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, { accepted = false, reason = "AlreadyInDungeon" })
		return false
	end

	nextId += 1
	local id = string.format("dungeon_%s_%d", dungeonId, nextId)
	local instance: Instance_ = {
		id = id,
		dungeonId = dungeonId,
		stageIndex = 1,
		state = Enums.DungeonState.Running,
		players = { player },
		startedAt = os.time(),
		leader = player,
	}
	instances[id] = instance
	partyOf[player] = id

	state.inDungeon = true
	-- Taming is disabled inside every dungeon.
	if #profile.activeCompanions > Limits.Companion.MaxActiveDungeon then
		while #profile.activeCompanions > Limits.Companion.MaxActiveDungeon do
			table.remove(profile.activeCompanions)
		end
	end

	services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, {
		accepted = true,
		id = id,
		dungeonId = dungeonId,
		stage = 1,
		stageCount = #dungeon.stages,
	})
	DungeonService.EnterStage(instance, 1)
	return true
end

function DungeonService.EnterStage(instance: Instance_, stageIndex: number)
	local dungeon = Dungeons:Get(instance.dungeonId)
	if not dungeon then
		return
	end
	instance.stageIndex = stageIndex
	local stage = dungeon.stages[stageIndex]
	if not stage then
		DungeonService.Complete(instance)
		return
	end
	for _, player in instance.players do
		services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, {
			id = instance.id,
			stage = stageIndex,
			stageName = stage.name,
			objective = stage.objective,
		})
	end
	if stage.bossId then
		services.BossService.StartEncounter(stage.bossId, { dungeonId = instance.dungeonId, kind = "Dungeon" })
	end
end

function DungeonService.AdvanceStage(id: string): boolean
	local instance = instances[id]
	if not instance then
		return false
	end
	local dungeon = Dungeons:Get(instance.dungeonId)
	if not dungeon then
		return false
	end
	if instance.stageIndex >= #dungeon.stages then
		DungeonService.Complete(instance)
		return true
	end
	DungeonService.EnterStage(instance, instance.stageIndex + 1)
	return true
end

function DungeonService.Complete(instance: Instance_)
	instance.state = Enums.DungeonState.Completed
	local dungeon = Dungeons:Get(instance.dungeonId)
	for _, player in instance.players do
		local state = services.PlayerService.Get(player)
		if state then
			state.inDungeon = false
		end
		partyOf[player] = nil
		if dungeon then
			for _, reward in dungeon.rewards or {} do
				services.InventoryService.AddItem(player, reward.id, reward.quantity or 1)
			end
			services.ProgressionService.AwardExperience(player, "dungeon_boss", dungeon.recommendedLevel)
		end
		services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, { id = instance.id, complete = true })
	end
	Logger.Info("DungeonService", string.format("%s completed", instance.dungeonId))
	task.delay(10, function()
		if instances[instance.id] == instance then
			instances[instance.id] = nil
		end
	end)
end

function DungeonService.Leave(player: Player): boolean
	local id = partyOf[player]
	if not id then
		return false
	end
	local instance = instances[id]
	if instance then
		for index, member in instance.players do
			if member == player then
				table.remove(instance.players, index)
				break
			end
		end
		if #instance.players == 0 then
			instances[id] = nil
		end
	end
	partyOf[player] = nil
	local state = services.PlayerService.Get(player)
	if state then
		state.inDungeon = false
	end
	services.NetworkService.Fire(player, Remotes.DungeonStateUpdated.name, { left = true })
	return true
end

-- Called by BossService when a stage boss dies.
function DungeonService.OnStageBossDefeated(dungeonId: string)
	for _, instance in instances do
		if instance.dungeonId == dungeonId then
			DungeonService.AdvanceStage(instance.id)
		end
	end
end

function DungeonService.OnPlayerRemoving(player: Player)
	DungeonService.Leave(player)
end

function DungeonService.ActiveCount(): number
	local count = 0
	for _ in instances do
		count += 1
	end
	return count
end

return DungeonService
