--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local RiftData = require(Shared.RiftData)
local UIBuilder = require(script.Parent.UIBuilder)
local Audio = require(script.Parent.Audio)

local DexPanel = {}
DexPanel.__index = DexPanel

local COLORS = Config.UI

function DexPanel.new(hud)
	local self = setmetatable({}, DexPanel)
	self.hud = hud
	self.cells = {}
	-- isOpen, not open: `open` is the method name below and a boolean field would
	-- shadow it, making self:open() fail with "attempt to call a boolean value".
	self.isOpen = false

	-- Parented to the HUD panel layer (above the control buttons) and Active, so
	-- an open panel both draws over the buttons and swallows clicks meant for them.
	local overlay = UIBuilder.frame({
		Parent = hud.panelLayer,
		Name = "DexOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Active = true,
		Visible = false,
		ZIndex = 20,
	})
	self.overlay = overlay

	local card = UIBuilder.frame({
		Parent = overlay,
		Name = "DexCard",
		Size = UDim2.fromOffset(790, 540),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.03,
		ZIndex = 21,
	})
	UIBuilder.corner(card, 16)
	UIBuilder.stroke(card, Color3.fromRGB(62, 80, 126), 1, 0.2)
	self.card = card

	UIBuilder.label({
		Parent = card,
		Text = "RIFTODEX",
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(24, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = COLORS.Text,
		ZIndex = 22,
	})
	self.summary = UIBuilder.label({
		Parent = card,
		Text = "0 / 25 discovered",
		Size = UDim2.fromOffset(320, 20),
		Position = UDim2.fromOffset(24, 50),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		ZIndex = 22,
	})
	self.bestLabel = UIBuilder.label({
		Parent = card,
		Text = "BEST  -",
		Size = UDim2.fromOffset(330, 20),
		Position = UDim2.fromOffset(390, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.AccentWarm,
		ZIndex = 22,
	})

	local close = UIBuilder.button({
		Parent = card,
		Text = "X",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -30, 0, 18),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(34, 42, 68),
		TextSize = 16,
		ZIndex = 22,
	})
	UIBuilder.corner(close, 10)
	close.MouseButton1Click:Connect(function()
		self:close()
	end)

	local scroll = UIBuilder.scrolling({
		Parent = card,
		Name = "DexScroll",
		Size = UDim2.fromOffset(742, 434),
		Position = UDim2.fromOffset(24, 82),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 6,
		ZIndex = 22,
	})
	self.scroll = scroll

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(238, 88)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	for index, rift in ipairs(RiftData.Rifts) do
		local tier = RiftData.TierById[rift.tier]
		local cell = UIBuilder.frame({
			Parent = scroll,
			Name = rift.id,
			Size = UDim2.fromOffset(238, 88),
			BackgroundColor3 = COLORS.PanelLight,
			BackgroundTransparency = 0.15,
			LayoutOrder = index,
			ZIndex = 22,
		})
		UIBuilder.corner(cell, 10)

		local bar = UIBuilder.frame({
			Parent = cell,
			Name = "Bar",
			Size = UDim2.fromOffset(4, 88),
			BackgroundColor3 = tier and tier.color or COLORS.Muted,
			ZIndex = 23,
		})
		UIBuilder.corner(bar, 2)

		local name = UIBuilder.label({
			Parent = cell,
			Text = "???",
			Size = UDim2.fromOffset(200, 20),
			Position = UDim2.fromOffset(14, 10),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = COLORS.Muted,
			ZIndex = 23,
		})
		local tierLabel = UIBuilder.label({
			Parent = cell,
			Text = tier and string.upper(tier.name) or "",
			Size = UDim2.fromOffset(200, 16),
			Position = UDim2.fromOffset(14, 30),
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = tier and tier.color or COLORS.Muted,
			ZIndex = 23,
		})
		local odds = UIBuilder.label({
			Parent = cell,
			Text = "undiscovered",
			Size = UDim2.fromOffset(200, 18),
			Position = UDim2.fromOffset(14, 48),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = COLORS.Muted,
			ZIndex = 23,
		})
		local count = UIBuilder.label({
			Parent = cell,
			Text = "",
			Size = UDim2.fromOffset(200, 16),
			Position = UDim2.fromOffset(14, 66),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = COLORS.Accent,
			ZIndex = 23,
		})

		self.cells[rift.id] = {
			rift = rift,
			tier = tier,
			cell = cell,
			bar = bar,
			name = name,
			tierLabel = tierLabel,
			odds = odds,
			count = count,
			found = false,
		}
	end

	scroll.CanvasSize = UDim2.fromOffset(0, math.ceil(#RiftData.Rifts / 3) * 98 + 8)

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:close()
		end
	end)

	return self
end

function DexPanel:setCounts(counts)
	local found = 0
	for riftId, entry in pairs(self.cells) do
		local amount = counts and counts[riftId] or 0
		if amount and amount > 0 then
			found = found + 1
			entry.found = true
			entry.name.Text = entry.rift.name
			entry.name.TextColor3 = COLORS.Text
			entry.tierLabel.Text = entry.tier and string.upper(entry.tier.name) or ""
			entry.odds.Text = Format.odds(entry.rift.odds) .. "  |  +" .. Format.compact(entry.rift.income) .. "/s"
			entry.count.Text = "x" .. Format.compact(amount)
			entry.cell.BackgroundColor3 = COLORS.PanelLight
			entry.bar.BackgroundColor3 = entry.tier and entry.tier.color or COLORS.Accent
		else
			entry.found = false
			entry.name.Text = "???"
			entry.name.TextColor3 = COLORS.Muted
			entry.tierLabel.Text = "UNDISCOVERED"
			entry.odds.Text = "keep tearing"
			entry.count.Text = ""
			entry.cell.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
			entry.bar.BackgroundColor3 = Color3.fromRGB(44, 50, 72)
		end
	end
	self.summary.Text = string.format("%d / %d discovered", found, #RiftData.Rifts)
end

function DexPanel:setBest(best)
	if best then
		self.bestLabel.Text = string.format("BEST  %s  (%s)", string.upper(best.name), Format.odds(best.odds))
	else
		self.bestLabel.Text = "BEST  -"
	end
end

function DexPanel:open()
	if self.isOpen then
		return
	end
	self.isOpen = true
	self.overlay.Visible = true
	Audio.play("ui")
	self.card.Size = UDim2.fromOffset(760, 520)
	UIBuilder.tween(self.card, 0.18, { Size = UDim2.fromOffset(790, 540) })
end

function DexPanel:close()
	if not self.isOpen then
		return
	end
	self.isOpen = false
	self.overlay.Visible = false
	Audio.play("ui")
end

function DexPanel:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

return DexPanel
