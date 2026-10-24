--!strict
--[[
	AudioController.luau
	Plays configured sounds and music layers.

	Asset ids are placeholders: if a configured sound has no uploaded asset
	yet, the request is skipped and logged once. Nothing errors at runtime and
	nothing invents an id.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Audio = require(Shared.Config.AudioConfig)
local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)

local AudioController = { Name = "AudioController" }

local controllers: any = nil
local player: Player? = nil
local soundFolder: Folder? = nil
local volumes: { [string]: number } = {}
local missingLogged: { [string]: boolean } = {}
local currentMusic: string? = nil

local DEFAULT_VOLUME = 0.7

local function ensureFolder(): Folder
	if soundFolder and soundFolder.Parent then
		return soundFolder
	end
	local parent = player or game:GetService("Players").LocalPlayer
	local character = parent.Character or parent.CharacterAdded:Wait()
	local folder = character:FindFirstChild("WB_Sounds")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WB_Sounds"
		folder.Parent = character
	end
	soundFolder = folder
	return folder
end

local function volumeFor(category: string): number
	return volumes[category] or DEFAULT_VOLUME
end

function AudioController.Init(svc: any, p: Player)
	controllers = svc
	player = p
	for _, category in Enums.AudioCategoryOrder do
		volumes[category] = DEFAULT_VOLUME
	end
end

-- Plays a sound by its CONFIGURED id. Returns false when the id is unknown or
-- has no asset yet, so callers can degrade gracefully.
function AudioController.Play(soundId: string, position: Vector3?): boolean
	local def = Audio:Has(soundId) and Audio:Get(soundId) or nil
	if not def then
		if not missingLogged[soundId] then
			missingLogged[soundId] = true
			Logger.Debug("Audio", string.format("sound %s is not registered yet", soundId))
		end
		return false
	end

	local assetId = def.assetId
	if type(assetId) ~= "string" or assetId == "" then
		if not missingLogged[soundId] then
			missingLogged[soundId] = true
			Logger.Debug("Audio", string.format("sound %s has no uploaded asset yet (placeholder)", soundId))
		end
		return false
	end

	local sound = Instance.new("Sound")
	sound.Name = soundId
	sound.SoundId = assetId
	sound.Volume = volumeFor(def.category or "SFX")
	sound.RollOffMaxDistance = def.maxDistance or 150
	sound.Parent = if position then game:GetService("Workspace").Terrain else ensureFolder()
	if position then
		-- Positional one-shots are parented to a transient part so they clean
		-- themselves up instead of accumulating.
		local emitter = Instance.new("Part")
		emitter.Name = "WB_Emitter"
		emitter.Size = Vector3.new(0.1, 0.1, 0.1)
		emitter.Transparency = 1
		emitter.CanCollide = false
		emitter.Anchored = true
		emitter.Position = position
		emitter.Parent = game:GetService("Workspace")
		sound.Parent = emitter
		sound.Ended:Connect(function()
			emitter:Destroy()
		end)
		game:GetService("Debris"):AddItem(emitter, (def.duration or 5) + 1)
	end
	sound:Play()
	if not position then
		game:GetService("Debris"):AddItem(sound, (def.duration or 5) + 1)
	end
	return true
end

function AudioController.SetVolume(category: string, value: number)
	volumes[category] = math.clamp(value, 0, 1)
end

function AudioController.SetMusic(musicId: string?)
	if currentMusic == musicId then
		return
	end
	currentMusic = musicId
	if musicId then
		AudioController.Play(musicId)
	end
end

function AudioController.Start()
	local Network = controllers.NetworkController
	local Settings_ = controllers.SettingsController

	Network.On(Remotes.PlaySound.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		AudioController.Play(tostring(payload.soundId), payload.position)
	end)

	Network.On(Remotes.MusicStateUpdated.name, function(payload: any)
		if type(payload) == "table" then
			AudioController.SetMusic(payload.musicId)
		end
	end)

	if Settings_ then
		for _, category in Enums.AudioCategoryOrder do
			local key = "audio_" .. string.lower(category)
			local stored = Settings_.Get(key)
			if type(stored) == "number" then
				volumes[category] = math.clamp(stored, 0, 1)
			end
		end
		Settings_.OnChanged(function(id: string, value: any)
			for _, category in Enums.AudioCategoryOrder do
				if id == "audio_" .. string.lower(category) and type(value) == "number" then
					volumes[category] = math.clamp(value, 0, 1)
				end
			end
		end)
	end
end

return AudioController
