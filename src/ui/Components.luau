--!strict
--[[
	Components.luau
	Shared UI primitives for WILDBREAK.

	Every element is created in code (no .rbxm assets are assumed to exist),
	so the interface renders correctly before any art is imported. Sizes are
	expressed in scale + offset so the same layout works on PC and Android.
]]

local Components = {}

local CORNER = UDim.new(0, 6)
export type BarOptions = {
	name: string?,
	color: Color3?,
	background: Color3?,
	height: number?,
	position: UDim2?,
	size: UDim2?,
}

local function applyDefaults(instance: GuiObject, options: BarOptions?)
	if not options then
		return
	end
	if options.position then
		instance.Position = options.position
	end
	if options.size then
		instance.Size = options.size
	end
end

function Components.Frame(options: BarOptions?, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.Name = (options and options.name) or "Frame"
	frame.BackgroundColor3 = (options and options.background) or Color3.fromRGB(16, 18, 24)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	applyDefaults(frame, options)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER
	corner.Parent = frame

	if parent then
		frame.Parent = parent
	end
	return frame
end

-- A progress bar with a background track. `SetFill` clamps to 0..1 so a bad
-- value from the server cannot render an inverted or overflowing bar.
function Components.Bar(options: BarOptions?, parent: Instance?)
	local track = Components.Frame({
		name = (options and options.name) or "Bar",
		background = Color3.fromRGB(28, 30, 38),
		position = options and options.position,
		size = options and options.size,
	}, parent)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = (options and options.color) or Color3.fromRGB(90, 200, 120)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER
	corner.Parent = fill

	return {
		Instance = track,
		SetFill = function(fraction: number)
			fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		end,
		SetColor = function(color: Color3)
			fill.BackgroundColor3 = color
		end,
		Destroy = function()
			track:Destroy()
		end,
	}
end

function Components.Label(options: {
	name: string?,
	text: string?,
	size: UDim2?,
	position: UDim2?,
	color: Color3?,
	scaled: boolean?,
	align: Enum.TextXAlignment?,
	font: Enum.Font?,
}, parent: Instance?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = options.name or "Label"
	label.Text = options.text or ""
	label.Size = options.size or UDim2.new(1, 0, 0, 20)
	label.Position = options.position or UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = options.color or Color3.fromRGB(235, 238, 245)
	label.TextXAlignment = options.align or Enum.TextXAlignment.Left
	label.TextScaled = options.scaled ~= false
	label.Font = options.font or Enum.Font.GothamSemibold
	label.Parent = parent
	return label
end

function Components.Button(options: {
	name: string?,
	text: string?,
	size: UDim2?,
	position: UDim2?,
	color: Color3?,
}, parent: Instance?): TextButton
	local button = Instance.new("TextButton")
	button.Name = options.name or "Button"
	button.Text = options.text or ""
	button.Size = options.size or UDim2.new(0, 160, 0, 40)
	button.Position = options.position or UDim2.new(0, 0, 0, 0)
	button.BackgroundColor3 = options.color or Color3.fromRGB(48, 96, 160)
	button.TextColor3 = Color3.fromRGB(245, 245, 250)
	button.TextScaled = true
	button.Font = Enum.Font.GothamSemibold
	button.BorderSizePixel = 0
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER
	corner.Parent = button

	button.Parent = parent
	return button
end

function Components.ScrollingList(options: { name: string?, size: UDim2?, position: UDim2? }, parent: Instance?): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = options.name or "List"
	list.Size = options.size or UDim2.new(1, 0, 1, 0)
	list.Position = options.position or UDim2.new(0, 0, 0, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- The canvas resizes to the content so a growing list cannot clip.
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	return list
end

-- Standard screen container: a dimmed backdrop with a centred panel.
function Components.Screen(name: string, parent: Instance?): { Root: Frame, Panel: Frame, Close: TextButton }
	local root = Instance.new("Frame")
	root.Name = name
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
	root.BackgroundTransparency = 0.55
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 10
	root.Parent = parent

	local panel = Components.Frame({
		name = "Panel",
		background = Color3.fromRGB(20, 22, 30),
		size = UDim2.new(0.7, 0, 0.78, 0),
		position = UDim2.new(0.15, 0, 0.11, 0),
	}, root)
	panel.ZIndex = 11

	local close = Components.Button({
		name = "Close",
		text = "Close",
		size = UDim2.new(0, 96, 0, 34),
		position = UDim2.new(1, -108, 0, 12),
	}, panel)
	close.ZIndex = 12

	return { Root = root, Panel = panel, Close = close }
end

return Components
