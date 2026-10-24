--!strict
--[[
	Timer.luau
	Server-controlled timers with explicit completion and cancellation.
	Used for resource respawns (exactly 180s for ordinary nodes), boss
	respawns (600s), event durations and ultimate windows.
]]

local Timer = {}
Timer.__index = Timer

export type Timer = typeof(setmetatable({} :: {
	id: string,
	duration: number,
	startedAt: number,
	expiresAt: number,
	cancelled: boolean,
	paused: boolean,
	remainingAtPause: number?,
	onComplete: ((Timer) -> ())?,
	context: any,
}, Timer))

local timers: { [string]: Timer } = {}

function Timer.new(id: string, duration: number, onComplete: ((Timer) -> ())?, context: any?): Timer
	local now = os.clock()
	local self = setmetatable({
		id = id,
		duration = math.max(0, duration),
		startedAt = now,
		expiresAt = now + math.max(0, duration),
		cancelled = false,
		paused = false,
		remainingAtPause = nil,
		onComplete = onComplete,
		context = context,
	}, Timer)
	timers[id] = self
	return self
end

function Timer.Get(id: string): Timer?
	return timers[id]
end

function Timer.Remaining(self: Timer): number
	if self.cancelled then
		return 0
	end
	if self.paused then
		return self.remainingAtPause or 0
	end
	return math.max(0, self.expiresAt - os.clock())
end

function Timer.Elapsed(self: Timer): number
	return math.max(0, os.clock() - self.startedAt)
end

function Timer.Complete(self: Timer): boolean
	if self.cancelled or self.paused then
		return false
	end
	return os.clock() >= self.expiresAt
end

function Timer.Pause(self: Timer)
	if self.paused or self.cancelled then
		return
	end
	self.paused = true
	self.remainingAtPause = Timer.Remaining(self)
end

function Timer.Resume(self: Timer)
	if not self.paused or self.cancelled then
		return
	end
	self.paused = false
	self.expiresAt = os.clock() + (self.remainingAtPause or 0)
	self.remainingAtPause = nil
end

function Timer.Cancel(self: Timer)
	self.cancelled = true
	timers[self.id] = nil
end

function Timer.Destroy(self: Timer)
	self:Cancel()
end

-- Driven by the server heartbeat; safe to call with any elapsed delta.
function Timer.UpdateAll()
	local now = os.clock()
	local completed = {}
	for id, timer in timers do
		if not timer.paused and not timer.cancelled and now >= timer.expiresAt then
			table.insert(completed, timer)
			timers[id] = nil
		end
	end
	for _, timer in completed do
		if timer.onComplete then
			local ok, err = pcall(timer.onComplete, timer)
			if not ok then
				warn(string.format("[Timer] callback error for %s: %s", timer.id, tostring(err)))
			end
		end
	end
	return #completed
end

function Timer.ActiveCount(): number
	local count = 0
	for _ in timers do
		count += 1
	end
	return count
end

function Timer.ClearAll()
	table.clear(timers)
end

return Timer
