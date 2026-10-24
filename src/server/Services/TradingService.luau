--!strict
--[[
	TradingService.luau
	Direct player-to-player trades. The server owns the whole state machine:
	offers are held here, both confirmations are recorded here, and items only
	move after a finalisation delay that prevents last-second swapping.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Trading = require(Shared.Config.TradingConfig)
local Items = require(Shared.Config.ItemConfig)
local Inventory = require(Shared.Inventory.InventoryModel)

local TradingService = {
	Name = "TradingService",
}

export type TradeSession = {
	id: string,
	a: Player,
	b: Player,
	offers: { [Player]: { [string]: number } },
	accepted: { [Player]: boolean },
	createdAt: number,
	finalisesAt: number?,
	state: string,
}

local sessions: { [string]: TradeSession } = {}
local activeOf: { [Player]: string } = {}
local nextId = 0
local services: any = nil

function TradingService.Init(svc: any)
	services = svc
end

function TradingService.Start(svc: any)
	services = svc
	services.NetworkService.On(Remotes.TradeRequest and Remotes.TradeRequest.name or "WB_TradeRequest", function(player, args)
		return TradingService.Handle(player, tostring(args[1]), args[2])
	end)
end

function TradingService.Handle(player: Player, action: string, payload: any?): any
	if action == "Request" then
		return TradingService.Request(player, tonumber(payload))
	elseif action == "Offer" then
		return TradingService.Offer(player, tostring(payload))
	elseif action == "Accept" then
		return TradingService.Accept(player)
	elseif action == "Cancel" then
		return TradingService.Cancel(player, "Cancelled")
	end
	return false
end

function TradingService.Request(player: Player, targetUserId: number?): boolean
	if not targetUserId then
		return false
	end
	if activeOf[player] then
		return false
	end
	local target = nil
	for _, candidate in game:GetService("Players"):GetPlayers() do
		if candidate.UserId == targetUserId then
			target = candidate
			break
		end
	end
	if not target or target == player then
		return false
	end
	local blocked = Trading.BlockReason({
		inDungeon = services.PlayerService.Get(player) and services.PlayerService.Get(player).inDungeon or false,
		inClanWar = services.PlayerService.Get(player) and services.PlayerService.Get(player).inClanWar or false,
		inBossEncounter = services.PlayerService.Get(player) and services.PlayerService.Get(player).inBossEncounter or false,
		tradeDisabled = services.PlayerService.Profile(target) and services.PlayerService.Profile(target).settings["pv_allow_trade_requests"] == false or false,
		distanceStuds = services.WorldService and services.WorldService.DistanceTo(services.WorldService.PositionOf(player), target) or nil,
	})
	if blocked then
		services.NetworkService.Fire(player, Remotes.Notification.name, { kind = "Warning", title = "Trade unavailable", body = blocked })
		return false
	end
	if activeOf[target] then
		return false
	end
	nextId += 1
	local id = string.format("trade_%d", nextId)
	sessions[id] = {
		id = id,
		a = player,
		b = target,
		offers = { [player] = {}, [target] = {} },
		accepted = { [player] = false, [target] = false },
		createdAt = os.time(),
		finalisesAt = nil,
		state = "Open",
	}
	activeOf[player] = id
	activeOf[target] = id
	services.NetworkService.Fire(target, Remotes.Notification.name, { kind = "Info", title = "Trade request", body = string.format("%s wants to trade.", player.Name) })
	return true
end

function TradingService.Offer(player: Player, itemId: string): boolean
	local id = activeOf[player]
	local session = id and sessions[id]
	if not session or session.state ~= "Open" then
		return false
	end
	local item = Items:Get(itemId)
	if not item then
		return false
	end
	if not Trading.CanTradeItemType(item.itemType) then
		return false
	end
	if not Trading.CanTradeTags(item.tags) then
		return false
	end
	local offered = session.offers[player]
	local count = 0
	for _ in offered do
		count += 1
	end
	if count >= Trading.Rules.maxDistinctItemKinds then
		return false
	end
	if services.InventoryService.CountItem(player, itemId) < 1 then
		return false
	end
	offered[itemId] = (offered[itemId] or 0) + 1
	-- Changing the offer retracts both confirmations.
	session.accepted[player] = false
	session.accepted[session.a == player and session.b or session.a] = false
	session.finalisesAt = nil
	TradingService.Push(session)
	return true
end

function TradingService.Accept(player: Player): boolean
	local id = activeOf[player]
	local session = id and sessions[id]
	if not session or session.state ~= "Open" then
		return false
	end
	session.accepted[player] = true
	local other = session.a == player and session.b or session.a
	if session.accepted[other] then
		session.state = "Finalising"
		session.finalisesAt = os.time() + Trading.Rules.finalisationDelaySeconds
		task.delay(Trading.Rules.finalisationDelaySeconds, function()
			TradingService.Finalise(session.id)
		end)
	else
		TradingService.Push(session)
	end
	return true
end

-- The only place where items actually move.
function TradingService.Finalise(id: string): boolean
	local session = sessions[id]
	if not session or session.state ~= "Finalising" then
		return false
	end

	-- Verify both sides still hold everything they offered.
	for _, side in { session.a, session.b } do
		for itemId, quantity in session.offers[side] do
			if services.InventoryService.CountItem(side, itemId) < quantity then
				TradingService.Cancel(side, "Offer no longer available")
				return false
			end
		end
	end

	-- Remove first, then grant: a failure mid-way is handled by refunding.
	for _, side in { session.a, session.b } do
		local other = side == session.a and session.b or session.a
		for itemId, quantity in session.offers[side] do
			local removed = services.InventoryService.RemoveItem(side, itemId, quantity)
			if removed < quantity then
				services.InventoryService.AddItem(other, itemId, removed)
			else
				services.InventoryService.AddItem(other, itemId, quantity)
			end
		end
	end

	session.state = "Complete"
	activeOf[session.a] = nil
	activeOf[session.b] = nil
	Logger.Info("TradingService", string.format("trade %s completed", id))
	task.delay(5, function()
		if sessions[id] == session then
			sessions[id] = nil
		end
	end)
	return true
end

function TradingService.Cancel(player: Player, reason: string): boolean
	local id = activeOf[player]
	local session = id and sessions[id]
	if not session then
		return false
	end
	session.state = "Cancelled"
	activeOf[session.a] = nil
	activeOf[session.b] = nil
	services.NetworkService.Fire(session.a, Remotes.Notification.name, { kind = "Info", title = "Trade cancelled", body = reason })
	services.NetworkService.Fire(session.b, Remotes.Notification.name, { kind = "Info", title = "Trade cancelled", body = reason })
	task.delay(2, function()
		if sessions[id] == session then
			sessions[id] = nil
		end
	end)
	return true
end

function TradingService.Push(session: TradeSession)
	for _, side in { session.a, session.b } do
		services.NetworkService.Fire(side, Remotes.InventoryUpdated.name, {
			trade = {
				id = session.id,
				yourOffer = session.offers[side],
				theirOffer = session.offers[side == session.a and session.b or session.a],
				youAccepted = session.accepted[side],
				theyAccepted = session.accepted[side == session.a and session.b or session.a],
			},
		})
	end
end

function TradingService.OnPlayerRemoving(player: Player)
	local id = activeOf[player]
	if id then
		TradingService.Cancel(player, "Player left")
	end
end

function TradingService.ActiveCount(): number
	local count = 0
	for _ in sessions do
		count += 1
	end
	return count
end

return TradingService
