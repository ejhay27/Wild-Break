--!strict
--[[
	Registry.luau
	Tiny generic registry used by every configuration module. It gives all
	registries identical lookup, ordering, iteration and integrity checking
	so the automated tests can validate hundreds of definitions uniformly.
]]

local TableUtil = require(script.Parent.Parent.Utilities.TableUtil)

local Registry = {}
Registry.__index = Registry

export type Registry<T> = typeof(setmetatable({} :: {
	name: string,
	entries: { [string]: T },
	requiredFields: { string },
}, Registry))

function Registry.new<T>(name: string, entries: { [string]: T }, requiredFields: { string }?): Registry<T>
	local self = setmetatable({
		name = name,
		entries = entries or {},
		requiredFields = requiredFields or { "id", "displayName" },
	}, Registry)
	return self
end

function Registry.Get<T>(self: Registry<T>, id: string): T?
	return self.entries[id]
end

function Registry.GetOrError<T>(self: Registry<T>, id: string): T
	local entry = self.entries[id]
	if not entry then
		error(string.format("[%s] unknown id %q", self.name, tostring(id)), 3)
	end
	return entry
end

function Registry.Has<T>(self: Registry<T>, id: string): boolean
	return self.entries[id] ~= nil
end

function Registry.All<T>(self: Registry<T>): { [string]: T }
	return self.entries
end

function Registry.List<T>(self: Registry<T>): { T }
	local list = {}
	for _, entry in TableUtil.SortedByKey(self.entries) do
		table.insert(list, entry.value)
	end
	return list
end

function Registry.Ids<T>(self: Registry<T>): { string }
	return TableUtil.SortedKeys(self.entries)
end

function Registry.Count<T>(self: Registry<T>): number
	return TableUtil.Count(self.entries)
end

function Registry.Filter<T>(self: Registry<T>, predicate: (T, string) -> boolean): { T }
	local list = {}
	for _, entry in TableUtil.SortedByKey(self.entries) do
		if predicate(entry.value, entry.key) then
			table.insert(list, entry.value)
		end
	end
	return list
end

-- Returns a list of human readable problems; empty list means the registry
-- is internally consistent.
function Registry.Validate<T>(self: Registry<T>): { string }
	local problems = {}
	for id, entry in TableUtil.SortedByKey(self.entries) do
		if entry.key ~= (entry.value :: any).id then
			table.insert(
				problems,
				string.format("[%s] entry key %q does not match its id field %q", self.name, entry.key, tostring((entry.value :: any).id))
			)
		end
		for _, field in self.requiredFields do
			if (entry.value :: any)[field] == nil then
				table.insert(problems, string.format("[%s] %s is missing required field %q", self.name, entry.key, field))
			end
		end
	end
	return problems
end

function Registry.Merge<T>(self: Registry<T>, extra: { [string]: T })
	for id, entry in extra do
		self.entries[id] = entry
	end
end

return Registry
