--!strict
--[[
	AudioService.luau
	Server-side audio orchestration: SFX, voice lines, exploration ambience,
	combat music and boss music, all driven by AudioConfig.

	The service only ever tells clients which configured id to play and where;
	it never invents asset ids. If an id has no uploaded asset yet, the client
	falls back to silence and logs the placeholder, so nothing errors at
	runtime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)
local Audio = require(Shared.Config.AudioConfig)
local Regions = require(Shared.Config.RegionConfig)

local AudioService = {
	Name = "AudioService",
}

local currentMusic: { [Player]: string? } = {}
local services: any = nil

function AudioService.Init(svc: any)
	services = svc
end

function AudioService.Start(svc: any)
	services = svc
	task.spawn(function()
		while true do
			task.wait(1)
			AudioService.Tick()
		end
	end)
end

-- Plays a configured sound at a position for the players who can hear it.
function AudioService.Play(soundId: string, position: Vector3?, players: { Player }?)
	if not Audio:Has(soundId) then
		Logger.Warn("AudioService", string.format("unknown sound id %s", soundId))
		return
	end
	local audience = players or game:GetService("Players"):GetPlayers()
	for _, player in audience do
		services.NetworkService.Fire(player, Remotes.PlayAudio.name, { soundId = soundId, position = position })
	end
end

function AudioService.PlayForPlayer(player: Player, soundId: string)
	if not Audio:Has(soundId) then
		return
	end
	services.NetworkService.Fire(player, Remotes.PlayAudio.name, { soundId = soundId })
end

-- Sets a player's music state, only when it actually changes.
function AudioService.SetMusic(player: Player, musicId: string?)
	if currentMusic[player] == musicId then
		return
	end
	currentMusic[player] = musicId
	services.NetworkService.Fire(player, Remotes.MusicStateUpdated.name, { musicId = musicId })
end

function AudioService.Tick()
	for _, player in game:GetService("Players"):GetPlayers() do
		local state = services.PlayerService.Get(player)
		if not state then
			continue
		end
		if state.inBossEncounter then
			AudioService.SetMusic(player, Audio.Music.boss)
		elseif state.inCombat then
			AudioService.SetMusic(player, Audio.Music.combat)
		elseif state.regionId then
			local region = Regions:Get(state.regionId)
			local ambience = region and region.ambienceId or nil
			if not ambience or Audio.Ambience[ambience] == nil then
				ambience = Audio.Music.exploration
			end
			AudioService.SetMusic(player, ambience)
		else
			AudioService.SetMusic(player, Audio.Music.menu)
		end
	end
end

function AudioService.OnPlayerRemoving(player: Player)
	currentMusic[player] = nil
end

function AudioService.PlayAmbience(player: Player, regionId: string)
	local region = Regions:Get(regionId)
	if not region or not region.ambienceId then
		return
	end
	-- Ambience is always paired with an event so it can be mixed properly.
	AudioService.PlayForPlayer(player, region.ambienceId)
	services.NetworkService.Fire(player, Remotes.PlayAudio.name, { event = Enums.AudioEvent.Ambience, regionId = regionId })
end

return AudioService
