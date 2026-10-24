--!strict
--[[
	AdminService.luau
	Two-owner allowlisted administration with a full audit log.

	Security model:
	  * authorisation is by UserId only, compared inside a single central
	    function
	  * the allowlist is empty by default, so the admin panel is disabled and
	    every admin remote is rejected until real UserIds are supplied
	  * every admin action writes an audit entry (actor, target, action,
	    reason, before/after)
	  * destructive actions are individually gated by level
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Extensions = require(Shared.Security.Extensions)
local Logger = require(Shared.Utilities.Logger)

local AdminService = {
	Name = "AdminService",
}

local audit: { { actorId: number, actorName: string, action: string, targetId: number?, reason: string, at: number } } = {}
local services: any = nil

function AdminService.Init(svc: any)
	services = svc
end

function AdminService.Start(svc: any)
	services = svc
	if not Extensions.IsAdminEnabled() then
		Extensions.LogAdminDisabled("AdminService")
	end
	local Network = services.NetworkService
	if Remotes.AdminAction then
		Network.On(Remotes.AdminAction.name, function(player, args)
			return AdminService.Action(player, tostring(args[1]), args[2], tostring(args[3] or ""))
		end)
	end
end

-- The single authorisation decision point.
function AdminService.IsAuthorised(userId: number, actionAdminLevel: number?): boolean
	return Extensions.IsOwner(userId, actionAdminLevel)
end

function AdminService.RecordDenied(player: Player, context: string)
	AdminService.Log(player.UserId, player.Name, "Denied", nil, context)
	Logger.Warn("AdminService", string.format("denied %s for %s", context, tostring(player.Name)))
end

function AdminService.Log(actorId: number, actorName: string, action: string, targetId: number?, reason: string)
	table.insert(audit, {
		actorId = actorId,
		actorName = actorName,
		action = action,
		targetId = targetId,
		reason = reason,
		at = os.time(),
	})
	-- The audit log is bounded so a long-running server cannot grow forever.
	if #audit > 1000 then
		table.remove(audit, 1)
	end
	services.NetworkService.FireAll(Remotes.AdminAuditEntry.name, audit[#audit])
end

function AdminService.Audit(): typeof(audit)
	return audit
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function AdminService.Action(player: Player, action: string, payload: any, reason: string): boolean
	local level = Extensions.AdminLevel(action)
	if not AdminService.IsAuthorised(player.UserId, level) then
		AdminService.RecordDenied(player, action)
		return false
	end
	local target = AdminService.PlayerFromPayload(payload)
	if action == "Kick" then
		if not target then
			return false
		end
		AdminService.Log(player.UserId, player.Name, "Kick", target.UserId, reason)
		target:Kick(reason)
		return true
	elseif action == "RespawnNode" then
		services.ResourceService.AdminRespawn(tostring(payload))
		AdminService.Log(player.UserId, player.Name, "RespawnNode", nil, tostring(payload))
		return true
	elseif action == "Teleport" then
		if not target then
			return false
		end
		services.DeploymentService.ReturnToHub(target)
		AdminService.Log(player.UserId, player.Name, "Teleport", target.UserId, reason)
		return true
	elseif action == "GrantItem" then
		if not target then
			return false
		end
		local itemId = payload[2]
		local quantity = tonumber(payload[3]) or 1
		services.InventoryService.AddItem(target, tostring(itemId), quantity)
		AdminService.Log(player.UserId, player.Name, "GrantItem", target.UserId, string.format("%s x%d", tostring(itemId), quantity))
		return true
	elseif action == "SetLevel" then
		if not target then
			return false
		end
		local profile = services.PlayerService.Profile(target)
		if not profile then
			return false
		end
		profile.level = math.clamp(tonumber(payload[2]) or profile.level, 1, 120)
		services.DataService.MarkDirty(target)
		AdminService.Log(player.UserId, player.Name, "SetLevel", target.UserId, tostring(profile.level))
		return true
	elseif action == "ForceSave" then
		services.DataService.SaveAll()
		AdminService.Log(player.UserId, player.Name, "ForceSave", nil, reason)
		return true
	elseif action == "StartBoss" then
		services.BossService.StartEncounter(tostring(payload), { kind = "World" })
		AdminService.Log(player.UserId, player.Name, "StartBoss", nil, tostring(payload))
		return true
	elseif action == "Broadcast" then
		services.NetworkService.FireAll(Remotes.Notification.name, { kind = "Admin", title = "Announcement", body = tostring(payload) })
		AdminService.Log(player.UserId, player.Name, "Broadcast", nil, tostring(payload))
		return true
	end
	return false
end

function AdminService.PlayerFromPayload(payload: any): Player?
	local reference = nil
	if type(payload) == "table" then
		reference = payload[1]
	else
		reference = payload
	end
	local userId = tonumber(reference)
	if not userId then
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.Name == tostring(reference) then
				return player
			end
		end
		return nil
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

function AdminService.Enabled(): boolean
	return Extensions.IsAdminEnabled()
end

return AdminService
