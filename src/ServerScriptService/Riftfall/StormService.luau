--!nolint
-- One Rift Storm event type: a timed, server-wide luck surge that unlocks the
-- storm-only rift pool. The server owns timing and odds; the client only draws
-- the visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local AnalyticsService = require(script.Parent.AnalyticsService)

local StormService = {}

local remotes = nil
local active = false
local startedAt = 0
local endsAt = 0

function StormService.init(remoteMap)
	remotes = remoteMap
	task.spawn(function()
		local lead = math.max(0, Config.Storm.WarningLead or 0)
		task.wait(math.max(0, Config.Storm.FirstDelay - lead))
		while true do
			StormService.warn()
			task.wait(lead)
			StormService.start()
			task.wait(Config.Storm.Duration)
			StormService.stop()
			local pause = math.random(Config.Storm.MinInterval, Config.Storm.MaxInterval)
			task.wait(math.max(0, pause - lead))
		end
	end)
end

--- Broadcast the incoming-storm banner a few seconds before the sky changes.
function StormService.warn()
	if remotes then
		remotes.Event:FireAllClients({
			kind = "storm",
			phase = "warning",
			duration = Config.Storm.WarningLead or 0,
			luck = Config.Storm.LuckMultiplier,
		})
	end
end

function StormService.isActive()
	return active
end

function StormService.luckMultiplier()
	if active then
		return Config.Storm.LuckMultiplier
	end
	return 1
end

function StormService.snapshot()
	if not active then
		return { active = false, remaining = 0, luck = 1 }
	end
	return {
		active = true,
		remaining = math.max(0, math.floor(endsAt - os.clock())),
		luck = Config.Storm.LuckMultiplier,
	}
end

function StormService.start()
	if active then
		return
	end
	active = true
	startedAt = os.clock()
	endsAt = startedAt + Config.Storm.Duration
	if remotes then
		remotes.Event:FireAllClients({
			kind = "storm",
			phase = "start",
			duration = Config.Storm.Duration,
			luck = Config.Storm.LuckMultiplier,
		})
	end
	for _, player in ipairs(Players:GetPlayers()) do
		AnalyticsService.log(player, "storm_start", Config.Storm.LuckMultiplier)
	end
	print("Riftfall: Rift Storm started")
end

function StormService.stop()
	if not active then
		return
	end
	active = false
	endsAt = 0
	if remotes then
		remotes.Event:FireAllClients({
			kind = "storm",
			phase = "end",
			duration = 0,
			luck = 1,
		})
	end
	print("Riftfall: Rift Storm ended")
end

return StormService
