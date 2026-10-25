--!nolint
local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function strip(value)
	local text = tostring(value)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

--- Compact a number for display: 1,204 -> "1.2K", 3_500_000 -> "3.5M".
function Format.compact(value)
	value = tonumber(value) or 0
	if value ~= value or value == math.huge then
		return "inf"
	end
	if value < 0 then
		return "-" .. Format.compact(-value)
	end
	if value < 1000 then
		if value >= 100 or value == math.floor(value) then
			return string.format("%d", math.floor(value))
		end
		return strip(string.format("%.1f", value))
	end
	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index = index + 1
	end
	local suffix = SUFFIXES[index] or ""
	local rendered
	if value >= 100 then
		rendered = string.format("%.0f", value)
	elseif value >= 10 then
		rendered = string.format("%.1f", value)
	else
		rendered = string.format("%.2f", value)
	end
	return strip(rendered) .. suffix
end

--- Display "1 in N" exactly, from the base pool odds.
function Format.odds(value)
	value = tonumber(value) or 1
	if value <= 0 then
		return "1 in 1"
	end
	if value < 10 then
		return string.format("1 in %.1f", value)
	end
	if value < 1000 then
		return string.format("1 in %d", math.floor(value + 0.5))
	end
	return "1 in " .. Format.compact(value)
end

function Format.percent(fraction)
	fraction = tonumber(fraction) or 0
	if fraction >= 0.01 then
		return string.format("%.1f%%", fraction * 100)
	end
	return string.format("%.4f%%", fraction * 100)
end

function Format.clock(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Format.timeAgo(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%dm", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%dh", math.floor(seconds / 3600))
	end
	return string.format("%dd", math.floor(seconds / 86400))
end

function Format.signed(value)
	value = tonumber(value) or 0
	if value >= 0 then
		return "+" .. Format.compact(value)
	end
	return "-" .. Format.compact(-value)
end

return Format
