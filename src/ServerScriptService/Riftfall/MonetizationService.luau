--!nolint
-- Monetization. Three fixed-value products only:
--   Rift Runner (pass)  - convenience: auto-tear + faster cooldown, no odds change
--   Omega Aura  (pass)  - cosmetic aura + title
--   Flux Pack   (product) - fixed Flux amount
--
-- Purchase ids are configured in Config.Products (0 means "not configured yet").
-- Grants are idempotent: a PurchaseId is written to the profile before the
-- receipt is acknowledged, and replayed receipts grant nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local MonetizationService = {}

local remotes = nil
local passCache = {}

local function emptyPasses()
	return { riftRunner = false, omegaAura = false }
end

local function clearCosmetics(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local aura = root:FindFirstChild("RiftfallAura")
		if aura then
			aura:Destroy()
		end
	end
	local head = character:FindFirstChild("Head")
	if head then
		local title = head:FindFirstChild("RiftfallTitle")
		if title then
			title:Destroy()
		end
	end
end

function MonetizationService.applyCosmetics(player)
	clearCosmetics(player)
	if not MonetizationService.hasPass(player, "OmegaAura") then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")

	if root then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RiftfallAura"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 18
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 246, 214))
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Parent = root
	end

	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "RiftfallTitle"
		billboard.Size = UDim2.fromOffset(180, 32)
		billboard.StudsOffset = Vector3.new(0, 2.4, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "OMEGA"
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 246, 214)
		label.TextStrokeTransparency = 0.35
		label.TextScaled = true
		label.Parent = billboard
	end
end

function MonetizationService.refresh(player)
	local result = emptyPasses()
	for key, product in pairs(Config.Products) do
		if product.kind == "pass" and product.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.id)
			end)
			if ok then
				if key == "RiftRunner" then
					result.riftRunner = owns == true
				elseif key == "OmegaAura" then
					result.omegaAura = owns == true
				end
			end
		end
	end
	passCache[player.UserId] = result
	MonetizationService.applyCosmetics(player)
	return result
end

function MonetizationService.passes(player)
	if not player then
		return emptyPasses()
	end
	return passCache[player.UserId] or emptyPasses()
end

function MonetizationService.hasPass(player, key)
	local passes = MonetizationService.passes(player)
	if key == "OmegaAura" then
		return passes.omegaAura == true
	end
	return passes.riftRunner == true
end

function MonetizationService.forget(player)
	passCache[player.UserId] = nil
end

local function handleReceipt(receipt)
	local retry = Enum.ProductPurchaseDecision.NotProcessedYet
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted
	if not receipt then
		return retry
	end

	local product = Config.Products.FluxPack
	if product.id <= 0 or receipt.ProductId ~= product.id then
		return retry
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return retry
	end
	local data = DataService.getData(player)
	if not data then
		return retry
	end

	local purchaseId = receipt.PurchaseId
	if type(purchaseId) ~= "string" or #purchaseId == 0 then
		return retry
	end
	for _, existing in ipairs(data.purchases) do
		if existing == purchaseId then
			return granted
		end
	end

	local flux = product.flux or 0
	data.flux = data.flux + flux
	table.insert(data.purchases, purchaseId)
	while #data.purchases > Config.Data.MaxPurchaseLog do
		table.remove(data.purchases, 1)
	end
	DataService.touch(player)

	if not DataService.save(player, true) then
		-- The grant was not persisted: undo and let Roblox retry the receipt.
		data.flux = data.flux - flux
		for index = #data.purchases, 1, -1 do
			if data.purchases[index] == purchaseId then
				table.remove(data.purchases, index)
				break
			end
		end
		return retry
	end

	AnalyticsService.log(player, "purchase_flux_pack", flux)
	if remotes then
		remotes.Event:FireClient(player, {
			kind = "purchase",
			ok = true,
			text = string.format("+%d Flux received", flux),
		})
	end
	return granted
end

function MonetizationService.init(remoteMap)
	remotes = remoteMap
	MarketplaceService.ProcessReceipt = handleReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		task.spawn(function()
			MonetizationService.refresh(player)
			if remotes then
				remotes.Event:FireClient(player, {
					kind = "purchase",
					ok = true,
					text = "Pass unlocked. Thank you!",
				})
			end
			AnalyticsService.log(player, "purchase_pass", gamePassId)
		end)
	end)

	remotes.RequestProduct.OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		local product = Config.Products[key]
		if not product then
			return
		end
		if product.id <= 0 then
			remotes.Event:FireClient(player, {
				kind = "notice",
				text = product.name .. " is not configured yet",
			})
			return
		end
		if product.kind == "pass" then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, product.id)
			end)
		else
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, product.id, false)
			end)
		end
	end)
end

return MonetizationService
