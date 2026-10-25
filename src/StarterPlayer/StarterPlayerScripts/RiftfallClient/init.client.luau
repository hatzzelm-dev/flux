--!nolint
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")

print("[Riftfall] client boot script running")

local player = Players.LocalPlayer
local state = nil

-- Boot status. Sits above everything and only exists until the server answers,
-- so a stuck boot or a client error is readable in game.
local playerGui = player:WaitForChild("PlayerGui")
local statusGui = Instance.new("ScreenGui")
statusGui.Name = "RiftfallStatus"
statusGui.ResetOnSpawn = false
statusGui.IgnoreGuiInset = true
statusGui.DisplayOrder = 5000
statusGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.new(0.5, 0, 0, 10)
statusLabel.Size = UDim2.fromOffset(900, 26)
statusLabel.BackgroundColor3 = Color3.fromRGB(6, 8, 16)
statusLabel.BackgroundTransparency = 0.25
statusLabel.BorderSizePixel = 0
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 16
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
statusLabel.Text = "RIFTFALL: connecting..."
statusLabel.Parent = statusGui

local statusFailed = false

local function setStatus(text, color)
	if not statusGui.Parent then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
end

local function clearStatus()
	if statusGui.Parent then
		statusGui:Destroy()
	end
end

LogService.MessageOut:Connect(function(message, messageType)
	if messageType == Enum.MessageType.MessageError and statusGui.Parent then
		statusFailed = true
		setStatus("RIFTFALL error: " .. string.sub(tostring(message), 1, 220), Color3.fromRGB(255, 120, 120))
	end
end)

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RiftData = require(Shared.RiftData)

local Hud = require(script.Hud)
local DexPanel = require(script.DexPanel)
local ShopPanel = require(script.ShopPanel)
local RevealController = require(script.RevealController)
local StormFX = require(script.StormFX)
local Fx = require(script.Fx)
local Audio = require(script.Audio)
local Onboarding = require(script.Onboarding)

local remotes = Remotes.client()

local hud
local dex
local shop
local reveal
local storm
local onboarding

local busy = false
local introShown = false

task.spawn(function()
	local waited = 0
	while not state and not statusFailed and statusGui.Parent do
		local boot = Shared:FindFirstChild("Boot")
		setStatus(string.format(
			"RIFTFALL: server %s | no state yet (%.0fs)",
			boot and tostring(boot.Value) or "script did not start",
			waited
		))
		waited = waited + 0.5
		task.wait(0.5)
	end
end)

--- Build one part of the client. A failure is reported and skipped instead of
--- taking the whole script (rolls, keys, state) down with it.
local function safe(name, fn)
	local ok, result = pcall(fn)
	if not ok then
		warn(string.format("[Riftfall] client part failed: %s: %s", name, tostring(result)))
		if statusGui.Parent then
			statusFailed = true
			setStatus(string.format("RIFTFALL %s failed: %s", name, tostring(result)), Color3.fromRGB(255, 120, 120))
		end
		return nil
	end
	return result
end

local function advanceTutorial(step)
	if onboarding then
		onboarding:advance(step)
	end
end

local function doRoll()
	if busy then
		return
	end
	if os.clock() < hud.cooldownEnd then
		return
	end
	busy = true
	hud:setBusy(true)
	local cooldown = (state and state.cooldown) or 1
	hud:setCooldown(cooldown, cooldown)
	Audio.play("roll")
	Audio.haptic(0.2)
	remotes.RequestRoll:FireServer()
	advanceTutorial(1)
	if not state then
		hud:toast("Waiting for the server...", Config.UI.AccentWarm)
	end
	task.delay(3, function()
		if busy then
			busy = false
			hud:setBusy(false)
		end
	end)
end

local function openDex()
	if shop then
		shop:close()
	end
	if dex then
		dex:open()
	end
end

local function openShop()
	if dex then
		dex:close()
	end
	if shop then
		shop:open()
	end
end

local function toggleAuto()
	if not state then
		hud:toast("Waiting for the server...", Config.UI.AccentWarm)
		return
	end
	if not state.autoAvailable then
		hud:toast("Auto-Tear is locked - unlock it in the RIFT LAB", Config.UI.AccentWarm)
		openShop()
		return
	end
	Audio.play("ui")
	remotes.SetAutoRoll:FireServer(not state.autoRoll)
end

local function toggleMute()
	Audio.play("ui")
	Audio.toggle()
end

hud = safe("Hud", function()
	return Hud.new(player, {
		onRoll = doRoll,
		onAuto = toggleAuto,
		onDex = openDex,
		onShop = openShop,
		onMute = toggleMute,
	})
end)

if not hud then
	setStatus("RIFTFALL: HUD failed to build - see Output", Color3.fromRGB(255, 120, 120))
	error("Riftfall: HUD could not be built")
end

hud:setMuted(Audio.isMuted())
Audio.onMuteChanged(function(muted)
	if hud then
		hud:setMuted(muted)
	end
end)

dex = safe("Riftodex", function()
	return DexPanel.new(hud)
end)

shop = safe("RiftLab", function()
	return ShopPanel.new(hud, {
		onUpgrade = function(key)
			Audio.play("buy")
			remotes.RequestUpgrade:FireServer(key)
			advanceTutorial(2)
		end,
		onProduct = function(key)
			Audio.play("ui")
			remotes.RequestProduct:FireServer(key)
		end,
	})
end)

reveal = safe("Reveal", function()
	return RevealController.new(hud)
end)

storm = safe("StormFX", function()
	return StormFX.new(hud)
end)

safe("Fx", function()
	Fx.init(hud)
end)

onboarding = safe("Onboarding", function()
	return Onboarding.new(hud, {
		onAdvance = function(step)
			remotes.Tutorial:FireServer(step)
		end,
	})
end)

local function applyState(payload)
	hud:set(payload)
	hud:setDexCount(payload.dex, payload.dexTotal)
	hud:setCooldown(payload.nextRollIn or 0, payload.cooldown or 1)
	if shop then
		shop:setState(payload)
	end
	if dex then
		dex:setBest(payload.best)
	end
	if payload.storm and storm then
		if payload.storm.active and not storm.active then
			storm:set(true, payload.storm.remaining or 0, payload.storm.luck or 1)
		elseif not payload.storm.active and storm.active then
			storm:set(false, 0, 1)
		end
	end
	if onboarding and Config.Onboarding and Config.Onboarding.Enabled then
		onboarding:setProgress(payload.tutorialStep or 0)
	end
	if not introShown then
		introShown = true
		hud:toast("Press R or TEAR A RIFT to open your first rift", Config.UI.Accent)
	end
end

remotes.State.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	state = payload
	clearStatus()
	local ok, err = pcall(applyState, payload)
	if not ok then
		warn("[Riftfall] state apply error: " .. tostring(err))
	end
end)

remotes.Collection.OnClientEvent:Connect(function(counts)
	if type(counts) == "table" and dex then
		dex:setCounts(counts)
	end
end)

remotes.Event.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind

	if kind == "roll" then
		busy = false
		hud:setBusy(false)
		if reveal then
			reveal:showRoll(payload)
		elseif payload.rift then
			-- Reveal module failed to build: still tell the player what dropped.
			hud:toast(string.format("%s  %s", string.upper(payload.rift.name), payload.oddsText or ""), Config.UI.Accent)
		end
	elseif kind == "broadcast" then
		if reveal and payload.playerName ~= player.Name then
			reveal:showBroadcast(payload)
		end
	elseif kind == "milestone" then
		if reveal then
			reveal:showMilestone(payload)
		end
	elseif kind == "storm" then
		if payload.phase == "warning" then
			hud:setStormWarning(payload.duration or Config.Storm.WarningLead)
			Audio.play("warn")
		elseif payload.phase == "start" then
			hud:setStorm(true, payload.duration or Config.Storm.Duration)
			if storm then
				storm:set(true, payload.duration or Config.Storm.Duration, payload.luck or Config.Storm.LuckMultiplier)
			end
		else
			hud:setStorm(false, 0)
			if storm then
				storm:set(false, 0, 1)
			end
		end
	elseif kind == "notice" then
		hud:toast(payload.text or "", Config.UI.Accent)
	elseif kind == "purchase" then
		Audio.play("buy")
		hud:toast(payload.text or "Purchase complete", Config.UI.Good)
	end
end)

-- Ask for state directly in case the join push landed before the handler above
-- existed. Retries stop as soon as anything arrives.
task.spawn(function()
	for _ = 1, 10 do
		if state then
			return
		end
		remotes.RequestState:FireServer()
		task.wait(1)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		doRoll()
	elseif input.KeyCode == Enum.KeyCode.E then
		openShop()
	elseif input.KeyCode == Enum.KeyCode.Q then
		openDex()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if dex then
			dex:close()
		end
		if shop then
			shop:close()
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if hud then
		hud:tick()
	end
end)

print(string.format("Riftfall client ready (%d rifts)", #RiftData.Rifts))
