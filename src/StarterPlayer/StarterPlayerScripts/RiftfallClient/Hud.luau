--!nolint
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local RiftData = require(Shared.RiftData)
local UIBuilder = require(script.Parent.UIBuilder)

local Hud = {}
Hud.__index = Hud

local BASE_WIDTH = 1000
local BASE_HEIGHT = 620

local COLORS = Config.UI
local STORM_PANEL = Color3.fromRGB(26, 74, 84)
local STORM_BORDER = Color3.fromRGB(120, 255, 235)
local WARNING_PANEL = Color3.fromRGB(64, 44, 16)
local WARNING_BORDER = Color3.fromRGB(255, 196, 96)

function Hud.new(player, callbacks)
	local self = setmetatable({}, Hud)
	self.callbacks = callbacks or {}
	self.cooldownEnd = 0
	self.cooldownDuration = 1
	self.busy = false
	self.warningUntil = nil
	self.toastToken = 0
	self.muted = false

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "RiftfallHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = playerGui
	self.gui = gui

	-- Scaled information layer. Text and cards shrink with the viewport.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = gui
	self.root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local function refreshScale()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local factor = math.min(viewport.X / BASE_WIDTH, viewport.Y / BASE_HEIGHT)
		scale.Scale = math.clamp(factor, 0.5, 1.35)
	end
	refreshScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
	end

	local brand = UIBuilder.label({
		Parent = root,
		Name = "Brand",
		Text = "RIFTFALL",
		Size = UDim2.fromOffset(300, 36),
		Position = UDim2.fromOffset(24, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = COLORS.Text,
	})
	UIBuilder.gradient(brand, Color3.fromRGB(168, 226, 255), Color3.fromRGB(255, 206, 140), 0)

	local tagline = UIBuilder.label({
		Parent = root,
		Name = "Tagline",
		Text = "TEAR REALITY",
		Size = UDim2.fromOffset(300, 16),
		Position = UDim2.fromOffset(26, 48),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = COLORS.Muted,
	})

	local fluxCard = UIBuilder.frame({
		Parent = root,
		Name = "FluxCard",
		Size = UDim2.fromOffset(264, 84),
		Position = UDim2.fromOffset(24, 80),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
	})
	UIBuilder.corner(fluxCard, 12)
	UIBuilder.stroke(fluxCard, Color3.fromRGB(46, 60, 100), 1, 0.25)

	UIBuilder.label({
		Parent = fluxCard,
		Text = "FLUX",
		Size = UDim2.fromOffset(120, 16),
		Position = UDim2.fromOffset(16, 10),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = COLORS.Muted,
	})
	self.fluxLabel = UIBuilder.label({
		Parent = fluxCard,
		Text = "0",
		Size = UDim2.fromOffset(200, 34),
		Position = UDim2.fromOffset(16, 24),
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = COLORS.Accent,
	})
	self.incomeLabel = UIBuilder.label({
		Parent = fluxCard,
		Text = "+0/s",
		Size = UDim2.fromOffset(120, 16),
		Position = UDim2.fromOffset(16, 58),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = COLORS.Muted,
	})

	local luckCard = UIBuilder.frame({
		Parent = root,
		Name = "LuckCard",
		Size = UDim2.fromOffset(264, 40),
		Position = UDim2.fromOffset(24, 176),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
	})
	UIBuilder.corner(luckCard, 10)
	UIBuilder.label({
		Parent = luckCard,
		Text = "LUCK",
		Size = UDim2.fromOffset(80, 16),
		Position = UDim2.fromOffset(14, 12),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = COLORS.Muted,
	})
	self.luckLabel = UIBuilder.label({
		Parent = luckCard,
		Text = "x1.00",
		Size = UDim2.fromOffset(110, 20),
		Position = UDim2.fromOffset(58, 10),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLORS.Text,
	})
	self.rollsLabel = UIBuilder.label({
		Parent = luckCard,
		Text = "0 rolls",
		Size = UDim2.fromOffset(110, 16),
		Position = UDim2.fromOffset(140, 12),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = COLORS.Muted,
	})

	local hint
	if not UserInputService.TouchEnabled then
		hint = UIBuilder.label({
			Parent = root,
			Text = "R tear  |  Q Riftodex  |  E Rift Lab",
			Size = UDim2.fromOffset(520, 16),
			Position = UDim2.fromOffset(24, 224),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = COLORS.Muted,
		})
	end

	-- Fixed-size control layer. Buttons are measured in real pixels instead of
	-- being scaled with the cards, so a touch target never drops below ~60px on
	-- a small phone. Safe inset keeps the top row clear of the Roblox topbar.
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.Size = UDim2.fromScale(1, 1)
	controls.BackgroundTransparency = 1
	controls.BorderSizePixel = 0
	controls.Parent = gui

	local inset = GuiService:GetGuiInset()
	local topOffset = inset.Y + 8

	-- Right-anchored so the banner can never sit on the Flux/Luck cards in the
	-- top-left column, and stops 88px short of the mute button.
	local stormBanner = UIBuilder.frame({
		Parent = controls,
		Name = "StormBanner",
		Size = UDim2.new(0.5, 0, 0, 46),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -88, 0, topOffset),
		BackgroundColor3 = STORM_PANEL,
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 12,
	})
	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MaxSize = Vector2.new(470, 46)
	bannerLimit.Parent = stormBanner
	UIBuilder.corner(stormBanner, 12)
	self.stormStroke = UIBuilder.stroke(stormBanner, STORM_BORDER, 2, 0.2)
	self.stormBanner = stormBanner
	self.stormLabel = UIBuilder.label({
		Parent = stormBanner,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(150, 255, 244),
		ZIndex = 13,
	})

	local muteButton = UIBuilder.button({
		Parent = controls,
		Name = "MuteButton",
		Text = "SFX\nON",
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, topOffset),
		BackgroundColor3 = Color3.fromRGB(22, 28, 48),
		BackgroundTransparency = 0.15,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = COLORS.Muted,
		ZIndex = 14,
	})
	UIBuilder.corner(muteButton, 12)
	UIBuilder.stroke(muteButton, Color3.fromRGB(64, 82, 130), 1, 0.3)
	self.muteButton = muteButton
	muteButton.MouseButton1Click:Connect(function()
		if self.callbacks.onMute then
			self.callbacks.onMute()
		end
	end)

	local rollButton = Instance.new("TextButton")
	rollButton.Name = "RollButton"
	rollButton.AnchorPoint = Vector2.new(0.5, 1)
	rollButton.Position = UDim2.new(0.5, 0, 1, -20)
	rollButton.Size = UDim2.fromOffset(300, 92)
	rollButton.BackgroundColor3 = Color3.fromRGB(46, 72, 128)
	rollButton.Text = ""
	rollButton.AutoButtonColor = true
	rollButton.ClipsDescendants = true
	rollButton.BorderSizePixel = 0
	rollButton.ZIndex = 10
	rollButton.Parent = controls
	UIBuilder.corner(rollButton, 20)
	UIBuilder.stroke(rollButton, Color3.fromRGB(150, 220, 255), 2, 0.15)
	UIBuilder.gradient(rollButton, Color3.fromRGB(64, 112, 190), Color3.fromRGB(22, 30, 58), 90)
	self.rollButton = rollButton

	self.cooldownFill = UIBuilder.frame({
		Parent = rollButton,
		Name = "Cooldown",
		Size = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(12, 18, 36),
		BackgroundTransparency = 0.35,
		ZIndex = 1,
	})
	UIBuilder.corner(self.cooldownFill, 20)

	self.rollLabel = UIBuilder.label({
		Parent = rollButton,
		Text = "TEAR A RIFT",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = COLORS.Text,
		ZIndex = 2,
	})
	self.rollSub = UIBuilder.label({
		Parent = rollButton,
		Text = "READY",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(190, 214, 255),
		ZIndex = 2,
	})

	rollButton.MouseButton1Click:Connect(function()
		if self.callbacks.onRoll then
			self.callbacks.onRoll()
		end
	end)

	local autoButton = UIBuilder.button({
		Parent = controls,
		Name = "AutoButton",
		Text = "AUTO: OFF",
		Size = UDim2.fromOffset(120, 60),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -20),
		BackgroundColor3 = COLORS.PanelLight,
		TextSize = 13,
		ZIndex = 11,
	})
	UIBuilder.corner(autoButton, 12)
	UIBuilder.stroke(autoButton, Color3.fromRGB(64, 82, 130), 1, 0.2)
	self.autoButton = autoButton
	autoButton.MouseButton1Click:Connect(function()
		if self.callbacks.onAuto then
			self.callbacks.onAuto()
		end
	end)

	local dexButton = UIBuilder.button({
		Parent = controls,
		Name = "DexButton",
		Text = "DEX  0/25",
		Size = UDim2.fromOffset(120, 60),
		AnchorPoint = Vector2.new(1, 1),
		-- Kept 130px above the bottom edge: Roblox's touch jump button owns the
		-- bottom-right corner, and a 60px button on top of it cannot be pressed.
		Position = UDim2.new(1, -16, 1, -130),
		BackgroundColor3 = COLORS.PanelLight,
		TextSize = 13,
		ZIndex = 11,
	})
	UIBuilder.corner(dexButton, 12)
	UIBuilder.stroke(dexButton, Color3.fromRGB(64, 82, 130), 1, 0.2)
	self.dexButton = dexButton
	dexButton.MouseButton1Click:Connect(function()
		if self.callbacks.onDex then
			self.callbacks.onDex()
		end
	end)

	local shopButton = UIBuilder.button({
		Parent = controls,
		Name = "ShopButton",
		Text = "SHOP",
		Size = UDim2.fromOffset(120, 60),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -196),
		BackgroundColor3 = COLORS.PanelLight,
		TextSize = 13,
		ZIndex = 11,
	})
	UIBuilder.corner(shopButton, 12)
	UIBuilder.stroke(shopButton, Color3.fromRGB(64, 82, 130), 1, 0.2)
	self.shopButton = shopButton
	shopButton.MouseButton1Click:Connect(function()
		if self.callbacks.onShop then
			self.callbacks.onShop()
		end
	end)

	-- Overlay layer for panels and reveals. It mirrors Root's scaled geometry but
	-- is a later sibling of Controls, so an open panel draws over the buttons and
	-- the layer is the one place that owns "what covers the HUD".
	local panelLayer = Instance.new("Frame")
	panelLayer.Name = "PanelLayer"
	panelLayer.AnchorPoint = Vector2.new(0.5, 0.5)
	panelLayer.Position = UDim2.fromScale(0.5, 0.5)
	panelLayer.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	panelLayer.BackgroundTransparency = 1
	panelLayer.BorderSizePixel = 0
	panelLayer.Parent = gui
	self.panelLayer = panelLayer

	local panelScale = Instance.new("UIScale")
	panelScale.Scale = scale.Scale
	panelScale.Parent = panelLayer
	scale:GetPropertyChangedSignal("Scale"):Connect(function()
		panelScale.Scale = scale.Scale
	end)

	local toast = UIBuilder.frame({
		Parent = controls,
		Name = "Toast",
		Size = UDim2.new(1, -180, 0, 34),
		-- Left edge and bottom offset keep it clear of AUTO, TEAR and the raised
		-- DEX/SHOP stack on a 640x360 phone.
		Position = UDim2.new(0, 16, 1, -120),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(12, 16, 30),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	})
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(470, 34)
	toastLimit.Parent = toast
	UIBuilder.corner(toast, 10)
	UIBuilder.stroke(toast, Color3.fromRGB(70, 92, 140), 1, 0.4)
	self.toastFrame = toast
	self.toastLabel = UIBuilder.label({
		Parent = toast,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		TextTransparency = 1,
		ZIndex = 16,
	})

	-- 11px type below ~0.82 scale is ~9px or smaller: unreadable, so drop the two
	-- decorative lines instead of shipping mush.
	local function refreshDetail()
		local readable = scale.Scale >= 0.82
		tagline.Visible = readable
		if hint then
			hint.Visible = readable
		end
	end
	refreshDetail()
	scale:GetPropertyChangedSignal("Scale"):Connect(refreshDetail)

	return self
end

function Hud:set(state)
	if not state then
		return
	end
	self.fluxLabel.Text = Format.compact(state.flux)
	self.incomeLabel.Text = "+" .. Format.compact(state.income) .. "/s"
	self.luckLabel.Text = string.format("x%.2f", state.luck or 1)
	if state.storm and state.storm.active then
		self.luckLabel.TextColor3 = Color3.fromRGB(140, 255, 236)
	else
		self.luckLabel.TextColor3 = COLORS.Text
	end
	self.rollsLabel.Text = string.format("%s rolls", Format.compact(state.rolls or 0))
	self.autoButton.Text = state.autoRoll and "AUTO: ON" or "AUTO: OFF"
	self.autoButton.TextColor3 = state.autoRoll and Color3.fromRGB(140, 255, 190) or COLORS.Muted
	if state.autoAvailable == false then
		self.autoButton.Text = "AUTO: LOCKED"
		self.autoButton.TextColor3 = COLORS.Muted
	end
	if state.storm then
		self:setStorm(state.storm.active == true, state.storm.remaining or 0)
	end
end

function Hud:setMuted(muted)
	self.muted = muted == true
	self.muteButton.Text = self.muted and "SFX\nOFF" or "SFX\nON"
	self.muteButton.TextColor3 = self.muted and Color3.fromRGB(255, 150, 150) or COLORS.Muted
	self.muteButton.BackgroundColor3 = self.muted and Color3.fromRGB(44, 22, 30) or Color3.fromRGB(22, 28, 48)
end

function Hud:setStorm(active, remaining)
	-- A live warning owns the banner until the storm actually starts, otherwise
	-- the 0.5s state push would wipe the countdown.
	if not active and self.warningUntil and self.warningUntil > os.clock() then
		return
	end
	self.warningUntil = nil
	self.stormBanner.Visible = active
	self.stormBanner.BackgroundColor3 = STORM_PANEL
	self.stormStroke.Color = STORM_BORDER
	self.stormLabel.TextColor3 = Color3.fromRGB(150, 255, 244)
	if active then
		self.stormLabel.Text = string.format(
			"RIFT STORM  |  LUCK x%.1f  |  %s",
			Config.Storm.LuckMultiplier,
			Format.clock(remaining)
		)
	end
end

function Hud:setStormWarning(seconds)
	local lead = math.max(0, tonumber(seconds) or 0)
	self.warningUntil = os.clock() + lead
	self.stormBanner.Visible = true
	self.stormBanner.BackgroundColor3 = WARNING_PANEL
	self.stormStroke.Color = WARNING_BORDER
	self.stormLabel.TextColor3 = Color3.fromRGB(255, 212, 130)
	self.stormLabel.Text = string.format("RIFT STORM IN %d", math.ceil(lead))
end

function Hud:setBusy(busy)
	self.busy = busy
	self.rollLabel.Text = busy and "TEARING..." or "TEAR A RIFT"
end

function Hud:setDexCount(found, total)
	self.dexButton.Text = string.format("DEX  %d/%d", found or 0, total or #RiftData.Rifts)
end

function Hud:toast(text, color)
	self.toastToken = self.toastToken + 1
	local token = self.toastToken
	self.toastFrame.Visible = true
	self.toastFrame.BackgroundTransparency = 0.1
	self.toastLabel.TextTransparency = 0
	self.toastLabel.Text = text
	self.toastLabel.TextColor3 = color or COLORS.Text
	task.delay(2.8, function()
		if self.toastToken ~= token then
			return
		end
		UIBuilder.tween(self.toastFrame, 0.45, { BackgroundTransparency = 1 })
		UIBuilder.tween(self.toastLabel, 0.45, { TextTransparency = 1 })
		task.delay(0.5, function()
			if self.toastToken == token then
				self.toastFrame.Visible = false
			end
		end)
	end)
end

function Hud:tick()
	local remaining = math.max(0, self.cooldownEnd - os.clock())
	local total = math.max(0.01, self.cooldownDuration or 1)
	local fraction = math.clamp(remaining / total, 0, 1)
	self.cooldownFill.Size = UDim2.fromScale(fraction, 1)
	if remaining > 0.05 then
		self.rollSub.Text = string.format("%.1fs", remaining)
		self.rollButton.BackgroundTransparency = 0.25
	else
		self.rollSub.Text = self.busy and "TEARING" or "READY"
		self.rollButton.BackgroundTransparency = 0
	end

	if self.warningUntil then
		local left = self.warningUntil - os.clock()
		if left > 0 then
			self.stormLabel.Text = string.format("RIFT STORM IN %d", math.ceil(left))
		else
			self.warningUntil = nil
		end
	end
end

function Hud:setCooldown(remaining, duration)
	self.cooldownEnd = os.clock() + math.max(0, remaining or 0)
	self.cooldownDuration = math.max(0.05, duration or 1)
end

return Hud
