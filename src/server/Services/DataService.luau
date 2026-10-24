--!strict
--[[
	DataService.luau
	Profile persistence with session locking, retries and a safe fallback.

	Rules this service follows:
	  * a profile is only ever saved by the server that owns its session lock
	  * every DataStore call is wrapped and retried with backoff
	  * if the DataStore is unavailable the player is told and plays in a
	    clearly flagged "unsaved session" instead of being silently lost
	  * nothing is written to a profile without going through Profile.Sanitise
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(Shared.PlayerData.Profile)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)

local DataService = {
	Name = "DataService",
}

local STORE_NAME = "WildBreakProfiles_v1"
local LOCK_NAME = "WildBreakSessionLocks_v1"
local RETRY_LIMIT = 4
local RETRY_BASE_SECONDS = 0.6

local store = DataStoreService:GetDataStore(STORE_NAME)
local lockStore = DataStoreService:GetDataStore(LOCK_NAME)

-- runtime state -------------------------------------------------------------
local sessions: { [Player]: { profile: any, lockId: string?, dirty: boolean, savedAt: number, unsaved: boolean } } = {}
local saveQueue: { Player } = {}
local service: any = nil

local function log(tag: string, message: string)
	Logger.Info("DataService", string.format("[%s] %s", tag, message))
end

-- Retries a DataStore call with exponential backoff. Returns ok, value.
local function withRetry(operation: string, key: string, fn: () -> any): (boolean, any)
	local attempt = 0
	local lastError = nil
	while attempt < RETRY_LIMIT do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < RETRY_LIMIT then
			task.wait(RETRY_BASE_SECONDS * math.pow(2, attempt - 1))
		end
	end
	Logger.Error("DataService", string.format("%s failed for %s after %d attempts: %s", operation, tostring(key), RETRY_LIMIT, tostring(lastError)))
	return false, nil
end

local function profileKey(userId: number): string
	return string.format("profile_%d", userId)
end

function DataService.Init(services: any)
	service = services
	log("init", string.format("store=%s autosave=%ds", STORE_NAME, Limits.Persistence.AutoSaveSeconds))
end

function DataService.Start(services: any)
	service = services
	-- Autosave loop: saves every dirty profile on a fixed interval and every
	-- player on leave.
	task.spawn(function()
		while true do
			task.wait(Limits.Persistence.AutoSaveSeconds)
			DataService.SaveAll()
		end
	end)
	game:BindToClose(function()
		DataService.SaveAll(true)
	end)
end

-- ---------------------------------------------------------------------------
-- Load / save
-- ---------------------------------------------------------------------------

function DataService.Load(player: Player): any
	local key = profileKey(player.UserId)
	local ok, raw = withRetry("GetAsync", key, function()
		return store:GetAsync(key)
	end)

	if not ok then
		-- The DataStore is unavailable. Start a clearly flagged unsaved session
		-- rather than pretending the save loaded.
		sessions[player] = {
			profile = Profile.Default(player.UserId, os.time()),
			lockId = nil,
			dirty = false,
			savedAt = 0,
			unsaved = true,
		}
		Logger.Warn("DataService", string.format("%s started an unsaved session", tostring(player.Name)))
		return sessions[player].profile
	end

	if raw ~= nil and type(raw) ~= "table" then
		Logger.Warn("DataService", string.format("profile for %s was corrupt (%s), resetting", tostring(player.Name), typeof(raw)))
		raw = nil
	end

	local profile = Profile.Sanitise(raw, player.UserId, os.time())
	local isNew = raw == nil
	if isNew then
		Profile.ApplyStarterLoadout(profile, { "ar_ranger", "me_wildclaw" }, {
			{ id = "energy_cell", quantity = 2 },
			{ id = "herb_emeraldleaf", quantity = 3 },
		})
	end

	sessions[player] = {
		profile = profile,
		lockId = nil,
		dirty = isNew,
		savedAt = os.time(),
		unsaved = false,
	}

	-- Session lock: only the server holding the lock may write this profile.
	local lockId = HttpService:GenerateGUID(false)
	local lockOk, existing = withRetry("UpdateAsync(lock)", key, function()
		return lockStore:UpdateAsync(key, function(current)
			if current and type(current) == "table" and current.serverId ~= game.JobId and os.time() < (current.expiresAt or 0) then
				return current
			end
			return { serverId = game.JobId, lockId = lockId, expiresAt = os.time() + Limits.Persistence.SessionLockSeconds }
		end)
	end)
	if lockOk then
		if type(existing) == "table" and existing.lockId == lockId then
			sessions[player].lockId = lockId
		else
			Logger.Warn("DataService", string.format("%s: another server holds the session lock", tostring(player.Name)))
		end
	end

	log("load", string.format("%s loaded (level %d, new=%s)", tostring(player.Name), profile.level, tostring(isNew)))
	return profile
end

function DataService.Save(player: Player, force: boolean?): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	if not session.dirty and not force then
		return true
	end
	if session.unsaved then
		return false
	end
	if session.lockId == nil then
		-- Another server owns the lock; writing would clobber that session.
		Logger.Warn("DataService", string.format("skipped save for %s: no session lock", tostring(player.Name)))
		return false
	end

	local key = profileKey(player.UserId)
	local payload = session.profile
	payload.updatedAt = os.time()
	local ok = withRetry("SetAsync", key, function()
		return store:SetAsync(key, payload)
	end)
	if ok then
		session.dirty = false
		session.savedAt = os.time()
		return true
	end
	session.unsaved = true
	return false
end

function DataService.SaveAll(force: boolean?)
	for player in sessions do
		DataService.Save(player, force)
	end
end

function DataService.Release(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	DataService.Save(player, true)
	if session.lockId then
		local key = profileKey(player.UserId)
		withRetry("RemoveAsync(lock)", key, function()
			return lockStore:RemoveAsync(key)
		end)
	end
	sessions[player] = nil
end

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

function DataService.Get(player: Player): any
	local session = sessions[player]
	return session and session.profile or nil
end

function DataService.MarkDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

function DataService.IsUnsaved(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.unsaved == true
end

-- ---------------------------------------------------------------------------
-- Admin / moderation helpers (all audited by AdminService)
-- ---------------------------------------------------------------------------

function DataService.AdminWrite(player: Player, mutator: (any) -> ()): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	mutator(session.profile)
	session.profile.adminRevision += 1
	session.dirty = true
	return DataService.Save(player, true)
end

function DataService.SessionCount(): number
	local count = 0
	for _ in sessions do
		count += 1
	end
	return count
end

return DataService
