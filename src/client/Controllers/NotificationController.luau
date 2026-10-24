--!strict
--[[
	NotificationController.luau
	Toasts, announcements and reward notices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)

local NotificationController = { Name = "NotificationController" }

local controllers: any = nil
local player: Player? = nil
local screen: ScreenGui? = nil
local container: Frame? = nil
local active: { Frame } = {}

local MAX_VISIBLE = 4
local LIFETIME = { Info = 3, Warning = 5, Reward = 5, Discovery = 4, Admin = 8 }

local function ensureGui(): Frame?
	if container and container.Parent then
		return container
	end
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local existing = gui:FindFirstChild("WB_Hud")
	if not existing then
		return nil
	end
	local host = existing:FindFirstChild("Notifications")
	if not host then
		host = Instance.new("Frame")
		host.Name = "Notifications"
		host.Size = UDim2.new(0.28, 0, 0.34, 0)
		host.Position = UDim2.new(0.71, 0, 0.06, 0)
		host.BackgroundTransparency = 1
		host.Parent = existing
	end
	container = host
	return host
end

function NotificationController.Init(svc: any, p: Player)
	controllers = svc
	player = p
end

function NotificationController.Notify(title: string, body: string?, kind: string?)
	local host = ensureGui()
	if not host then
		return
	end

	-- Oldest notifications are recycled rather than leaking Gui objects.
	while #active >= MAX_VISIBLE do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.new(1, 0, 0, 54)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = host

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0, 20)
	titleLabel.Position = UDim2.new(0, 8, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextScaled = true
	titleLabel.Text = tostring(title)
	titleLabel.Parent = frame

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -16, 0, 24)
	bodyLabel.Position = UDim2.new(0, 8, 0, 26)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.TextColor3 = Color3.fromRGB(180, 186, 200)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextScaled = true
	bodyLabel.Text = tostring(body or "")
	bodyLabel.Parent = frame

	table.insert(active, frame)

	task.delay(LIFETIME[kind or "Info"] or 4, function()
		local index = table.find(active, frame)
		if index then
			table.remove(active, index)
		end
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

function NotificationController.Start()
	local Network = controllers.NetworkController
	Network.On(Remotes.Notification.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		NotificationController.Notify(tostring(payload.title), tostring(payload.body or ""), tostring(payload.kind or "Info"))
	end)
	Network.On(Remotes.Announcement.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		NotificationController.Notify(tostring(payload.title), tostring(payload.body or ""), "Admin")
	end)
	Network.On(Remotes.RewardSummary.name, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local count = 0
		for _ in payload.rewards or {} do
			count += 1
		end
		NotificationController.Notify(
			tostring(payload.source or "Rewards"),
			string.format("%d item(s) granted", count),
			"Reward"
		)
	end)
	Network.On(Remotes.RegionDiscovered.name, function(payload: any)
		if type(payload) == "table" then
			NotificationController.Notify("Discovered", tostring(payload.name or payload.regionId), "Discovery")
		end
	end)
end

return NotificationController
