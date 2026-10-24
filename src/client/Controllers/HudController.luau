--!strict
--[[
	HudController.luau
	Builds and drives the heads-up display and the screen stack.

	Everything rendered here is a mirror of server state. The HUD never
	computes health, ammo or damage; it only displays what the server sent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = ReplicatedStorage:WaitForChild("UI")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Logger = require(Shared.Utilities.Logger)
local Hud = require(UI.Hud)
local Screens = require(UI.Screens)
local Effects = require(script.Parent.Parent.Effects.EffectPool)
local MobileControls = require(script.Parent.Parent.Input.MobileControls)

local HudController = { Name = "HudController" }

local controllers: any = nil
local player: Player? = nil
local refs: any? = nil
local screens: { [string]: any } = {}
local currentScreen: string? = nil
local flashUntil = 0
local hitMarkerUntil = 0

local HIT_MARKER_DURATION = 0.12

function HudController.Init(svc: any, p: Player)
	controllers = svc
	player = p
end

function HudController.ToggleScreen(name: string)
	if currentScreen == name then
		HudController.CloseScreen()
		return
	end
	HudController.OpenScreen(name)
end

function HudController.OpenScreen(name: string)
	if currentScreen and screens[currentScreen] then
		screens[currentScreen].Close()
	end
	local screen = screens[name]
	if not screen then
		return
	end
	screen.Open()
	currentScreen = name
end

function HudController.CloseScreen()
	if currentScreen and screens[currentScreen] then
		screens[currentScreen].Close()
	end
	currentScreen = nil
end

function HudController.FlashDamage()
	if not refs then
		return
	end
	flashUntil = os.clock() + 0.35
end

function HudController.ShowDeployment(payload: any)
	if not refs then
		return
	end
	refs.Detonation.Visible = false
	Logger.Debug("Hud", "deployment overlay shown")
	_ = payload
end

function HudController.HideDeployment()
	-- The drop overlay is transient; closing the deployment screen handles it.
	HudController.CloseScreen()
end

-- The detonation telegraph is deliberately loud: a scripted wipe mechanic has
-- to be readable at a glance.
function HudController.ShowDetonation(payload: any)
	if not refs then
		return
	end
	refs.Detonation.Visible = true
	refs.DetonationLabel.Text = string.format("CELESTIAL DETONATION - %.0fs", payload.countdownSeconds or 0)
	task.delay(payload.countdownSeconds or 0, function()
		if refs then
			refs.Detonation.Visible = false
		end
	end)
end

function HudController.Start()
	local gui = player:WaitForChild("PlayerGui")
	refs = Hud.Build(gui, controllers.InputController.IsTouch())
	screens = Screens.Build(refs.Root, controllers)

	-- The touch layer was being built but never bound, so on a phone the
	-- sticks and action buttons were inert. It routes through the same named
	-- actions the keyboard uses, so combat code is identical on both.
	if refs.Mobile then
		MobileControls.Bind(refs.Mobile, {
			onAxis = function(look: Vector2, move: Vector2)
				controllers.InputController.SetTouchAxis(look, move)
			end,
			onAction = function(action: string, down: boolean)
				controllers.InputController.TouchAction(action, down)
			end,
		})
	end

	local Network = controllers.NetworkController
	local State = controllers.StateController

	State.OnRuntime(function(runtime: any)
		if not refs or type(runtime) ~= "table" then
			return
		end
		refs.Health.SetFill((runtime.health or 0) / math.max(1, runtime.maxHealth or 100))
		refs.Stamina.SetFill((runtime.stamina or 0) / math.max(1, runtime.maxStamina or 100))
	end)

	State.OnProfile(function(profile: any)
		if not refs or type(profile) ~= "table" then
			return
		end
		refs.Region.Text = profile.regionId or "Haven Overlook"
	end)

	Network.On(Remotes.WeaponStateUpdated.name, function(payload: any)
		if not refs or type(payload) ~= "table" then
			return
		end
		refs.WeaponName.Text = tostring(payload.name or payload.weaponId or "Unarmed")
		refs.Ammo.Text = tostring(payload.ammo or "--")
		refs.Reserve.Text = payload.reserveAmmo and string.format("/ %d", payload.reserveAmmo) or ""
	end)

	Network.On(Remotes.ShotResolved.name, function(payload: any)
		if type(payload) == "table" and payload.hit then
			hitMarkerUntil = os.clock() + HIT_MARKER_DURATION
		end
	end)

	Network.On(Remotes.BossStateUpdated.name, function(payload: any)
		if not refs or type(payload) ~= "table" then
			return
		end
		if payload.state == Enums.BossState.Defeated or payload.state == Enums.BossState.Resetting then
			refs.BossBar.Visible = false
			return
		end
		refs.BossBar.Visible = true
		refs.BossName.Text = tostring(payload.bossId or "Boss")
		refs.BossHealth.SetFill((payload.health or 0) / math.max(1, payload.maxHealth or 1))
		refs.BossPhase.Text = string.format("Phase %d - %s", payload.phaseIndex or 1, tostring(payload.phaseName or ""))
	end)

	Network.On(Remotes.PlayEffect.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		-- Boss telegraphs are drawn even when the HUD is hidden: a scripted
		-- wipe mechanic has to be visible at all times.
		if payload.kind == "BossAttack" and payload.radius then
			Effects.Telegraph(Vector3.new(0, 0, 0), payload.radius, payload.telegraph or 1)
		elseif payload.kind == "Detonation" and payload.radiusStuds then
			Effects.Burst(Vector3.new(0, 0, 0), payload.radiusStuds, Color3.fromRGB(255, 220, 150))
		end
	end)

	Network.On(Remotes.Cinematic.name, function(payload: any)
		if type(payload) == "table" and payload.kind == "BossDetonation" then
			HudController.ShowDetonation(payload)
		end
	end)

	-- Escape closes whatever screen is open.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and currentScreen then
			HudController.CloseScreen()
		end
	end)
end

function HudController.Render()
	if not refs then
		return
	end
	local now = os.clock()
	refs.HitMarker.Visible = now < hitMarkerUntil
	refs.DamageFlash.BackgroundTransparency = now < flashUntil and 0.75 or 1
end

return HudController
