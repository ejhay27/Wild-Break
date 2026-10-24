--!strict
--[[
	RateLimiter.luau
	Token-bucket rate limiter used for remote-event flood protection.
	One bucket per (player, action) pair, trimmed automatically so idle
	buckets never accumulate.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Bucket = {
	tokens: number,
	lastRefill: number,
}

export type RateLimiter = typeof(setmetatable({} :: {
	_buckets: { [string]: Bucket },
}, RateLimiter))

local TRIM_INTERVAL = 120
local nextTrim = 0

function RateLimiter.new(): RateLimiter
	return setmetatable({ _buckets = {} }, RateLimiter)
end

-- Returns true when the action is allowed, false when it should be dropped.
function RateLimiter.Allow(self: RateLimiter, key: string, perSecond: number, burst: number?): boolean
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = burst or perSecond, lastRefill = now }
		self._buckets[key] = bucket
	end
	local elapsed = math.max(0, now - bucket.lastRefill)
	bucket.lastRefill = now
	bucket.tokens = math.min(burst or perSecond, bucket.tokens + elapsed * perSecond)
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	if now > nextTrim then
		nextTrim = now + TRIM_INTERVAL
		self:Trim(now)
	end
	return true
end

function RateLimiter.Remaining(self: RateLimiter, key: string): number
	local bucket = self._buckets[key]
	if not bucket then
		return 0
	end
	return math.floor(bucket.tokens)
end

function RateLimiter.Reset(self: RateLimiter, key: string?)
	if key then
		self._buckets[key] = nil
	else
		table.clear(self._buckets)
	end
end

function RateLimiter.Trim(self: RateLimiter, now: number?)
	local current = now or os.clock()
	for key, bucket in self._buckets do
		if current - bucket.lastRefill > TRIM_INTERVAL then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
