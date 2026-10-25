--!nolint
-- Thin wrapper around AnalyticsService:LogCustomEvent. Wrapped in pcall because
-- analytics availability changes between Studio and live servers, and no game
-- logic should ever depend on it.

local Analytics = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)

local AnalyticsService = {}

local lastSent = {}
local THROTTLE = Config.Analytics.Throttle

function AnalyticsService.init() end

function AnalyticsService.log(player, eventName, value)
	if not Config.Analytics.Enabled or not player or not eventName then
		return false
	end
	local key = tostring(player.UserId) .. ":" .. eventName
	local now = os.clock()
	local previous = lastSent[key]
	if previous and now - previous < THROTTLE then
		return false
	end
	lastSent[key] = now
	local ok = pcall(function()
		Analytics:LogCustomEvent(player, eventName, tonumber(value) or 0)
	end)
	return ok
end

function AnalyticsService.forget(player)
	local prefix = tostring(player.UserId) .. ":"
	for key in pairs(lastSent) do
		if string.sub(key, 1, #prefix) == prefix then
			lastSent[key] = nil
		end
	end
end

return AnalyticsService
