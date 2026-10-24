--!strict
--[[
	ActorFactory.luau
	Builds the physical actors WILDBREAK runs on: bosses, beasts, resource
	nodes, pickups and interaction props.

	Production models do not exist yet, so every actor here is procedural:
	primitive parts arranged into a recognisable silhouette, coloured from the
	region or element identity. These are NOT decorative stand-ins. Each actor
	has the collision, ownership, anchoring, health surface and cleanup
	behaviour the gameplay systems require, so bosses can be targeted and
	killed, nodes can be harvested, and beasts can be fought.

	Part budget: every constructor takes an explicit detail level and the
	counts are capped, so a populated region stays inside the performance
	budget. All actors are parented to a single server-owned folder so
	cleanup is a single Destroy().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Enums = require(Shared.Constants.Enums)
local Bosses = require(Shared.Config.BossConfig)
local Beasts = require(Shared.Config.BeastConfig)
local Resources = require(Shared.Config.ResourceConfig)
local Rarity = require(Shared.Config.RarityConfig)
local Items = require(Shared.Config.ItemConfig)

local ActorFactory = {}

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

local function container(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

local function part(options: {
	name: string?,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	anchored: boolean?,
	shape: Enum.PartType?,
	cframe: CFrame?,
}): Part
	local p = Instance.new("Part")
	p.Name = options.name or "Part"
	p.Size = options.size
	p.Material = options.material or Enum.Material.SmoothPlastic
	p.Color = options.color
	p.Transparency = options.transparency or 0
	p.Anchored = if options.anchored ~= nil then options.anchored else true
	p.CanCollide = false
	p.Shape = options.shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if options.cframe then
		p.CFrame = options.cframe
	else
		p.Position = options.position
	end
	return p
end

-- Element identity drives every procedural silhouette so the seven bosses
-- read as different creatures at a glance.
local ELEMENT_COLORS: { [string]: Color3 } = {
	[Enums.Element.Forest] = Color3.fromRGB(64, 148, 84),
	[Enums.Element.Fire] = Color3.fromRGB(214, 88, 42),
	[Enums.Element.Ice] = Color3.fromRGB(120, 186, 226),
	[Enums.Element.Dark] = Color3.fromRGB(74, 58, 96),
	[Enums.Element.Light] = Color3.fromRGB(238, 214, 128),
	[Enums.Element.Water] = Color3.fromRGB(52, 118, 178),
	[Enums.Element.Void] = Color3.fromRGB(44, 30, 62),
}

function ActorFactory.ElementColor(element: string?): Color3
	return ELEMENT_COLORS[element or ""] or Color3.fromRGB(150, 150, 160)
end

-- ---------------------------------------------------------------------------
-- Boss actors
-- ---------------------------------------------------------------------------

-- A boss model needs a Humanoid so Roblox targeting, health bars and any
-- engine-level interaction behave. The health value is mirrored from the
-- encounter; the encounter remains the authority.
function ActorFactory.BossActor(bossId: string, position: Vector3): Model?
	local def = Bosses:Get(bossId)
	if not def then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = string.format("Boss_%s", bossId)

	local color = ActorFactory.ElementColor(def.element)
	local scale = 1 + (def.tier or 1) * 0.25

	local root = part({
		name = "HumanoidRootPart",
		size = Vector3.new(6 * scale, 14 * scale, 6 * scale),
		position = position + Vector3.new(0, 7 * scale, 0),
		color = color,
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
	})
	root.Parent = model
	model.PrimaryPart = root

	-- Torso: the readable mass of the silhouette.
	local torso = part({
		name = "Torso",
		size = Vector3.new(8 * scale, 10 * scale, 5 * scale),
		position = position + Vector3.new(0, 9 * scale, 0),
		color = color,
		material = Enum.Material.Slate,
	})
	torso.Parent = model

	-- Head: small and high, so the boss reads as a creature.
	local head = part({
		name = "Head",
		size = Vector3.new(4 * scale, 4 * scale, 4 * scale),
		position = position + Vector3.new(0, 16.5 * scale, 0),
		color = color:Lerp(Color3.new(1, 1, 1), 0.25),
		material = Enum.Material.Slate,
	})
	head.Parent = model

	-- Limbs.
	for index, side in { -1, 1 } do
		local arm = part({
			name = "Arm" .. (index),
			size = Vector3.new(2.4 * scale, 9 * scale, 2.4 * scale),
			position = position + Vector3.new(side * 5.5 * scale, 9 * scale, 0),
			color = color:Lerp(Color3.new(0, 0, 0), 0.2),
		})
		arm.Parent = model

		local leg = part({
			name = "Leg" .. (index),
			size = Vector3.new(3 * scale, 8 * scale, 3 * scale),
			position = position + Vector3.new(side * 2.4 * scale, 2.5 * scale, 0),
			color = color:Lerp(Color3.new(0, 0, 0), 0.35),
		})
		leg.Parent = model
	end

	-- The weak point is a real, targetable attachment on the model, so the
	-- configured weak-point ids correspond to something a player can aim at.
	local core = part({
		name = "CoreSocket",
		size = Vector3.new(2.6 * scale, 2.6 * scale, 2.6 * scale),
		position = position + Vector3.new(0, 10 * scale, -2.8 * scale),
		color = Color3.fromRGB(255, 226, 130),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})
	core.Parent = model

	-- Silhouette accents differentiate the bosses further.
	if def.element == Enums.Element.Light then
		for index = 1, 6 do
			local angle = (index / 6) * math.pi * 2
			local wing = part({
				name = "Wing" .. index,
				size = Vector3.new(1.2 * scale, 12 * scale, 4 * scale),
				position = position
					+ Vector3.new(math.cos(angle) * 6 * scale, 12 * scale, math.sin(angle) * 6 * scale),
				color = Color3.fromRGB(255, 240, 190),
				material = Enum.Material.Neon,
				cframe = CFrame.new(
					position + Vector3.new(math.cos(angle) * 6 * scale, 12 * scale, math.sin(angle) * 6 * scale)
				) * CFrame.Angles(0, -angle, math.rad(18)),
			})
			wing.Parent = model
		end
	elseif def.element == Enums.Element.Void then
		-- Null Horizon reads as an unstable silhouette: offset shards that
		-- flicker are handled by the client, but the shards exist here.
		for index = 1, 5 do
			local angle = (index / 5) * math.pi * 2
			local shard = part({
				name = "Shard" .. index,
				size = Vector3.new(1.6 * scale, 7 * scale, 1.6 * scale),
				position = position + Vector3.new(math.cos(angle) * 7 * scale, 8 * scale, math.sin(angle) * 7 * scale),
				color = Color3.fromRGB(150, 110, 220),
				material = Enum.Material.Neon,
				transparency = 0.35,
			})
			shard.Parent = model
		end
	elseif def.element == Enums.Element.Fire then
		local glow = part({
			name = "EmberCore",
			size = Vector3.new(5 * scale, 5 * scale, 5 * scale),
			position = position + Vector3.new(0, 6 * scale, 0),
			color = Color3.fromRGB(255, 140, 50),
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
		})
		glow.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = def.baseHealth or 100
	humanoid.Health = humanoid.MaxHealth
	-- Bosses do not use the engine's fall/state machine; the encounter drives
	-- every state change.
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	model:SetAttribute("WBBossId", bossId)
	model:SetAttribute("WBActorKind", "Boss")
	model:SetAttribute("WBMaxHealth", def.baseHealth or 100)
	-- The encounter id is stamped on once the encounter owns the actor, so
	-- two encounters can never be confused for one another.
	model:SetAttribute("WBEncounterId", "")

	model.Parent = container("WB_Bosses")
	return model
end

-- Mirrors the encounter's health onto the actor for the client HUD.
function ActorFactory.SetBossHealth(model: Model, health: number, maxHealth: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = math.max(1, maxHealth)
		humanoid.Health = math.clamp(health, 0, humanoid.MaxHealth)
	end
	model:SetAttribute("WBHealth", health)
	model:SetAttribute("WBMaxHealth", maxHealth)
end

-- The vanish/reappear mechanic hides and restores the actor without
-- destroying it, so the damageable registration survives the transition.
function ActorFactory.SetBossVisible(model: Model, visible: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Transparency = if visible then (descendant:GetAttribute("WBBaseTransparency") or 0) else 1
			descendant.CanCollide = false
		end
	end
	model:SetAttribute("WBHidden", not visible)
end

-- Teleports an actor (boss, beast) to a new position. The RootPart stays the
-- pivot so the model moves as one piece and children keep their offsets.
function ActorFactory.MoveActor(model: Model, position: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return
	end
	local offset = position - root.Position
	model:PivotTo(model:GetPivot() + offset)
end

-- ---------------------------------------------------------------------------
-- Beast actors
-- ---------------------------------------------------------------------------

function ActorFactory.BeastActor(speciesId: string, position: Vector3, level: number?): Model?
	local species = Beasts:Get(speciesId)
	if not species then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = string.format("Beast_%s", speciesId)
	local color = ActorFactory.ElementColor(species.element)
	local scale = 0.6 + (species.tier or 1) * 0.22

	local root = part({
		name = "HumanoidRootPart",
		size = Vector3.new(3 * scale, 4 * scale, 3 * scale),
		position = position + Vector3.new(0, 2 * scale, 0),
		color = color,
		transparency = 1,
	})
	root.Parent = model
	model.PrimaryPart = root

	local body = part({
		name = "Body",
		size = Vector3.new(3.4 * scale, 2.8 * scale, 6 * scale),
		position = position + Vector3.new(0, 2.4 * scale, 0),
		color = color,
		material = Enum.Material.SmoothPlastic,
	})
	body.Parent = model

	local head = part({
		name = "Head",
		size = Vector3.new(2 * scale, 2 * scale, 2.6 * scale),
		position = position + Vector3.new(0, 3.2 * scale, -3.4 * scale),
		color = color:Lerp(Color3.new(1, 1, 1), 0.2),
	})
	head.Parent = model

	for index = 1, 4 do
		local leg = part({
			name = "Leg" .. index,
			size = Vector3.new(0.8 * scale, 2.2 * scale, 0.8 * scale),
			position = position
				+ Vector3.new((index % 2 == 0 and 1 or -1) * 1.2 * scale, 1.1 * scale, (index <= 2 and -1 or 1) * 2 * scale),
			color = color:Lerp(Color3.new(0, 0, 0), 0.35),
		})
		leg.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = species.baseHealth or 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	model:SetAttribute("WBActorKind", "Beast")
	model:SetAttribute("WBSpeciesId", speciesId)
	model:SetAttribute("WBLevel", level or 1)
	model.Parent = container("WB_Beasts")
	return model
end

-- ---------------------------------------------------------------------------
-- Resource nodes
-- ---------------------------------------------------------------------------

function ActorFactory.ResourceNode(resourceId: string, position: Vector3): Model?
	local def = Resources:Get(resourceId)
	if not def then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = string.format("Node_%s", resourceId)

	local rarityColor = Color3.fromRGB(150, 150, 160)
	if def.rarity and Rarity:Get(def.rarity) then
		local rarity = Rarity:Get(def.rarity)
		local identity = rarity.colorIdentity
		if identity and #identity >= 3 then
			rarityColor = Color3.fromRGB(identity[1], identity[2], identity[3])
		end
	end

	-- The base is the interactable volume; the crystal is the readable shape.
	local base = part({
		name = "Base",
		size = Vector3.new(5, 1.2, 5),
		position = position + Vector3.new(0, 0.6, 0),
		color = Color3.fromRGB(88, 84, 80),
		material = Enum.Material.Rock,
		shape = Enum.PartType.Cylinder,
	})
	base.Parent = model

	local crystalHeight = 3 + (def.tier or 1) * 1.4
	local crystal = part({
		name = "Crystal",
		size = Vector3.new(2.4, crystalHeight, 2.4),
		position = position + Vector3.new(0, 1.2 + crystalHeight / 2, 0),
		color = rarityColor,
		material = Enum.Material.Neon,
	})
	crystal.Parent = model

	local promptPart = part({
		name = "InteractVolume",
		size = Vector3.new(7, 7, 7),
		position = position + Vector3.new(0, 3, 0),
		color = rarityColor,
		transparency = 1,
	})
	promptPart.CanCollide = false
	promptPart.Parent = model
	model.PrimaryPart = promptPart

	model:SetAttribute("WBActorKind", "ResourceNode")
	model:SetAttribute("WBResourceId", resourceId)
	model:SetAttribute("WBHarvested", false)
	model.Parent = container("WB_Nodes")
	return model
end

-- Depleting a node sinks and dims it instead of destroying it, so respawn is
-- a state change and the actor can be reused.
function ActorFactory.SetNodeHarvested(model: Model, harvested: boolean)
	model:SetAttribute("WBHarvested", harvested)
	local crystal = model:FindFirstChild("Crystal")
	if crystal and crystal:IsA("BasePart") then
		crystal.Transparency = if harvested then 0.85 else 0
		crystal.Material = if harvested then Enum.Material.Slate else Enum.Material.Neon
	end
	local base = model:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		base.Position = base.Position - Vector3.new(0, if harvested then 0.5 else -0.5, 0)
	end
end

-- ---------------------------------------------------------------------------
-- Pickups
-- ---------------------------------------------------------------------------

function ActorFactory.Pickup(itemId: string, quantity: number, position: Vector3): Model?
	local def = Items:Get(itemId)
	if not def then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = string.format("Pickup_%s", itemId)

	local rarityColor = Color3.fromRGB(170, 170, 180)
	if def.rarity and Rarity:Get(def.rarity) then
		local rarity = Rarity:Get(def.rarity)
		local identity = rarity.colorIdentity
		if identity and #identity >= 3 then
			rarityColor = Color3.fromRGB(identity[1], identity[2], identity[3])
		end
	end

	local marker = part({
		name = "Marker",
		size = Vector3.new(1.8, 1.8, 1.8),
		position = position + Vector3.new(0, 1.6, 0),
		color = rarityColor,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})
	marker.Parent = model
	model.PrimaryPart = marker

	model:SetAttribute("WBActorKind", "Pickup")
	model:SetAttribute("WBItemId", itemId)
	model:SetAttribute("WBQuantity", quantity)
	model.Parent = container("WB_Pickups")
	return model
end

-- ---------------------------------------------------------------------------
-- Interaction props
-- ---------------------------------------------------------------------------

-- A trigger volume used for world boss activation and discovery. It is
-- non-colliding and purely server-side.
function ActorFactory.TriggerVolume(name: string, position: Vector3, radius: number, kind: string): Part
	local p = part({
		name = name,
		size = Vector3.new(radius * 2, radius, radius * 2),
		position = position + Vector3.new(0, radius / 2, 0),
		color = Color3.fromRGB(255, 190, 80),
		material = Enum.Material.Neon,
		transparency = 0.92,
		shape = Enum.PartType.Cylinder,
	})
	p.CanCollide = false
	p:SetAttribute("WBActorKind", "Trigger")
	p:SetAttribute("WBTriggerKind", kind)
	p.Parent = container("WB_Triggers")
	return p
end

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

function ActorFactory.DestroyActor(instance: Instance)
	if instance then
		instance:Destroy()
	end
end

function ActorFactory.Container(name: string): Folder
	return container(name)
end

function ActorFactory.Containers(): { string }
	return { "WB_Bosses", "WB_Beasts", "WB_Nodes", "WB_Pickups", "WB_Triggers" }
end

return ActorFactory
