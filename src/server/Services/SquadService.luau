--!strict
--[[
	SquadService.luau
	Small, temporary groups for open-world play and Tactical Deployment.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)

local SquadService = {
	Name = "SquadService",
}

export type Squad = {
	id: string,
	leader: Player,
	members: { Player },
	state: string,
	createdAt: number,
}

local squads: { [string]: Squad } = {}
local squadOf: { [Player]: string } = {}
local invites: { [Player]: number } = {}
local nextId = 0
local services: any = nil

function SquadService.Init(svc: any)
	services = svc
end

function SquadService.Start(svc: any)
	services = svc
	services.NetworkService.On(Remotes.SquadRequest.name, function(player, args)
		return SquadService.Handle(player, tostring(args[1]), args[2])
	end)
end

function SquadService.Handle(player: Player, action: string, target: any?): boolean
	if action == "Create" then
		return SquadService.Create(player)
	elseif action == "Invite" then
		return SquadService.Invite(player, target)
	elseif action == "Accept" then
		return SquadService.Accept(player, tostring(target))
	elseif action == "Leave" then
		return SquadService.Leave(player)
	elseif action == "Kick" then
		return SquadService.Kick(player, tostring(target))
	end
	return false
end

function SquadService.Create(player: Player): boolean
	if squadOf[player] then
		return false
	end
	nextId += 1
	local id = string.format("squad_%d", nextId)
	squads[id] = {
		id = id,
		leader = player,
		members = { player },
		state = Enums.SquadState.Forming,
		createdAt = os.time(),
	}
	squadOf[player] = id
	SquadService.Push(id)
	return true
end

function SquadService.Invite(player: Player, targetId: any): boolean
	local squadId = squadOf[player]
	if not squadId then
		SquadService.Create(player)
		squadId = squadOf[player]
	end
	local squad = squads[squadId]
	if not squad then
		return false
	end
	if #squad.members >= (Limits.Squad and Limits.Squad.MaxSize or 4) then
		return false
	end
	local target = SquadService.PlayerFromReference(targetId)
	if not target then
		return false
	end
	-- Respect the invite privacy setting.
	local targetState = services.PlayerService.Get(target)
	if services.PlayerService.Profile(target) and not SquadService.AllowsInvites(target) then
		_ = targetState
		return false
	end
	invites[target] = os.time()
	services.NetworkService.Fire(target, Remotes.SquadUpdated.name, { kind = "Invite", from = player.Name, squadId = squadId })
	return true
end

function SquadService.AllowsInvites(player: Player): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	return profile.settings["pv_allow_invites"] ~= false
end

function SquadService.PlayerFromReference(reference: any): Player?
	if typeof(reference) == "Instance" and reference:IsA("Player") then
		return reference
	end
	if type(reference) == "number" then
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.UserId == reference then
				return player
			end
		end
	end
	return nil
end

function SquadService.Accept(player: Player, squadId: string): boolean
	local squad = squads[squadId]
	if not squad then
		return false
	end
	if #squad.members >= (Limits.Squad and Limits.Squad.MaxSize or 4) then
		return false
	end
	if squadOf[player] then
		SquadService.Leave(player)
	end
	table.insert(squad.members, player)
	squadOf[player] = squadId
	SquadService.Push(squadId)
	return true
end

function SquadService.Leave(player: Player): boolean
	local squadId = squadOf[player]
	if not squadId then
		return false
	end
	local squad = squads[squadId]
	if squad then
		for index, member in squad.members do
			if member == player then
				table.remove(squad.members, index)
				break
			end
		end
		if #squad.members == 0 then
			squads[squadId] = nil
		else
			if squad.leader == player then
				squad.leader = squad.members[1]
			end
			SquadService.Push(squadId)
		end
	end
	squadOf[player] = nil
	services.NetworkService.Fire(player, Remotes.SquadUpdated.name, { kind = "Left" })
	return true
end

function SquadService.Kick(player: Player, targetName: string): boolean
	local squadId = squadOf[player]
	local squad = squadId and squads[squadId]
	if not squad or squad.leader ~= player then
		return false
	end
	for index, member in squad.members do
		if member.Name == targetName then
			table.remove(squad.members, index)
			squadOf[member] = nil
			services.NetworkService.Fire(member, Remotes.SquadUpdated.name, { kind = "Kicked" })
			SquadService.Push(squadId)
			return true
		end
	end
	return false
end

function SquadService.Push(squadId: string)
	local squad = squads[squadId]
	if not squad then
		return
	end
	local names = {}
	for _, member in squad.members do
		table.insert(names, member.Name)
	end
	for _, member in squad.members do
		services.NetworkService.Fire(member, Remotes.SquadUpdated.name, {
			kind = "State",
			squadId = squadId,
			leader = squad.leader.Name,
			members = names,
		})
	end
end

function SquadService.SquadOf(player: Player): Squad?
	local squadId = squadOf[player]
	return squadId and squads[squadId] or nil
end

function SquadService.OnPlayerRemoving(player: Player)
	SquadService.Leave(player)
	invites[player] = nil
end

function SquadService.ActiveCount(): number
	local count = 0
	for _ in squads do
		count += 1
	end
	return count
end

return SquadService
