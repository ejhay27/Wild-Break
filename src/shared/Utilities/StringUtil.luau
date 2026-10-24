--!strict
-- Formatting helpers for UI, logs and localization keys.

local StringUtil = {}

function StringUtil.CommaNumber(value: number): string
	local integer = math.floor(math.abs(value))
	local formatted = tostring(integer)
	local out = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	if value < 0 then
		out = "-" .. out
	end
	return out
end

function StringUtil.AbbreviateNumber(value: number): string
	local abs = math.abs(value)
	if abs >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif abs >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif abs >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

function StringUtil.FormatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remaining = seconds % 60
	if minutes >= 60 then
		local hours = math.floor(minutes / 60)
		return string.format("%dh %02dm", hours, minutes % 60)
	end
	return string.format("%d:%02d", minutes, remaining)
end

function StringUtil.TitleCase(text: string): string
	return (text:gsub("(%a)([%w_%.%-%']*)", function(first: string, rest: string)
		return first:upper() .. rest:lower()
	end))
end

function StringUtil.Split(text: string, separator: string): { string }
	local parts = {}
	for part in string.gmatch(text, "([^" .. separator .. "]+)") do
		table.insert(parts, part)
	end
	return parts
end

function StringUtil.Trim(text: string): string
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function StringUtil.Truncate(text: string, maxLength: number): string
	if #text <= maxLength then
		return text
	end
	return string.sub(text, 1, math.max(1, maxLength - 1)) .. "…"
end

-- Stable id from a display name: "Pyr axis" -> "pyr_axis"
function StringUtil.ToId(displayName: string): string
	local id = displayName:lower():gsub("[^%w]+", "_"):gsub("^_", ""):gsub("_$", "")
	return id
end

return StringUtil
