--!strict
--[[
	Minimal Roblox value-type stubs so shared modules that build Vector3 /
	Color3 / CFrame values can be exercised by the headless test runner.
	These are TEST DOUBLES for the test harness only - the game itself uses the
	real Roblox engine types. Instances and services are NOT emulated here on
	purpose: modules that need them are covered by Studio playtest steps.
]]

local Stub = {}

-- Each type table is declared first so that its methods capture the local
-- instead of a global of the same name.
local function class(name: string)
	local tbl = { __type = name, ClassName = name }
	tbl.__index = tbl
	return tbl
end

-- ---------------------------------------------------------------------------
-- Vector3
-- ---------------------------------------------------------------------------

local Vector3 = class("Vector3")
local vector3Methods: { [string]: any } = {
	new = function(x: number?, y: number?, z: number?): any
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
	end,
	zero = function(): any
		return setmetatable({ X = 0, Y = 0, Z = 0 }, Vector3)
	end,
	one = function(): any
		return setmetatable({ X = 1, Y = 1, Z = 1 }, Vector3)
	end,
	FromNormalId = function(): any
		return setmetatable({ X = 0, Y = 1, Z = 0 }, Vector3)
	end,
	Magnitude = function(self: any): number
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end,
	Unit = function(self: any): any
		local m = self:Magnitude()
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end,
	Dot = function(self: any, other: any): number
		return self.X * other.X + self.Y * other.Y + self.Z * other.Z
	end,
	Cross = function(self: any, other: any): any
		return Vector3.new(
			self.Y * other.Z - self.Z * other.Y,
			self.Z * other.X - self.X * other.Z,
			self.X * other.Y - self.Y * other.X
		)
	end,
	Lerp = function(self: any, target: any, alpha: number): any
		return Vector3.new(
			self.X + (target.X - self.X) * alpha,
			self.Y + (target.Y - self.Y) * alpha,
			self.Z + (target.Z - self.Z) * alpha
		)
	end,
	FuzzyEq = function(self: any, other: any, epsilon: number?): boolean
		local e = epsilon or 1e-5
		return math.abs(self.X - other.X) <= e and math.abs(self.Y - other.Y) <= e and math.abs(self.Z - other.Z) <= e
	end,
}, {
	__add = function(a: any, b: any): any
		return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
	__sub = function(a: any, b: any): any
		return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__mul = function(a: any, b: any): any
		if typeof(b) == "number" then
			return Vector3.new(a.X * b, a.Y * b, a.Z * b)
		elseif typeof(a) == "number" then
			return Vector3.new(a * b.X, a * b.Y, a * b.Z)
		end
		return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__div = function(a: any, b: any): any
		if typeof(b) == "number" then
			return Vector3.new(a.X / b, a.Y / b, a.Z / b)
		end
		return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end,
	__unm = function(a: any): any
		return Vector3.new(-a.X, -a.Y, -a.Z)
	end,
	__eq = function(a: any, b: any): boolean
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	end,
	__tostring = function(a: any): string
		return string.format("%g, %g, %g", a.X, a.Y, a.Z)
	end,
}
for key, value in vector3Methods do
	Vector3[key] = value
end

-- ---------------------------------------------------------------------------
-- Vector2
-- ---------------------------------------------------------------------------

local Vector2 = class("Vector2")
local vector2Methods: { [string]: any } = {
	new = function(x: number?, y: number?): any
		return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
	end,
	zero = function(): any
		return setmetatable({ X = 0, Y = 0 }, Vector2)
	end,
	Magnitude = function(self: any): number
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end,
	Lerp = function(self: any, target: any, alpha: number): any
		return Vector2.new(self.X + (target.X - self.X) * alpha, self.Y + (target.Y - self.Y) * alpha)
	end,
}, {
	__add = function(a: any, b: any): any
		return Vector2.new(a.X + b.X, a.Y + b.Y)
	end,
	__sub = function(a: any, b: any): any
		return Vector2.new(a.X - b.X, a.Y - b.Y)
	end,
	__mul = function(a: any, b: any): any
		if typeof(b) == "number" then
			return Vector2.new(a.X * b, a.Y * b)
		elseif typeof(a) == "number" then
			return Vector2.new(a * b.X, a * b.Y)
		end
		return Vector2.new(a.X * b.X, a.Y * b.Y)
	end,
	__div = function(a: any, b: any): any
		if typeof(b) == "number" then
			return Vector2.new(a.X / b, a.Y / b)
		end
		return Vector2.new(a.X / b.X, a.Y / b.Y)
	end,
	__eq = function(a: any, b: any): boolean
		return a.X == b.X and a.Y == b.Y
	end,
}
for key, value in vector2Methods do
	Vector2[key] = value
end

-- ---------------------------------------------------------------------------
-- CFrame (subset: position + optional rotation matrix, enough for config math)
-- ---------------------------------------------------------------------------

local CFrame = class("CFrame")
local cframeMethods: { [string]: any } = {
	new = function(x: number?, y: number?, z: number?): any
		local self = setmetatable({}, CFrame)
		self.Position = Vector3.new(x or 0, y or 0, z or 0)
		self.Rotation = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		return self
	end,
	Angles = function(rx: number?, ry: number?, rz: number?): any
		local self = setmetatable({}, CFrame)
		self.Position = Vector3.new(0, 0, 0)
		self.Rotation = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		self._angles = { rx or 0, ry or 0, rz or 0 }
		return self
	end,
	fromEulerAnglesYXZ = function(y: number?, x: number?, z: number?): any
		return CFrame.Angles(x or 0, y or 0, z or 0)
	end,
	Identity = function(): any
		return CFrame.new(0, 0, 0)
	end,
	Inverse = function(self: any): any
		return CFrame.new(-self.Position.X, -self.Position.Y, -self.Position.Z)
	end,
	Lerp = function(self: any, target: any, alpha: number): any
		return CFrame.new(
			self.Position.X + (target.Position.X - self.Position.X) * alpha,
			self.Position.Y + (target.Position.Y - self.Position.Y) * alpha,
			self.Position.Z + (target.Position.Z - self.Position.Z) * alpha
		)
	end,
	PointToWorldSpace = function(self: any, point: any): any
		return self.Position + point
	end,
	PointToObjectSpace = function(self: any, point: any): any
		return point - self.Position
	end,
	ToWorldSpace = function(self: any, other: any): any
		return self * other
	end,
}, {
	__mul = function(a: any, b: any): any
		if typeof(b) == "number" then
			return a
		end
		if b.X ~= nil then
			return CFrame.new(a.Position.X + b.X, a.Position.Y + b.Y, a.Position.Z + b.Z)
		end
		return CFrame.new(
			a.Position.X + b.Position.X,
			a.Position.Y + b.Position.Y,
			a.Position.Z + b.Position.Z
		)
	end,
	__add = function(a: any, b: any): any
		return CFrame.new(a.Position.X + b.X, a.Position.Y + b.Y, a.Position.Z + b.Z)
	end,
	__sub = function(a: any, b: any): any
		return CFrame.new(a.Position.X - b.X, a.Position.Y - b.Y, a.Position.Z - b.Z)
	end,
}
for key, value in cframeMethods do
	CFrame[key] = value
end

-- ---------------------------------------------------------------------------
-- Colour / UI value types
-- ---------------------------------------------------------------------------

local Color3 = class("Color3")
local color3Methods: { [string]: any } = {
	new = function(r: number?, g: number?, b: number?): any
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
	end,
	fromRGB = function(r: number?, g: number?, b: number?): any
		return setmetatable({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }, Color3)
	end,
	fromHSV = function(h: number, s: number, v: number): any
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then
			return Color3.new(v, t, p)
		elseif i == 1 then
			return Color3.new(q, v, p)
		elseif i == 2 then
			return Color3.new(p, v, t)
		elseif i == 3 then
			return Color3.new(p, q, v)
		elseif i == 4 then
			return Color3.new(t, p, v)
		end
		return Color3.new(v, p, q)
	end,
	Lerp = function(self: any, target: any, alpha: number): any
		return Color3.new(
			self.R + (target.R - self.R) * alpha,
			self.G + (target.G - self.G) * alpha,
			self.B + (target.B - self.B) * alpha
		)
	end,
}, {
	__eq = function(a: any, b: any): boolean
		return a.R == b.R and a.G == b.G and a.B == b.B
	end,
}
for key, value in color3Methods do
	Color3[key] = value
end

local UDim = class("UDim")
local udimMethods: { [string]: any } = {
	new = function(scale: number?, offset: number?): any
		return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
	end,
}
for key, value in udimMethods do
	UDim[key] = value
end

local UDim2 = class("UDim2")
local udim2Methods: { [string]: any } = {
	new = function(xScale: number?, xOffset: number?, yScale: number?, yOffset: number?): any
		return setmetatable({
			X = UDim.new(xScale or 0, xOffset or 0),
			Y = UDim.new(yScale or 0, yOffset or 0),
		}, UDim2)
	end,
	fromScale = function(xScale: number?, yScale: number?): any
		return UDim2.new(xScale or 0, 0, yScale or 0, 0)
	end,
	fromOffset = function(xOffset: number?, yOffset: number?): any
		return UDim2.new(0, xOffset or 0, 0, yOffset or 0)
	end,
}
for key, value in udim2Methods do
	UDim2[key] = value
end

local Rect = class("Rect")
local rectMethods: { [string]: any } = {
	new = function(x0: number?, y0: number?, x1: number?, y1: number?): any
		return setmetatable({ Min = { x0 or 0, y0 or 0 }, Max = { x1 or 0, y1 or 0 } }, Rect)
	end,
}
for key, value in rectMethods do
	Rect[key] = value
end

local NumberRange = class("NumberRange")
local numberRangeMethods: { [string]: any } = {
	new = function(minimum: number?, maximum: number?): any
		return setmetatable({ Min = minimum or 0, Max = maximum or math.huge }, NumberRange)
	end,
}
for key, value in numberRangeMethods do
	NumberRange[key] = value
end

-- ---------------------------------------------------------------------------
-- Global installation
-- ---------------------------------------------------------------------------

-- The Luau CLI sandbox makes _G readonly, so the test runner injects these
-- types as file-level locals into every mirrored module instead of installing
-- them as globals.
function Stub.Inject()
	return Vector3, Vector2, CFrame, Color3, UDim, UDim2, Rect, NumberRange
end

-- Kept for callers that just want the table of stubs.
function Stub.Install()
	return Stub
end

Stub.Vector3 = Vector3
Stub.Vector2 = Vector2
Stub.CFrame = CFrame
Stub.Color3 = Color3
Stub.UDim = UDim
Stub.UDim2 = UDim2

return Stub
