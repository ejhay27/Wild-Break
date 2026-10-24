--!strict
--[[
	Logger.luau
	Tagged logging with levels. Server logs are the source of truth for the
	audit trail; client logs are suppressed in release builds unless the
	WILDBREAK_DEBUG attribute is set.
]]

local Logger = {}

export type Level = "Debug" | "Info" | "Warn" | "Error"

local ORDER: { [Level]: number } = {
	Debug = 1,
	Info = 2,
	Warn = 3,
	Error = 4,
}

local minimumLevel: Level = "Info"
local runContext = "Shared"

function Logger.Configure(context: string, level: Level?)
	runContext = context
	if level then
		minimumLevel = level
	end
end

function Logger.SetLevel(level: Level)
	minimumLevel = level
end

local function emit(level: Level, tag: string, message: string)
	if ORDER[level] < ORDER[minimumLevel] then
		return
	end
	local line = string.format("[%s][%s][%s] %s", runContext, level, tag, message)
	if level == "Error" then
		warn(line)
	elseif level == "Warn" then
		warn(line)
	else
		print(line)
	end
end

function Logger.Debug(tag: string, message: string)
	emit("Debug", tag, message)
end

function Logger.Info(tag: string, message: string)
	emit("Info", tag, message)
end

function Logger.Warn(tag: string, message: string)
	emit("Warn", tag, message)
end

function Logger.Error(tag: string, message: string)
	emit("Error", tag, message)
end

-- Prefix helper: Logger.For("Combat") returns a tagged sub-logger.
function Logger.For(tag: string)
	return {
		Debug = function(message: string)
			Logger.Debug(tag, message)
		end,
		Info = function(message: string)
			Logger.Info(tag, message)
		end,
		Warn = function(message: string)
			Logger.Warn(tag, message)
		end,
		Error = function(message: string)
			Logger.Error(tag, message)
		end,
	}
end

return Logger
