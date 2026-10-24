--!strict
--[[
	Screens.luau
	Full-screen panels: inventory, settings, deployment, map and companions.

	Only one screen is open at a time. Opening a screen unlocks the mouse;
	closing it returns to first-person-locked input.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = ReplicatedStorage:WaitForChild("UI")
local Components = require(UI.Components)

local Enums = require(Shared.Constants.Enums)
local Settings = require(Shared.Config.SettingsConfig)
local Graphics = require(Shared.Config.GraphicsConfig)
local Regions = require(Shared.Config.RegionConfig)

local Screens = {}

export type ScreenHandle = {
	Name: string,
	Root: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

local function newScreen(name: string, parent: Instance): ScreenHandle
	local built = Components.Screen(name, parent)
	local open = false

	local function close()
		open = false
		built.Root.Visible = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	built.Close.MouseButton1Click:Connect(close)

	return {
		Name = name,
		Root = built.Root,
		Open = function()
			open = true
			built.Root.Visible = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end,
		Close = close,
		IsOpen = function()
			return open
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

local function buildInventory(parent: Instance, controller: any): ScreenHandle
	local screen = newScreen("Inventory", parent)
	local list = Components.ScrollingList({ name = "Items", size = UDim2.new(1, -24, 1, -70), position = UDim2.new(0, 12, 0, 56) }, screen.Root)

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local inventory = controller.Get()
		if not inventory or not inventory.items then
			return
		end
		for _, entry in inventory.items do
			local row = Components.Frame({ name = "Row", size = UDim2.new(1, -8, 0, 34) }, list)
			Components.Label({
				name = "Name",
				text = tostring(entry.name or entry.id),
				size = UDim2.new(0.6, 0, 1, 0),
				position = UDim2.new(0, 10, 0, 0),
			}, row)
			Components.Label({
				name = "Qty",
				text = string.format("x%d", entry.quantity or 0),
				size = UDim2.new(0.3, -10, 1, 0),
				position = UDim2.new(0.7, 0, 0, 0),
				align = Enum.TextXAlignment.Right,
			}, row)
		end
	end

	controller.OnChanged(refresh)
	return screen
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local function buildSettings(parent: Instance, controller: any): ScreenHandle
	local screen = newScreen("Settings", parent)
	local list = Components.ScrollingList({ name = "Options", size = UDim2.new(1, -24, 1, -70), position = UDim2.new(0, 12, 0, 56) }, screen.Root)

	-- Graphics preset row.
	local presetRow = Components.Frame({ name = "Preset", size = UDim2.new(1, -8, 0, 40) }, list)
	Components.Label({ name = "Label", text = "Graphics preset", size = UDim2.new(0.5, 0, 1, 0), position = UDim2.new(0, 10, 0, 0) }, presetRow)
	local presetButton = Components.Button({
		name = "Value",
		text = tostring(controller.Get("gp_graphics_preset") or "Auto"),
		size = UDim2.new(0.3, 0, 0.8, 0),
		position = UDim2.new(0.65, 0, 0.1, 0),
	}, presetRow)

	local presetOrder = Enums.GraphicsPresetOrder
	local presetIndex = 1
	presetButton.MouseButton1Click:Connect(function()
		presetIndex = (presetIndex % #presetOrder) + 1
		local next = presetOrder[presetIndex]
		presetButton.Text = next
		controller.Set("gp_graphics_preset", next)
	end)

	-- Every declared setting gets a row.
	for _, def in Settings.All do
		if def and def.kind == "Boolean" then
			local row = Components.Frame({ name = id, size = UDim2.new(1, -8, 0, 34) }, list)
			Components.Label({ name = "Label", text = def.displayName, size = UDim2.new(0.6, 0, 1, 0), position = UDim2.new(0, 10, 0, 0) }, row)
			local button = Components.Button({
				name = "Value",
				text = tostring(controller.Get(def.id)),
				size = UDim2.new(0.3, 0, 0.8, 0),
				position = UDim2.new(0.65, 0, 0.1, 0),
			}, row)
			button.MouseButton1Click:Connect(function()
				local next = not (controller.Get(def.id) == true)
				button.Text = tostring(next)
				controller.Set(def.id, next)
			end)
		elseif def and def.kind == "Number" then
			local row = Components.Frame({ name = def.id, size = UDim2.new(1, -8, 0, 34) }, list)
			Components.Label({ name = "Label", text = def.displayName, size = UDim2.new(0.5, 0, 1, 0), position = UDim2.new(0, 10, 0, 0) }, row)
			local slider = Instance.new("TextBox")
			slider.Name = "Value"
			slider.Size = UDim2.new(0.3, 0, 0.8, 0)
			slider.Position = UDim2.new(0.65, 0, 0.1, 0)
			slider.Text = tostring(controller.Get(def.id))
			slider.ClearTextOnFocus = false
			slider.Parent = row
			slider.FocusLost:Connect(function()
				local value = tonumber(slider.Text)
				if value then
					controller.Set(def.id, value)
				else
					slider.Text = tostring(controller.Get(def.id))
				end
			end)
		end
	end

	return screen
end

-- ---------------------------------------------------------------------------
-- Deployment
-- ---------------------------------------------------------------------------

local function buildDeployment(parent: Instance, controller: any): ScreenHandle
	local screen = newScreen("Deployment", parent)
	local list = Components.ScrollingList({ name = "Regions", size = UDim2.new(1, -24, 1, -70), position = UDim2.new(0, 12, 0, 56) }, screen.Root)

	for _, region in Regions:List() do
		if Regions.IsHub(region.id) then
			continue
		end
		local row = Components.Frame({ name = region.id, size = UDim2.new(1, -8, 0, 52) }, list)
		Components.Label({
			name = "Name",
			text = region.displayName or region.id,
			size = UDim2.new(0.55, 0, 1, 0),
			position = UDim2.new(0, 10, 0, 0),
		}, row)

		local quick = Components.Button({
			name = "QuickDrop",
			text = "Quick Drop",
			size = UDim2.new(0.2, 0, 0.8, 0),
			position = UDim2.new(0.57, 0, 0.1, 0),
		}, row)
		quick.MouseButton1Click:Connect(function()
			controller.Request("QuickDrop", region.id)
			screen.Close()
		end)

		local tactical = Components.Button({
			name = "Tactical",
			text = "Tactical",
			size = UDim2.new(0.2, 0, 0.8, 0),
			position = UDim2.new(0.78, 0, 0.1, 0),
		}, row)
		tactical.MouseButton1Click:Connect(function()
			controller.Request("Tactical", region.id)
			screen.Close()
		end)
	end

	local hubButton = Components.Button({
		name = "ReturnToHub",
		text = "Return to Haven Overlook",
		size = UDim2.new(0.4, 0, 0, 40),
		position = UDim2.new(0.3, 0, 1, -52),
	}, screen.Root)
	hubButton.MouseButton1Click:Connect(function()
		controller.ReturnToHub()
		screen.Close()
	end)

	return screen
end

-- ---------------------------------------------------------------------------
-- Companion roster
-- ---------------------------------------------------------------------------

local function buildCompanions(parent: Instance, controller: any): ScreenHandle
	local screen = newScreen("Companions", parent)
	local list = Components.ScrollingList({ name = "Roster", size = UDim2.new(1, -24, 1, -70), position = UDim2.new(0, 12, 0, 56) }, screen.Root)

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, companion in controller.Roster() do
			local row = Components.Frame({ name = companion.uid, size = UDim2.new(1, -8, 0, 44) }, list)
			Components.Label({
				name = "Name",
				text = string.format("%s (Lv %d)", tostring(companion.name), companion.level or 1),
				size = UDim2.new(0.5, 0, 1, 0),
				position = UDim2.new(0, 10, 0, 0),
			}, row)

			local active = controller.IsActive(companion.uid)
			local button = Components.Button({
				name = "Toggle",
				text = active and "Recall" or "Deploy",
				size = UDim2.new(0.3, 0, 0.8, 0),
				position = UDim2.new(0.65, 0, 0.1, 0),
			}, row)
			button.MouseButton1Click:Connect(function()
				if controller.IsActive(companion.uid) then
					controller.Recall(companion.uid)
				else
					controller.Deploy(companion.uid)
				end
				refresh()
			end)
		end
	end

	screen.Root:GetPropertyChangedSignal("Visible"):Connect(function()
		if screen.Root.Visible then
			refresh()
		end
	end)

	return screen
end

-- ---------------------------------------------------------------------------
-- Map
-- ---------------------------------------------------------------------------

local function buildMap(parent: Instance, controller: any): ScreenHandle
	local screen = newScreen("Map", parent)
	local list = Components.ScrollingList({ name = "Regions", size = UDim2.new(1, -24, 1, -70), position = UDim2.new(0, 12, 0, 56) }, screen.Root)

	for _, region in Regions:List() do
		local row = Components.Frame({ name = region.id, size = UDim2.new(1, -8, 0, 40) }, list)
		Components.Label({
			name = "Name",
			text = region.displayName or region.id,
			size = UDim2.new(0.7, 0, 1, 0),
			position = UDim2.new(0, 10, 0, 0),
		}, row)
	end

	return screen
end

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

function Screens.Build(parent: Instance, controllers: any): { [string]: ScreenHandle }
	return {
		Inventory = buildInventory(parent, controllers.InventoryController),
		Settings = buildSettings(parent, controllers.SettingsController),
		Deployment = buildDeployment(parent, controllers.DeploymentController),
		Companions = buildCompanions(parent, controllers.CompanionController),
		Map = buildMap(parent, controllers.StateController),
	}
end

return Screens
