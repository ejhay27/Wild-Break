--!strict
--[[
	CameraController.luau
	Third-person camera with shoulder swap, aim zoom and deployment/glide
	framing. Presentation only: the server owns where the character is.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Settings = require(Shared.Config.SettingsConfig)

local CameraController = { Name = "CameraController" }

local controllers: any = nil
local yaw = 0
local pitch = 0
local distance = 12
local targetDistance = 12
local aiming = false
local shoulder = 1
local sensitivity = 1
local invertY = false

local MIN_PITCH = -math.rad(75)
local MAX_PITCH = math.rad(75)

function CameraController.Init(svc: any)
	controllers = svc
end

function CameraController.SetAiming(active: boolean)
	aiming = active
	targetDistance = active and 6.5 or 12
	shoulder = active and 1 or shoulder
end

function CameraController.Start()
	local Input = controllers.InputController
	Input.OnAxis(function(axis: any)
		local look = axis.look
		if look.Magnitude == 0 then
			return
		end
		yaw -= look.X * 0.002 * sensitivity
		local deltaY = look.Y * 0.002 * sensitivity
		pitch += if invertY then deltaY else -deltaY
		pitch = math.clamp(pitch, MIN_PITCH, MAX_PITCH)
	end)

	Input.Bind("Aim", function(down: boolean)
		CameraController.SetAiming(down)
	end)

	Input.Bind("Inventory", function(down: boolean)
		if down then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)

	local Settings_ = controllers.SettingsController
	if Settings_ then
		local stored = Settings_.Get("ctrl_sensitivity")
		if type(stored) == "number" then
			sensitivity = math.clamp(stored, 0.1, 5)
		end
		invertY = Settings_.Get("ctrl_invert_y") == true
		Settings_.OnChanged(function(id: string, value: any)
			if id == "ctrl_sensitivity" and type(value) == "number" then
				sensitivity = math.clamp(value, 0.1, 5)
			elseif id == "ctrl_invert_y" then
				invertY = value == true
			end
		end)
	end
end

function CameraController.Render(delta: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local character = game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	distance += (targetDistance - distance) * math.min(1, delta * 8)

	local offset = Vector3.new(
		math.cos(yaw) * math.cos(pitch),
		math.sin(pitch),
		math.sin(yaw) * math.cos(pitch)
	) * distance
	local side = Vector3.new(-math.sin(yaw), 0, math.cos(yaw)) * (shoulder * 1.75)

	local goal = root.Position + offset + side
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(goal, root.Position + Vector3.new(0, 1.5, 0))
	camera.FieldOfView = aiming and 60 or 70
end

return CameraController
