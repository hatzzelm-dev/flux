--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local UIBuilder = require(script.Parent.UIBuilder)
local Audio = require(script.Parent.Audio)

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local COLORS = Config.UI

local function costText(cost)
	return Format.compact(cost) .. " Flux"
end

function ShopPanel.new(hud, callbacks)
	local self = setmetatable({}, ShopPanel)
	self.hud = hud
	self.callbacks = callbacks or {}
	-- isOpen, not open: `open` is the method name below and a boolean field would
	-- shadow it, making self:open() fail with "attempt to call a boolean value".
	self.isOpen = false
	self.rows = {}
	self.products = {}

	-- Parented to the HUD panel layer (above the control buttons) and Active, so
	-- an open panel both draws over the buttons and swallows clicks meant for them.
	local overlay = UIBuilder.frame({
		Parent = hud.panelLayer,
		Name = "ShopOverlay",
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
		Name = "ShopCard",
		Size = UDim2.fromOffset(790, 560),
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
		Text = "RIFT LAB",
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(24, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = COLORS.Text,
		ZIndex = 22,
	})
	self.fluxLabel = UIBuilder.label({
		Parent = card,
		Text = "0 Flux",
		Size = UDim2.fromOffset(250, 20),
		Position = UDim2.fromOffset(24, 50),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = COLORS.Accent,
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
		Name = "ShopScroll",
		Size = UDim2.fromOffset(742, 440),
		Position = UDim2.fromOffset(24, 82),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 6,
		ZIndex = 22,
	})
	self.scroll = scroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local function makeRow(order, title, description)
		local row = UIBuilder.frame({
			Parent = scroll,
			Size = UDim2.fromOffset(716, 88),
			BackgroundColor3 = COLORS.PanelLight,
			BackgroundTransparency = 0.1,
			LayoutOrder = order,
			ZIndex = 22,
		})
		UIBuilder.corner(row, 12)

		UIBuilder.label({
			Parent = row,
			Text = title,
			Size = UDim2.fromOffset(420, 22),
			Position = UDim2.fromOffset(18, 14),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = COLORS.Text,
			ZIndex = 23,
		})
		UIBuilder.label({
			Parent = row,
			Text = description,
			Size = UDim2.fromOffset(440, 34),
			Position = UDim2.fromOffset(18, 38),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = COLORS.Muted,
			TextWrapped = true,
			ZIndex = 23,
		})
		local level = UIBuilder.label({
			Parent = row,
			Text = "",
			Size = UDim2.fromOffset(300, 18),
			Position = UDim2.fromOffset(18, 64),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLORS.Accent,
			ZIndex = 23,
		})
		local button = UIBuilder.button({
			Parent = row,
			Text = "",
			Size = UDim2.fromOffset(170, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(40, 60, 100),
			TextSize = 14,
			ZIndex = 23,
		})
		UIBuilder.corner(button, 10)
		return { row = row, level = level, button = button }
	end

	local luckRow = makeRow(1, Config.Upgrades.luck.name, Config.Upgrades.luck.description)
	luckRow.button.MouseButton1Click:Connect(function()
		if self.callbacks.onUpgrade then
			self.callbacks.onUpgrade("luck")
		end
	end)
	self.rows.luck = luckRow

	local speedRow = makeRow(2, Config.Upgrades.speed.name, Config.Upgrades.speed.description)
	speedRow.button.MouseButton1Click:Connect(function()
		if self.callbacks.onUpgrade then
			self.callbacks.onUpgrade("speed")
		end
	end)
	self.rows.speed = speedRow

	local autoRow = makeRow(3, Config.Upgrades.auto.name, Config.Upgrades.auto.description)
	autoRow.button.MouseButton1Click:Connect(function()
		if self.callbacks.onUpgrade then
			self.callbacks.onUpgrade("auto")
		end
	end)
	self.rows.auto = autoRow

	UIBuilder.label({
		Parent = scroll,
		Text = "SUPPORT  |  fixed prices, no paid odds",
		Size = UDim2.fromOffset(716, 22),
		LayoutOrder = 4,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		ZIndex = 22,
	})

	local productOrder = { "RiftRunner", "OmegaAura", "FluxPack" }
	local order = 5
	for _, key in ipairs(productOrder) do
		local product = Config.Products[key]
		if product then
			local row = makeRow(order, product.name, product.description)
			order = order + 1
			row.button.MouseButton1Click:Connect(function()
				if self.callbacks.onProduct then
					self.callbacks.onProduct(key)
				end
			end)
			self.products[key] = { product = product, row = row }
		end
	end

	scroll.CanvasSize = UDim2.fromOffset(0, 3 * 98 + 5 * 98 + 20)

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:close()
		end
	end)

	return self
end

function ShopPanel:setState(state)
	if not state then
		return
	end
	self.state = state
	self.fluxLabel.Text = Format.compact(state.flux) .. " Flux"

	local luck = self.rows.luck
	luck.level.Text = string.format("LEVEL %d / %d   |   LUCK x%.2f", state.luckLevel or 0, Config.Upgrades.luck.maxLevel, state.baseLuck or 1)
	if state.nextLuckCost then
		luck.button.Text = costText(state.nextLuckCost)
		luck.button.BackgroundColor3 = (state.flux >= state.nextLuckCost) and Color3.fromRGB(44, 88, 132) or Color3.fromRGB(38, 44, 64)
		luck.button.TextColor3 = (state.flux >= state.nextLuckCost) and COLORS.Text or COLORS.Muted
	else
		luck.button.Text = "MAXED"
		luck.button.BackgroundColor3 = Color3.fromRGB(34, 44, 60)
		luck.button.TextColor3 = COLORS.Muted
	end

	local speed = self.rows.speed
	speed.level.Text = string.format("LEVEL %d / %d   |   COOLDOWN %.2fs", state.speedLevel or 0, Config.Upgrades.speed.maxLevel, state.cooldown or 0)
	if state.nextSpeedCost then
		speed.button.Text = costText(state.nextSpeedCost)
		speed.button.BackgroundColor3 = (state.flux >= state.nextSpeedCost) and Color3.fromRGB(44, 88, 132) or Color3.fromRGB(38, 44, 64)
		speed.button.TextColor3 = (state.flux >= state.nextSpeedCost) and COLORS.Text or COLORS.Muted
	else
		speed.button.Text = "MAXED"
		speed.button.BackgroundColor3 = Color3.fromRGB(34, 44, 60)
		speed.button.TextColor3 = COLORS.Muted
	end

	local auto = self.rows.auto
	if state.autoUnlocked then
		auto.level.Text = "UNLOCKED  |  toggles from the HUD"
		auto.button.Text = "OWNED"
		auto.button.BackgroundColor3 = Color3.fromRGB(32, 60, 48)
		auto.button.TextColor3 = Color3.fromRGB(140, 255, 190)
	elseif state.pass and state.pass.riftRunner then
		auto.level.Text = "INCLUDED WITH RIFT RUNNER"
		auto.button.Text = "OWNED"
		auto.button.BackgroundColor3 = Color3.fromRGB(32, 60, 48)
		auto.button.TextColor3 = Color3.fromRGB(140, 255, 190)
	else
		auto.level.Text = "ONE-TIME UNLOCK"
		auto.button.Text = costText(state.autoCost or Config.Upgrades.auto.cost)
		local affordable = state.flux >= (state.autoCost or Config.Upgrades.auto.cost)
		auto.button.BackgroundColor3 = affordable and Color3.fromRGB(44, 88, 132) or Color3.fromRGB(38, 44, 64)
		auto.button.TextColor3 = affordable and COLORS.Text or COLORS.Muted
	end

	for key, entry in pairs(self.products) do
		if entry.product.id <= 0 then
			entry.row.button.Text = "COMING SOON"
			entry.row.button.BackgroundColor3 = Color3.fromRGB(38, 44, 64)
			entry.row.button.TextColor3 = COLORS.Muted
			entry.row.button.Active = false
		else
			entry.row.button.Text = tostring(entry.product.price) .. " R$"
			entry.row.button.BackgroundColor3 = Color3.fromRGB(64, 92, 60)
			entry.row.button.TextColor3 = COLORS.Text
			entry.row.button.Active = true
		end
		if key == "RiftRunner" and state.pass and state.pass.riftRunner then
			entry.row.button.Text = "OWNED"
			entry.row.button.BackgroundColor3 = Color3.fromRGB(32, 60, 48)
		elseif key == "OmegaAura" and state.pass and state.pass.omegaAura then
			entry.row.button.Text = "OWNED"
			entry.row.button.BackgroundColor3 = Color3.fromRGB(32, 60, 48)
		end
	end
end

function ShopPanel:open()
	if self.isOpen then
		return
	end
	self.isOpen = true
	self.overlay.Visible = true
	Audio.play("ui")
end

function ShopPanel:close()
	if not self.isOpen then
		return
	end
	self.isOpen = false
	self.overlay.Visible = false
	Audio.play("ui")
end

function ShopPanel:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

return ShopPanel
