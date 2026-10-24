--!strict
--[[
	DeploymentConfig.luau
	How a player gets from Haven Overlook into a region.

	Quick Drop: the drop ship flies a server-chosen line over the selected
	region and the player jumps out with a flying-squirrel membrane glide
	(see MovementConfig.Glide). The player picks the exit moment, so the same
	drop line still produces different landing spots.

	Tactical deployment: a squad leader spends a limited number of squad
	deployments to place the whole squad at a validated landing zone. Landing
	zones are chosen from a curated list per region so a squad can never drop
	inside a boss arena, a dungeon interior, or another player's camp.

	Respawn always returns the player to Haven Overlook; the player then
	deploys again. There is no respawn inside a region during combat.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Deployment = {}

Deployment.Modes = {
	[Enums.DeploymentMode.QuickDrop] = {
		id = Enums.DeploymentMode.QuickDrop,
		displayName = "Quick Drop",
		requiresSquad = false,
		glideEnabled = true,
		partySize = 1,
		cooldownSeconds = 8,
		description = "Jump from the drop ship and glide to your own landing spot.",
	},
	[Enums.DeploymentMode.Tactical] = {
		id = Enums.DeploymentMode.Tactical,
		displayName = "Tactical Deployment",
		requiresSquad = true,
		glideEnabled = true,
		partySize = 4,
		cooldownSeconds = 45,
		description = "Drop the whole squad together at a validated landing zone.",
	},
}

Deployment.DropShip = {
	cruiseAltitudeStuds = 620,
	speedStudsPerSecond = 90,
	-- Seconds the player has to jump after the line starts.
	windowSeconds = 34,
	-- Server-chosen jitter so the line is never identical between runs.
	lineJitterStuds = 320,
	-- Distance before the target region at which the ship starts its run.
	approachDistanceStuds = 1400,
	minPlayersForTactical = 2,
	maxSquadSize = 4,
	audio = "deploy_launch",
	landingAudio = "deploy_land",
}

Deployment.Glide = {
	membraneDeployDelaySeconds = 0.35,
	autoDeployAltitudeStuds = 90,
	-- The glide cannot be redeployed after it ends in the same drop.
	singleUsePerDrop = true,
	-- Landing inside the grace window takes no fall damage.
	landingGraceSeconds = Limits.Movement.GlideLandingGraceSeconds,
	-- Deploying into deep water is allowed and cancels fall damage.
	waterLandingCancelsFallDamage = true,
}

Deployment.Respawn = {
	returnToHub = true,
	hubId = "HavenOverlook",
	delaySeconds = 5,
	-- Losing an expedition drops a small, configurable share of unbanked
	-- resources. Everything already stored in the hub is safe.
	unbankedLossRatio = Limits.Survival.ExpeditionLossRatio,
	maxLossStacks = Limits.Survival.ExpeditionLossMaxStacks,
	-- Squad members may be revived instead of respawning at the hub.
	reviveSeconds = 5,
	reviveRangeStuds = 12,
	downedHealth = 30,
	downedBleedOutSeconds = 25,
}

-- Per-region landing zones. These are authored, validated positions: a
-- deployment is never resolved from a raw client position.
export type LandingZone = {
	id: string,
	regionId: string,
	position: { number },
	name: string,
	safe: boolean,
	-- Zones can be locked behind regional reputation.
	requiredReputation: number?,
	description: string,
}

local zones: { [string]: LandingZone } = {}
local function zone(regionId: string, id: string, x: number, z: number, name: string, description: string, safe: boolean?, reputation: number?)
	zones[id] = {
		id = id,
		regionId = regionId,
		position = { x, 0, z },
		name = name,
		safe = if safe == nil then true else safe,
		requiredReputation = reputation,
		description = description,
	}
end

zone(Enums.RegionId.VerdantReach, "lz_reach_ridge", 420, -380, "Reach Ridge", "Open high ground above the canopy.", true)
zone(Enums.RegionId.VerdantReach, "lz_reach_rootgate", 180, 260, "Rootgate Approach", "Close to the ROOTFALL entrance.", true, 5)
zone(Enums.RegionId.Cinderfall, "lz_cinder_vent", -300, 410, "Vent Shelf", "Hot landing; bring a heat salve.", false)
zone(Enums.RegionId.Cinderfall, "lz_cinder_forge", 120, -180, "Forge Road", "Safe road toward the geothermal complex.", true)
zone(Enums.RegionId.Frostveil, "lz_frost_pass", -520, 96, "Frost Pass", "Sheltered from the worst of the blizzard.", true)
zone(Enums.RegionId.Frostveil, "lz_frost_lab", 300, -420, "Cryostasis Approach", "Close to the Cryostasis Lab.", false, 8)
zone(Enums.RegionId.UmbraExpanse, "lz_umbra_black", -180, -520, "Blacksite Perimeter", "Dark, quiet, dangerous.", false)
zone(Enums.RegionId.SolaraBasin, "lz_solara_terrace", 260, 340, "Sun Terrace", "Open ground with good visibility.", true)
zone(Enums.RegionId.PelagicFrontier, "lz_pelagic_shoal", -420, 220, "Shoal Flats", "Shallow water landing.", true)
zone(Enums.RegionId.PelagicFrontier, "lz_pelagic_rig", 480, -140, "Abyssal Rig", "Directly above the Abyssal Station.", false, 10)
zone(Enums.RegionId.NullHorizon, "lz_null_shard", 90, 610, "Shard Field", "Unstable ground; watch the anomalies.", false)
zone(Enums.RegionId.NullHorizon, "lz_null_platform", -240, 80, "Nullpoint Platform", "Safe platform near the complex.", true)

function Deployment.ZonesForRegion(regionId: string): { LandingZone }
	local out = {}
	for _, entry in zones do
		if entry.regionId == regionId then
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Deployment.Zone(id: string): LandingZone?
	return zones[id]
end

function Deployment.AllZones(): { LandingZone }
	local out = {}
	for _, entry in zones do
		table.insert(out, entry)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- Server-side resolution of a drop: the client proposes, the server decides.
-- Returns the zone id and the resolved spawn CFrame-ish position.
function Deployment.ResolveLanding(regionId: string, requestedZoneId: string?, reputation: number?, random: any?): LandingZone?
	local candidates = Deployment.ZonesForRegion(regionId)
	if #candidates == 0 then
		return nil
	end
	if requestedZoneId then
		local requested = zones[requestedZoneId]
		if requested and requested.regionId == regionId then
			if requested.requiredReputation and (reputation or 0) < requested.requiredReputation then
				return nil
			end
			return requested
		end
	end
	local safe = {}
	for _, candidate in candidates do
		if not candidate.requiredReputation or (reputation or 0) >= candidate.requiredReputation then
			table.insert(safe, candidate)
		end
	end
	if #safe == 0 then
		return candidates[1]
	end
	if random and random.NextInteger then
		return safe[random:NextInteger(1, #safe)]
	end
	return safe[(math.floor((reputation or 0) + #safe) % #safe) + 1]
end

function Deployment.ValidateAll(): { string }
	local problems = {}
	if not Deployment.Modes[Enums.DeploymentMode.QuickDrop] then
		table.insert(problems, "[Deployment] Quick Drop mode is missing")
	end
	if not Deployment.Modes[Enums.DeploymentMode.Tactical] then
		table.insert(problems, "[Deployment] Tactical Deployment mode is missing")
	end
	if Deployment.Respawn.returnToHub ~= true then
		table.insert(problems, "[Deployment] respawn must return the player to Haven Overlook")
	end
	for _, regionId in ipairs(Enums.RegionOrder) do
		if #Deployment.ZonesForRegion(regionId) == 0 then
			table.insert(problems, string.format("[Deployment] region %s has no landing zones", tostring(regionId)))
		end
	end
	for _, entry in Deployment.AllZones() do
		local known = false
		for _, regionId in ipairs(Enums.RegionOrder) do
			if regionId == entry.regionId then
				known = true
				break
			end
		end
		if not known then
			table.insert(problems, string.format("[Deployment] zone %s targets unknown region %s", entry.id, tostring(entry.regionId)))
		end
		if #entry.position ~= 3 then
			table.insert(problems, string.format("[Deployment] zone %s needs three position components", entry.id))
		end
		if Deployment.ResolveLanding(entry.regionId, entry.id, 99) == nil and not entry.requiredReputation then
			table.insert(problems, string.format("[Deployment] zone %s cannot be resolved", entry.id))
		end
	end
	if Deployment.Respawn.unbankedLossRatio < 0 or Deployment.Respawn.unbankedLossRatio > 0.5 then
		table.insert(problems, "[Deployment] the unbanked resource loss ratio must stay between 0 and 0.5")
	end
	return problems
end

return Deployment
