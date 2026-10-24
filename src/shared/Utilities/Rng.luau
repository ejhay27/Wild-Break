--!strict
--[[
	Rng.luau
	Small deterministic PRNG (xorshift128) so spawn placement, loot rolls and
	procedural generation can be reproduced from a seed. The server always
	seeds from its own source of entropy and never trusts a client seed.
]]

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: {
	state: { number },
	seed: number,
}, Rng))

local function nextState(self: Rng): number
	-- xorshift128
	local s = self.state
	local t = s[4]
	local v = s[1]
	t = bit32.bxor(t, bit32.lshift(t, 11))
	t = bit32.bxor(t, bit32.rshift(t, 8))
	s[4] = s[3]
	s[3] = s[2]
	s[2] = v
	v = bit32.bxor(v, bit32.rshift(v, 19))
	v = bit32.bxor(v, t)
	v = bit32.bxor(v, bit32.lshift(v, 8))
	-- bit32 is unsigned 32 bit; convert to [0, 1)
	s[1] = v
	return (v % 16777216) / 16777216
end

function Rng.new(seed: number?): Rng
	local resolvedSeed = seed or os.time()
	local state = {}
	for index = 1, 4 do
		state[index] = bit32.bxor(math.floor(resolvedSeed * (index + 1)) + index * 2654435761, 0x9E3779B9)
		if state[index] == 0 then
			state[index] = index * 1013904223
		end
	end
	local self = setmetatable({
		state = state,
		seed = resolvedSeed,
	}, Rng)
	-- Warm up
	for _ = 1, 12 do
		nextState(self)
	end
	return self
end

function Rng.Next(self: Rng): number
	return nextState(self)
end

function Rng.NextInteger(self: Rng, minValue: number, maxValue: number): number
	if maxValue < minValue then
		minValue, maxValue = maxValue, minValue
	end
	return minValue + math.floor(nextState(self) * (maxValue - minValue + 1))
end

function Rng.NextNumber(self: Rng, minValue: number, maxValue: number): number
	return minValue + nextState(self) * (maxValue - minValue)
end

function Rng.Chance(self: Rng, probability: number): boolean
	return nextState(self) < probability
end

function Rng.Pick<T>(self: Rng, source: { T }): T?
	if #source == 0 then
		return nil
	end
	return source[self:NextInteger(1, #source)]
end

function Rng.Shuffle<T>(self: Rng, source: { T }): { T }
	local result = table.clone(source)
	for index = #result, 2, -1 do
		local other = self:NextInteger(1, index)
		result[index], result[other] = result[other], result[index]
	end
	return result
end

function Rng.WeightedPick<T>(self: Rng, entries: { T }, weightOf: (T) -> number): T?
	local total = 0
	for _, entry in entries do
		total += math.max(0, weightOf(entry) or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = nextState(self) * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += math.max(0, weightOf(entry) or 0)
		if roll <= cumulative then
			return entry
		end
	end
	return entries[#entries]
end

return Rng
