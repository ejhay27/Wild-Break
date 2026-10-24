--!strict
--[[
	CompanionController.luau
	Companion roster, deployment and commands.

	Caps are enforced on the server; this controller only renders the result
	and explains a refusal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)

local CompanionController = { Name = "CompanionController" }

local controllers: any = nil
local roster: { [string]: any } = {}
local active: { [string]: boolean } = {}

function CompanionController.Init(svc: any)
	controllers = svc
end

function CompanionController.Roster(): { any }
	local out = {}
	for _, companion in roster do
		table.insert(out, companion)
	end
	return out
end

function CompanionController.IsActive(uid: string): boolean
	return active[uid] == true
end

function CompanionController.Tame(beastId: string, speciesId: string)
	controllers.NetworkController.Fire(Remotes.RequestTame.name, { beastId = beastId, speciesId = speciesId })
end

function CompanionController.Hatch(speciesId: string)
	controllers.NetworkController.Fire(Remotes.RequestHatch.name, { speciesId = speciesId })
end

function CompanionController.Deploy(uid: string)
	controllers.NetworkController.Fire(Remotes.RequestCompanionAction.name, { action = "Deploy", uid = uid })
end

function CompanionController.Recall(uid: string)
	controllers.NetworkController.Fire(Remotes.RequestCompanionAction.name, { action = "Recall", uid = uid })
end

function CompanionController.Command(uid: string, command: string)
	controllers.NetworkController.Fire(Remotes.RequestCompanionAction.name, { action = command, uid = uid })
end

function CompanionController.Start()
	local Network = controllers.NetworkController

	Network.On(Remotes.CompanionUpdated.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.success == false then
			controllers.NotificationController.Notify("Companion", tostring(payload.reason))
			return
		end
		if payload.deployed then
			active[payload.uid] = true
		elseif payload.recalled then
			active[payload.uid] = nil
		end
	end)

	controllers.StateController.OnProfile(function(profile: any)
		if type(profile) ~= "table" or type(profile.companions) ~= "table" then
			return
		end
		roster = profile.companions
	end)
end

return CompanionController
