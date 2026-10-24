--!strict
--[[
	Validate.luau
	Argument and state validation helpers.

	Every remote call in WILDBREAK is validated with these helpers before any
	gameplay handler runs. Nothing here trusts the client: values are range
	checked, NaN guarded and distance checked against server-known state.
]]

local Validate = {}

export type Result<T> = { ok: boolean, value: T?, reason: string? }

local function ok<T>(value: T): Result<T>
	return { ok = true, value = value, reason = nil }
end

local function fail<T>(reason: string): Result<T>
	return { ok = false, value = nil, reason = reason }
end

local MAX_MAGNITUDE = 1e6

function Validate.IsFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.Number(value: any, minValue: number?, maxValue: number?): Result<number>
	if not Validate.IsFiniteNumber(value) then
		return fail("number expected")
	end
	local number = value :: number
	if minValue ~= nil and number < minValue then
		return fail(string.format("number below minimum (%s < %s)", tostring(number), tostring(minValue)))
	end
	if maxValue ~= nil and number > maxValue then
		return fail(string.format("number above maximum (%s > %s)", tostring(number), tostring(maxValue)))
	end
	return ok(number)
end

function Validate.Integer(value: any, minValue: number?, maxValue: number?): Result<number>
	local result = Validate.Number(value, minValue, maxValue)
	if not result.ok then
		return result
	end
	if (result.value :: number) % 1 ~= 0 then
		return fail("integer expected")
	end
	return result
end

function Validate.String(value: any, maxLength: number?, pattern: string?): Result<string>
	if type(value) ~= "string" then
		return fail("string expected")
	end
	local text = value :: string
	if #text == 0 then
		return fail("empty string")
	end
	if maxLength and #text > maxLength then
		return fail("string too long")
	end
	if pattern and not string.match(text, pattern) then
		return fail("string rejected by pattern")
	end
	return ok(text)
end

function Validate.Identifier(value: any, maxLength: number?): Result<string>
	-- Stable identifiers: letters, digits, underscore, dot and dash only.
	return Validate.String(value, maxLength or 64, "^[%w_%.%-]+$")
end

function Validate.Boolean(value: any): Result<boolean>
	if type(value) ~= "boolean" then
		return fail("boolean expected")
	end
	return ok(value)
end

function Validate.Table(value: any, maxEntries: number?): Result<{ [any]: any }>
	if type(value) ~= "table" then
		return fail("table expected")
	end
	if maxEntries then
		local count = 0
		for _ in value :: { [any]: any } do
			count += 1
			if count > maxEntries then
				return fail("table too large")
			end
		end
	end
	return ok(value)
end

function Validate.OneOf(value: any, allowed: { any }): Result<any>
	for _, candidate in allowed do
		if candidate == value then
			return ok(value)
		end
	end
	return fail(string.format("value %q is not an allowed option", tostring(value)))
end

function Validate.Vector3(value: any, maxMagnitude: number?): Result<Vector3>
	if typeof(value) == "Vector3" then
		local vector: Vector3 = value
		if not (Validate.IsFiniteNumber(vector.X) and Validate.IsFiniteNumber(vector.Y) and Validate.IsFiniteNumber(vector.Z)) then
			return fail("vector contains non-finite component")
		end
		if vector.Magnitude > (maxMagnitude or MAX_MAGNITUDE) then
			return fail("vector out of bounds")
		end
		return ok(vector)
	end
	-- Tolerate loose tables coming from JSON-ish payloads.
	if type(value) == "table" then
		local x, y, z = value.x or value.X or value[1], value.y or value.Y or value[2], value.z or value.Z or value[3]
		if Validate.IsFiniteNumber(x) and Validate.IsFiniteNumber(y) and Validate.IsFiniteNumber(z) then
			local vector: Vector3 = Vector3.new(x :: number, y :: number, z :: number)
			if vector.Magnitude > (maxMagnitude or MAX_MAGNITUDE) then
				return fail("vector out of bounds")
			end
			return ok(vector)
		end
	end
	return fail("Vector3 expected")
end

function Validate.Direction(value: any): Result<Vector3>
	local result = Validate.Vector3(value, 4)
	if not result.ok then
		return fail("direction vector expected")
	end
	local vector: Vector3 = result.value :: Vector3
	if math.abs(vector.Magnitude - 1) > 0.15 then
		return fail("direction must be normalized")
	end
	return ok(vector)
end

-- Distance check between two server-known points.
function Validate.Distance(a: Vector3, b: Vector3, maxDistance: number): Result<number>
	local distance = (a - b).Magnitude
	if not Validate.IsFiniteNumber(distance) then
		return fail("distance not finite")
	end
	if distance > maxDistance then
		return fail(string.format("too far (%.1f > %.1f studs)", distance, maxDistance))
	end
	return ok(distance)
end

function Validate.InstanceOf(value: any, className: string): Result<any>
	if typeof(value) ~= "Instance" then
		return fail("Instance expected")
	end
	if not value:IsA(className) then
		return fail(string.format("Instance is not a %s", className))
	end
	return ok(value)
end

-- Validates an argument list against a schema of validators.
function Validate.Args(args: { any }, schema: { { name: string, validator: (any) -> Result<any>, optional: boolean? } }): Result<{ [string]: any }>
	local out = {}
	for index, entry in schema do
		local value = args[index]
		if value == nil then
			if not entry.optional then
				return fail(string.format("missing argument %s", entry.name))
			end
			continue
		end
		local result = entry.validator(value)
		if not result.ok then
			return fail(string.format("argument %s: %s", entry.name, tostring(result.reason)))
		end
		out[entry.name] = result.value
	end
	return ok(out)
end

function Validate.Ok(): Result<boolean>
	return ok(true)
end

function Validate.Fail(reason: string): Result<any>
	return fail(reason)
end

return Validate
