--!strict
--[[
	ClanService.luau
	Clans: creation, membership, roles, permissions, vault and the Clan War
	queue. The Clan War matches themselves live in a separate place; this
	service owns the queue, the roster and the result handling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Clan = require(Shared.Config.ClanConfig)

local ClanService = {
	Name = "ClanService",
}

export type ClanRecord = {
	id: string,
	name: string,
	ownerId: number,
	roles: { [number]: string },
	vault: { [string]: { id: string, quantity: number } },
	rating: number,
	createdAt: number,
	motd: string,
}

export type QueueEntry = {
	clanId: string,
	mode: string,
	configuration: { teams: number, perTeam: number },
	members: { number },
	queuedAt: number,
}

local clans: { [string]: ClanRecord } = {}
local membership: { [number]: string? } = {}
local queue: { QueueEntry } = {}
local services: any = nil
local nextClanId = 0

function ClanService.Init(svc: any)
	services = svc
end

function ClanService.Start(svc: any)
	services = svc
	local Network = services.NetworkService
	Network.On(Remotes.ClanRequest.name, function(player, args)
		return ClanService.Handle(player, tostring(args[1]), args[2])
	end)
	Network.On(Remotes.ClanWarRequest.name, function(player, args)
		return ClanService.WarHandle(player, tostring(args[1]), args[2])
	end)
end

function ClanService.Handle(player: Player, action: string, payload: any?): any
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return nil
	end
	if action == "Create" then
		return ClanService.Create(player, tostring(payload))
	elseif action == "Invite" then
		return ClanService.Invite(player, tonumber(payload))
	elseif action == "Join" then
		return ClanService.Join(player, tostring(payload))
	elseif action == "Leave" then
		return ClanService.Leave(player)
	elseif action == "Promote" or action == "Demote" or action == "Kick" then
		return ClanService.Role(player, action, tonumber(payload))
	elseif action == "SetMotd" then
		return ClanService.SetMotd(player, tostring(payload))
	elseif action == "Info" then
		return ClanService.Info(profile.clanId)
	end
	return nil
end

local function clanOf(player: Player): ClanRecord?
	local profile = services.PlayerService.Profile(player)
	if not profile or not profile.clanId then
		return nil
	end
	return clans[profile.clanId]
end

local function roleOf(player: Player): string?
	local clan = clanOf(player)
	if not clan then
		return nil
	end
	return clan.roles[player.UserId]
end

function ClanService.Create(player: Player, name: string): boolean
	if clanOf(player) then
		return false
	end
	if #name < Clan.Limits.minNameLength or #name > Clan.Limits.maxNameLength then
		return false
	end
	for _, clan in clans do
		if string.lower(clan.name) == string.lower(name) then
			return false
		end
	end
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	if not services.ProgressionService.SpendCurrency(player, "sap", Clan.Limits.createCostSap) then
		return false
	end
	nextClanId += 1
	local id = string.format("clan_%d", nextClanId)
	clans[id] = {
		id = id,
		name = name,
		ownerId = player.UserId,
		roles = { [player.UserId] = Enums.ClanRole.Owner },
		vault = {},
		rating = 1000,
		createdAt = os.time(),
		motd = "",
	}
	membership[player.UserId] = id
	profile.clanId = id
	services.DataService.MarkDirty(player)
	Logger.Info("ClanService", string.format("%s created clan %s", tostring(player.Name), name))
	return true
end

function ClanService.Invite(player: Player, targetUserId: number?): boolean
	if not targetUserId then
		return false
	end
	if not Clan.Can(roleOf(player) or Enums.ClanRole.Recruit, "invite") then
		return false
	end
	local clan = clanOf(player)
	if not clan then
		return false
	end
	local target = nil
	for _, candidate in game:GetService("Players"):GetPlayers() do
		if candidate.UserId == targetUserId then
			target = candidate
			break
		end
	end
	if not target then
		return false
	end
	local targetProfile = services.PlayerService.Profile(target)
	if not targetProfile or targetProfile.clanId then
		return false
	end
	services.NetworkService.Fire(target, Remotes.ClanUpdated.name, { kind = "Invite", clanId = clan.id, clanName = clan.name })
	return true
end

function ClanService.Join(player: Player, clanId: string): boolean
	local clan = clans[clanId]
	local profile = services.PlayerService.Profile(player)
	if not clan or not profile or profile.clanId then
		return false
	end
	local memberCount = 0
	for _ in clan.roles do
		memberCount += 1
	end
	if memberCount >= Clan.Limits.maxMembers then
		return false
	end
	clan.roles[player.UserId] = Enums.ClanRole.Recruit
	membership[player.UserId] = clanId
	profile.clanId = clanId
	services.DataService.MarkDirty(player)
	ClanService.Push(clanId)
	return true
end

function ClanService.Leave(player: Player): boolean
	local clan = clanOf(player)
	local profile = services.PlayerService.Profile(player)
	if not clan or not profile then
		return false
	end
	if clan.ownerId == player.UserId then
		return false
	end
	clan.roles[player.UserId] = nil
	membership[player.UserId] = nil
	profile.clanId = nil
	services.DataService.MarkDirty(player)
	ClanService.Push(clan.id)
	return true
end

function ClanService.Role(player: Player, action: string, targetUserId: number?): boolean
	if not targetUserId or targetUserId == player.UserId then
		return false
	end
	local clan = clanOf(player)
	if not clan then
		return false
	end
	local actorRole = roleOf(player) or Enums.ClanRole.Recruit
	local targetRole = clan.roles[targetUserId] or Enums.ClanRole.Recruit
	if Enums.ClanRoleRank[targetRole] >= Enums.ClanRoleRank[actorRole] then
		return false
	end
	if action == "Promote" then
		if not Clan.Can(actorRole, "promote") then
			return false
		end
		local order = Enums.ClanRoleOrder
		for index, role in ipairs(order) do
			if role == targetRole and index > 1 then
				local nextRole = order[index - 1]
				if nextRole == Enums.ClanRole.Owner then
					return false
				end
				if nextRole == Enums.ClanRole.Officer then
					local officers = 0
					for _, role2 in clan.roles do
						if role2 == Enums.ClanRole.Officer then
							officers += 1
						end
					end
					if officers >= Clan.Limits.maxOfficers then
						return false
					end
				end
				clan.roles[targetUserId] = nextRole
				ClanService.Push(clan.id)
				return true
			end
		end
		return false
	elseif action == "Demote" then
		if not Clan.Can(actorRole, "demote") then
			return false
		end
		local order = Enums.ClanRoleOrder
		for index, role in ipairs(order) do
			if role == targetRole and index < #order then
				clan.roles[targetUserId] = order[index + 1]
				ClanService.Push(clan.id)
				return true
			end
		end
		return false
	elseif action == "Kick" then
		if not Clan.Can(actorRole, "kick") then
			return false
		end
		clan.roles[targetUserId] = nil
		membership[targetUserId] = nil
		ClanService.Push(clan.id)
		return true
	end
	return false
end

function ClanService.SetMotd(player: Player, message: string): boolean
	if not Clan.Can(roleOf(player) or Enums.ClanRole.Recruit, "edit_motd") then
		return false
	end
	local clan = clanOf(player)
	if not clan then
		return false
	end
	clan.motd = string.sub(message, 1, 200)
	ClanService.Push(clan.id)
	return true
end

function ClanService.Info(clanId: string?): any?
	if not clanId then
		return nil
	end
	local clan = clans[clanId]
	if not clan then
		return nil
	end
	local members = {}
	for userId, role in clan.roles do
		table.insert(members, { userId = userId, role = role })
	end
	return { id = clan.id, name = clan.name, rating = clan.rating, motd = clan.motd, members = members }
end

-- ---------------------------------------------------------------------------
-- Clan War queue
-- ---------------------------------------------------------------------------

function ClanService.WarHandle(player: Player, action: string, payload: any?): boolean
	if action == "Queue" then
		return ClanService.Queue(player, tostring(payload))
	elseif action == "LeaveQueue" then
		return ClanService.LeaveQueue(player)
	end
	return false
end

function ClanService.Queue(player: Player, mode: string): boolean
	if not Clan.Mode(mode) then
		return false
	end
	if not Clan.Can(roleOf(player) or Enums.ClanRole.Recruit, "start_war") then
		return false
	end
	local clan = clanOf(player)
	if not clan then
		return false
	end
	for _, entry in queue do
		if entry.clanId == clan.id then
			return false
		end
	end
	local members = {}
	for userId in clan.roles do
		table.insert(members, userId)
	end
	local configuration = Clan.War.supportedConfigurations[1]
	for _, candidate in Clan.War.supportedConfigurations do
		if candidate.perTeam <= #members then
			configuration = candidate
		end
	end
	table.insert(queue, {
		clanId = clan.id,
		mode = mode,
		configuration = configuration,
		members = members,
		queuedAt = os.time(),
	})
	services.NetworkService.Fire(player, Remotes.ClanUpdated.name, { kind = "WarQueue", mode = mode })
	return true
end

function ClanService.LeaveQueue(player: Player): boolean
	local clan = clanOf(player)
	if not clan then
		return false
	end
	for index, entry in queue do
		if entry.clanId == clan.id then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

function ClanService.Push(clanId: string)
	local clan = clans[clanId]
	if not clan then
		return
	end
	for userId in clan.roles do
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.UserId == userId then
				services.NetworkService.Fire(player, Remotes.ClanUpdated.name, { kind = "State", clan = ClanService.Info(clanId) })
			end
		end
	end
end

function ClanService.OnPlayerRemoving(player: Player)
	ClanService.LeaveQueue(player)
end

function ClanService.ClanCount(): number
	local count = 0
	for _ in clans do
		count += 1
	end
	return count
end

function ClanService.QueueSize(): number
	return #queue
end

return ClanService
