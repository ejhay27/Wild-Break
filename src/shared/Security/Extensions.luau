--!strict
--[[
	Extensions.luau
	Security helpers layered on top of AdminConfig.

	WILDBREAK uses a two-owner allowlist. Until the real owner UserIds are
	supplied, `AdminConfig.OwnerUserIds` is empty, `PanelEnabled` is false and
	every privileged action is refused. This module is the SINGLE place where
	that decision is made, so no service can accidentally authorise an
	operator by a different rule.

	Nothing here is exposed to clients: it lives under ReplicatedStorage
	because both the server services and the shared remote definitions need to
	agree on what "authorised" means, but it performs no privileged work by
	itself and stores no secrets.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local Admin = require(script.Parent.Parent.Config.AdminConfig)

local Extensions = {}

export type Decision = {
	allowed: boolean,
	reason: string,
	userId: number,
	actionId: string?,
}

-- ---------------------------------------------------------------------------
-- Feature gate
-- ---------------------------------------------------------------------------

-- The admin panel is disabled until real owner UserIds exist.
function Extensions.IsAdminEnabled(): boolean
	return Admin.PanelEnabled and #Admin.OwnerUserIds > 0
end

-- Services call this once at startup so the disabled state is visible in the
-- output log instead of failing silently later.
function Extensions.LogAdminDisabled(context: string?)
	Logger.Warn(
		"Security",
		string.format(
			"%s: admin panel is DISABLED (OwnerUserIds is empty). "
				.. "Add the real owner UserIds to src/shared/Config/AdminConfig.luau "
				.. "and set PanelEnabled = true to enable it.",
			context or "Admin"
		)
	)
end

-- ---------------------------------------------------------------------------
-- Authorisation
-- ---------------------------------------------------------------------------

-- Minimum admin level an action requires, or the highest level when the
-- action is unknown. Unknown actions are treated as maximally privileged so a
-- typo can never grant access.
function Extensions.AdminLevel(actionId: string?): number
	if not actionId then
		return Enums.AdminLevel.Owner
	end
	local action = Admin.Action(actionId)
	if not action then
		return Enums.AdminLevel.Owner
	end
	return action.minimumLevel
end

-- The single authorisation decision point.
-- `requiredLevel` is optional; when omitted the action's own minimum level is
-- used (or Owner for unknown actions).
function Extensions.IsAuthorised(userId: number, actionId: string?, requiredLevel: number?): boolean
	return Extensions.Decide(userId, actionId, requiredLevel).allowed
end

-- Same decision, with the reason attached, so callers can audit denials.
function Extensions.Decide(userId: number, actionId: string?, requiredLevel: number?): Decision
	local minimum = requiredLevel or Extensions.AdminLevel(actionId)

	if not Extensions.IsAdminEnabled() then
		return {
			allowed = false,
			reason = "Admin panel is disabled: no owner UserIds have been supplied.",
			userId = userId,
			actionId = actionId,
		}
	end

	local level = Admin.LevelFor(userId)
	if level < minimum then
		return {
			allowed = false,
			reason = string.format("Requires admin level %d, operator has %d.", minimum, level),
			userId = userId,
			actionId = actionId,
		}
	end

	if Admin.TestOnlyMode then
		-- Test-only mode still authorises, but the action is recorded as
		-- non-production so an operator cannot mistake it for a live change.
		return {
			allowed = true,
			reason = "Authorised in test-only mode.",
			userId = userId,
			actionId = actionId,
		}
	end

	return {
		allowed = true,
		reason = "Authorised.",
		userId = userId,
		actionId = actionId,
	}
end

-- Backwards-compatible alias used by AdminService.
function Extensions.IsOwner(userId: number, requiredLevel: number?): boolean
	return Extensions.IsAuthorised(userId, nil, requiredLevel or Enums.AdminLevel.Owner)
end

-- ---------------------------------------------------------------------------
-- Client input validation helpers
-- ---------------------------------------------------------------------------

-- Rejects any client-supplied number that is not finite. NaN and infinity
-- survive JSON-style round trips and silently poison saved data.
function Extensions.IsFiniteNumber(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Clamps a client-supplied number into an inclusive range and rejects
-- non-numbers outright.
function Extensions.SanitiseNumber(value: any, minimum: number, maximum: number, fallback: number): number
	if not Extensions.IsFiniteNumber(value) then
		return fallback
	end
	return math.clamp(value :: number, minimum, maximum)
end

-- Client-supplied strings are length-capped so a remote cannot be used to
-- push unbounded text into a DataStore.
function Extensions.SanitiseString(value: any, maxLength: number, fallback: string): string
	if type(value) ~= "string" then
		return fallback
	end
	if #value > maxLength then
		return string.sub(value, 1, maxLength)
	end
	return value
end

return Extensions
