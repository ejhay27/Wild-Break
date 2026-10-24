--!strict
--[[
	Hud.luau
	The in-game heads-up display: vitals, weapon state, crosshair, boss bar,
	deployment overlay and the mobile control layer.

	Built entirely in code so it renders before any art exists. Layout is
	scale-based, and the mobile layer only appears on touch devices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage:WaitForChild("UI").Components)

local Hud = {}

export type HudRefs = {
	Root: ScreenGui,
	Health: any,
	Stamina: any,
	Ammo: TextLabel,
	Reserve: TextLabel,
	WeaponName: TextLabel,
	Crosshair: Frame,
	HitMarker: Frame,
	DamageFlash: Frame,
	BossBar: Frame,
	BossName: TextLabel,
	BossHealth: any,
	BossPhase: TextLabel,
	Detonation: Frame,
	DetonationLabel: TextLabel,
	Region: TextLabel,
	Mobile: Frame?,
}

local DAMAGE_FLASH_COLOR = Color3.fromRGB(190, 40, 40)

local function bar(parent: Instance, name: string, color: Color3, position: UDim2, size: UDim2)
	return Components.Bar({
		name = name,
		color = color,
		position = position,
		size = size,
	}, parent)
end

function Hud.Build(parent: Instance, isTouch: boolean): HudRefs
	local root = Instance.new("ScreenGui")
	root.Name = "WB_Hud"
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = true
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.Parent = parent

	-- Notifications host (created first so notifications can attach).
	local notifications = Instance.new("Frame")
	notifications.Name = "Notifications"
	notifications.Size = UDim2.new(0.28, 0, 0.34, 0)
	notifications.Position = UDim2.new(0.71, 0, 0.06, 0)
	notifications.BackgroundTransparency = 1
	notifications.Parent = root

	-- Vitals: bottom-left.
	local vitals = Instance.new("Frame")
	vitals.Name = "Vitals"
	vitals.Size = UDim2.new(0.26, 0, 0.1, 0)
	vitals.Position = UDim2.new(0.02, 0, 0.86, 0)
	vitals.BackgroundTransparency = 1
	vitals.Parent = root

	local health = bar(vitals, "Health", Color3.fromRGB(200, 60, 60), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 16))
	local stamina = bar(vitals, "Stamina", Color3.fromRGB(80, 170, 220), UDim2.new(0, 0, 0, 22), UDim2.new(1, 0, 0, 10))

	-- Weapon state: bottom-right.
	local weapon = Instance.new("Frame")
	weapon.Name = "Weapon"
	weapon.Size = UDim2.new(0.22, 0, 0.09, 0)
	weapon.Position = UDim2.new(0.76, 0, 0.87, 0)
	weapon.BackgroundTransparency = 1
	weapon.Parent = root

	local weaponName = Components.Label({
		name = "WeaponName",
		text = "Unarmed",
		size = UDim2.new(1, 0, 0, 18),
		align = Enum.TextXAlignment.Right,
	}, weapon)

	local ammo = Components.Label({
		name = "Ammo",
		text = "--",
		size = UDim2.new(0.5, 0, 0, 30),
		position = UDim2.new(0, 0, 0, 20),
		align = Enum.TextXAlignment.Right,
	}, weapon)

	local reserve = Components.Label({
		name = "Reserve",
		text = "",
		size = UDim2.new(0.45, 0, 0, 30),
		position = UDim2.new(0.55, 0, 0, 20),
		align = Enum.TextXAlignment.Right,
		color = Color3.fromRGB(160, 168, 185),
	}, weapon)

	-- Crosshair.
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 18, 0, 18)
	crosshair.Position = UDim2.new(0.5, -9, 0.5, -9)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = root

	for _, axis in { "Vertical", "Horizontal" } do
		local line = Instance.new("Frame")
		line.Name = axis
		line.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
		line.BorderSizePixel = 0
		if axis == "Vertical" then
			line.Size = UDim2.new(0, 2, 1, 0)
			line.Position = UDim2.new(0.5, -1, 0, 0)
		else
			line.Size = UDim2.new(1, 0, 0, 2)
			line.Position = UDim2.new(0, 0, 0.5, -1)
		end
		line.Parent = crosshair
	end

	-- Hit marker: shown briefly when the server confirms a hit.
	local hitMarker = Instance.new("Frame")
	hitMarker.Name = "HitMarker"
	hitMarker.Size = UDim2.new(0, 26, 0, 26)
	hitMarker.Position = UDim2.new(0.5, -13, 0.5, -13)
	hitMarker.BackgroundTransparency = 1
	hitMarker.Visible = false
	hitMarker.Parent = root

	for index = 1, 4 do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. index
		tick.Size = UDim2.new(0, 8, 0, 2)
		tick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tick.BorderSizePixel = 0
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, 0, 0.5, 0)
		tick.Rotation = index * 90 + 45
		local offset = 7
		tick.Position = UDim2.new(
			0.5,
			math.cos(math.rad(index * 90 + 45)) * offset,
			0.5,
			math.sin(math.rad(index * 90 + 45)) * offset
		)
		tick.Parent = hitMarker
	end

	-- Damage flash (full-screen vignette).
	local damageFlash = Instance.new("Frame")
	damageFlash.Name = "DamageFlash"
	damageFlash.Size = UDim2.new(1, 0, 1, 0)
	damageFlash.BackgroundColor3 = DAMAGE_FLASH_COLOR
	damageFlash.BackgroundTransparency = 1
	damageFlash.BorderSizePixel = 0
	damageFlash.Parent = root

	-- Boss bar: top-centre.
	local bossBar = Instance.new("Frame")
	bossBar.Name = "BossBar"
	bossBar.Size = UDim2.new(0.5, 0, 0.07, 0)
	bossBar.Position = UDim2.new(0.25, 0, 0.04, 0)
	bossBar.BackgroundTransparency = 1
	bossBar.Visible = false
	bossBar.Parent = root

	local bossName = Components.Label({
		name = "BossName",
		text = "",
		size = UDim2.new(1, 0, 0, 20),
		align = Enum.TextXAlignment.Center,
	}, bossBar)
	local bossHealth = bar(bossBar, "BossHealth", Color3.fromRGB(210, 80, 60), UDim2.new(0, 0, 0, 24), UDim2.new(1, 0, 0, 14))
	local bossPhase = Components.Label({
		name = "BossPhase",
		text = "",
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.new(0, 0, 0, 42),
		align = Enum.TextXAlignment.Center,
		color = Color3.fromRGB(170, 178, 195),
	}, bossBar)

	-- Detonation telegraph: an unmissable countdown for the Light Samurai
	-- finale and any other scripted wipe mechanic.
	local detonation = Instance.new("Frame")
	detonation.Name = "Detonation"
	detonation.Size = UDim2.new(0.46, 0, 0.12, 0)
	detonation.Position = UDim2.new(0.27, 0, 0.16, 0)
	detonation.BackgroundColor3 = Color3.fromRGB(70, 30, 20)
	detonation.BackgroundTransparency = 0.35
	detonation.BorderSizePixel = 0
	detonation.Visible = false
	detonation.Parent = root

	local detonationLabel = Components.Label({
		name = "DetonationLabel",
		text = "",
		size = UDim2.new(1, -16, 1, -8),
		position = UDim2.new(0, 8, 0, 4),
		align = Enum.TextXAlignment.Center,
		color = Color3.fromRGB(255, 210, 160),
	}, detonation)

	-- Region readout: top-left.
	local region = Components.Label({
		name = "Region",
		text = "Haven Overlook",
		size = UDim2.new(0.3, 0, 0, 22),
		position = UDim2.new(0.02, 0, 0.02, 0),
		color = Color3.fromRGB(200, 206, 220),
	}, root)

	local mobile: Frame? = nil
	if isTouch then
		mobile = Hud.BuildMobileControls(root)
	end

	return {
		Root = root,
		Health = health,
		Stamina = stamina,
		Ammo = ammo,
		Reserve = reserve,
		WeaponName = weaponName,
		Crosshair = crosshair,
		HitMarker = hitMarker,
		DamageFlash = damageFlash,
		BossBar = bossBar,
		BossName = bossName,
		BossHealth = bossHealth,
		BossPhase = bossPhase,
		Detonation = detonation,
		DetonationLabel = detonationLabel,
		Region = region,
		Mobile = mobile,
	}
end

-- CODM-style touch controls: left thumbstick drives movement, the right side
-- of the screen drives the camera, and the fire/aim/reload/jump buttons sit
-- under the right thumb.
function Hud.BuildMobileControls(root: ScreenGui): Frame
	local layer = Instance.new("Frame")
	layer.Name = "Mobile"
	layer.Size = UDim2.new(1, 0, 1, 0)
	layer.BackgroundTransparency = 1
	layer.Parent = root

	local function stick(name: string, position: UDim2): { Knob: Frame, Base: Frame }
		local base = Instance.new("Frame")
		base.Name = name
		base.Size = UDim2.new(0, 120, 0, 120)
		base.Position = position
		base.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
		base.BackgroundTransparency = 0.8
		base.BorderSizePixel = 0
		base.Parent = layer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = base

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.new(0, 52, 0, 52)
		knob.Position = UDim2.new(0.5, -26, 0.5, -26)
		knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
		knob.BackgroundTransparency = 0.35
		knob.BorderSizePixel = 0
		knob.Parent = base

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(0.5, 0)
		knobCorner.Parent = knob

		return { Base = base, Knob = knob }
	end

	local move = stick("MoveStick", UDim2.new(0, 24, 1, -150))
	local look = stick("LookStick", UDim2.new(1, -330, 1, -150))

	local function actionButton(name: string, text: string, position: UDim2, size: UDim2): TextButton
		local button = Components.Button({ name = name, text = text, position = position, size = size }, layer)
		button.BackgroundTransparency = 0.35
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
		return button
	end

	actionButton("FireButton", "FIRE", UDim2.new(1, -180, 1, -180), UDim2.new(0, 92, 0, 92))
	actionButton("AimButton", "AIM", UDim2.new(1, -180, 1, -280), UDim2.new(0, 74, 0, 74))
	actionButton("ReloadButton", "RELOAD", UDim2.new(1, -280, 1, -180), UDim2.new(0, 74, 0, 74))
	actionButton("JumpButton", "JUMP", UDim2.new(1, -100, 1, -300), UDim2.new(0, 66, 0, 66))
	actionButton("MeleeButton", "MELEE", UDim2.new(1, -280, 1, -80), UDim2.new(0, 66, 0, 66))
	actionButton("SprintButton", "SPRINT", UDim2.new(1, -100, 1, -80), UDim2.new(0, 66, 0, 66))

	layer:SetAttribute("MoveStick", move.Base.Name)
	layer:SetAttribute("LookStick", look.Base.Name)
	return layer
end

return Hud
