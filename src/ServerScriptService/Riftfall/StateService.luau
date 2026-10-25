--!nolint
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local RiftData = require(Shared.RiftData)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local StormService = require(script.Parent.StormService)

local StateService = {}

local remotes = nil
local nextRollProvider = nil

function StateService.init(remoteMap)
	remotes = remoteMap
end

function StateService.payload(player)
	-- peek, not getData: the HUD appears on join even if the DataStore request is
	-- still in flight. Gameplay still requires the settled profile.
	local data = DataService.peek(player)
	if not data then
		return nil
	end
	local passes = MonetizationService.passes(player)
	local storm = StormService.snapshot()
	local baseLuck = EconomyService.baseLuck(data)
	local best = nil
	if data.bestId then
		local rift = RiftData.RiftById[data.bestId]
		if rift then
			best = {
				id = rift.id,
				name = rift.name,
				odds = rift.odds,
				tier = rift.tier,
				income = rift.income,
			}
		end
	end
	local nextRollIn = 0
	if nextRollProvider then
		nextRollIn = nextRollProvider(player)
	end
	return {
		flux = data.flux,
		income = EconomyService.incomeOf(data),
		luck = baseLuck * (storm.active and storm.luck or 1),
		baseLuck = baseLuck,
		cooldown = EconomyService.cooldownOf(data, passes),
		nextRollIn = nextRollIn,
		rolls = data.rolls,
		autoRoll = data.autoRoll,
		autoAvailable = data.autoRollUnlocked or passes.riftRunner,
		autoUnlocked = data.autoRollUnlocked,
		luckLevel = data.luckLevel,
		speedLevel = data.speedLevel,
		nextLuckCost = EconomyService.luckCost(data.luckLevel),
		nextSpeedCost = EconomyService.speedCost(data.speedLevel),
		autoCost = EconomyService.costOf("auto", data),
		dex = DataService.uniqueCount(data),
		dexTotal = #RiftData.Rifts,
		best = best,
		milestone = data.milestone,
		tutorialStep = data.tutorialStep or 0,
		storm = {
			active = storm.active,
			remaining = storm.remaining,
			luck = storm.luck,
		},
		pass = {
			riftRunner = passes.riftRunner,
			omegaAura = passes.omegaAura,
		},
	}
end

function StateService.push(player, nextRollIn)
	local payload = StateService.payload(player)
	if not payload then
		return
	end
	if nextRollIn ~= nil then
		payload.nextRollIn = nextRollIn
	end
	remotes.State:FireClient(player, payload)
end

function StateService.pushCollection(player)
	local data = DataService.peek(player)
	if not data then
		return
	end
	remotes.Collection:FireClient(player, data.rifts)
end

function StateService.start(providers)
	nextRollProvider = providers and providers.nextRollIn or nil
	local tick = 0
	task.spawn(function()
		while true do
			task.wait(Config.Data.StateInterval)
			tick = tick + 1
			for _, player in ipairs(Players:GetPlayers()) do
				StateService.push(player)
				-- Collection is resent periodically so a client that connected after
				-- the join push still receives its full Riftodex.
				if tick % 4 == 0 then
					StateService.pushCollection(player)
				end
			end
		end
	end)
end

return StateService
