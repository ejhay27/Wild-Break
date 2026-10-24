--!strict
--[[
	SpawnService.luau
	Character lifecycle: building the world, putting characters into it, and
	getting them back out when they die or fall out of it.

	Before this service existed the server never called LoadCharacter, never
	created a SpawnLocation and had no notion of a world floor, so a player
	who joined had nowhere to appear and a player who fell had no way back.
	This is the piece that turns the simulated systems into a place you can
	stand in.

	Rules:
	  * the world is built exactly once, at server start, before anyone joins
	  * spawning is always at Haven Overlook (the hub)
	  * the server owns character stats; clients never set health or speed
	  * falling out of the world is detected and recovered rather than
	    leaving a player falling forever
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Deployment = require(Shared.Config.DeploymentConfig)
local Regions = require(Shared.Config.RegionConfig)
local WorldBuilder = require(Server:WaitForChild("World"):WaitForChild("WorldBuilder"))

local SpawnService = {
	Name = "SpawnService",
}

local services: any = nil

-- Below this altitude a character is considered to have fallen out of the
-- world. It sits well under the lowest region plate (Frostveil at y=25) and
-- above Workspace.FallenPartsDestroyHeight.
local WORLD_FLOOR_Y = -600

-- How often fall-out is checked. This is cheap and does not need to run at
-- frame rate.
local FALL_CHECK_INTERVAL_SECONDS = 1

-- Deployment is manual so the hub spawn point is used rather than Roblox
-- dropping characters at the origin.
Players.CharacterAutoLoads = false

local lastFallCheck = 0

function SpawnService.Init(svc: any)
	services = svc

	if not WorldBuilder.Claim("SpawnService") then
		Logger.Warn("SpawnService", "the world was already claimed; not rebuilding it")
		return
	end

	local ok, err = pcall(function()
		WorldBuilder.Build()
	end)
	if not ok then
		Logger.Error("SpawnService", string.format("world generation failed: %s", tostring(err)))
	else
		Logger.Info(
			"SpawnService",
			string.format("world ready: %d regions, spawn at %s", WorldBuilder.Count(), tostring(WorldBuilder.SpawnCFrameValue()))
		)
	end
end

function SpawnService.Start(svc: any)
	services = svc

	Players.PlayerAdded:Connect(function(player)
		SpawnService.OnPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		SpawnService.OnPlayerRemoving(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			SpawnService.OnPlayerAdded(player)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Character setup
-- ---------------------------------------------------------------------------

-- Applies the server's authoritative stats to a freshly spawned character.
local function configureCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Walk speed and jump power come from StarterPlayer, so they stay in one
	-- place. Health is authoritative here: the server sets it, never a client.
	humanoid.MaxHealth = Limits.Survival.MaxHealth
	humanoid.Health = Limits.Survival.MaxHealth

	-- Death is handled by PlayerService (downed state), so the engine's own
	-- death handling must not also destroy the character out from under it.
	humanoid.BreakJointsOnDeath = false

	local state = services.PlayerService and services.PlayerService.Get(player)
	if state then
		humanoid.Health = math.max(1, state.health)
	end
end

function SpawnService.OnPlayerAdded(player: Player)
	-- Load order: the profile has to exist before the character is placed,
	-- so the spawn waits for PlayerService to have handled the join.
	if services.PlayerService and not services.PlayerService.Get(player) then
		local waited = 0
		while not services.PlayerService.Get(player) and waited < 10 do
			task.wait(0.25)
			waited += 0.25
		end
	end

	player.CharacterAdded:Connect(function(character)
		configureCharacter(player, character)
	end)

	SpawnService.SpawnAtHub(player)
end

function SpawnService.OnPlayerRemoving(_player: Player) end

-- ---------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------

-- Places a character into the hub. Used for the first join and for every
-- respawn afterwards.
function SpawnService.SpawnAtHub(player: Player)
	local cframe = WorldBuilder.SpawnCFrameValue()

	local ok, err = pcall(function()
		if player.Character then
			-- Reuse the existing character so equipment and state survive.
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				player.Character:PivotTo(cframe)
				return
			end
		end
		player:LoadCharacter()
	end)
	if not ok then
		Logger.Warn("SpawnService", string.format("could not spawn %s: %s", tostring(player.Name), tostring(err)))
		return false
	end

	-- LoadCharacter does not place at an arbitrary CFrame, so set it once the
	-- character exists.
	SpawnService.Teleport(player, cframe)

	if services.WorldService and services.WorldService.ResetPosition then
		services.WorldService.ResetPosition(player)
	end

	Logger.Debug("SpawnService", string.format("%s spawned at Haven Overlook", tostring(player.Name)))
	return true
end

function SpawnService.RespawnAtHub(player: Player)
	local delaySeconds = Deployment.Respawn and Deployment.Respawn.delaySeconds or 5
	task.delay(delaySeconds, function()
		if player.Parent ~= Players then
			return
		end
		SpawnService.SpawnAtHub(player)
	end)
end

-- Moves a character to a CFrame, waiting briefly for it to exist.
function SpawnService.Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	character:PivotTo(cframe)
	return true
end

-- ---------------------------------------------------------------------------
-- Fall recovery
-- ---------------------------------------------------------------------------

-- If a character ends up under the world it is returned to the hub rather
-- than falling forever. This is the safety net that makes "no falling
-- through the world" true even when terrain generation is wrong.
function SpawnService.Tick()
	local now = os.clock()
	if now - lastFallCheck < FALL_CHECK_INTERVAL_SECONDS then
		return
	end
	lastFallCheck = now

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local position = root.Position
		if position.Y > WORLD_FLOOR_Y then
			continue
		end

		Logger.Warn(
			"SpawnService",
			string.format("%s fell out of the world at y=%.0f, returning to the hub", tostring(player.Name), position.Y)
		)
		if services.PlayerService and services.PlayerService.ApplyDamage then
			-- Falling out is lethal; the normal death/respawn flow handles it.
			services.PlayerService.ApplyDamage(player, Limits.Survival.MaxHealth, "fall_out_of_world")
		end
		SpawnService.SpawnAtHub(player)
	end
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- The hub a player returns to after a wipe or a respawn.
function SpawnService.HubId(): string
	return Regions.HubId
end

function SpawnService.HubPosition(): Vector3
	return WorldBuilder.SpawnCFrameValue().Position
end

function SpawnService.IsWorldReady(): boolean
	return WorldBuilder.IsBuilt()
end

function SpawnService.RegionCount(): number
	return WorldBuilder.Count()
end

return SpawnService
