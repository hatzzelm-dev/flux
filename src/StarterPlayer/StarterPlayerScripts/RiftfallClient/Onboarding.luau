--!nolint
-- Three-step first-run guide: roll, upgrade, then the Riftodex and storms.
--
-- The overlay is a non-interactive dim layer (Active = false), so the real HUD
-- buttons underneath stay tappable and the guide can never trap a player. The
-- progress number is persisted on the server profile, so a player who leaves
-- mid-tutorial resumes at the same step.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local UIBuilder = require(script.Parent.UIBuilder)
local Audio = require(script.Parent.Audio)

local Onboarding = {}
Onboarding.__index = Onboarding

local COLORS = Config.UI
local TOTAL = 3

local STEPS = {
	{
		target = "rollButton",
		title = "1 / 3   TEAR A RIFT",
		body = "Press the big button (or R) to rip open your first rift.",
	},
	{
		target = "shopButton",
		title = "2 / 3   RIFT LAB",
		body = "Spend Flux on Resonance. Luck pulls rarer rifts out of the void.",
	},
	{
		target = "dexButton",
		title = "3 / 3   RIFTODEX",
		body = "Every rift you find is logged here. A RIFT STORM rolls in every few minutes.",
	},
}

function Onboarding.new(hud, callbacks)
	local self = setmetatable({}, Onboarding)
	self.hud = hud
	self.callbacks = callbacks or {}
	self.progress = 0
	self.initialized = false
	self.visible = false

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "RiftfallOnboarding"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 400
	gui.Parent = playerGui
	self.gui = gui

	local dim = UIBuilder.frame({
		Parent = gui,
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 6, 12),
		BackgroundTransparency = 0.55,
		Active = false,
		Visible = false,
		ZIndex = 1,
	})
	self.dim = dim

	local highlight = UIBuilder.frame({
		Parent = gui,
		Name = "Highlight",
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		ZIndex = 3,
	})
	UIBuilder.corner(highlight, 16)
	self.highlightStroke = UIBuilder.stroke(highlight, COLORS.Accent, 3, 0.05)
	self.highlight = highlight

	local arrow = UIBuilder.label({
		Parent = gui,
		Name = "Arrow",
		Text = "▼",
		Size = UDim2.fromOffset(44, 44),
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = COLORS.Accent,
		Visible = false,
		ZIndex = 5,
	})
	self.arrow = arrow

	local card = UIBuilder.frame({
		Parent = gui,
		Name = "Card",
		Size = UDim2.fromOffset(470, 136),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 96),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 6,
	})
	UIBuilder.corner(card, 14)
	UIBuilder.stroke(card, Color3.fromRGB(70, 96, 150), 2, 0.2)
	self.card = card

	self.titleLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, -118, 0, 20),
		Position = UDim2.fromOffset(14, 12),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Accent,
		ZIndex = 7,
	})

	self.bodyLabel = UIBuilder.label({
		Parent = card,
		Text = "",
		Size = UDim2.new(1, -118, 0, 60),
		Position = UDim2.fromOffset(14, 34),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.Text,
		ZIndex = 7,
	})

	local ok = UIBuilder.button({
		Parent = card,
		Text = "OK",
		Size = UDim2.fromOffset(88, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 72),
		BackgroundColor3 = Color3.fromRGB(44, 74, 130),
		TextSize = 16,
		ZIndex = 7,
	})
	UIBuilder.corner(ok, 12)
	self.okButton = ok

	local skip = UIBuilder.button({
		Parent = card,
		Text = "SKIP",
		Size = UDim2.fromOffset(76, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		BackgroundColor3 = Color3.fromRGB(26, 32, 54),
		TextSize = 12,
		TextColor3 = COLORS.Muted,
		ZIndex = 8,
	})
	UIBuilder.corner(skip, 8)
	self.skipButton = skip

	ok.MouseButton1Click:Connect(function()
		Audio.play("ui")
		self:advance(self.progress + 1)
	end)
	skip.MouseButton1Click:Connect(function()
		Audio.play("ui")
		self:advance(TOTAL)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			self:advance(TOTAL)
		end
	end)

	local pulse = 1
	task.spawn(function()
		while gui.Parent do
			task.wait(0.45)
			if self.visible then
				pulse = pulse == 1 and 0.45 or 1
				UIBuilder.tween(self.arrow, 0.35, { TextTransparency = pulse })
				UIBuilder.tween(self.highlightStroke, 0.35, { Transparency = pulse })
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if self.visible then
			self:place()
		end
	end)

	return self
end

function Onboarding:place()
	local spec = STEPS[self.progress + 1]
	local target = spec and self.hud[spec.target]
	if not target or not target.Parent then
		return
	end
	local position = target.AbsolutePosition
	local size = target.AbsoluteSize
	self.highlight.Position = UDim2.fromOffset(position.X - 6, position.Y - 6)
	self.highlight.Size = UDim2.fromOffset(size.X + 12, size.Y + 12)
	self.arrow.Position = UDim2.fromOffset(
		position.X + size.X * 0.5 - self.arrow.AbsoluteSize.X * 0.5,
		position.Y - self.arrow.AbsoluteSize.Y - 10
	)
end

function Onboarding:render()
	local spec = STEPS[self.progress + 1]
	if not spec then
		self:hide()
		return
	end
	local inset = game:GetService("GuiService"):GetGuiInset()
	self.card.Position = UDim2.new(0, 16, 0, inset.Y + 8)
	self.titleLabel.Text = spec.title
	self.bodyLabel.Text = spec.body
	self.card.Visible = true
	self.dim.Visible = true
	self.arrow.Visible = true
	self.highlight.Visible = true
	self.visible = true
	self:place()
end

function Onboarding:hide()
	self.card.Visible = false
	self.dim.Visible = false
	self.arrow.Visible = false
	self.highlight.Visible = false
	self.visible = false
end

--- Apply server-persisted progress. The first call decides where to resume;
--- later pushes only move forward, because a local advance can reach the server
--- a beat after the state packet that still carries the old value.
function Onboarding:setProgress(value)
	local nextProgress = math.clamp(math.floor(tonumber(value) or 0), 0, TOTAL)
	if not self.initialized then
		self.initialized = true
		self.progress = nextProgress
		if nextProgress >= TOTAL then
			self:hide()
		else
			self:render()
		end
		return
	end
	if nextProgress <= self.progress then
		return
	end
	self.progress = nextProgress
	if nextProgress >= TOTAL then
		self:hide()
	else
		self:render()
	end
end

function Onboarding:advance(value)
	local nextProgress = math.clamp(math.floor(tonumber(value) or 0), 0, TOTAL)
	if nextProgress <= self.progress then
		return
	end
	self.progress = nextProgress
	if nextProgress >= TOTAL then
		self:hide()
	else
		self:render()
	end
	if self.callbacks.onAdvance then
		task.spawn(self.callbacks.onAdvance, nextProgress)
	end
end

function Onboarding:destroy()
	if self.gui.Parent then
		self.gui:Destroy()
	end
	self.visible = false
end

return Onboarding
