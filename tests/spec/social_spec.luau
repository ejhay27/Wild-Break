--!strict
--[[
	Social systems spec.

	Covers the shared rule layer the server enforces for player-to-player
	interaction and progression gating:

	  * trading safety  -- block rules, finalisation delay, tradeable types
	  * clan hierarchy  -- role ranks, permission escalation, caps
	  * deployment      -- landing zones, region containment, reputation gates
	  * companions      -- caps, taming rules, cross-registry references

	These rules live in src/shared/Config, so they can be verified without a
	running Roblox server.
]]

local Test = require("../harness/Harness")

local Enums = require("@shared/Constants/Enums")
local Limits = require("@shared/Constants/Limits")
local Trading = require("@shared/Config/TradingConfig")
local Clan = require("@shared/Config/ClanConfig")
local Deployment = require("@shared/Config/DeploymentConfig")
local Regions = require("@shared/Config/RegionConfig")
local Items = require("@shared/Config/ItemConfig")
local Ores = require("@shared/Config/OreConfig")
local Companion = require("@shared/Config/CompanionConfig")
local Beast = require("@shared/Config/BeastConfig")

local function isKnownItem(id: string): boolean
	return Items:Has(id) or Ores:Has(id)
end

local function cleanContext()
	return {
		inDungeon = false,
		inClanWar = false,
		inBossEncounter = false,
		tradeDisabled = false,
		distanceStuds = 5,
	}
end

-- ---------------------------------------------------------------------------
-- Trading safety
-- ---------------------------------------------------------------------------

Test.describe("Trading", function()
	Test.it("trading is enabled", function()
		Test.truthy(Trading.Rules.enabled, "trading is disabled in config")
	end)

	Test.it("a clean context is not blocked", function()
		Test.falsy(Trading.BlockReason(cleanContext()), "a valid trade context was blocked")
	end)

	Test.it("trading is blocked inside a dungeon", function()
		local context = cleanContext()
		context.inDungeon = true
		Test.truthy(Trading.BlockReason(context), "dungeon trading must be blocked")
	end)

	Test.it("trading is blocked during a clan war match", function()
		local context = cleanContext()
		context.inClanWar = true
		Test.truthy(Trading.BlockReason(context), "clan war trading must be blocked")
	end)

	Test.it("trading is blocked during a boss encounter", function()
		local context = cleanContext()
		context.inBossEncounter = true
		Test.truthy(Trading.BlockReason(context), "boss encounter trading must be blocked")
	end)

	Test.it("a player who disabled requests cannot be traded with", function()
		local context = cleanContext()
		context.tradeDisabled = true
		Test.truthy(Trading.BlockReason(context), "trade requests must respect the target's privacy setting")
	end)

	Test.it("trading requires proximity", function()
		local context = cleanContext()
		context.distanceStuds = Trading.Rules.maxDistanceStuds + 1
		Test.truthy(Trading.BlockReason(context), "trading beyond max distance must be blocked")

		local inside = cleanContext()
		inside.distanceStuds = Trading.Rules.maxDistanceStuds
		Test.falsy(Trading.BlockReason(inside), "trading inside the range must be allowed")
	end)

	Test.it("trades have a finalisation delay", function()
		Test.gte(Trading.Rules.finalisationDelaySeconds, 1, "offers must not be swappable at the last moment")
	end)

	Test.it("distinct item kinds are capped", function()
		Test.gte(Trading.Rules.maxDistinctItemKinds, 1)
		Test.lte(Trading.Rules.maxDistinctItemKinds, 32)
	end)

	Test.it("materials are tradeable and quest items are not", function()
		Test.truthy(Trading.CanTradeItemType("Material"), "materials must be tradeable")
		Test.falsy(Trading.CanTradeItemType("QuestItem"), "quest items must never be tradeable")
	end)

	Test.it("no tradeable item override references an unknown id", function()
		for itemId in (Trading.Rules.itemOverrides or {}) do
			Test.truthy(isKnownItem(itemId), string.format("unknown item override %s", tostring(itemId)))
		end
	end)

	Test.it("trading config validates clean", function()
		Test.empty(Trading.ValidateAll())
	end)
end)

-- ---------------------------------------------------------------------------
-- Clan role hierarchy
-- ---------------------------------------------------------------------------

Test.describe("Clans", function()
	Test.it("every role resolves a rank", function()
		for _, role in Enums.ClanRoleOrder do
			Test.truthy(Enums.ClanRoleRank[role], string.format("missing rank for %s", role))
		end
	end)

	Test.it("role order is strictly descending", function()
		for index = 2, #Enums.ClanRoleOrder do
			local higher = Enums.ClanRoleOrder[index - 1]
			local lower = Enums.ClanRoleOrder[index]
			Test.truthy(
				Enums.ClanRoleRank[higher] > Enums.ClanRoleRank[lower],
				string.format("%s must outrank %s", higher, lower)
			)
		end
	end)

	Test.it("an owner can promote", function()
		Test.truthy(Clan.Can(Enums.ClanRole.Owner, "promote"))
	end)

	Test.it("a recruit cannot kick", function()
		Test.falsy(Clan.Can(Enums.ClanRole.Recruit, "kick"), "a recruit must not be able to kick")
	end)

	Test.it("the officer cap sits below the member cap", function()
		Test.gte(Clan.Limits.maxOfficers, 1)
		Test.truthy(
			Clan.Limits.maxMembers > Clan.Limits.maxOfficers,
			"member cap must exceed officer cap"
		)
	end)

	Test.it("creation cost and name limits are sane", function()
		Test.gte(Clan.Limits.createCostSap, 0)
		Test.gte(Clan.Limits.minNameLength, 1)
		Test.truthy(
			Clan.Limits.minNameLength < Clan.Limits.maxNameLength,
			"name length limits are inconsistent"
		)
	end)

	Test.it("at least one clan war mode exists", function()
		Test.gte(#Clan.Modes(), 1)
	end)

	Test.it("declared war configurations are reported as supported", function()
		for _, configuration in Clan.War.supportedConfigurations do
			Test.gte(configuration.teams, 2)
			Test.gte(configuration.perTeam, 1)
			Test.truthy(
				Clan.IsSupportedConfiguration(configuration.teams, configuration.perTeam),
				string.format("%dv%d is declared but not supported", configuration.teams, configuration.perTeam)
			)
		end
	end)

	Test.it("clan config validates clean", function()
		Test.empty(Clan.ValidateAll())
	end)
end)

-- ---------------------------------------------------------------------------
-- Deployment
-- ---------------------------------------------------------------------------

Test.describe("Deployment", function()
	Test.it("at least one drop mode exists", function()
		local count = 0
		for _ in Deployment.Modes do
			count += 1
		end
		Test.gte(count, 1)
	end)

	Test.it("every drop mode has a non-negative cooldown", function()
		for modeId, mode in Deployment.Modes do
			Test.gte(mode.cooldownSeconds or 0, 0, string.format("mode %s", modeId))
		end
	end)

	Test.it("the drop ship flies at a positive altitude with a real window", function()
		Test.gte(Deployment.DropShip.cruiseAltitudeStuds, 1)
		Test.gte(Deployment.DropShip.windowSeconds, 1)
	end)

	Test.it("every non-hub region has at least one landing zone", function()
		for _, region in Regions:List() do
			if not Regions.IsHub(region.id) then
				Test.gte(
					#Deployment.ZonesForRegion(region.id),
					1,
					string.format("region %s has no landing zone", region.id)
				)
			end
		end
	end)

	Test.it("landing resolution never escapes the requested region", function()
		for _, region in Regions:List() do
			if Regions.IsHub(region.id) then
				continue
			end
			local zone = Deployment.ResolveLanding(region.id, nil, 0, nil)
			Test.truthy(zone, string.format("no zone resolved for %s", region.id))
			if zone then
				Test.eq(zone.regionId, region.id, "resolved zone is in the wrong region")
			end
		end
	end)

	Test.it("reputation gated zones are refused without reputation", function()
		for _, zone in Deployment.AllZones() do
			if zone.requiredReputation and zone.requiredReputation > 0 then
				local resolved = Deployment.ResolveLanding(zone.regionId, zone.id, 0, nil)
				if resolved then
					Test.neq(resolved.id, zone.id, string.format("gated zone %s was granted for free", zone.id))
				end
			end
		end
	end)

	Test.it("the hub respawn target is configured", function()
		Test.truthy(Deployment.Respawn.hubId ~= nil and Deployment.Respawn.hubId ~= "", "missing hub respawn target")
		Test.truthy(Regions.IsHub(Deployment.Respawn.hubId), "the respawn target must be the hub region")
	end)

	Test.it("deployment config validates clean", function()
		Test.empty(Deployment.ValidateAll())
	end)
end)

-- ---------------------------------------------------------------------------
-- Companions
-- ---------------------------------------------------------------------------

Test.describe("Companions", function()
	Test.it("dungeons allow fewer companions than the open world", function()
		Test.gte(Limits.Companion.MaxActiveOpenWorld, 1)
		Test.truthy(
			Limits.Companion.MaxActiveDungeon < Limits.Companion.MaxActiveOpenWorld,
			"dungeons must allow fewer companions than the open world"
		)
	end)

	Test.it("every companion species declares known roles", function()
		for _, companion in Companion:List() do
			Test.gte(#(companion.roles or {}), 1, string.format("%s has no role", companion.id))
			for _, role in companion.roles or {} do
				local known = false
				for _, value in Enums.CompanionRole do
					if value == role then
						known = true
						break
					end
				end
				Test.truthy(known, string.format("%s has unknown role %s", companion.id, tostring(role)))
			end
		end
	end)

	Test.it("every companion egg references a real item", function()
		for _, companion in Companion:List() do
			if companion.eggItemId then
				Test.truthy(
					isKnownItem(companion.eggItemId),
					string.format("%s egg %s does not exist", companion.id, tostring(companion.eggItemId))
				)
			end
		end
	end)

	Test.it("every companion maps to a real beast", function()
		for _, companion in Companion:List() do
			if companion.sourceBeastId then
				Test.truthy(
					Beast:Has(companion.sourceBeastId),
					string.format("%s references unknown beast %s", companion.id, tostring(companion.sourceBeastId))
				)
			end
		end
	end)

	Test.it("taming takes time and requires a weakened beast", function()
		Test.gte(Limits.Companion.TameMinSeconds, 1)
		Test.gte(Limits.Companion.TameMaxSeconds, Limits.Companion.TameMinSeconds)
		Test.truthy(
			Limits.Companion.TameHealthThreshold > 0 and Limits.Companion.TameHealthThreshold < 1,
			"a beast must be weakened before it can be tamed"
		)
	end)

	Test.it("companion config validates clean", function()
		Test.empty(Companion.ValidateAll())
	end)
end)

Test.Finish()

return true
