--!strict
--[[
	CombatController.luau
	Sends combat INTENTS and renders the results.

	The client never computes damage. It says "I fired toward direction D" and
	renders whatever the server resolves. Ammo, cooldowns and hit markers come
	back from the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Logger = require(Shared.Utilities.Logger)

local CombatController = { Name = "CombatController" }

local controllers: any = nil
local firing = false
local blocking = false
local lastShotAt = 0
local weaponState: any? = nil
local hitMarkerAt = 0

function CombatController.Init(svc: any)
	controllers = svc
end

local function aimDirection(): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, -1)
	end
	return camera.CFrame.LookVector
end

local function originPosition(): Vector3
	local character = game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or Vector3.new(0, 0, 0)
end

function CombatController.Fire()
	local now = os.clock()
	if now - lastShotAt < 0.05 then
		return
	end
	lastShotAt = now
	controllers.NetworkController.Fire(Remotes.RequestFire.name, {
		origin = originPosition(),
		direction = aimDirection(),
	})
end

function CombatController.Start()
	local Network = controllers.NetworkController
	local Input = controllers.InputController
	local State = controllers.StateController

	Input.Bind("Fire", function(down: boolean)
		firing = down
	end)
	Input.Bind("Reload", function(down: boolean)
		if down then
			Network.Fire(Remotes.RequestReload.name, {})
		end
	end)
	Input.Bind("Melee", function(down: boolean)
		if down then
			Network.Fire(Remotes.RequestMelee.name, { direction = aimDirection() })
		end
	end)
	Input.Bind("Block", function(down: boolean)
		blocking = down
		Network.Fire(Remotes.RequestBlock.name, { blocking = down })
	end)
	Input.Bind("Ability", function(down: boolean)
		if down then
			Network.Fire(Remotes.RequestAbility.name, { direction = aimDirection() })
		end
	end)
	Input.Bind("Ultimate", function(down: boolean)
		if down then
			Network.Fire(Remotes.RequestUltimate.name, { direction = aimDirection() })
		end
	end)
	Input.Bind("Gadget", function(down: boolean)
		if down then
			Network.Fire(Remotes.RequestGadget.name, { position = originPosition(), direction = aimDirection() })
		end
	end)

	-- Server-resolved results.
	Network.On(Remotes.ShotResolved.name, function(payload: any)
		if type(payload) == "table" and payload.hit then
			hitMarkerAt = os.clock()
		end
	end)
	Network.On(Remotes.WeaponStateUpdated.name, function(payload: any)
		weaponState = payload
	end)
	Network.On(Remotes.ReloadResolved.name, function(payload: any)
		weaponState = payload
	end)
	Network.On(Remotes.DamageFeedback.name, function(payload: any)
		if type(payload) == "table" and payload.kind == "Incoming" then
			controllers.HudController.FlashDamage()
		end
	end)
	Network.On(Remotes.CombatStateUpdated.name, function(payload: any)
		State.Combat = payload
	end)
end

function CombatController.Render()
	if firing then
		CombatController.Fire()
	end
end

function CombatController.HitMarkerAge(): number
	return os.clock() - hitMarkerAt
end

function CombatController.IsBlocking(): boolean
	return blocking
end

function CombatController.WeaponState(): any?
	return weaponState
end

return CombatController
