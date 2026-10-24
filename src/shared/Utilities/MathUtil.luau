--!strict
-- Deterministic math helpers. Pure functions only: no Roblox engine state.

local MathUtil = {}

function MathUtil.Clamp(value: number, minValue: number, maxValue: number): number
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function MathUtil.Clamp01(value: number): number
	return MathUtil.Clamp(value, 0, 1)
end

function MathUtil.Lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * MathUtil.Clamp01(alpha)
end

function MathUtil.InverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return MathUtil.Clamp01((value - a) / (b - a))
end

function MathUtil.Round(value: number, decimals: number?): number
	local factor = 10 ^ (decimals or 0)
	return math.floor(value * factor + 0.5) / factor
end

function MathUtil.IsFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Guards against NaN / inf entering scores, damage and saved data.
function MathUtil.Sanitize(value: number, fallback: number?): number
	if not MathUtil.IsFinite(value) then
		return fallback or 0
	end
	return value
end

function MathUtil.Distance2D(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

function MathUtil.SmoothDamp(current: number, target: number, smoothing: number, dt: number): number
	if dt <= 0 then
		return current
	end
	local alpha = 1 - math.exp(-smoothing * dt)
	return current + (target - current) * alpha
end

function MathUtil.Approach(current: number, target: number, maxDelta: number): number
	local delta = target - current
	if math.abs(delta) <= maxDelta then
		return target
	end
	return current + (if delta > 0 then maxDelta else -maxDelta)
end

-- Weighted pick. `weights` maps key -> weight (must be >= 0).
function MathUtil.WeightedPick<T>(entries: { T }, weightOf: (T) -> number, random: number?): T?
	local total = 0
	for _, entry in entries do
		local weight = math.max(0, weightOf(entry) or 0)
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = (random or math.random()) * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += math.max(0, weightOf(entry) or 0)
		if roll <= cumulative then
			return entry
		end
	end
	return entries[#entries]
end

function MathUtil.Shuffle<T>(source: { T }, rng: () -> number): { T }
	local result = table.clone(source)
	for index = #result, 2, -1 do
		local other = math.floor((rng() * index) + 1)
		result[index], result[other] = result[other], result[index]
	end
	return result
end

return MathUtil
