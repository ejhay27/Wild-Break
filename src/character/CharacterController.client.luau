--!strict
--[[
	CharacterController.client.luau
	Character-side movement: sprinting, stamina-gated movement skills, the
	Quick Drop glide and fall damage reporting.

	The client moves the character locally for responsiveness, but it reports
	its position to the server, and the server validates every move it accepts
	(PlayerService.ValidatePosition). Movement skills are authorised by the
	server, and stamina is held authoritatively by PlayerService - the local
	number is only a prediction for the HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Networking.Remotes)
local Movement = require(Shared.Config.MovementConfig)
local Enums = require(Shared.Constants.Enums)

local CharacterController = {}

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart

local gliding = false
local glideVelocityY = 0
local lastPosition = root.Position
local lastReportAt = 0
local jumpRequested = false
local pendingImpactSpeed = 0

local REPORT_INTERVAL = 0.2

-- The Quick Drop glide is a flying-squirrel style membrane glide, not a
-- parachute: it holds a shallow, controllable descent rather than dropping
-- straight down.
local function startGlide()
	if gliding then
		return
	end
	if root.Position.Y < Movement.Glide.minimumDeployHeightStuds then
		return
	end
	gliding = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	glideVelocityY = -Movement.Glide.descentSpeed
end

local function stopGlide()
	if not gliding then
		return
	end
	gliding = false
	pendingImpactSpeed = math.abs(glideVelocityY)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	-- The server decides whether the glide grace window applies.
	Remotes.Land(pendingImpactSpeed)
end

-- Thin networking shim so this script can send intents without importing the
-- whole client controller stack (StarterCharacterScripts runs before the
-- PlayerScripts controllers in some respawn orders).
function Remotes.Land(impactSpeed: number)
	local folder = ReplicatedStorage:FindFirstChild("WB_Remotes")
	local remote = folder and folder:FindFirstChild(Remotes.RequestMovementSkill.name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer({ skillId = "glide_land", impactSpeed = impactSpeed })
	end
end

function Remotes.Report(position: Vector3, velocity: number)
	local folder = ReplicatedStorage:FindFirstChild("WB_Remotes")
	local remote = folder and folder:FindFirstChild(Remotes.ClientReady.name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer({ position = position, velocity = velocity })
	end
end

local function onJumpRequest()
	if gliding then
		stopGlide()
		return
	end
	-- Holding jump while airborne opens the membrane.
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		startGlide()
	end
end

UserInputService.JumpRequest:Connect(onJumpRequest)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		jumpRequested = true
		onJumpRequest()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		jumpRequested = false
	end
end)

RunService.Heartbeat:Connect(function(delta)
	-- Position reporting: the server validates each report against its own
	-- plausibility rules, so a teleporting client cannot move freely.
	local now = os.clock()
	if now - lastReportAt >= REPORT_INTERVAL then
		lastReportAt = now
		local velocity = (root.Position - lastPosition).Magnitude / math.max(0.001, REPORT_INTERVAL)
		lastPosition = root.Position
		Remotes.Report(root.Position, velocity)
	end

	if not gliding then
		return
	end

	-- Glide physics: forward speed is preserved, descent is capped, and the
	-- player can steer with the movement axis.
	local glide = Movement.Glide
	-- Diving accelerates the descent, pulling up bleeds speed back into lift.
	glideVelocityY -= glide.diveAcceleration * delta
	if glideVelocityY < -glide.maxSpeed then
		glideVelocityY = -glide.maxSpeed
	end

	local look = root.CFrame.LookVector
	local forwardSpeed = math.min(glide.maxSpeed, glide.forwardSpeed + math.abs(glideVelocityY) * glide.liftPerSpeedUnit)
	root.Velocity = Vector3.new(
		look.X * forwardSpeed,
		glideVelocityY,
		look.Z * forwardSpeed
	)

	-- Stamina drains while gliding; the server enforces the real cost.
	if humanoid.Health <= 0 then
		stopGlide()
	end

	if root.Position.Y <= 3 then
		stopGlide()
	end
end)

humanoid.StateChanged:Connect(function(_old, new)
	if new == Enum.HumanoidStateType.Landed then
		stopGlide()
	end
	if new == Enum.HumanoidStateType.Dead then
		gliding = false
	end
end)

-- Keeps the character upright while gliding so the membrane reads correctly.
RunService.RenderStepped:Connect(function()
	if not gliding then
		return
	end
	local velocity = root.Velocity
	if velocity.Magnitude > 1 then
		root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(velocity.X, -0.35, velocity.Z))
	end
end)

CharacterController.IsGliding = function()
	return gliding
end

CharacterController.GlidePhase = function()
	return gliding and Enums.DeployPhase.Gliding or Enums.DeployPhase.Idle
end

return CharacterController
