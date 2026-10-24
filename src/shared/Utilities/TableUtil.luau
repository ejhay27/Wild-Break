--!strict
-- Small deterministic helpers used across the codebase.

local TableUtil = {}

function TableUtil.ShallowCopy<T>(source: { [any]: T }): { [any]: T }
	local copy = {}
	for key, value in source do
		copy[key] = value
	end
	return copy
end

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local seen = {}
	local function copy(node: any): any
		if type(node) ~= "table" then
			return node
		end
		if seen[node] then
			return seen[node]
		end
		local result = {}
		seen[node] = result
		for key, subValue in node do
			result[copy(key)] = copy(subValue)
		end
		return result
	end
	return copy(value :: any) :: any
end

function TableUtil.Keys<T>(source: { [any]: T }): { any }
	local keys = {}
	for key, _ in source do
		table.insert(keys, key)
	end
	return keys
end

function TableUtil.Values<T>(source: { [any]: T }): { T }
	local values = {}
	for _, value in source do
		table.insert(values, value)
	end
	return values
end

function TableUtil.Count(source: { [any]: any }): number
	local total = 0
	for _ in source do
		total += 1
	end
	return total
end

function TableUtil.IsEmpty(source: { [any]: any }): boolean
	for _ in source do
		return false
	end
	return true
end

function TableUtil.SortedKeys(source: { [any]: any }): { any }
	local keys = TableUtil.Keys(source)
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Deterministic iteration order for reproducible loot / spawns.
function TableUtil.SortedByKey<T>(source: { [string]: T }): { { key: string, value: T } }
	local entries = {}
	for key, value in source do
		table.insert(entries, { key = key, value = value })
	end
	table.sort(entries, function(a, b)
		return a.key < b.key
	end)
	return entries
end

function TableUtil.Merge<T>(base: T, overrides: { [any]: any }?): T
	local result = TableUtil.DeepCopy(base)
	if not overrides then
		return result
	end
	for key, value in overrides do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = TableUtil.Merge(result[key], value)
		else
			result[key] = TableUtil.DeepCopy(value)
		end
	end
	return result
end

function TableUtil.Filter<T>(source: { T }, predicate: (T) -> boolean): { T }
	local result = {}
	for _, value in source do
		if predicate(value) then
			table.insert(result, value)
		end
	end
	return result
end

function TableUtil.Map<T, U>(source: { T }, transform: (T, number) -> U): { U }
	local result = {}
	for index, value in source do
		result[index] = transform(value, index)
	end
	return result
end

function TableUtil.Reduce<T, U>(source: { T }, initial: U, reducer: (U, T, number) -> U): U
	local accumulator = initial
	for index, value in source do
		accumulator = reducer(accumulator, value, index)
	end
	return accumulator
end

function TableUtil.Contains<T>(source: { T }, needle: T): boolean
	for _, value in source do
		if value == needle then
			return true
		end
	end
	return false
end

function TableUtil.IndexOf<T>(source: { T }, needle: T): number?
	for index, value in source do
		if value == needle then
			return index
		end
	end
	return nil
end

function TableUtil.Freeze(source: { [any]: any }): { [any]: any }
	return table.freeze(source)
end

return TableUtil
