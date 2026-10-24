--!strict
--[[
	AdminConfig.luau
	Permissions, actions and the audit log rules for the admin panel.

	OWNER ALLOWLIST - PLACEHOLDER
	--------------------------------------------------------------------
	The panel is restricted to exactly two owners. The two UserIds have NOT
	been supplied yet, so `OwnerUserIds` is empty and `PanelEnabled` is false.
	The panel runs in a disabled, test-only mode: every command is validated
	and logged, but none of them execute against live player data until the
	real UserIds are filled in here (or in the matching secure secret store)
	and `PanelEnabled` is set to true.

	Nothing here grants authority based on a name, a group rank or a client
	claim. Authority is a UserId comparison, evaluated on the server.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)

local Admin = {}

Admin.OwnerUserIds = {} :: { number }
Admin.PanelEnabled = false
-- Set to false only after the real owner UserIds are present.
Admin.TestOnlyMode = true

export type AdminActionDef = {
	id: string,
	displayName: string,
	minimumLevel: number,
	-- Actions that change another player's progress or inventory are always
	-- written to the audit log and are never reversible silently.
	destructive: boolean,
	-- Whether the action needs a written reason from the operator.
	requiresReason: boolean,
	category: string,
	description: string,
}

Admin.Actions = {
	{ id = "view_status", displayName = "View server status", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "Diagnostic", description = "Read-only server health, population and performance." },
	{ id = "view_player", displayName = "Inspect a player", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "Diagnostic", description = "Read-only view of a player's progression and inventory." },
	{ id = "teleport_to_player", displayName = "Teleport to a player", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "Movement", description = "Move yourself to another player." },
	{ id = "teleport_player", displayName = "Teleport a player", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Movement", description = "Move another player to a location." },
	{ id = "give_item", displayName = "Grant an item", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Inventory", description = "Add items to a player's inventory." },
	{ id = "remove_item", displayName = "Remove an item", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Inventory", description = "Remove items from a player's inventory." },
	{ id = "set_level", displayName = "Set level", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Progression", description = "Change a player's level." },
	{ id = "set_currency", displayName = "Set currency", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Economy", description = "Change a player's Sap or coin balance." },
	{ id = "spawn_beast", displayName = "Spawn a beast", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "World", description = "Spawn a beast for testing." },
	{ id = "spawn_boss", displayName = "Spawn a boss", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "World", description = "Start a boss encounter for testing." },
	{ id = "start_event", displayName = "Start a world event", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "World", description = "Force-start a regional world event." },
	{ id = "grant_reward", displayName = "Grant an event reward", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Economy", description = "Grant a reward table to a player." },
	{ id = "kick_player", displayName = "Kick a player", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Moderation", description = "Remove a player from the server." },
	{ id = "ban_player", displayName = "Ban a player", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Moderation", description = "Ban a player. Requires a written reason." },
	{ id = "unban_player", displayName = "Unban a player", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Moderation", description = "Lift a ban." },
	{ id = "reset_dungeon", displayName = "Reset a dungeon", minimumLevel = Enums.AdminLevel.Tester, destructive = false, requiresReason = false, category = "World", description = "Reset dungeon progress for a testing group." },
	{ id = "view_audit_log", displayName = "View the audit log", minimumLevel = Enums.AdminLevel.Owner, destructive = false, requiresReason = false, category = "Audit", description = "Read the admin audit log." },
	{ id = "export_audit_log", displayName = "Export the audit log", minimumLevel = Enums.AdminLevel.Owner, destructive = false, requiresReason = true, category = "Audit", description = "Export the audit log for review." },
	{ id = "broadcast", displayName = "Server announcement", minimumLevel = Enums.AdminLevel.Owner, destructive = false, requiresReason = true, category = "Communication", description = "Send a server-wide announcement." },
	{ id = "toggle_maintenance", displayName = "Toggle maintenance mode", minimumLevel = Enums.AdminLevel.Owner, destructive = true, requiresReason = true, category = "Server", description = "Block new joins during maintenance." },
}

local actionById: { [string]: AdminActionDef } = {}
for _, action in Admin.Actions do
	actionById[action.id] = action
end

Admin.Audit = {
	enabled = true,
	-- Every entry records who, what, when, the target and the reason.
	retentionDays = 90,
	maxEntriesPerRequest = 200,
	-- Audit entries are append-only: nothing in the game can edit or delete
	-- them from inside an admin action.
	appendOnly = true,
	-- Results are recorded for denied attempts too.
	recordDenied = true,
}

-- Evaluated on the server only.
function Admin.LevelFor(userId: number): number
	if #Admin.OwnerUserIds == 0 then
		-- No owner ids have been supplied: nobody has authority.
		return Enums.AdminLevel.None
	end
	for _, ownerId in Admin.OwnerUserIds do
		if ownerId == userId then
			return Enums.AdminLevel.Owner
		end
	end
	return Enums.AdminLevel.None
end

function Admin.Can(userId: number, actionId: string): boolean
	local action = actionById[actionId]
	if not action then
		return false
	end
	if not Admin.PanelEnabled then
		return false
	end
	return Admin.LevelFor(userId) >= action.minimumLevel
end

function Admin.Action(actionId: string): AdminActionDef?
	return actionById[actionId]
end

function Admin.ValidateAll(): { string }
	local problems = {}
	if #Admin.OwnerUserIds > 2 then
		table.insert(problems, "[Admin] the panel is restricted to at most two owners")
	end
	for _, userId in Admin.OwnerUserIds do
		if type(userId) ~= "number" or userId <= 0 or math.floor(userId) ~= userId then
			table.insert(problems, "[Admin] owner UserIds must be positive integers")
		end
	end
	if Admin.PanelEnabled and #Admin.OwnerUserIds == 0 then
		table.insert(problems, "[Admin] the panel cannot be enabled without owner UserIds")
	end
	local seen = {}
	for _, action in Admin.Actions do
		if seen[action.id] then
			table.insert(problems, string.format("[Admin] duplicate action %s", action.id))
		end
		seen[action.id] = true
		if action.destructive and not action.requiresReason then
			table.insert(problems, string.format("[Admin] destructive action %s must require a reason", action.id))
		end
		if action.minimumLevel < Enums.AdminLevel.Tester then
			table.insert(problems, string.format("[Admin] action %s cannot be available to non-staff", action.id))
		end
	end
	if not Admin.Audit.enabled then
		table.insert(problems, "[Admin] the audit log must stay enabled")
	end
	if not Admin.Audit.appendOnly then
		table.insert(problems, "[Admin] the audit log must be append-only")
	end
	if Admin.Can(1, "ban_player") then
		table.insert(problems, "[Admin] an arbitrary user id must never have authority")
	end
	return problems
end

return Admin
