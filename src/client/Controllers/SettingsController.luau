--!strict
--[[
	SettingsController.luau
	Applies player preferences locally and persists them through the server.

	Settings are validated on the server (SettingsConfig.ServerValidatedIds)
	before they are stored, so a tampered client cannot write an illegal value
	into its profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Settings = require(Shared.Config.SettingsConfig)
local Logger = require(Shared.Utilities.Logger)

local SettingsController = { Name = "SettingsController" }

local controllers: any = nil
local player: Player? = nil
local platform = "PC"
local values: { [string]: any } = {}
local listeners: { (string, any) -> () } = {}

function SettingsController.Init(svc: any, p: Player)
	controllers = svc
	player = p
	platform = svc.NetworkController.Platform()
	values = Settings.Defaults(platform)
end

function SettingsController.Get(id: string): any
	return values[id]
end

function SettingsController.Set(id: string, value: any)
	if values[id] == value then
		return
	end
	values[id] = value
	for _, listener in listeners do
		pcall(listener, id, value)
	end
	SettingsController.Persist()
end

function SettingsController.OnChanged(listener: (string, any) -> ())
	table.insert(listeners, listener)
end

-- Sends the whole table; the server sanitises it before saving.
function SettingsController.Persist()
	local Network = controllers.NetworkController
	Network.Fire(Remotes.UpdateSettings.name, values)
end

function SettingsController.ApplyProfile(profile: any)
	if type(profile) ~= "table" then
		return
	end
	local sanitised, problems = Settings.Sanitise(profile.settings, platform)
	if #problems > 0 then
		Logger.Debug("Settings", string.format("discarded %d invalid settings", #problems))
	end
	values = sanitised
	for _, listener in listeners do
		pcall(listener, "*", values)
	end
end

function SettingsController.Start()
	local State = controllers.StateController
	State.OnProfile(function(profile: any)
		SettingsController.ApplyProfile(profile)
	end)

	controllers.NetworkController.On(Remotes.UpdateSettings.name, function(payload: any)
		if type(payload) == "table" then
			SettingsController.ApplyProfile({ settings = payload })
		end
	end)
end

return SettingsController
