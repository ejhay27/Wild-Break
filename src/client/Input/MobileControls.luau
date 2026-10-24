--!strict
--[[
	MobileControls.luau
	Binds the on-screen touch controls to the same named actions the keyboard
	uses, so combat code is identical on PC and Android.

	Layout follows the CODM convention: left thumbstick for movement, right
	side of the screen for looking, fire/aim/reload under the right thumb.
]]

local UserInputService = game:GetService("UserInputService")

local MobileControls = {}

export type Config = {
	onAxis: (look: Vector2, move: Vector2) -> (),
	onAction: (action: string, down: boolean) -> (),
}

local ACTION_BUTTONS: { [string]: string } = {
	FireButton = "Fire",
	AimButton = "Aim",
	ReloadButton = "Reload",
	JumpButton = "Jump",
	MeleeButton = "Melee",
	SprintButton = "Sprint",
}

local STICK_RADIUS = 52

local function trackStick(base: Frame, knob: Frame, onChanged: (Vector2) -> ())
	local active: InputObject? = nil

	base.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		active = input
	end)

	base.InputEnded:Connect(function(input)
		if input == active then
			active = nil
			knob.Position = UDim2.new(0.5, -knob.AbsoluteSize.X / 2, 0.5, -knob.AbsoluteSize.Y / 2)
			onChanged(Vector2.new(0, 0))
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input ~= active then
			return
		end
		local delta = input.Position - base.AbsolutePosition - base.AbsoluteSize / 2
		local clamped = delta.Magnitude > STICK_RADIUS and delta.Unit * STICK_RADIUS or delta
		knob.Position = UDim2.new(0.5, clamped.X - knob.AbsoluteSize.X / 2, 0.5, clamped.Y - knob.AbsoluteSize.Y / 2)
		onChanged(clamped / STICK_RADIUS)
	end)
end

-- Wires the touch layer built by src/ui/Hud.
function MobileControls.Bind(layer: Frame, config: Config)
	local moveVector = Vector2.new(0, 0)
	local lookVector = Vector2.new(0, 0)
	local function push()
		config.onAxis(lookVector, moveVector)
	end

	local moveStick = layer:FindFirstChild("MoveStick")
	if moveStick and moveStick:IsA("Frame") then
		local knob = moveStick:FindFirstChild("Knob")
		if knob and knob:IsA("Frame") then
			trackStick(moveStick, knob, function(value: Vector2)
				moveVector = value
			end)
		end
	end

	local lookStick = layer:FindFirstChild("LookStick")
	if lookStick and lookStick:IsA("Frame") then
		local knob = lookStick:FindFirstChild("Knob")
		if knob and knob:IsA("Frame") then
			trackStick(lookStick, knob, function(value: Vector2)
				lookVector = value
			end)
		end
	end

	-- Sticks are sampled continuously while held, so the axis reaches the
	-- controllers even when no touch event is firing.
	local lastPush = 0
	task.spawn(function()
		while layer.Parent do
			task.wait()
			local now = os.clock()
			if now - lastPush > 0.03 then
				lastPush = now
				push()
			end
		end
	end)

	for buttonName, action in ACTION_BUTTONS do
		local button = layer:FindFirstChild(buttonName)
		if button and button:IsA("TextButton") then
			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					config.onAction(action, true)
				end
			end)
			button.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					config.onAction(action, false)
				end
			end)
		end
	end
end

function MobileControls.Enabled(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return MobileControls
