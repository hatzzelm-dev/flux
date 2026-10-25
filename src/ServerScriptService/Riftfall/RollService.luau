--!nolint
-- All odds live on the server. The client asks to roll; it never sends luck,
-- cooldown, a rift id or a result. Every roll is rate limited twice: by the
-- authoritative cooldown and by a rolling window cap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local RiftData = require(Shared.RiftData)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local IndexService = require(script.Parent.IndexService)
local StormService = require(script.Parent.StormService)
local MonetizationService = require(script.Parent.MonetizationService)
local StateService = require(script.Parent.StateService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PlotService = require(script.Parent.PlotService)

local RollService = {}

local remotes = nil
local nextRollAt = {}
local windows = {}
local serverBest = { odds = 0, name = nil, rift = nil }

local function effectiveWeight(rift, luck, storm)
	local base = rift.weight
	if storm and rift.stormWeight > 0 then
		base = rift.stormWeight
	end
	if base <= 0 then
		return 0
	end
	local tier = math.min(rift.tier, Config.Roll.LuckTierCap)
	return base * (luck ^ (tier * Config.Roll.LuckTierExponent))
end

local function pickRift(luck, storm)
	local total = 0
	for _, rift in ipairs(RiftData.Rifts) do
		total = total + effectiveWeight(rift, luck, storm)
	end
	if total <= 0 then
		return RiftData.Rifts[1]
	end
	local roll = math.random() * total
	local accumulated = 0
	for _, rift in ipairs(RiftData.Rifts) do
		accumulated = accumulated + effectiveWeight(rift, luck, storm)
		if roll <= accumulated then
			return rift
		end
	end
	return RiftData.Rifts[#RiftData.Rifts]
end

local function rateLimited(player)
	local now = os.clock()
	local list = windows[player.UserId]
	if not list then
		list = {}
		windows[player.UserId] = list
	end
	local kept = {}
	for _, stamp in ipairs(list) do
		if now - stamp < Config.Roll.RateWindow then
			table.insert(kept, stamp)
		end
	end
	if #kept >= Config.Roll.MaxRollsPerWindow then
		windows[player.UserId] = kept
		return true
	end
	table.insert(kept, now)
	windows[player.UserId] = kept
	return false
end

function RollService.nextRollIn(player)
	local readyAt = nextRollAt[player.UserId]
	if not readyAt then
		return 0
	end
	return math.max(0, readyAt - os.clock())
end

function RollService.forget(player)
	nextRollAt[player.UserId] = nil
	windows[player.UserId] = nil
end

function RollService.roll(player, source)
	local data = DataService.getData(player)
	if not data then
		return nil, "loading"
	end
	local now = os.clock()
	local readyAt = nextRollAt[player.UserId] or 0
	if now < readyAt - Config.Roll.ServerCooldownSlack then
		return nil, "cooldown"
	end
	if rateLimited(player) then
		return nil, "rate"
	end

	local passes = MonetizationService.passes(player)
	local storm = StormService.isActive()
	local luck = EconomyService.baseLuck(data) * (storm and Config.Storm.LuckMultiplier or 1)
	local rift = pickRift(luck, storm)

	nextRollAt[player.UserId] = now + EconomyService.cooldownOf(data, passes)

	data.rolls = data.rolls + 1
	data.rifts[rift.id] = (data.rifts[rift.id] or 0) + 1
	local count = data.rifts[rift.id]
	local isNew = count == 1

	if rift.odds > (data.bestOdds or 0) then
		data.bestOdds = rift.odds
		data.bestId = rift.id
	end
	DataService.touch(player)

	local tier = RiftData.TierById[rift.tier]
	IndexService.check(player, data)

	local reveal = {
		kind = "roll",
		rift = {
			id = rift.id,
			name = rift.name,
			tier = rift.tier,
			odds = rift.odds,
			income = rift.income,
		},
		tier = tier,
		count = count,
		isNew = isNew,
		oddsText = Format.odds(rift.odds),
		rolls = data.rolls,
		source = source,
	}
	remotes.Event:FireClient(player, reveal)

	if rift.tier >= Config.Storm.BroadcastTier or rift.odds >= Config.Rewards.RareBroadcastOdds then
		remotes.Event:FireAllClients({
			kind = "broadcast",
			playerName = player.Name,
			rift = reveal.rift,
			tier = tier,
			oddsText = Format.odds(rift.odds),
		})
	end

	if rift.odds > serverBest.odds then
		serverBest = { odds = rift.odds, name = player.Name, rift = rift }
		PlotService.updateBoard(player.Name, rift)
	end

	PlotService.refresh(player)
	StateService.push(player, RollService.nextRollIn(player))
	StateService.pushCollection(player)

	if data.rolls == 1 then
		AnalyticsService.log(player, "first_roll", rift.tier)
	end
	if rift.tier >= 4 then
		AnalyticsService.log(player, "roll_rare", rift.tier)
	end

	return rift
end

function RollService.init(remoteMap)
	remotes = remoteMap

	remotes.RequestRoll.OnServerEvent:Connect(function(player)
		local rift, reason = RollService.roll(player, "manual")
		if not rift and reason == "loading" then
			-- The profile is still settling: answer instead of dropping the press.
			remotes.Event:FireClient(player, { kind = "notice", text = "Loading your profile..." })
		end
	end)

	remotes.SetAutoRoll.OnServerEvent:Connect(function(player, value)
		if type(value) ~= "boolean" then
			return
		end
		local data = DataService.getData(player)
		if not data then
			return
		end
		local passes = MonetizationService.passes(player)
		if value and not (data.autoRollUnlocked or passes.riftRunner) then
			remotes.Event:FireClient(player, { kind = "notice", text = "Auto-Tear is locked" })
			return
		end
		data.autoRoll = value
		DataService.touch(player)
		StateService.push(player, RollService.nextRollIn(player))
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.getData(player)
				if data and data.autoRoll then
					local passes = MonetizationService.passes(player)
					if data.autoRollUnlocked or passes.riftRunner then
						if (nextRollAt[player.UserId] or 0) <= os.clock() then
							RollService.roll(player, "auto")
						end
					end
				end
			end
		end
	end)
end

return RollService
