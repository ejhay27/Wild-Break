--!strict
--[[
	Remotes.luau
	The single source of truth for WILDBREAK networking.

	Nothing in the game may create an ad-hoc RemoteEvent. Every remote is
	declared here with:
	  * kind           - Event or Function
	  * direction      - ClientToServer, ServerToClient or Bidirectional
	  * args           - ordered argument schema (see Networking/Packet)
	  * rateLimit      - requests per second allowed per player (server side)
	  * burst          - token bucket burst allowance
	  * adminLevel     - minimum admin level required (if any)
	  * trust          - what the server is allowed to believe from the client
	  * description    - what the remote is for

	The server (server/Services/NetworkService) creates these objects and
	wraps every incoming call with schema validation, rate limiting and
	audit logging.
]]

local Packet = require(script.Parent.Packet)
local Enums = require(script.Parent.Parent.Constants.Enums)

local Remotes = {}

export type Direction = "ClientToServer" | "ServerToClient" | "Bidirectional"

export type Definition = {
	name: string,
	kind: "Event" | "Function",
	direction: Direction,
	args: Packet.Schema?,
	rateLimit: number?,
	burst: number?,
	adminLevel: number?,
	description: string,
}

local function define(
	name: string,
	kind: "Event" | "Function",
	direction: Direction,
	description: string,
	options: {
		args: Packet.Schema?,
		rateLimit: number?,
		burst: number?,
		adminLevel: number?,
	}?
): Definition
	return {
		name = name,
		kind = kind,
		direction = direction,
		description = description,
		args = options and options.args or nil,
		rateLimit = options and options.rateLimit or nil,
		burst = options and options.burst or nil,
		adminLevel = options and options.adminLevel or nil,
	}
end

local RegionIdValues = Enums.RegionOrder

-- ---------------------------------------------------------------------------
-- Player / profile
-- ---------------------------------------------------------------------------

Remotes.PlayerProfileUpdated = define(
	"WB_PlayerProfileUpdated",
	"Event",
	"ServerToClient",
	"Pushes the authoritative player profile / incremental profile patches."
)

Remotes.PlayerStateUpdated = define(
	"WB_PlayerStateUpdated",
	"Event",
	"ServerToClient",
	"Health, stamina, shield, hazard exposure and survival stats."
)

Remotes.RequestProfileData = define("WB_RequestProfileData", "Function", "ClientToServer", "Requests the full profile snapshot for the local player.", {
	rateLimit = 1,
	burst = 2,
})

-- ---------------------------------------------------------------------------
-- Combat
-- ---------------------------------------------------------------------------

Remotes.RequestFire = define(
	"WB_RequestFire",
	"Event",
	"ClientToServer",
	"Requests a weapon shot. Server re-validates range, rate, ammo, line of sight and state.",
	{
		args = {
			Packet.Id("weaponInstanceId"),
			Packet.Vector3("origin", 100000),
			Packet.Direction("direction"),
			Packet.Number("clientTime", 0, 1e12, true),
			Packet.Table("hitCandidates", 12, true),
		},
		rateLimit = 25,
		burst = 40,
	}
)

Remotes.ShotResolved = define("WB_ShotResolved", "Event", "ServerToClient", "Authoritative shot result: ammo, hits, damage dealt.")

Remotes.RequestReload = define("WB_RequestReload", "Event", "ClientToServer", "Requests a reload. Server validates state, ammo pool and timing.", {
	args = { Packet.Id("weaponInstanceId") },
	rateLimit = 4,
	burst = 6,
})

Remotes.ReloadResolved = define("WB_ReloadResolved", "Event", "ServerToClient", "Reload accepted/denied plus resulting ammo state.")

Remotes.RequestSwitchWeapon = define(
	"WB_RequestSwitchWeapon",
	"Event",
	"ClientToServer",
	"Requests a weapon swap to a slot index or weapon instance.",
	{
		args = { Packet.Id("weaponInstanceId"), Packet.Integer("slot", 1, 6, true) },
		rateLimit = 6,
		burst = 10,
	}
)

Remotes.WeaponStateUpdated = define("WB_WeaponStateUpdated", "Event", "ServerToClient", "Equipped weapon, ammo and firing state.")

Remotes.RequestMelee = define(
	"WB_RequestMelee",
	"Event",
	"ClientToServer",
	"Requests a melee swing. Server validates combo window, range and state.",
	{
		args = {
			Packet.Id("weaponInstanceId"),
			Packet.Integer("comboIndex", 1, 5),
			Packet.Direction("direction", true),
		},
		rateLimit = 6,
		burst = 10,
	}
)

Remotes.MeleeResolved = define("WB_MeleeResolved", "Event", "ServerToClient", "Melee swing accepted/denied and resulting hits.")

Remotes.RequestBlock = define("WB_RequestBlock", "Event", "ClientToServer", "Start/stop melee block or parry attempt.", {
	args = { Packet.Boolean("active"), Packet.Boolean("parry", true) },
	rateLimit = 8,
	burst = 12,
})

Remotes.DamageFeedback = define("WB_DamageFeedback", "Event", "ServerToClient", "Damage numbers, hit markers and kill confirmations.")

Remotes.TargetHealthUpdated = define("WB_TargetHealthUpdated", "Event", "ServerToClient", "Authoritative health/shield for beasts and bosses in range.")

Remotes.CombatStateUpdated = define("WB_CombatStateUpdated", "Event", "ServerToClient", "Player combat state machine transitions (reload, stun, ultimate ...).")

-- ---------------------------------------------------------------------------
-- Movement / deployment
-- ---------------------------------------------------------------------------

Remotes.RequestMovementSkill = define(
	"WB_RequestMovementSkill",
	"Event",
	"ClientToServer",
	"Requests an unlockable movement skill (aerial dash, grapple, phase blink).",
	{
		args = {
			Packet.Enum("skill", { "AerialDash", "GrappleLaunch", "PhaseBlink" }),
			Packet.Direction("direction", true),
			Packet.Vector3("targetPoint", 100000, true),
		},
		rateLimit = 4,
		burst = 6,
	}
)

Remotes.MovementResolved = define("WB_MovementResolved", "Event", "ServerToClient", "Movement skill accepted/denied and resulting cooldowns.")

Remotes.RequestDeploy = define(
	"WB_RequestDeploy",
	"Function",
	"ClientToServer",
	"Requests a deployment (quick drop or tactical). Server validates progression and destination.",
	{
		args = {
			Packet.Enum("mode", { "QuickDrop", "Tactical" }),
			Packet.Enum("regionId", RegionIdValues, true),
			Packet.Id("destinationId", true),
			Packet.Id("activityId", true),
		},
		rateLimit = 2,
		burst = 3,
	}
)

Remotes.DeployStarted = define("WB_DeployStarted", "Event", "ServerToClient", "Deployment accepted: launch position, glide parameters and target.")

Remotes.DeployLanded = define("WB_DeployLanded", "Event", "ClientToServer", "Client reports glide completion; server validates landing position only.", {
	args = { Packet.Vector3("landingPosition", 100000) },
	rateLimit = 2,
	burst = 3,
})

Remotes.RequestTeleport = define(
	"WB_RequestTeleport",
	"Function",
	"ClientToServer",
	"Requests a hub/region teleport or a reserved-server place teleport.",
	{
		args = { Packet.Id("destinationId"), Packet.Enum("regionId", RegionIdValues, true) },
		rateLimit = 1,
		burst = 3,
	}
)

-- ---------------------------------------------------------------------------
-- Abilities / gadgets / ultimates
-- ---------------------------------------------------------------------------

Remotes.RequestAbility = define(
	"WB_RequestAbility",
	"Event",
	"ClientToServer",
	"Activates one of the four regular ability slots.",
	{
		args = {
			Packet.Integer("slot", 1, 4),
			Packet.Vector3("aimPoint", 100000, true),
			Packet.Id("targetId", true),
		},
		rateLimit = 8,
		burst = 12,
	}
)

Remotes.AbilityStateUpdated = define("WB_AbilityStateUpdated", "Event", "ServerToClient", "Ability cooldowns, ranks, tiers and activation feedback.")

Remotes.RequestUltimate = define(
	"WB_RequestUltimate",
	"Event",
	"ClientToServer",
	"Activates the equipped weapon's signature Ultimate.",
	{
		args = {
			Packet.Id("weaponInstanceId"),
			Packet.Vector3("aimPoint", 100000, true),
			Packet.Id("targetId", true),
		},
		rateLimit = 3,
		burst = 4,
	}
)

Remotes.UltimateStateUpdated = define("WB_UltimateStateUpdated", "Event", "ServerToClient", "Ultimate charge, readiness, cooldown and activation broadcast.")

Remotes.RequestGadget = define(
	"WB_RequestGadget",
	"Event",
	"ClientToServer",
	"Deploys or uses a tactical gadget from the active loadout.",
	{
		args = {
			Packet.Id("gadgetId"),
			Packet.Vector3("targetPoint", 100000, true),
			Packet.Id("targetId", true),
		},
		rateLimit = 4,
		burst = 8,
	}
)

Remotes.GadgetStateUpdated = define("WB_GadgetStateUpdated", "Event", "ServerToClient", "Gadget charges, active deployables and cooldowns.")

-- ---------------------------------------------------------------------------
-- Inventory / crafting / gunsmith
-- ---------------------------------------------------------------------------

Remotes.InventoryUpdated = define("WB_InventoryUpdated", "Event", "ServerToClient", "Authoritative inventory patches.")
Remotes.RequestEquip = define("WB_RequestEquip", "Function", "ClientToServer", "Equips a weapon, gadget, consumable or companion.", {
	args = { Packet.Id("instanceId"), Packet.Id("slot", true) },
	rateLimit = 5,
	burst = 8,
})
Remotes.RequestUseConsumable = define("WB_RequestUseConsumable", "Event", "ClientToServer", "Consumes a consumable item.", {
	args = { Packet.Id("itemId"), Packet.Integer("quantity", 1, 20, true) },
	rateLimit = 3,
	burst = 5,
})
Remotes.RequestDropItem = define("WB_RequestDropItem", "Event", "ClientToServer", "Discards an item (with confirmation requirements client side).", {
	args = { Packet.Id("itemId"), Packet.Integer("quantity", 1, 999, true) },
	rateLimit = 3,
	burst = 5,
})

Remotes.RequestCraft = define("WB_RequestCraft", "Function", "ClientToServer", "Requests a craft. Server validates recipe, station, materials and concurrency.", {
	args = { Packet.Id("recipeId"), Packet.Integer("quantity", 1, 99, true) },
	rateLimit = 3,
	burst = 5,
})
Remotes.CraftingResult = define("WB_CraftingResult", "Event", "ServerToClient", "Craft success/failure and inventory delta.")
Remotes.RequestRecipes = define("WB_RequestRecipes", "Function", "ClientToServer", "Returns known recipes and their material requirements.", {
	rateLimit = 1,
	burst = 2,
})

Remotes.RequestAttach = define("WB_RequestAttach", "Function", "ClientToServer", "Installs an attachment or Beast Core module on a weapon.", {
	args = { Packet.Id("weaponInstanceId"), Packet.Id("attachmentId"), Packet.Id("slot") },
	rateLimit = 4,
	burst = 8,
})
Remotes.RequestDetach = define("WB_RequestDetach", "Function", "ClientToServer", "Removes an attachment or module from a weapon.", {
	args = { Packet.Id("weaponInstanceId"), Packet.Id("slot") },
	rateLimit = 4,
	burst = 8,
})
Remotes.RequestEvolveWeapon = define("WB_RequestEvolveWeapon", "Function", "ClientToServer", "Evolves a weapon along a configured evolution path.", {
	args = { Packet.Id("weaponInstanceId"), Packet.Id("evolutionId") },
	rateLimit = 2,
	burst = 4,
})
Remotes.WeaponInstanceUpdated = define("WB_WeaponInstanceUpdated", "Event", "ServerToClient", "Weapon instance stats, rarity, stars, attachments and modules.")

-- ---------------------------------------------------------------------------
-- Resources
-- ---------------------------------------------------------------------------

Remotes.RequestHarvest = define("WB_RequestHarvest", "Event", "ClientToServer", "Begins or continues a harvest interaction on a resource node.", {
	args = { Packet.Id("nodeId"), Packet.Boolean("start") },
	rateLimit = 6,
	burst = 10,
})
Remotes.HarvestProgress = define("WB_HarvestProgress", "Event", "ServerToClient", "Harvest progress, completion and yields.")
Remotes.ResourceStateChanged = define("WB_ResourceStateChanged", "Event", "ServerToClient", "Node depletion and respawn state.")
Remotes.RequestInteract = define("WB_RequestInteract", "Event", "ClientToServer", "Generic world interaction (cache, terminal, door, nest ...).", {
	args = { Packet.Id("objectId"), Packet.String("action", 32, true) },
	rateLimit = 6,
	burst = 10,
})

-- ---------------------------------------------------------------------------
-- Beasts / bosses / dungeons / events
-- ---------------------------------------------------------------------------

Remotes.BossStateUpdated = define("WB_BossStateUpdated", "Event", "ServerToClient", "Boss health, shield, phase and state changes.")
Remotes.BossPhaseChanged = define("WB_BossPhaseChanged", "Event", "ServerToClient", "Boss phase transition with telegraph information.")
Remotes.BossDefeated = define("WB_BossDefeated", "Event", "ServerToClient", "Boss defeat summary and reward eligibility.")
Remotes.RequestBossInfo = define("WB_RequestBossInfo", "Function", "ClientToServer", "Returns live boss encounter information.", {
	args = { Packet.Id("bossId", true) },
	rateLimit = 2,
	burst = 4,
})

Remotes.BeastStateUpdated = define("WB_BeastStateUpdated", "Event", "ServerToClient", "Nearby beast health and behaviour state (throttled).")

Remotes.RequestDungeonEntry = define("WB_RequestDungeonEntry", "Function", "ClientToServer", "Requests entry into a dungeon or major operation.", {
	args = { Packet.Id("dungeonId"), Packet.Enum("format", { "OpenWorldFacility", "MajorOperation" }, true) },
	rateLimit = 1,
	burst = 3,
})
Remotes.DungeonStateUpdated = define("WB_DungeonStateUpdated", "Event", "ServerToClient", "Dungeon progress, objectives and completion.")

Remotes.WorldEventUpdated = define("WB_WorldEventUpdated", "Event", "ServerToClient", "World event announcements, stages and results.")
Remotes.RequestWorldEventInfo = define("WB_RequestWorldEventInfo", "Function", "ClientToServer", "Returns active world event data.", {
	rateLimit = 1,
	burst = 2,
})

-- ---------------------------------------------------------------------------
-- Companions
-- ---------------------------------------------------------------------------

Remotes.RequestCompanionAction = define("WB_RequestCompanionAction", "Event", "ClientToServer", "Companion command (follow, hold, attack, scout, dismiss).", {
	args = {
		Packet.Id("companionInstanceId"),
		Packet.Enum("command", { "Follow", "Hold", "Attack", "Defend", "Scout", "Dismiss" }),
		Packet.Id("targetId", true),
	},
	rateLimit = 5,
	burst = 8,
})
Remotes.RequestTame = define("WB_RequestTame", "Function", "ClientToServer", "Attempts to tame an eligible wild beast in the open world.", {
	args = { Packet.Id("beastId") },
	rateLimit = 2,
	burst = 3,
})
Remotes.RequestHatch = define("WB_RequestHatch", "Function", "ClientToServer", "Hatches a companion egg.", {
	args = { Packet.Id("eggInstanceId") },
	rateLimit = 2,
	burst = 4,
})
Remotes.CompanionUpdated = define("WB_CompanionUpdated", "Event", "ServerToClient", "Companion roster, state, level and active slots.")

-- ---------------------------------------------------------------------------
-- Squads, clans, clan wars, trading
-- ---------------------------------------------------------------------------

Remotes.SquadRequest = define("WB_SquadRequest", "Function", "ClientToServer", "Squad create/invite/join/leave/kick/promote.", {
	args = {
		Packet.String("action", 24),
		Packet.Number("targetUserId", 0, 1e15, true),
	},
	rateLimit = 4,
	burst = 8,
})
Remotes.SquadUpdated = define("WB_SquadUpdated", "Event", "ServerToClient", "Squad roster and state.")

Remotes.ClanRequest = define("WB_ClanRequest", "Function", "ClientToServer", "Clan create/join/leave/invite/promote/settings.", {
	args = {
		Packet.String("action", 24),
		Packet.Table("payload", 16, true),
	},
	rateLimit = 4,
	burst = 8,
})
Remotes.ClanUpdated = define("WB_ClanUpdated", "Event", "ServerToClient", "Clan profile, roster and war statistics.")

Remotes.ClanWarRequest = define("WB_ClanWarRequest", "Function", "ClientToServer", "Clan war queue, join, leave and match actions.", {
	args = {
		Packet.String("action", 24),
		Packet.Table("payload", 16, true),
	},
	rateLimit = 3,
	burst = 6,
})
Remotes.ClanWarUpdated = define("WB_ClanWarUpdated", "Event", "ServerToClient", "Match state, score, objectives and results.")

Remotes.TradeRequest = define("WB_TradeRequest", "Function", "ClientToServer", "Secure player trading of eligible items and unhatched eggs.", {
	args = {
		Packet.String("action", 24),
		Packet.Number("targetUserId", 0, 1e15, true),
		Packet.Table("payload", 32, true),
	},
	rateLimit = 4,
	burst = 8,
})
Remotes.TradeUpdated = define("WB_TradeUpdated", "Event", "ServerToClient", "Trade session state.")

-- ---------------------------------------------------------------------------
-- Boats
-- ---------------------------------------------------------------------------

Remotes.BoatRequest = define("WB_BoatRequest", "Event", "ClientToServer", "Spawn, board, disembark, recover or steer a boat.", {
	args = {
		Packet.String("action", 24),
		Packet.Id("boatId", true),
		Packet.Table("payload", 8, true),
	},
	rateLimit = 4,
	burst = 8,
})
Remotes.BoatStateUpdated = define("WB_BoatStateUpdated", "Event", "ServerToClient", "Boat ownership, durability and occupant state.")

-- ---------------------------------------------------------------------------
-- Presentation (server -> client only)
-- ---------------------------------------------------------------------------

Remotes.PlaySound = define("WB_PlaySound", "Event", "ServerToClient", "Requests a categorised sound playback on the client.")
Remotes.PlayEffect = define("WB_PlayEffect", "Event", "ServerToClient", "Requests a pooled visual effect on the client.")
Remotes.Notification = define("WB_Notification", "Event", "ServerToClient", "Toast notifications, reward notices and warnings.")
Remotes.Announcement = define("WB_Announcement", "Event", "ServerToClient", "Server-wide announcements and cinematic banners.")
Remotes.Cinematic = define("WB_Cinematic", "Event", "ServerToClient", "Camera cinematics for boss intros, transformations and deaths.")
Remotes.MissionUpdated = define("WB_MissionUpdated", "Event", "ServerToClient", "Mission tracker state and objective progress.")
Remotes.Dialogue = define("WB_Dialogue", "Function", "ClientToServer", "Dialogue progression (server authoritative rewards).", {
	args = { Packet.Id("dialogueId"), Packet.Integer("choiceIndex", 0, 8, true) },
	rateLimit = 6,
	burst = 10,
})
Remotes.RegionDiscovered = define("WB_RegionDiscovered", "Event", "ServerToClient", "Region and landmark discovery notifications.")
Remotes.DefeatSummary = define("WB_DefeatSummary", "Event", "ServerToClient", "Defeat summary including expedition resource loss.")
Remotes.RewardSummary = define("WB_RewardSummary", "Event", "ServerToClient", "Reward distribution summary.")
Remotes.MusicStateUpdated = define("WB_MusicStateUpdated", "Event", "ServerToClient", "Music state changes: exploration, combat, boss and menu layers.")
Remotes.PerformanceStateUpdated = define("WB_PerformanceStateUpdated", "Event", "ServerToClient", "Server performance stage and the client budget it should apply.")

-- ---------------------------------------------------------------------------
-- Client -> server reporting
-- ---------------------------------------------------------------------------

Remotes.ClientPerformanceReport = define("WB_ClientPerformanceReport", "Event", "ClientToServer", "Client FPS and quality feedback for auto graphics tuning.", {
	args = { Packet.Number("fps", 0, 1000, true), Packet.String("preset", 16, true), Packet.Number("memoryMb", 0, 1e6, true) },
	rateLimit = 1,
	burst = 2,
})
Remotes.UpdateSettings = define("WB_UpdateSettings", "Function", "ClientToServer", "Persists non-competitive player preferences.", {
	args = { Packet.Table("settings", 200) },
	rateLimit = 3,
	burst = 5,
})
Remotes.UpdateHudLayout = define("WB_UpdateHudLayout", "Function", "ClientToServer", "Persists a validated HUD layout.", {
	args = { Packet.String("device", 12), Packet.Table("layout", 400) },
	rateLimit = 3,
	burst = 5,
})
Remotes.ClientReady = define("WB_ClientReady", "Event", "ClientToServer", "Client signals it has finished loading and is ready to receive state.", {
	rateLimit = 1,
	burst = 2,
})

-- ---------------------------------------------------------------------------
-- Owner administration
-- ---------------------------------------------------------------------------

Remotes.AdminRequest = define(
	"WB_AdminRequest",
	"Function",
	"ClientToServer",
	"Owner admin panel actions. Every call is permission checked on the server.",
	{
		args = {
			Packet.String("action", 48),
			Packet.Table("payload", 64, true),
			Packet.String("confirmationToken", 128, true),
		},
		rateLimit = 6,
		burst = 10,
		adminLevel = Enums.AdminLevel.Tester,
	}
)
Remotes.AdminStateUpdated = define("WB_AdminStateUpdated", "Event", "ServerToClient", "Admin panel data: server health, players, encounters, audit tail. Only sent to authorised operators.", {
		adminLevel = Enums.AdminLevel.Tester,
	})
Remotes.AdminAuditEntry = define("WB_AdminAuditEntry", "Event", "ServerToClient", "Audit log entry broadcast to authorized panels. Only sent to authorised operators.", {
		adminLevel = Enums.AdminLevel.Owner,
	})

-- ---------------------------------------------------------------------------
-- Registry helpers
-- ---------------------------------------------------------------------------

local byName: { [string]: Definition } = {}
local ordered: { Definition } = {}

for key, value in Remotes do
	if type(value) == "table" and (value :: any).kind ~= nil and (value :: any).direction ~= nil then
		byName[value.name] = value
		table.insert(ordered, value)
	end
end

table.sort(ordered, function(a, b)
	return a.name < b.name
end)

function Remotes.Get(name: string): Definition?
	return byName[name]
end

function Remotes.All(): { Definition }
	return ordered
end

function Remotes.Count(): number
	return #ordered
end

return Remotes
