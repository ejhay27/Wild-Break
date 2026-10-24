--!strict
--[[
	NetworkService.luau
	Owns every remote in the game.

	Nothing else may create a RemoteEvent or RemoteFunction: the definitions in
	shared/Networking/Remotes are the only source of truth, and every inbound
	call passes through schema validation, rate limiting, admin authorisation
	and audit logging before it reaches a handler.

	The service is deliberately strict:
	  * unknown remotes are refused and logged
	  * payloads are validated against the declared schema
	  * per-player token buckets rate limit every client-originated remote
	  * calls that fail validation are counted, never silently dropped
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Networking.Remotes)
local Packet = require(ReplicatedStorage:WaitForChild("Shared").Networking.Packet)
local Enums = require(ReplicatedStorage:WaitForChild("Shared").Constants.Enums)
local Limits = require(ReplicatedStorage:WaitForChild("Shared").Constants.Limits)
local Logger = require(ReplicatedStorage:WaitForChild("Shared").Utilities.Logger)

local NetworkService = {
	Name = "NetworkService",
}

export type Request = {
	player: Player,
	definition: any,
	args: { any },
}

local folder: Folder? = nil
local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local handlers: { [string]: (Player, { any }) -> any } = {}
local hooks: { [string]: { (Player, { any }) -> (boolean, string?) } } = {}

-- bucket[player][remoteName] = { tokens, updatedAt }
local buckets: { [Player]: { [string]: { tokens: number, updatedAt: number } } } = {}
local violationCounts: { [Player]: number } = {}
local muted: { [Player]: number } = {}

local stats = {
	inbound = 0,
	rejected = 0,
	rateLimited = 0,
	outbound = 0,
}

local function now(): number
	return os.clock()
end

local function bucketFor(player: Player, name: string, rate: number, burst: number)
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local entry = perPlayer[name]
	if not entry then
		entry = { tokens = burst, updatedAt = now() }
		perPlayer[name] = entry
	end
	return entry
end

-- Token bucket. Returns true when the call is allowed.
local function consume(player: Player, name: string, definition: any): boolean
	local rate = definition.rateLimit or Limits.Networking.DefaultRatePerSecond
	local burst = definition.burst or math.max(1, math.ceil(rate))
	local entry = bucketFor(player, name, rate, burst)
	local elapsed = now() - entry.updatedAt
	entry.updatedAt = now()
	entry.tokens = math.min(burst, entry.tokens + elapsed * rate)
	if entry.tokens < 1 then
		return false
	end
	entry.tokens -= 1
	return true
end

local function recordViolation(player: Player, reason: string)
	stats.rejected += 1
	violationCounts[player] = (violationCounts[player] or 0) + 1
	Logger.Warn("NetworkService", string.format("rejected %s from %s: %s", reason, tostring(player.Name), tostring(player.UserId)))
	if violationCounts[player] >= Limits.Networking.ViolationsBeforeKick then
		Logger.Error("NetworkService", string.format("kicking %s after repeated protocol violations", tostring(player.Name)))
		player:Kick("Connection closed: repeated invalid network requests.")
	end
end

function NetworkService.Init(services: any)
	NetworkService.Services = services
	folder = Instance.new("Folder")
	folder.Name = "WB_Remotes"
	folder.Parent = ReplicatedStorage

	for _, definition in Remotes.All() do
		if definition.kind == "Function" then
			local remote = Instance.new("RemoteFunction")
			remote.Name = definition.name
			remote.Parent = folder
			functions[definition.name] = remote
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = definition.name
			remote.Parent = folder
			events[definition.name] = remote
		end
	end
	Logger.Info("NetworkService", string.format("created %d remotes", Remotes.Count()))
end

function NetworkService.Start(services: any)
	NetworkService.Services = services

	for _, definition in Remotes.All() do
		local remote = if definition.kind == "Function" then functions[definition.name] else events[definition.name]
		if not remote then
			continue
		end
		if definition.direction == "ServerToClient" then
			continue
		end

		local name = definition.name
		if definition.kind == "Function" then
			(remote :: RemoteFunction).OnServerInvoke = function(player: Player, ...)
				return NetworkService.Handle(player, name, { ... })
			end
		else
			(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
				NetworkService.Handle(player, name, { ... })
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		violationCounts[player] = nil
		muted[player] = nil
	end)

	if RunService:IsStudio() then
		Logger.Info("NetworkService", "running in Studio: remote validation and rate limiting are active")
	end
end

-- The single entry point for every inbound call.
function NetworkService.Handle(player: Player, remoteName: string, args: { any }): any
	stats.inbound += 1
	local definition = Remotes.Get(remoteName)
	if not definition or definition.direction == "ServerToClient" then
		recordViolation(player, "unknown remote " .. tostring(remoteName))
		return nil
	end

	if muted[player] and os.time() < muted[player] then
		return nil
	end

	if not consume(player, remoteName, definition) then
		stats.rateLimited += 1
		return nil
	end

	-- Schema validation: refuse anything that does not match the declaration.
	if definition.args then
		local ok, problems = Packet.ValidateArgs(definition.args, args)
		if not ok then
			recordViolation(player, string.format("invalid payload for %s (%s)", remoteName, tostring(problems)))
			return nil
		end
	elseif #args > Limits.Networking.MaxUnscheduledArguments then
		recordViolation(player, "oversized payload for " .. remoteName)
		return nil
	end

	if definition.adminLevel and definition.adminLevel > 0 then
		local admin = NetworkService.Services and NetworkService.Services.AdminService
		if not admin or not admin.IsAuthorised(player.UserId, definition.adminLevel) then
			if admin then
				admin.RecordDenied(player, remoteName)
			end
			Logger.Warn("NetworkService", string.format("%s attempted privileged remote %s", tostring(player.Name), remoteName))
			return nil
		end
	end

	for _, hook in hooks[remoteName] or {} do
		local allowed, reason = hook(player, args)
		if not allowed then
			recordViolation(player, string.format("blocked %s (%s)", remoteName, tostring(reason)))
			return nil
		end
	end

	local handler = handlers[remoteName]
	if not handler then
		Logger.Warn("NetworkService", string.format("no handler registered for %s", remoteName))
		return nil
	end

	local ok, result = pcall(handler, player, args)
	if not ok then
		Logger.Error("NetworkService", string.format("handler for %s failed: %s", remoteName, tostring(result)))
		return nil
	end
	return result
end

function NetworkService.On(remoteName: string, handler: (Player, { any }) -> any)
	handlers[remoteName] = handler
end

function NetworkService.Before(remoteName: string, hook: (Player, { any }) -> (boolean, string?))
	if not hooks[remoteName] then
		hooks[remoteName] = {}
	end
	table.insert(hooks[remoteName], hook)
end

-- ---------------------------------------------------------------------------
-- Outbound
-- ---------------------------------------------------------------------------

function NetworkService.Fire(player: Player, remoteName: string, ...): boolean
	local definition = Remotes.Get(remoteName)
	if not definition or definition.direction == "ClientToServer" then
		Logger.Error("NetworkService", "refusing to fire " .. tostring(remoteName) .. " to a client")
		return false
	end
	local remote = events[remoteName]
	if not remote then
		return false
	end
	stats.outbound += 1
	remote:FireClient(player, ...)
	return true
end

function NetworkService.FireAll(remoteName: string, ...): boolean
	local definition = Remotes.Get(remoteName)
	if not definition or definition.direction == "ClientToServer" then
		Logger.Error("NetworkService", "refusing to broadcast " .. tostring(remoteName))
		return false
	end
	local remote = events[remoteName]
	if not remote then
		return false
	end
	stats.outbound += 1
	remote:FireAllClients(...)
	return true
end

function NetworkService.FireExcept(remoteName: string, except: Player, ...): boolean
	local definition = Remotes.Get(remoteName)
	if not definition or definition.direction == "ClientToServer" then
		return false
	end
	local remote = events[remoteName]
	if not remote then
		return false
	end
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
	stats.outbound += 1
	return true
end

function NetworkService.Mute(player: Player, seconds: number)
	muted[player] = os.time() + math.max(1, seconds)
end

function NetworkService.Unmute(player: Player)
	muted[player] = nil
end

function NetworkService.Stats()
	return stats
end

return NetworkService
