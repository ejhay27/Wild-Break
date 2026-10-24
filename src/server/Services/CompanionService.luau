--!strict
--[[
	CompanionService.luau
	Taming, hatching, levelling and commanding companions.

	Companions are capped: 3 active in the open world, 1 inside a dungeon.
	Taming is never possible inside a dungeon (DungeonConfig enforces it and
	this service re-checks).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Companions = require(Shared.Config.CompanionConfig)
local Dungeons = require(Shared.Config.DungeonConfig)

local CompanionService = {
	Name = "CompanionService",
}

local active: { [Player]: { [string]: boolean } } = {}
local services: any = nil

local function now(): number
	return os.clock()
end

function CompanionService.Init(svc: any)
	services = svc
end

function CompanionService.Start(svc: any)
	services = svc
	local Network = services.NetworkService
	Network.On(Remotes.RequestTame.name, function(player, args)
		return CompanionService.Tame(player, tostring(args[1]), tostring(args[2]))
	end)
	Network.On(Remotes.RequestHatch.name, function(player, args)
		return CompanionService.Hatch(player, tostring(args[1]))
	end)
	Network.On(Remotes.RequestCompanionAction.name, function(player, args)
		return CompanionService.Command(player, tostring(args[1]), tostring(args[2]))
	end)
end

local function activeCount(player: Player): number
	local set = active[player]
	if not set then
		return 0
	end
	local count = 0
	for _ in set do
		count += 1
	end
	return count
end

local function capFor(player: Player): number
	local state = services.PlayerService.Get(player)
	if state and state.inDungeon then
		return Limits.Companion.MaxActiveDungeon
	end
	return Limits.Companion.MaxActiveOpenWorld
end

-- Taming is refused inside dungeons, even if a client asks.
function CompanionService.Tame(player: Player, beastInstanceId: string, speciesId: string): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	if state.inDungeon or Dungeons.AllowsTaming("any") then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "NoTamingInDungeon" })
		return false
	end
	local species = Companions:Get(speciesId)
	if not species then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "NotTameable" })
		return false
	end
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	local stored = 0
	for _ in profile.companions do
		stored += 1
	end
	if stored >= Limits.Companion.MaxStoredCompanions then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "StorageFull" })
		return false
	end

	-- The taming attempt itself is resolved by BeastService so the beast's
	-- state stays authoritative.
	local started = services.BeastService.BeginTame(player, beastInstanceId)
	if not started then
		return false
	end
	task.delay(Limits.Companion.TameMinSeconds, function()
		CompanionService.CompleteTame(player, beastInstanceId, speciesId)
	end)
	return true
end

function CompanionService.CompleteTame(player: Player, beastInstanceId: string, speciesId: string): boolean
	local beast = services.BeastService.Instance(beastInstanceId)
	if not beast then
		return false
	end
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	local uid = string.format("cmp_%d_%s", player.UserId, tostring(os.time()))
	profile.companions[uid] = {
		uid = uid,
		speciesId = speciesId,
		name = Companions:Get(speciesId).displayName,
		level = 1,
		bond = 10,
		role = Companions:Get(speciesId).roles and Companions:Get(speciesId).roles[1] or Enums.CompanionRole.Combat,
	}
	services.DataService.MarkDirty(player)
	services.BeastService.Kill(beast, player)
	services.ProgressionService.AwardExperience(player, "tame", nil)
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, {
		success = true,
		tamed = true,
		uid = uid,
		speciesId = speciesId,
	})
	Logger.Info("CompanionService", string.format("%s tamed %s", tostring(player.Name), speciesId))
	return true
end

function CompanionService.Hatch(player: Player, speciesId: string): boolean
	local species = Companions:Get(speciesId)
	local profile = services.PlayerService.Profile(player)
	if not species or not profile then
		return false
	end
	if services.InventoryService.CountItem(player, species.eggItemId) < 1 then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "NoEgg" })
		return false
	end
	local stored = 0
	for _ in profile.companions do
		stored += 1
	end
	if stored >= Limits.Companion.MaxStoredCompanions then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "StorageFull" })
		return false
	end
	services.InventoryService.RemoveItem(player, species.eggItemId, 1)
	local uid = string.format("cmp_%d_%s", player.UserId, tostring(os.time()))
	profile.companions[uid] = {
		uid = uid,
		speciesId = speciesId,
		name = species.displayName,
		level = 1,
		bond = 0,
		role = species.roles and species.roles[1] or Enums.CompanionRole.Combat,
	}
	services.DataService.MarkDirty(player)
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = true, hatched = true, uid = uid, speciesId = speciesId })
	return true
end

function CompanionService.Deploy(player: Player, uid: string): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile or not profile.companions[uid] then
		return false
	end
	if not active[player] then
		active[player] = {}
	end
	if active[player][uid] then
		return true
	end
	if activeCount(player) >= capFor(player) then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = false, reason = "ActiveLimit" })
		return false
	end
	active[player][uid] = true
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = true, deployed = true, uid = uid })
	return true
end

function CompanionService.Recall(player: Player, uid: string): boolean
	if not active[player] or not active[player][uid] then
		return false
	end
	active[player][uid] = nil
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = true, recalled = true, uid = uid })
	return true
end

function CompanionService.Command(player: Player, uid: string, command: string): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile or not profile.companions[uid] then
		return false
	end
	local allowed = false
	for _, value in Enums.CompanionCommand do
		if value == command then
			allowed = true
			break
		end
	end
	if not allowed then
		return false
	end
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { success = true, uid = uid, command = command })
	return true
end

-- Companion levelling: bond and levels grow from time spent active.
function CompanionService.Tick(delta: number)
	for player, set in active do
		local profile = services.PlayerService.Profile(player)
		if not profile then
			continue
		end
		for uid in set do
			local companion = profile.companions[uid]
			if not companion then
				set[uid] = nil
				continue
			end
			local species = Companions:Get(companion.speciesId)
			if not species then
				continue
			end
			companion.bond = math.min(100, companion.bond + delta * 0.05)
			if companion.level < Limits.Companion.MaxLevel then
				companion.experience = (companion.experience or 0) + delta
				if companion.experience >= 60 + companion.level * 30 then
					companion.experience = 0
					companion.level += 1
					services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { uid = uid, levelUp = companion.level })
				end
			end
		end
	end
end

function CompanionService.OnPlayerRemoving(player: Player)
	active[player] = nil
end

return CompanionService
