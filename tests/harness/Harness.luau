--!strict
--[[
	Minimal test harness for the headless Luau test runner (tools/run_tests.py).
	No Roblox dependency: pure Luau so it runs under the Luau CLI.
]]

local Test = {}

local state = {
	suite = "",
	passed = 0,
	failed = 0,
	failures = {} :: { string },
	-- Cursor into `failures` and the counters as of the previous Report(), so
	-- each spec reports only its own results.
	reportedPassed = 0,
	reportedFailed = 0,
	failureCursor = 0,
}

local function fmt(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "number" then
		return tostring(value)
	elseif type(value) == "boolean" or value == nil then
		return tostring(value)
	end
	return string.format("<%s>", typeof(value))
end

function Test.describe(name: string, fn: () -> ())
	local previous = state.suite
	state.suite = if previous == "" then name else previous .. " / " .. name
	fn()
	state.suite = previous
end

function Test.it(name: string, fn: () -> ())
	local label = if state.suite == "" then name else state.suite .. " > " .. name
	local ok, err = pcall(fn)
	if ok then
		state.passed += 1
	else
		state.failed += 1
		table.insert(state.failures, label .. "\n    " .. tostring(err))
	end
end

function Test.fail(message: string)
	error(message, 2)
end

function Test.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "equality", fmt(expected), fmt(actual)), 2)
	end
end

function Test.neq(actual: any, unexpected: any, message: string?)
	if actual == unexpected then
		error(string.format("%s: expected anything but %s", message or "inequality", fmt(unexpected)), 2)
	end
end

function Test.truthy(value: any, message: string?)
	if not value then
		error(string.format("%s: expected truthy, got %s", message or "truthy", fmt(value)), 2)
	end
end

function Test.falsy(value: any, message: string?)
	if value then
		error(string.format("%s: expected falsy, got %s", message or "falsy", fmt(value)), 2)
	end
end

function Test.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > (tolerance or 1e-6) then
		error(
			string.format(
				"%s: expected %s within %s of %s, got %s",
				message or "near",
				fmt(actual),
				fmt(tolerance or 1e-6),
				fmt(expected),
				fmt(actual)
			),
			2
		)
	end
end

function Test.gte(actual: number, minimum: number, message: string?)
	if actual < minimum then
		error(string.format("%s: expected >= %s, got %s", message or "gte", fmt(minimum), fmt(actual)), 2)
	end
end

function Test.lte(actual: number, maximum: number, message: string?)
	if actual > maximum then
		error(string.format("%s: expected <= %s, got %s", message or "lte", fmt(maximum), fmt(actual)), 2)
	end
end

function Test.gt(actual: number, maximum: number, message: string?)
	if actual <= maximum then
		error(string.format("%s: expected > %s, got %s", message or "gt", fmt(maximum), fmt(actual)), 2)
	end
end

function Test.lt(actual: number, minimum: number, message: string?)
	if actual >= minimum then
		error(string.format("%s: expected < %s, got %s", message or "lt", fmt(minimum), fmt(actual)), 2)
	end
end

function Test.contains(haystack: string, needle: string, message: string?)
	if not string.find(haystack, needle, 1, true) then
		error(string.format("%s: expected %q to contain %q", message or "contains", haystack, needle), 2)
	end
end

function Test.empty(problems: { any }, message: string?)
	if #problems > 0 then
		local joined = table.concat((problems :: any) :: { string }, "\n    ")
		error(string.format("%s: expected no problems, got %d:\n    %s", message or "empty", #problems, joined), 2)
	end
end

function Test.noError(fn: () -> (), message: string?)
	local ok, err = pcall(fn)
	if not ok then
		error(string.format("%s: unexpected error: %s", message or "noError", tostring(err)), 2)
	end
end

-- Prints this spec's own summary. Returns true when every case in THIS spec
-- passed. Counts are deltas against the previous report because the Harness
-- module is shared by every spec running in the same Lua VM.
function Test.Report(): boolean
	local passed = state.passed - state.reportedPassed
	local failed = state.failed - state.reportedFailed
	state.reportedPassed = state.passed
	state.reportedFailed = state.failed

	print(string.format("\n  passed: %d   failed: %d", passed, failed))
	for index = state.failureCursor + 1, #state.failures do
		print("  [FAIL] " .. state.failures[index])
	end
	state.failureCursor = #state.failures
	return failed == 0
end

-- Convenience: run and hard-fail the module so the runner reports it.
function Test.Finish()
	if not Test.Report() then
		error("spec failed", 2)
	end
end

return Test
