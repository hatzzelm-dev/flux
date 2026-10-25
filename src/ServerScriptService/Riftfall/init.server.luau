--!nolint
-- RIFTFALL server entry point. Boot order matters: data first, then everything
-- that reads it, then the world, then remote handlers.
--
-- The whole boot runs inside xpcall. If any step throws, the error text is
-- written to ReplicatedStorage.Riftfall.Boot, which the client shows on screen,
-- so a broken server reports itself instead of going quiet.

print("[Riftfall] server boot script running")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")

local boot = Shared:FindFirstChild("Boot")
if not boot then
	boot = Instance.new("StringValue")
	boot.Name = "Boot"
	boot.Parent = Shared
end

local function phase(text)
	boot.Value = text
	print("[Riftfall] boot: " .. text)
end

local function start()
	phase("2 requires")
	local Config = require(Shared.Config)
	local RiftData = require(Shared.RiftData)
	local Remotes = require(Shared.Remotes)
	local remotes = Remotes.server()

	local DataService = require(script.DataService)
	local EconomyService = require(script.EconomyService)
	local AnalyticsService = require(script.AnalyticsService)
	local MonetizationService = require(script.MonetizationService)
	local StormService = require(script.StormService)
	local IndexService = require(script.IndexService)
	local StateService = require(script.StateService)
	local PlotService = require(script.PlotService)
	local RollService = require(script.RollService)
	local WorldBuilder = require(ServerStorage:WaitForChild("World"):WaitForChild("WorldBuilder"))

	phase("3 world")
	local layout = WorldBuilder.build()

	phase("4 services")
	DataService.init()
	EconomyService.init()
	AnalyticsService.init()
	MonetizationService.init(remotes)
	StormService.init(remotes)
	IndexService.init(remotes)
	StateService.init(remotes)
	PlotService.init(layout)
	RollService.init(remotes)
	StateService.start({ nextRollIn = RollService.nextRollIn })

	Players.RespawnTime = 2
	Players.CharacterAutoLoads = true

	local function sendNotice(player, text)
		remotes.Event:FireClient(player, { kind = "notice", text = text })
	end

	remotes.RequestState.OnServerEvent:Connect(function(player)
		StateService.push(player, RollService.nextRollIn(player))
		StateService.pushCollection(player)
	end)

	-- Onboarding progress only ever moves forward; the server clamps it so a
	-- client cannot rewind or skip past the last step.
	remotes.Tutorial.OnServerEvent:Connect(function(player, step)
		if type(step) ~= "number" then
			return
		end
		local data = DataService.getData(player)
		if not data then
			return
		end
		local nextStep = math.clamp(math.floor(step), 0, 3)
		if nextStep > (data.tutorialStep or 0) then
			data.tutorialStep = nextStep
			DataService.touch(player)
			StateService.push(player, RollService.nextRollIn(player))
		end
	end)

	local function onPlayerAdded(player)
		local entry = DataService.load(player)
		if not player.Parent then
			DataService.release(player)
			return
		end

		local plot = PlotService.assign(player)
		if not plot then
			sendNotice(player, "All plots are taken - your rifts still save and count")
		end
		MonetizationService.refresh(player)

		if not player.Parent then
			PlotService.release(player)
			DataService.release(player)
			return
		end

		StateService.pushCollection(player)
		StateService.push(player, RollService.nextRollIn(player))
		AnalyticsService.log(player, "session_start", 1)

		if entry.error == "no-api" then
			sendNotice(player, "DataStores are off: progress will not save this session")
		elseif entry.error == "timeout" then
			sendNotice(player, "Data store did not answer: progress will not save this session")
		elseif entry.error == "locked" then
			sendNotice(player, "Profile is open in another session: progress will not save")
		elseif entry.canSave == false then
			sendNotice(player, "Could not reach DataStores: publish the place and enable Studio API access to save")
		end
	end

	local function onCharacterAdded(player, character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end

		-- Fall guard. A character can spawn in the same frame the placeholder
		-- floor is replaced, or walk off the generated world later. Without this
		-- the player drops forever through empty space.
		task.spawn(function()
			while character.Parent and root.Parent do
				if root.Position.Y < -40 then
					root.CFrame = layout.spawnCFrame + Vector3.new(0, 4, 0)
					root.AssemblyLinearVelocity = Vector3.zero
				end
				task.wait(0.5)
			end
		end)

		MonetizationService.applyCosmetics(player)
	end

	local function handlePlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				onCharacterAdded(player, character)
			end)
		end)
		task.spawn(function()
			onPlayerAdded(player)
		end)
	end

	Players.PlayerAdded:Connect(handlePlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		handlePlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player, true)
		DataService.release(player)
		PlotService.release(player)
		MonetizationService.forget(player)
		RollService.forget(player)
		AnalyticsService.forget(player)
	end)

	remotes.RequestUpgrade.OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" or #key > 16 then
			return
		end
		if key ~= "luck" and key ~= "speed" and key ~= "auto" then
			return
		end
		local ok, message = EconomyService.upgrade(player, key)
		if not ok then
			sendNotice(player, message)
			return
		end
		AnalyticsService.log(player, "upgrade", 1)
		StateService.push(player, RollService.nextRollIn(player))
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.save(player, true)
		end
		task.wait(1)
	end)

	phase("ready")
	print(string.format("Riftfall ready: %d rifts, %d tiers", #RiftData.Rifts, #RiftData.Tiers))
	print(string.format("Riftfall config: %d plots, storm every %ds-%ds", Config.Plot.Count, Config.Storm.MinInterval, Config.Storm.MaxInterval))
end

phase("1 start")
local ok, err = xpcall(start, function(message)
	return tostring(message) .. "\n" .. debug.traceback("", 2)
end)

if not ok then
	boot.Value = "ERROR: " .. string.sub(tostring(err), 1, 300)
	warn("[Riftfall] server boot failed: " .. tostring(err))
end
