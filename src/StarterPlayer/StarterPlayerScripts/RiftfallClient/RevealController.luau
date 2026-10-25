--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local UIBuilder = require(script.Parent.UIBuilder)
local Fx = require(script.Parent.Fx)
local Audio = require(script.Parent.Audio)

local RevealController = {}
RevealController.__index = RevealController

local COLORS = Config.UI

local function tierDuration(tier)
	local level = tier or 1
	if level >= 8 then
		return 3.2
	elseif level >= 6 then
		return 2.4
	elseif level >= 4 then
		return 1.7
	end
	return 1.15
end

function RevealController.new(hud)
	local self = setmetatable({}, RevealController)
	self.hud = hud
	self.queue = {}
	self.busy = false
	self.bannerToken = 0

	local card = Instance.new("CanvasGroup")
	card.Name = "RevealCard"
	card.Size = UDim2.fromOffset(760, 300)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.BackgroundColor3 = COLORS.Panel
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.Visible = false
	card.ZIndex = 30
	-- Reveals live on the same overlay layer as the panels, so the card is never
	-- clipped by the SHOP/DEX buttons on a small screen.
	card.Parent = hud.panelLayer
	UIBuilder.corner(card, 18)
	self.card = card
	self.stroke = UIBuilder.stroke(card, COLORS.Accent, 2, 0.1)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(30, 44, 76), Color3.fromRGB(10, 12, 22))
	gradient.Parent = card
	self.gradient = gradient

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = card
	self.scale = scale

	-- Charge phase: a ring collapses into the card while the roll is decided.
	local chargeRing = UIBuilder.frame({
		Parent = hud.panelLayer,
		Name = "ChargeRing",
		Size = UDim2.fromOffset(280, 280),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 29,
	})
	UIBuilder.corner(chargeRing, 999)
	self.chargeRingStroke = UIBuilder.stroke(chargeRing, COLORS.Accent, 3, 0.15)
	self.chargeRing = chargeRing

	self.chargeCore = UIBuilder.frame({
		Parent = chargeRing,
		Name = "Core",
		Size = UDim2.fromScale(0.34, 0.34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COLORS.Accent,
		BackgroundTransparency = 0.35,
		ZIndex = 30,
	})
	UIBuilder.corner(self.chargeCore, 999)

	self.tierLabel = UIBuilder.label({
		Parent = card,
		Text = "RIFT",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Accent,
		ZIndex = 31,
	})
	self.nameLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 46),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 44,
		TextColor3 = COLORS.Text,
		ZIndex = 31,
	})
	self.oddsLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 112),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.Text,
		ZIndex = 31,
	})
	self.detailLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 144),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		ZIndex = 31,
	})
	self.newBadge = UIBuilder.label({
		Parent = card,
		Text = "NEW",
		Size = UDim2.fromOffset(72, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 186),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(12, 14, 24),
		BackgroundColor3 = COLORS.Accent,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 31,
	})
	UIBuilder.corner(self.newBadge, 8)
	self.countLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 234),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = COLORS.Muted,
		ZIndex = 31,
	})

	-- Broadcast banner (top right). Stays in Root so the mute button keeps drawing
	-- over it; only the reveal card and charge ring move to the panel layer.
	local banner = UIBuilder.frame({
		Parent = hud.root,
		Name = "Broadcast",
		Size = UDim2.fromOffset(430, 86),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 450, 0, 86),
		BackgroundColor3 = Color3.fromRGB(15, 19, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 32,
	})
	UIBuilder.corner(banner, 12)
	self.bannerStroke = UIBuilder.stroke(banner, COLORS.Accent, 2, 0.1)
	self.banner = banner
	self.bannerTitle = UIBuilder.label({
		Parent = banner,
		Text = "",
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(14, 10),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = COLORS.Muted,
		ZIndex = 33,
	})
	self.bannerName = UIBuilder.label({
		Parent = banner,
		Text = "",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(14, 27),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = COLORS.Text,
		ZIndex = 33,
	})
	self.bannerSub = UIBuilder.label({
		Parent = banner,
		Text = "",
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(14, 59),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = COLORS.Muted,
		ZIndex = 33,
	})

	return self
end

function RevealController:apply(payload)
	local tier = payload.tier or {}
	local color = tier.color or COLORS.Accent
	local rift = payload.rift or {}

	self.tierLabel.Text = string.upper(tier.name or "RIFT")
	self.tierLabel.TextColor3 = color
	self.nameLabel.Text = string.upper(rift.name or "UNKNOWN")
	self.nameLabel.TextColor3 = color
	self.oddsLabel.Text = payload.oddsText or Format.odds(rift.odds or 1)
	self.detailLabel.Text = string.format(
		"+%s Flux/s per copy  |  you own x%s",
		Format.compact(rift.income or 0),
		Format.compact(payload.count or 1)
	)
	self.countLabel.Text = string.format("ROLL #%s", Format.compact(payload.rolls or 0))
	self.stroke.Color = color
	self.newBadge.Visible = payload.isNew == true
	self.newBadge.BackgroundColor3 = color
	self.gradient.Color = ColorSequence.new(
		color:Lerp(Color3.fromRGB(10, 12, 22), 0.78),
		Color3.fromRGB(10, 12, 22)
	)
end

function RevealController:play(payload)
	self.busy = true
	self:apply(payload)
	local tier = payload.rift and payload.rift.tier or 1
	local color = (payload.tier and payload.tier.color) or COLORS.Accent

	-- Rarer tears charge longer: 0.6s at tier 1 up to 0.9s at tier 8.
	local charge = math.clamp(0.54 + math.min(tier, 8) * 0.05, 0.6, 0.9)

	self.card.Visible = true
	self.card.GroupTransparency = 1
	self.scale.Scale = 0.9

	self.chargeRing.Visible = true
	self.chargeRing.Size = UDim2.fromOffset(280, 280)
	self.chargeRingStroke.Color = color
	self.chargeRingStroke.Transparency = 0.12
	self.chargeCore.BackgroundColor3 = color
	self.chargeCore.BackgroundTransparency = 0.4
	UIBuilder.tween(
		self.chargeRing,
		charge,
		{ Size = UDim2.fromOffset(96, 96) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	UIBuilder.tween(self.chargeCore, charge, { BackgroundTransparency = 0.05 })
	Fx.shake(0.03 + tier * 0.004, charge * 0.7)

	local chargeSound = Audio.play("charge")
	Audio.haptic(0.12 + tier * 0.02)

	task.delay(charge, function()
		if not self.card.Visible then
			return
		end
		Audio.stop(chargeSound)
		self.chargeRing.Visible = false

		Audio.play("reveal")
		Audio.haptic(0.25 + tier * 0.03)
		self.scale.Scale = 0.72
		TweenService:Create(self.card, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()
		TweenService:Create(
			self.scale,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()

		-- Flash, shake and sting are one moment, so they share one threshold.
		if tier >= Config.Audio.StingTier then
			Fx.flash(color, math.clamp(0.62 - tier * 0.04, 0.2, 0.55))
			Fx.shake(0.16 + tier * 0.07, 0.18 + tier * 0.03)
			Audio.play("rare")
		end
		if tier >= 5 then
			Fx.punch(3 + tier, 0.1)
		end

		local duration = tierDuration(tier)
		task.delay(duration, function()
			TweenService:Create(self.card, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
			task.delay(0.3, function()
				self.card.Visible = false
				self.busy = false
				local nextPayload = table.remove(self.queue, 1)
				if nextPayload then
					self:play(nextPayload)
				end
			end)
		end)
	end)
end

function RevealController:showRoll(payload)
	if not payload or not payload.rift then
		return
	end
	if self.busy then
		if #self.queue < 8 then
			table.insert(self.queue, payload)
		end
		return
	end
	self:play(payload)
end

function RevealController:showBanner(title, name, subtitle, color)
	self.bannerToken = self.bannerToken + 1
	local token = self.bannerToken

	self.banner.Visible = true
	self.bannerTitle.Text = title
	self.bannerName.Text = name
	self.bannerName.TextColor3 = color or COLORS.Text
	self.bannerSub.Text = subtitle
	self.bannerStroke.Color = color or COLORS.Accent
	self.banner.Position = UDim2.new(1, 450, 0, 86)
	TweenService:Create(
		self.banner,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -24, 0, 86) }
	):Play()

	task.delay(4.6, function()
		if self.bannerToken ~= token then
			return
		end
		TweenService:Create(
			self.banner,
			TweenInfo.new(0.25),
			{ Position = UDim2.new(1, 450, 0, 86) }
		):Play()
		task.delay(0.3, function()
			if self.bannerToken == token then
				self.banner.Visible = false
			end
		end)
	end)
end

function RevealController:showBroadcast(payload)
	if not payload or not payload.rift then
		return
	end
	local color = (payload.tier and payload.tier.color) or COLORS.Accent
	self:showBanner(
		"SERVER ANNOUNCEMENT",
		string.upper(payload.rift.name),
		string.format("%s  |  %s", payload.playerName or "someone", payload.oddsText or ""),
		color
	)
	Audio.play("rare", { volume = 0.5 })
end

function RevealController:showMilestone(payload)
	self:showBanner(
		string.format("RIFTODEX MILESTONE %d", payload.tier or 1),
		"+" .. Format.compact(payload.flux or 0) .. " FLUX",
		string.format("%d unique rifts  |  +%d%% luck", payload.unique or 0, math.floor((payload.luckBonus or 0) * 100)),
		COLORS.AccentWarm
	)
	Fx.flash(COLORS.AccentWarm, 0.75)
	Audio.play("milestone")
end

return RevealController
