--!nolint
-- Flux economy and upgrade math. All costs are recomputed on the server; the
-- client only ever sends "please buy this key".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local RiftData = require(Shared.RiftData)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

function EconomyService.incomeOf(data)
	local total = 0
	for riftId, count in pairs(data.rifts) do
		local rift = RiftData.RiftById[riftId]
		if rift then
			total = total + rift.income * count
		end
	end
	return total
end

function EconomyService.milestoneLuck(data)
	local bonus = 0
	for index = 1, data.milestone do
		local milestone = Config.Milestones[index]
		if milestone then
			bonus = bonus + milestone.luckBonus
		end
	end
	return bonus
end

function EconomyService.baseLuck(data)
	return 1 + data.luckLevel * Config.Roll.LuckPerLevel + EconomyService.milestoneLuck(data)
end

function EconomyService.cooldownOf(data, passes)
	local cooldown = Config.Roll.BaseCooldown - data.speedLevel * Config.Roll.SpeedStep
	if passes and passes.riftRunner then
		cooldown = cooldown * Config.Roll.PassCooldownMult
	end
	return math.max(Config.Roll.MinCooldown, cooldown)
end

function EconomyService.luckCost(level)
	if level >= Config.Upgrades.luck.maxLevel then
		return nil
	end
	return math.floor(Config.Upgrades.luck.baseCost * (Config.Upgrades.luck.growth ^ level))
end

function EconomyService.speedCost(level)
	if level >= Config.Upgrades.speed.maxLevel then
		return nil
	end
	return math.floor(Config.Upgrades.speed.baseCost * (Config.Upgrades.speed.growth ^ level))
end

function EconomyService.autoCost()
	return Config.Upgrades.auto.cost
end

--- Returns cost, or nil if the upgrade is already maxed.
function EconomyService.costOf(key, data)
	if key == "luck" then
		return EconomyService.luckCost(data.luckLevel)
	elseif key == "speed" then
		return EconomyService.speedCost(data.speedLevel)
	elseif key == "auto" then
		if data.autoRollUnlocked then
			return nil
		end
		return Config.Upgrades.auto.cost
	end
	return nil
end

--- Attempt an upgrade. Returns ok, message.
function EconomyService.upgrade(player, key)
	local data = DataService.getData(player)
	if not data then
		return false, "Profile is still loading"
	end
	if key ~= "luck" and key ~= "speed" and key ~= "auto" then
		return false, "Unknown upgrade"
	end

	local cost = EconomyService.costOf(key, data)
	if cost == nil then
		return false, "Already maxed"
	end
	if data.flux < cost then
		return false, "Not enough Flux"
	end

	data.flux = data.flux - cost
	if key == "luck" then
		data.luckLevel = data.luckLevel + 1
	elseif key == "speed" then
		data.speedLevel = data.speedLevel + 1
	elseif key == "auto" then
		data.autoRollUnlocked = true
		data.autoRoll = true
	end
	DataService.touch(player)
	return true, "Upgraded"
end

function EconomyService.addFlux(player, amount)
	local data = DataService.getData(player)
	if not data or amount <= 0 then
		return false
	end
	data.flux = data.flux + amount
	DataService.touch(player)
	return true
end

--- Accrue passive income for every loaded profile. Called once per second.
function EconomyService.accrue(seconds)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.getData(player)
		if data then
			local income = EconomyService.incomeOf(data)
			if income > 0 then
				data.flux = data.flux + income * seconds
				DataService.touch(player)
			end
		end
	end
end

function EconomyService.init()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local delta = math.min(now - last, 5)
			last = now
			EconomyService.accrue(delta)
		end
	end)
end

return EconomyService
