--!strict
--[[
	InputController.luau
	Unified input for keyboard/mouse, touch and gamepad.

	Actions are named, not key-specific, so the same combat code serves PC and
	mobile. Mobile uses CODM-style on-screen controls; the controller reports
	the same named actions either way.
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Settings = require(Shared.Config.SettingsConfig)

local InputController = { Name = "InputController" }

local controllers: any = nil
local bindings: { [string]: { (boolean, any?) -> () } } = {}
local axisListeners: { ({ look: Vector2, move: Vector2 }) -> () } = {}
local lookDelta = Vector2.new(0, 0)
local moveVector = Vector2.new(0, 0)
local touchLook = Vector2.new(0, 0)
local touchMove = Vector2.new(0, 0)
local sensitivity = 1

local ACTION_KEYS: { [string]: { Enum.KeyCode } } = {
	Fire = { Enum.KeyCode.MouseButton1, Enum.KeyCode.ButtonR2 },
	Aim = { Enum.KeyCode.MouseButton2, Enum.KeyCode.ButtonL2 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	Melee = { Enum.KeyCode.V, Enum.KeyCode.ButtonB },
	Block = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
	Crouch = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonY },
	Gadget = { Enum.KeyCode.G, Enum.KeyCode.ButtonR1 },
	Ability = { Enum.KeyCode.Q, Enum.KeyCode.ButtonR1 },
	Ultimate = { Enum.KeyCode.X, Enum.KeyCode.DPadDown },
	Deploy = { Enum.KeyCode.T, Enum.KeyCode.DPadUp },
	Inventory = { Enum.KeyCode.Tab, Enum.KeyCode.DPadLeft },
	Map = { Enum.KeyCode.M, Enum.KeyCode.DPadRight },
	Mount = { Enum.KeyCode.B },
}

local function keyToAction(keyCode: Enum.KeyCode): string?
	for action, keys in ACTION_KEYS do
		for _, key in keys do
			if key == keyCode then
				return action
			end
		end
	end
	return nil
end

function InputController.Bind(action: string, handler: (boolean, any?) -> ())
	if not bindings[action] then
		bindings[action] = {}
	end
	table.insert(bindings[action], handler)
end

function InputController.OnAxis(listener: ({ look: Vector2, move: Vector2 }) -> ())
	table.insert(axisListeners, listener)
end

local function dispatch(action: string, down: boolean, payload: any?)
	for _, handler in bindings[action] or {} do
		pcall(handler, down, payload)
	end
end

-- Called by the mobile control layer so touch produces identical actions.
function InputController.SetTouchAxis(look: Vector2?, move: Vector2?)
	if look then
		touchLook = look
	end
	if move then
		touchMove = move
	end
end

function InputController.TouchAction(action: string, down: boolean)
	dispatch(action, down, { source = "Touch" })
end

function InputController.Init(svc: any)
	controllers = svc
end

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			return
		end
		local action = keyToAction(input.KeyCode)
		if action then
			dispatch(action, true, { input = input })
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			return
		end
		local action = keyToAction(input.KeyCode)
		if action then
			dispatch(action, false, { input = input })
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			lookDelta += input.Delta * sensitivity
		end
	end)

	local Settings_ = controllers.SettingsController
	if Settings_ then
		Settings_.OnChanged(function(id: string, value: any)
			if id == "ctrl_sensitivity" and type(value) == "number" then
				sensitivity = math.clamp(value, 0.1, 5)
			elseif id == "ctrl_invert_y" then
				-- Applied when the axis is consumed.
			end
		end)
		local stored = Settings_.Get("ctrl_sensitivity")
		if type(stored) == "number" then
			sensitivity = math.clamp(stored, 0.1, 5)
		end
	end
end

function InputController.Render()
	-- Keyboard movement axis.
	local x, y = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		y += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		y -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		x += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		x -= 1
	end
	moveVector = Vector2.new(x, y)
	if moveVector.Magnitude > 1 then
		moveVector = moveVector.Unit
	end

	local combinedMove = moveVector
	if touchMove.Magnitude > 0 then
		combinedMove = touchMove
	end

	local combinedLook = lookDelta + touchLook
	lookDelta = Vector2.new(0, 0)

	if #axisListeners > 0 then
		for _, listener in axisListeners do
			pcall(listener, { look = combinedLook, move = combinedMove })
		end
	end
end

-- Exposed so the HUD can show the right prompts for the active device.
function InputController.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function InputController.Actions(): { string }
	local out = {}
	for action in ACTION_KEYS do
		table.insert(out, action)
	end
	table.sort(out)
	return out
end

return InputController
