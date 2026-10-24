--!strict
--[[
	TradingConfig.luau
	Direct player-to-player trading rules.

	The server owns the trade state machine end to end: both players propose,
	both confirm, and only the server moves items. There is no client-side
	"trade accepted" step that could desynchronise inventories.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Trading = {}

Trading.Rules = {
	enabled = true,
	maxDistanceStuds = 30,
	maxItemsPerSide = 8,
	maxDistinctItemKinds = 8,
	-- Seconds each player has to accept before the trade expires.
	confirmTimeoutSeconds = 60,
	-- Additional delay after both players accept. Prevents item-swap races
	-- where a player edits the offer during the final commit.
	finalisationDelaySeconds = 2,
	-- Refresh requests are rate limited per player.
	requestCooldownSeconds = 10,
	-- A player may only have one active trade at a time.
	oneTradePerPlayer = true,
	-- Trading is disabled during a Clan War match and inside dungeons.
	disabledDuringClanWar = true,
	disabledInDungeon = true,
	disabledDuringBossEncounter = true,
}

-- Item kinds that can never be traded. Bound items, quest items and anything
-- tied to account progression stay with the account that earned them.
Trading.NonTradeableItemTypes = {
	[Enums.ItemType.QuestItem] = true,
	[Enums.ItemType.Blueprint] = true,
	[Enums.ItemType.ResearchItem] = true,
}

Trading.NonTradeableTags = {
	["Soulbound"] = true,
	["Quest"] = true,
	["EventReward"] = true,
}

Trading.Fees = {
	-- Percentage of the trade value paid in Sap. Zero by default: trading is
	-- not meant to be a sink.
	sapPercentage = 0,
	minimumSap = 0,
	maximumSap = 0,
}

function Trading.CanTradeItemType(itemType: string): boolean
	return Trading.NonTradeableItemTypes[itemType] ~= true
end

function Trading.CanTradeTags(tags: { string }?): boolean
	if not tags then
		return true
	end
	for _, tag in tags do
		if Trading.NonTradeableTags[tag] then
			return false
		end
	end
	return true
end

-- Returns nil when the trade may proceed, otherwise a human readable reason.
function Trading.BlockReason(context: {
	inDungeon: boolean?,
	inClanWar: boolean?,
	inBossEncounter: boolean?,
	distanceStuds: number?,
	tradeDisabled: boolean?,
}): string?
	if not Trading.Rules.enabled then
		return "Trading is currently disabled."
	end
	if context.tradeDisabled then
		return "This player is not accepting trade requests."
	end
	if context.inDungeon and Trading.Rules.disabledInDungeon then
		return "You cannot trade inside a dungeon."
	end
	if context.inClanWar and Trading.Rules.disabledDuringClanWar then
		return "You cannot trade during a Clan War match."
	end
	if context.inBossEncounter and Trading.Rules.disabledDuringBossEncounter then
		return "You cannot trade during a boss encounter."
	end
	local distance = context.distanceStuds
	if distance and distance > Trading.Rules.maxDistanceStuds then
		return "Stand closer to trade."
	end
	return nil
end

function Trading.ValidateAll(): { string }
	local problems = {}
	if Trading.Rules.maxItemsPerSide < 1 then
		table.insert(problems, "[Trading] players must be able to offer at least one item")
	end
	if Trading.Rules.confirmTimeoutSeconds <= 0 then
		table.insert(problems, "[Trading] the confirm timeout must be positive")
	end
	if Trading.Rules.finalisationDelaySeconds <= 0 then
		table.insert(problems, "[Trading] the finalisation delay must be positive")
	end
	if Trading.Fees.sapPercentage < 0 or Trading.Fees.sapPercentage > 100 then
		table.insert(problems, "[Trading] the trade fee percentage is out of range")
	end
	if Trading.CanTradeItemType(Enums.ItemType.QuestItem) then
		table.insert(problems, "[Trading] quest items must not be tradeable")
	end
	if not Trading.CanTradeItemType(Enums.ItemType.Material) then
		table.insert(problems, "[Trading] materials must be tradeable")
	end
	if Trading.CanTradeTags({ "Soulbound" }) then
		table.insert(problems, "[Trading] soulbound items must not be tradeable")
	end
	if Trading.BlockReason({ inDungeon = true }) == nil then
		table.insert(problems, "[Trading] dungeon trades must be blocked")
	end
	if Trading.BlockReason({ distanceStuds = 100 }) == nil then
		table.insert(problems, "[Trading] long distance trades must be blocked")
	end
	if Trading.BlockReason({ distanceStuds = 5 }) ~= nil then
		table.insert(problems, "[Trading] valid trades are being blocked")
	end
	return problems
end

return Trading
