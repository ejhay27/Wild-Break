--!strict
--[[
	ClanConfig.luau
	Clan structure, permissions, and the three Clan War modes.

	Clan War is an opt-in competitive mode. It never changes the open world and
	never blocks access to resources, dungeons or bosses.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Clan = {}

export type PermissionDef = {
	id: string,
	displayName: string,
	minimumRole: string,
	description: string,
}

Clan.Permissions = {
	{ id = "invite", displayName = "Invite members", minimumRole = Enums.ClanRole.Officer, description = "Send clan invites." },
	{ id = "kick", displayName = "Kick members", minimumRole = Enums.ClanRole.Officer, description = "Remove a member below your role." },
	{ id = "promote", displayName = "Promote members", minimumRole = Enums.ClanRole.Officer, description = "Promote a member below your role." },
	{ id = "demote", displayName = "Demote members", minimumRole = Enums.ClanRole.Officer, description = "Demote a member below your role." },
	{ id = "edit_motd", displayName = "Edit the message of the day", minimumRole = Enums.ClanRole.Officer, description = "Change the clan MOTD." },
	{ id = "withdraw", displayName = "Withdraw from the vault", minimumRole = Enums.ClanRole.Officer, description = "Take items from the clan vault." },
	{ id = "start_war", displayName = "Queue a Clan War", minimumRole = Enums.ClanRole.Officer, description = "Queue the clan for a Clan War match." },
	{ id = "manage_roles", displayName = "Manage roles", minimumRole = Enums.ClanRole.Owner, description = "Change another member's role." },
	{ id = "disband", displayName = "Disband the clan", minimumRole = Enums.ClanRole.Owner, description = "Permanently disband the clan." },
	{ id = "transfer_ownership", displayName = "Transfer ownership", minimumRole = Enums.ClanRole.Owner, description = "Hand the clan to another member." },
}

local permissionById: { [string]: PermissionDef } = {}
for _, permission in Clan.Permissions do
	permissionById[permission.id] = permission
end

function Clan.Can(role: string, permissionId: string): boolean
	local permission = permissionById[permissionId]
	if not permission then
		return false
	end
	return (Enums.ClanRoleRank[role] or 0) >= (Enums.ClanRoleRank[permission.minimumRole] or 0)
end

Clan.Limits = {
	maxNameLength = Limits.Clan.MaxNameLength,
	minNameLength = Limits.Clan.MinNameLength,
	maxMembers = Limits.Clan.MaxMembers,
	maxOfficers = Limits.Clan.MaxOfficers,
	maxInvitesOutstanding = Limits.Clan.MaxInvitesOutstanding,
	inviteExpirySeconds = Limits.Clan.InviteExpirySeconds,
	createCostSap = 25,
	renameCostSap = 10,
	renameCooldownSeconds = 604800,
}

Clan.Ranks = {
	-- Reputation thresholds for the public clan ladder.
	{ id = "bronze", displayName = "Bronze", minRating = 0 },
	{ id = "silver", displayName = "Silver", minRating = 1200 },
	{ id = "gold", displayName = "Gold", minRating = 1600 },
	{ id = "platinum", displayName = "Platinum", minRating = 2000 },
	{ id = "apex", displayName = "Apex", minRating = 2400 },
}

function Clan.RankFor(rating: number): string
	local best = "bronze"
	for _, rank in Clan.Ranks do
		if rating >= rank.minRating then
			best = rank.id
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- Clan War
-- ---------------------------------------------------------------------------

export type ClanWarModeDef = {
	id: string,
	displayName: string,
	description: string,
	scoreLimit: number,
	durationSeconds: number,
	objectiveCount: number,
	-- Seconds needed to capture one objective.
	captureSeconds: number,
	-- Points awarded per second per held objective.
	pointsPerSecond: number,
	-- Points awarded for eliminating an enemy player.
	pointsPerElimination: number,
	respawnDelaySeconds: number,
	-- Beasts can be turned into objectives in Beastfront War.
	beastObjectives: boolean,
	-- Vehicle / boat support inside the match.
	boatsEnabled: boolean,
	rewards: { winSap: number, lossSap: number, winRating: number, lossRating: number },
}

Clan.WarModes = {
	[Enums.ClanWarMode.OutpostAssault] = {
		id = Enums.ClanWarMode.OutpostAssault,
		displayName = "Outpost Assault",
		description = "One team defends a fortified outpost while the other attacks. Sides swap after the first half.",
		scoreLimit = Limits.ClanWar.ScoreLimit,
		durationSeconds = Limits.ClanWar.MatchDurationSeconds,
		objectiveCount = 3,
		captureSeconds = 12,
		pointsPerSecond = 1.5,
		pointsPerElimination = 6,
		respawnDelaySeconds = 8,
		beastObjectives = false,
		boatsEnabled = true,
		rewards = { winSap = 12, lossSap = 4, winRating = 25, lossRating = -12 },
	},
	[Enums.ClanWarMode.CoreControl] = {
		id = Enums.ClanWarMode.CoreControl,
		displayName = "Core Control",
		description = "Fight for rotating cores across the arena. Holding more cores scores faster.",
		scoreLimit = Limits.ClanWar.ScoreLimit,
		durationSeconds = Limits.ClanWar.MatchDurationSeconds,
		objectiveCount = 5,
		captureSeconds = 4,
		pointsPerSecond = 2.2,
		pointsPerElimination = 5,
		respawnDelaySeconds = 6,
		beastObjectives = false,
		boatsEnabled = false,
		rewards = { winSap = 12, lossSap = 4, winRating = 25, lossRating = -12 },
	},
	[Enums.ClanWarMode.BeastfrontWar] = {
		id = Enums.ClanWarMode.BeastfrontWar,
		displayName = "Beastfront War",
		description = "Both teams fight the local wildlife for control of the beast front. Tamed companions join the fight.",
		scoreLimit = Limits.ClanWar.ScoreLimit,
		durationSeconds = Limits.ClanWar.MatchDurationSeconds,
		objectiveCount = 4,
		captureSeconds = 8,
		pointsPerSecond = 1.8,
		pointsPerElimination = 8,
		respawnDelaySeconds = 7,
		beastObjectives = true,
		boatsEnabled = true,
		rewards = { winSap = 16, lossSap = 5, winRating = 30, lossRating = -14 },
	},
}

Clan.War = {
	supportedConfigurations = Limits.ClanWar.SupportedConfigurations,
	maxTotalPlayers = Limits.ClanWar.MaxTotalPlayers,
	queueTimeoutSeconds = Limits.ClanWar.QueueTimeoutSeconds,
	maxActiveMatches = Limits.ClanWar.MaxActiveMatches,
	disconnectGraceSeconds = Limits.ClanWar.DisconnectGraceSeconds,
	rejoinWindowSeconds = Limits.ClanWar.RejoinWindowSeconds,
	-- Anti-abuse: leaving a match early blocks requeueing for a while.
	deserterPenaltySeconds = 300,
	-- Rating is only exchanged between clans of comparable strength.
	maxRatingDeltaForRanked = 400,
}

function Clan.Mode(id: string): ClanWarModeDef?
	return Clan.WarModes[id]
end

function Clan.Modes(): { ClanWarModeDef }
	local out = {}
	for _, mode in Clan.WarModes do
		table.insert(out, mode)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Clan.IsSupportedConfiguration(teams: number, perTeam: number): boolean
	for _, configuration in Clan.War.supportedConfigurations do
		if configuration.teams == teams and configuration.perTeam == perTeam then
			return true
		end
	end
	return false
end

function Clan.ValidateAll(): { string }
	local problems = {}
	if #Clan.Modes() ~= 3 then
		table.insert(problems, string.format("[Clan] expected 3 Clan War modes, found %d", #Clan.Modes()))
	end
	for _, mode in Clan.Modes() do
		if mode.scoreLimit <= 0 then
			table.insert(problems, string.format("[Clan] %s needs a positive score limit", mode.id))
		end
		if mode.objectiveCount < 1 then
			table.insert(problems, string.format("[Clan] %s needs at least one objective", mode.id))
		end
		if mode.captureSeconds <= 0 then
			table.insert(problems, string.format("[Clan] %s needs a positive capture time", mode.id))
		end
		if mode.rewards.winSap < mode.rewards.lossSap then
			table.insert(problems, string.format("[Clan] %s rewards losing more than winning", mode.id))
		end
	end
	local seenPermissions = {}
	for _, permission in Clan.Permissions do
		if seenPermissions[permission.id] then
			table.insert(problems, string.format("[Clan] duplicate permission %s", permission.id))
		end
		seenPermissions[permission.id] = true
		if Enums.ClanRoleRank[permission.minimumRole] == nil then
			table.insert(problems, string.format("[Clan] permission %s references unknown role %s", permission.id, tostring(permission.minimumRole)))
		end
	end
	if Clan.Can(Enums.ClanRole.Member, "invite") then
		table.insert(problems, "[Clan] members must not be able to invite")
	end
	if not Clan.Can(Enums.ClanRole.Officer, "invite") then
		table.insert(problems, "[Clan] officers must be able to invite")
	end
	if not Clan.Can(Enums.ClanRole.Owner, "disband") then
		table.insert(problems, "[Clan] the owner must be able to disband")
	end
	if Clan.Can(Enums.ClanRole.Member, "disband") then
		table.insert(problems, "[Clan] members must not be able to disband")
	end
	for _, configuration in Clan.War.supportedConfigurations do
		if configuration.teams * configuration.perTeam > Clan.War.maxTotalPlayers then
			table.insert(problems, string.format("[Clan] configuration %dx%d exceeds the player cap", configuration.teams, configuration.perTeam))
		end
		if not Clan.IsSupportedConfiguration(configuration.teams, configuration.perTeam) then
			table.insert(problems, string.format("[Clan] configuration %dx%d is not recognised", configuration.teams, configuration.perTeam))
		end
	end
	if Clan.RankFor(0) ~= "bronze" or Clan.RankFor(99999) ~= "apex" then
		table.insert(problems, "[Clan] rating ladder is not ordered")
	end
	return problems
end

return Clan
