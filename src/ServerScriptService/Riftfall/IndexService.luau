--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local IndexService = {}

local remotes = nil

function IndexService.init(remoteMap)
	remotes = remoteMap
end

--- Award every milestone the player now qualifies for. Returns the last award.
function IndexService.check(player, data)
	local unique = DataService.uniqueCount(data)
	local awarded = nil
	while data.milestone < #Config.Milestones do
		local nextMilestone = Config.Milestones[data.milestone + 1]
		if unique < nextMilestone.unique then
			break
		end
		data.milestone = data.milestone + 1
		data.flux = data.flux + nextMilestone.flux
		awarded = {
			tier = data.milestone,
			unique = unique,
			flux = nextMilestone.flux,
			luckBonus = nextMilestone.luckBonus,
		}
		if remotes then
			remotes.Event:FireClient(player, {
				kind = "milestone",
				tier = awarded.tier,
				unique = unique,
				flux = awarded.flux,
				luckBonus = awarded.luckBonus,
			})
		end
		AnalyticsService.log(player, "dex_milestone", awarded.tier)
	end
	if awarded then
		DataService.touch(player)
	end
	return awarded
end

return IndexService
