--!strict
--[[
	ProgressionService.luau
	Experience, levels, mastery, discoveries and level rewards.

	All experience is granted server-side from named sources; the client never
	sends an experience amount.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Logger = require(Shared.Utilities.Logger)
local Progression = require(Shared.Config.ProgressionConfig)

local ProgressionService = {
	Name = "ProgressionService",
}

local services: any = nil

function ProgressionService.Init(svc: any)
	services = svc
end

function ProgressionService.Start(svc: any)
	services = svc
end

-- Grants experience from a named source and applies any level ups.
function ProgressionService.AwardExperience(player: Player, sourceId: string, contentLevel: number?): number
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return 0
	end
	local amount = Progression.ExperienceFor(sourceId, contentLevel, profile.level)
	if amount <= 0 then
		return 0
	end
	profile.experience += amount
	profile.experienceTotal += amount
	local levelsGained = 0
	while profile.level < 120 do
		local needed = Progression.ExperienceForLevel(profile.level)
		if profile.experience < needed then
			break
		end
		profile.experience -= needed
		profile.level += 1
		levelsGained += 1
		ProgressionService.ApplyLevelRewards(player, profile.level)
	end
	if levelsGained > 0 then
		services.DataService.MarkDirty(player)
		Logger.Info("ProgressionService", string.format("%s reached level %d", tostring(player.Name), profile.level))
	end
	services.NetworkService.Fire(player, Remotes.PlayerProfileUpdated.name, {
		level = profile.level,
		experience = profile.experience,
		experienceTotal = profile.experienceTotal,
		gained = amount,
		levelsGained = levelsGained,
	})
	return amount
end

function ProgressionService.ApplyLevelRewards(player: Player, level: number)
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return
	end
	for _, reward in Progression.RewardsForLevel(level) do
		if reward.kind == "Currency" then
			profile.sap += reward.quantity or 0
		elseif reward.kind == "Capacity" then
			if reward.id == "capacity_inventory" then
				profile.inventoryCapacity = math.min(200, profile.inventoryCapacity + (reward.quantity or 0))
			elseif reward.id == "capacity_stash" then
				profile.stashCapacity = math.min(240, profile.stashCapacity + (reward.quantity or 0))
			end
		elseif reward.kind == "Unlock" then
			-- Unlocks are derived from level; nothing to store here.
		end
		services.NetworkService.Fire(player, Remotes.Notification.name, {
			kind = "Reward",
			title = string.format("Level %d", level),
			body = reward.displayName,
		})
	end
end

function ProgressionService.AwardMastery(player: Player, trackId: string, amount: number): number
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return 0
	end
	local track = Progression.Mastery(trackId)
	if not track then
		return 0
	end
	local before = Progression.MasteryRankFromExperience(trackId, profile.mastery[trackId] or 0)
	profile.mastery[trackId] = (profile.mastery[trackId] or 0) + amount
	local after = Progression.MasteryRankFromExperience(trackId, profile.mastery[trackId])
	if after > before then
		services.NetworkService.Fire(player, Remotes.Notification.name, {
			kind = "Reward",
			title = track.displayName,
			body = string.format("Rank %d reached.", after),
		})
		services.DataService.MarkDirty(player)
	end
	return amount
end

function ProgressionService.Discover(player: Player, landmarkId: string): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	if profile.discoveries[landmarkId] then
		return false
	end
	profile.discoveries[landmarkId] = true
	ProgressionService.AwardExperience(player, "discovery", nil)
	services.DataService.MarkDirty(player)
	services.NetworkService.Fire(player, Remotes.Notification.name, {
		kind = "Discovery",
		title = "Location discovered",
		body = landmarkId,
	})
	return true
end

function ProgressionService.AwardCurrency(player: Player, currency: string, amount: number): number
	local profile = services.PlayerService.Profile(player)
	if not profile or amount <= 0 then
		return 0
	end
	if currency == "sap" then
		profile.sap += amount
	elseif currency == "coin" then
		profile.coin += amount
	else
		return 0
	end
	services.DataService.MarkDirty(player)
	services.NetworkService.Fire(player, Remotes.PlayerProfileUpdated.name, { sap = profile.sap, coin = profile.coin })
	return amount
end

function ProgressionService.SpendCurrency(player: Player, currency: string, amount: number): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile or amount <= 0 then
		return false
	end
	if currency == "sap" and profile.sap >= amount then
		profile.sap -= amount
	elseif currency == "coin" and profile.coin >= amount then
		profile.coin -= amount
	else
		return false
	end
	services.DataService.MarkDirty(player)
	services.NetworkService.Fire(player, Remotes.PlayerProfileUpdated.name, { sap = profile.sap, coin = profile.coin })
	return true
end

return ProgressionService
