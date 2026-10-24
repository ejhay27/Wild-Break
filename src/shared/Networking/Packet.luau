--!strict
--[[
	Packet.luau
	Schema helpers for remote payload validation.

	Every remote declared in Networking/Remotes.luau has an ordered argument
	schema built from these helpers. The server validates each incoming call
	against its schema BEFORE the gameplay handler sees the payload, so no
	handler has to re-implement argument sanity checking.
]]

local Validate = require(script.Parent.Parent.Utilities.Validate)

local Packet = {}

export type Field = {
	name: string,
	optional: boolean?,
	validator: (any) -> Validate.Result<any>,
}

export type Schema = { Field }

local function field(name: string, validator: (any) -> Validate.Result<any>, optional: boolean?): Field
	return { name = name, optional = optional or false, validator = validator }
end

function Packet.String(name: string, maxLength: number?, optional: boolean?): Field
	return field(name, function(value)
		return Validate.String(value, maxLength)
	end, optional)
end

function Packet.Id(name: string, optional: boolean?): Field
	return field(name, function(value)
		return Validate.Identifier(value)
	end, optional)
end

function Packet.Number(name: string, minValue: number?, maxValue: number?, optional: boolean?): Field
	return field(name, function(value)
		return Validate.Number(value, minValue, maxValue)
	end, optional)
end

function Packet.Integer(name: string, minValue: number?, maxValue: number?, optional: boolean?): Field
	return field(name, function(value)
		return Validate.Integer(value, minValue, maxValue)
	end, optional)
end

function Packet.Boolean(name: string, optional: boolean?): Field
	return field(name, Validate.Boolean, optional)
end

function Packet.Vector3(name: string, maxMagnitude: number?, optional: boolean?): Field
	return field(name, function(value)
		return Validate.Vector3(value, maxMagnitude)
	end, optional)
end

function Packet.Direction(name: string, optional: boolean?): Field
	return field(name, Validate.Direction, optional)
end

function Packet.Table(name: string, maxEntries: number?, optional: boolean?): Field
	return field(name, function(value)
		return Validate.Table(value, maxEntries)
	end, optional)
end

function Packet.Enum(name: string, allowed: { any }, optional: boolean?): Field
	return field(name, function(value)
		return Validate.OneOf(value, allowed)
	end, optional)
end

-- Validates an ordered argument list against a schema.
function Packet.ValidateArgs(schema: Schema, args: { any }): Validate.Result<{ [string]: any }>
	if #args > #schema then
		return { ok = false, value = nil, reason = string.format("too many arguments (%d > %d)", #args, #schema) }
	end
	local adapted = {}
	for index, entry in schema do
		adapted[index] = { name = entry.name, validator = entry.validator, optional = entry.optional }
	end
	return Validate.Args(args, adapted)
end

function Packet.Describe(schema: Schema): string
	local parts = {}
	for index, entry in schema do
		table.insert(parts, string.format("%d:%s%s", index, entry.name, if entry.optional then "?" else ""))
	end
	return table.concat(parts, ", ")
end

return Packet
