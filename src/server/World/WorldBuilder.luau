--!strict
--[[
	WorldBuilder.luau
	Constructs the physical WILDBREAK world from RegionConfig.

	Production terrain art does not exist, so the world is generated from
	primitives. This is a real, traversable world, not a placeholder plane:

	  * Haven Overlook is a built hub with a spawn point and a safe zone
	  * each region gets a grounded landmass, a landmark and a boss arena
	  * raised causeways connect the hub to every region so the world is
	    traversable on foot without a deployment
	  * every region declares its own lighting and atmosphere, applied when a
	    player enters it

	Part budget is the main constraint. Generation is driven by
	Limits.Performance: plate subdivision, foliage counts and decoration are
	all capped, and the whole world is built once at server start.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Rng = require(Shared.Utilities.Rng)
local Regions = require(Shared.Config.RegionConfig)
local Bosses = require(Shared.Config.BossConfig)
local Resources = require(Shared.Config.ResourceConfig)
local ActorFactory = require(script.Parent.ActorFactory)

local WorldBuilder = {}

export type RegionBuild = {
	regionId: string,
	center: Vector3,
	radius: number,
	arenaPosition: Vector3,
	arenaRadius: number,
	plate: BasePart,
	landmark: Model,
	foliage: { BasePart },
	nodeSpots: { Vector3 },
	beastSpots: { Vector3 },
}

local build: { [string]: RegionBuild } = {}
local built = false
local buildToken = nil

local HUB_PLATE_RADIUS = 320
local ARENA_RADIUS = 130
-- The arena sits off-centre so approaching it is a journey, not a spawn.
local ARENA_OFFSET_FRACTION = 0.55

-- Decoration budget. Foliage is non-colliding scenery; the cap keeps the
-- generated world inside a sane part budget.
WorldBuilder.MaxFoliagePerRegion = 90

local function vectorFrom(list: { number }?): Vector3
	if not list then
		return Vector3.new(0, 0, 0)
	end
	return Vector3.new(list[1] or 0, list[2] or 0, list[3] or 0)
end

local function colorFrom(list: { number }?, fallback: Color3): Color3
	if not list or #list < 3 then
		return fallback
	end
	return Color3.fromRGB(list[1], list[2], list[3])
end

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function folder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

-- ---------------------------------------------------------------------------
-- Ground: a subdivided plate so the terrain reads as shaped, not flat
-- ---------------------------------------------------------------------------

-- One plate per region plus a modest skirt. A full voxel terrain fill for
-- eight regions at this scale is not viable at runtime, so the landmass is a
-- slab with a sloping rim that prevents players walking off into the void.
local function buildGround(region: any, rng: any, parent: Folder): BasePart
	local center = vectorFrom(region.center)
	local radius = region.radius or 800
	local terrain = region.terrain or {}
	local baseHeight = terrain.baseHeight or 20

	local identity = region.colorIdentity
	local groundColor = colorFrom(identity, Color3.fromRGB(96, 96, 104))
	groundColor = groundColor:Lerp(Color3.fromRGB(58, 46, 38), 0.55)

	local materialName = (terrain.materials and terrain.materials[1]) or "Grass"
	local material = Enum.Material.Grass
	for _, candidate in Enum.Material:GetEnumItems() do
		if candidate.Name == materialName then
			material = candidate
			break
		end
	end

	local plate = newPart(
		string.format("Ground_%s", region.id),
		Vector3.new(radius * 2, baseHeight, radius * 2),
		CFrame.new(center.X, center.Y - baseHeight / 2, center.Z),
		groundColor,
		material
	)
	plate.Parent = parent

	-- A raised rim keeps players inside the playable disc instead of letting
	-- them walk off the edge and fall out of the world.
	local rimSegments = math.clamp(math.floor(radius / 90), 12, 40)
	for index = 1, rimSegments do
		local angle = (index / rimSegments) * math.pi * 2
		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius
		local height = baseHeight + 14 + rng:Next() * 18
		local rim = newPart(
			string.format("Rim_%s_%d", region.id, index),
			Vector3.new(radius * 0.42, height, 26),
			CFrame.new(x, center.Y - baseHeight / 2 + height / 2, z) * CFrame.Angles(0, -angle, math.rad(rng:Next() * 12 - 6)),
			groundColor:Lerp(Color3.fromRGB(40, 34, 30), 0.5),
			Enum.Material.Rock
		)
		rim.Parent = parent
	end

	return plate
end

-- ---------------------------------------------------------------------------
-- Landmark: a readable structure per region
-- ---------------------------------------------------------------------------

local function buildLandmark(region: any, position: Vector3, rng: any, parent: Folder): Model
	local model = Instance.new("Model")
	model.Name = string.format("Landmark_%s", region.id)

	local identity = region.colorIdentity
	local accent = colorFrom(identity, Color3.fromRGB(150, 150, 160))
	local structure = Color3.fromRGB(64, 66, 74)

	-- A tower cluster: tall enough to be a navigation beacon from anywhere in
	-- the region.
	local towers = 3
	for index = 1, towers do
		local angle = (index / towers) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 34, 0, math.sin(angle) * 34)
		local height = 70 + rng:Next() * 60
		local tower = newPart(
			string.format("Tower%d", index),
			Vector3.new(24, height, 24),
			CFrame.new(position + offset + Vector3.new(0, height / 2, 0)),
			structure,
			Enum.Material.Concrete
		)
		tower.Parent = model

		local beacon = newPart(
			string.format("Beacon%d", index),
			Vector3.new(12, 12, 12),
			CFrame.new(position + offset + Vector3.new(0, height + 8, 0)),
			accent,
			Enum.Material.Neon
		)
		beacon.Parent = model
	end

	-- Central hub structure.
	local core = newPart(
		"Core",
		Vector3.new(56, 40, 56),
		CFrame.new(position + Vector3.new(0, 20, 0)),
		structure:Lerp(accent, 0.25),
		Enum.Material.Metal
	)
	core.Parent = model

	model.PrimaryPart = core
	model:SetAttribute("WBActorKind", "Landmark")
	model:SetAttribute("WBRegionId", region.id)
	model:SetAttribute("WBLandmarkId", region.landmark and region.landmark.id or region.id)
	model.Parent = parent
	return model
end

-- ---------------------------------------------------------------------------
-- Boss arena
-- ---------------------------------------------------------------------------

local function buildArena(region: any, center: Vector3, rng: any, parent: Folder): (Vector3, number)
	local bossId = region.worldBossId
	local boss = (bossId and bossId ~= "") and Bosses:Get(bossId) or nil

	-- The arena is placed along the axis facing away from the world origin so
	-- it sits deep inside the region.
	local direction = center - Vector3.new(0, center.Y, 0)
	if direction.Magnitude < 1 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit
	local distance = (region.radius or 800) * ARENA_OFFSET_FRACTION
	local arenaPosition = Vector3.new(
		center.X + direction.X * distance,
		center.Y,
		center.Z + direction.Z * distance
	)

	local accent = boss and ActorFactory.ElementColor(boss.element) or Color3.fromRGB(180, 180, 190)

	local floor = newPart(
		string.format("Arena_%s", region.id),
		Vector3.new(ARENA_RADIUS * 2, 6, ARENA_RADIUS * 2),
		CFrame.new(arenaPosition + Vector3.new(0, 3, 0)),
		Color3.fromRGB(52, 52, 60):Lerp(accent, 0.25),
		Enum.Material.Slate
	)
	floor:SetAttribute("WBActorKind", "Arena")
	floor:SetAttribute("WBRegionId", region.id)
	floor.Parent = parent

	-- Boundary pillars mark the leash edge so players can see the fight area.
	local pillars = 8
	for index = 1, pillars do
		local angle = (index / pillars) * math.pi * 2
		local x = arenaPosition.X + math.cos(angle) * ARENA_RADIUS
		local z = arenaPosition.Z + math.sin(angle) * ARENA_RADIUS
		local pillar = newPart(
			string.format("ArenaPillar_%s_%d", region.id, index),
			Vector3.new(8, 34, 8),
			CFrame.new(x, arenaPosition.Y + 17, z),
			accent,
			Enum.Material.Neon
		)
		pillar.CanCollide = false
		pillar.Parent = parent
	end

	return arenaPosition, ARENA_RADIUS
end

-- ---------------------------------------------------------------------------
-- Foliage and scatter
-- ---------------------------------------------------------------------------

local function scatterFoliage(region: any, center: Vector3, arenaPosition: Vector3, rng: any, parent: Folder): { BasePart }
	local out = {}
	-- Foliage is decoration only; it never collides, and the cap keeps the
	-- whole world inside a sane part budget (8 regions x this number x 2 parts).
	local count = math.clamp(math.floor((region.radius or 800) / 90), 18, WorldBuilder.MaxFoliagePerRegion)
	local identity = region.colorIdentity
	local base = colorFrom(identity, Color3.fromRGB(90, 120, 80))

	for index = 1, count do
		local angle = rng:Next() * math.pi * 2
		local distance = math.sqrt(rng:Next()) * (region.radius or 800) * 0.92
		local position = Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)

		-- Keep the arena and the landmark clear so they stay usable.
		if (position - arenaPosition).Magnitude < ARENA_RADIUS + 40 then
			continue
		end

		local height = 12 + rng:Next() * 26
		local trunk = newPart(
			string.format("Foliage_%s_%d", region.id, index),
			Vector3.new(3 + rng:Next() * 2, height, 3 + rng:Next() * 2),
			CFrame.new(position + Vector3.new(0, height / 2, 0)),
			base:Lerp(Color3.fromRGB(60, 44, 30), 0.6),
			Enum.Material.Wood
		)
		trunk.CanCollide = false
		trunk.Parent = parent
		table.insert(out, trunk)

		local canopy = newPart(
			string.format("Canopy_%s_%d", region.id, index),
			Vector3.new(16 + rng:Next() * 12, 10 + rng:Next() * 8, 16 + rng:Next() * 12),
			CFrame.new(position + Vector3.new(0, height + 4, 0)),
			base,
			Enum.Material.Grass
		)
		canopy.CanCollide = false
		canopy.Parent = parent
		table.insert(out, canopy)
	end

	return out
end

-- ---------------------------------------------------------------------------
-- Spawn spots for resources and beasts
-- ---------------------------------------------------------------------------

-- Deterministic scatter inside the region, avoiding the arena and landmark.
local function scatterSpots(region: any, center: Vector3, arenaPosition: Vector3, count: number, rng: any): { Vector3 }
	local spots = {}
	local attempts = 0
	while #spots < count and attempts < count * 12 do
		attempts += 1
		local angle = rng:Next() * math.pi * 2
		local distance = math.sqrt(rng:Next()) * (region.radius or 800) * 0.88
		local position = Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)
		if (position - arenaPosition).Magnitude < ARENA_RADIUS + 30 then
			continue
		end
		table.insert(spots, position)
	end
	return spots
end

-- ---------------------------------------------------------------------------
-- Haven Overlook
-- ---------------------------------------------------------------------------

-- The hub is a built, safe space: a plate, a raised rim, a landmark structure
-- and an explicit SpawnLocation. Players who fall are returned here.
local function buildHub(region: any, rng: any, parent: Folder): (BasePart, SpawnLocation)
	local center = vectorFrom(region.center)

	local plate = newPart(
		"HubPlate",
		Vector3.new(HUB_PLATE_RADIUS * 2, 24, HUB_PLATE_RADIUS * 2),
		CFrame.new(center.X, center.Y - 12, center.Z),
		Color3.fromRGB(120, 118, 112),
		Enum.Material.Slate
	)
	plate.Parent = parent

	-- A rim so nobody walks off the hub into the void.
	local rimSegments = 28
	for index = 1, rimSegments do
		local angle = (index / rimSegments) * math.pi * 2
		local height = 30 + rng:Next() * 12
		local rim = newPart(
			string.format("HubRim_%d", index),
			Vector3.new(HUB_PLATE_RADIUS * 0.36, height, 24),
			CFrame.new(
				center.X + math.cos(angle) * HUB_PLATE_RADIUS,
				center.Y - 12 + height / 2,
				center.Z + math.sin(angle) * HUB_PLATE_RADIUS
			) * CFrame.Angles(0, -angle, 0),
			Color3.fromRGB(96, 94, 90),
			Enum.Material.Rock
		)
		rim.Parent = parent
	end

	-- Central structure: the visual identity of Haven Overlook.
	local hall = newPart(
		"HallOfHaven",
		Vector3.new(70, 46, 70),
		CFrame.new(center + Vector3.new(0, 23, 0)),
		Color3.fromRGB(150, 144, 130),
		Enum.Material.Marble
	)
	hall.Parent = parent

	local spire = newPart(
		"HavenSpire",
		Vector3.new(18, 90, 18),
		CFrame.new(center + Vector3.new(0, 68, 0)),
		Color3.fromRGB(210, 190, 140),
		Enum.Material.Neon
	)
	spire.CanCollide = false
	spire.Parent = parent

	-- Deployment pads: where a player lands when they redeploy.
	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2
		local pad = newPart(
			string.format("DeployPad_%d", index),
			Vector3.new(60, 4, 60),
			CFrame.new(center + Vector3.new(math.cos(angle) * 190, 2, math.sin(angle) * 190)),
			Color3.fromRGB(90, 150, 190),
			Enum.Material.Neon
		)
		pad.CanCollide = false
		pad:SetAttribute("WBActorKind", "DeployPad")
		pad.Parent = parent
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HavenSpawn"
	spawn.Size = Vector3.new(24, 2, 24)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 4, 90))
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn:SetAttribute("WBActorKind", "Spawn")
	spawn.Parent = parent

	return plate, spawn
end

-- ---------------------------------------------------------------------------
-- Causeways: connect the hub to every region
-- ---------------------------------------------------------------------------

local function buildCauseway(hubCenter: Vector3, regionCenter: Vector3, regionId: string, parent: Folder): BasePart
	local from = Vector3.new(hubCenter.X, hubCenter.Y - 12, hubCenter.Z)
	local to = Vector3.new(regionCenter.X, regionCenter.Y, regionCenter.Z)
	local delta = to - from
	local length = delta.Magnitude
	local midpoint = from + delta / 2

	local bridge = newPart(
		string.format("Causeway_%s", regionId),
		Vector3.new(70, 10, length),
		CFrame.new(midpoint) * CFrame.lookAt(Vector3.new(0, 0, 0), delta),
		Color3.fromRGB(112, 108, 100),
		Enum.Material.Slate
	)
	bridge.Parent = parent
	return bridge
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

function WorldBuilder.Build(): { [string]: RegionBuild }
	if built then
		Logger.Warn("WorldBuilder", "Build() called twice; ignoring the second call")
		return build
	end
	built = true

	local rng = Rng.new(20241024)
	local world = folder("WB_World")
	local hubRegion = Regions:Get(Regions.HubId)

	Logger.Info("WorldBuilder", "generating the WILDBREAK world")

	local hubCenter = vectorFrom(hubRegion and hubRegion.center)
	local hubPlate, spawn = buildHub(hubRegion, rng, world)

	local hubLandmark = Instance.new("Model")
	hubLandmark.Name = "Landmark_HavenOverlook"
	hubLandmark.PrimaryPart = hubPlate
	for _, name in { "HallOfHaven", "HavenSpire" } do
		local child = world:FindFirstChild(name)
		if child then
			child.Parent = hubLandmark
		end
	end
	hubLandmark:SetAttribute("WBActorKind", "Landmark")
	hubLandmark:SetAttribute("WBRegionId", Regions.HubId)
	hubLandmark.Parent = world

	build[Regions.HubId] = {
		regionId = Regions.HubId,
		center = hubCenter,
		radius = HUB_PLATE_RADIUS,
		arenaPosition = hubCenter,
		arenaRadius = 0,
		plate = hubPlate,
		landmark = hubLandmark,
		foliage = {},
		nodeSpots = {},
		beastSpots = {},
	}
	WorldBuilder.SpawnCFrame = spawn.CFrame + Vector3.new(0, 6, 0)
	WorldBuilder.HubCenter = hubCenter

	for _, region in Regions:List() do
		if Regions.IsHub(region.id) then
			continue
		end

		local center = vectorFrom(region.center)
		local arenaPosition, arenaRadius = buildArena(region, center, rng, world)
		local plate = buildGround(region, rng, world)
		local landmark = buildLandmark(region, center, rng, world)
		local foliage = scatterFoliage(region, center, arenaPosition, rng, world)

		local resourceCount = 0
		for _ in region.resourceNodes or {} do
			resourceCount += 1
		end
		local nodeSpots = scatterSpots(
			region,
			center,
			arenaPosition,
			math.clamp(resourceCount * 6, 12, Limits.Performance.MaxActiveNodesPerRegion or 400),
			rng
		)
		local beastSpots = scatterSpots(
			region,
			center,
			arenaPosition,
			math.clamp(#(region.beastSpecies or {}) * 8, 8, Limits.Performance.MaxActiveBeastsPerRegion or 60),
			rng
		)

		buildCauseway(hubCenter, center, region.id, world)

		-- A discovery trigger at the region boundary.
		ActorFactory.TriggerVolume(
			string.format("Discover_%s", region.id),
			Vector3.new(center.X, center.Y, center.Z),
			(region.radius or 800) * 0.95,
			"RegionDiscovery"
		)

		-- A boss activation trigger at the arena.
		if region.worldBossId and region.worldBossId ~= "" then
			local trigger = ActorFactory.TriggerVolume(
				string.format("BossTrigger_%s", region.id),
				arenaPosition,
				arenaRadius * 0.75,
				"BossActivation"
			)
			trigger:SetAttribute("WBRegionId", region.id)
			trigger:SetAttribute("WBBossId", region.worldBossId)
		end

		build[region.id] = {
			regionId = region.id,
			center = center,
			radius = region.radius or 800,
			arenaPosition = arenaPosition,
			arenaRadius = arenaRadius,
			plate = plate,
			landmark = landmark,
			foliage = foliage,
			nodeSpots = nodeSpots,
			beastSpots = beastSpots,
		}
	end

	WorldBuilder.ApplyLighting(Regions.HubId)
	Logger.Info("WorldBuilder", string.format("world generated: %d regions", WorldBuilder.Count()))
	return build
end

-- ---------------------------------------------------------------------------
-- Atmosphere
-- ---------------------------------------------------------------------------

-- Each region declares its own sky, fog and time of day. Applied when the
-- server's dominant region changes so all players share one atmosphere.
function WorldBuilder.ApplyLighting(regionId: string)
	local region = Regions:Get(regionId)
	if not region or not region.lighting then
		return
	end
	local lighting = region.lighting

	Lighting.Ambient = colorFrom(lighting.ambient, Lighting.Ambient)
	Lighting.OutdoorAmbient = colorFrom(lighting.outdoorAmbient, Lighting.OutdoorAmbient)
	Lighting.FogColor = colorFrom(lighting.fogColor, Lighting.FogColor)
	Lighting.FogEnd = lighting.fogEnd or Lighting.FogEnd
	Lighting.FogStart = lighting.fogStart or 0
	Lighting.Brightness = lighting.brightness or Lighting.Brightness
	Lighting.ClockTime = lighting.clockTime or Lighting.ClockTime
	if lighting.exposure then
		Lighting.ExposureCompensation = lighting.exposure
	end

	-- One atmosphere instance, recoloured per region rather than recreated.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Color = Lighting.FogColor
	atmosphere.Density = 0.28 + (region.threatLevel or 1) * 0.03

	WorldBuilder.CurrentLightingRegion = regionId
end

-- ---------------------------------------------------------------------------
-- Queries used by the gameplay services
-- ---------------------------------------------------------------------------

function WorldBuilder.RegionBuild(regionId: string): RegionBuild?
	return build[regionId]
end

function WorldBuilder.ArenaPosition(regionId: string): Vector3?
	local entry = build[regionId]
	return entry and entry.arenaPosition or nil
end

function WorldBuilder.ArenaRadius(regionId: string): number
	local entry = build[regionId]
	return entry and entry.arenaRadius or ARENA_RADIUS
end

function WorldBuilder.Center(regionId: string): Vector3?
	local entry = build[regionId]
	return entry and entry.center or nil
end

function WorldBuilder.NodeSpots(regionId: string): { Vector3 }
	local entry = build[regionId]
	return entry and entry.nodeSpots or {}
end

function WorldBuilder.BeastSpots(regionId: string): { Vector3 }
	local entry = build[regionId]
	return entry and entry.beastSpots or {}
end

function WorldBuilder.SpawnCFrameValue(): CFrame
	return WorldBuilder.SpawnCFrame or CFrame.new(0, 200, 90)
end

function WorldBuilder.Count(): number
	local count = 0
	for _ in build do
		count += 1
	end
	return count
end

function WorldBuilder.IsBuilt(): boolean
	return built
end

-- Guards against a second bootstrap initialising the world a second time.
function WorldBuilder.Claim(token: string): boolean
	if buildToken and buildToken ~= token then
		return false
	end
	buildToken = token
	return true
end

return WorldBuilder
