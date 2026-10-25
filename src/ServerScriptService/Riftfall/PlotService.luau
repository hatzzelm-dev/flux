--!nolint
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local RiftData = require(Shared.RiftData)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local WorldFolder = ServerStorage:WaitForChild("World")
local RiftModel = require(WorldFolder:WaitForChild("RiftModel"))

local PlotService = {}

local layout = nil
local slots = {}

function PlotService.init(worldLayout)
	layout = worldLayout
end

function PlotService.getPlot(player)
	if not player then
		return nil
	end
	return slots[player.UserId]
end

function PlotService.assign(player)
	if slots[player.UserId] then
		return slots[player.UserId]
	end
	if not layout then
		return nil
	end
	for _, plot in ipairs(layout.plots) do
		if plot.owner == nil then
			plot.owner = player.UserId
			slots[player.UserId] = plot
			plot.signLabel.Text = player.Name
			PlotService.refresh(player)
			return plot
		end
	end
	return nil
end

function PlotService.clearModels(plot)
	for _, model in ipairs(plot.models) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	plot.models = {}
	plot.signature = nil
end

function PlotService.refresh(player)
	local plot = slots[player.UserId]
	local data = DataService.getData(player)
	if not plot or not data then
		return
	end

	local entries = {}
	for riftId, count in pairs(data.rifts) do
		local rift = RiftData.RiftById[riftId]
		if rift then
			table.insert(entries, { rift = rift, count = count })
		end
	end
	table.sort(entries, function(a, b)
		if a.rift.odds == b.rift.odds then
			return a.rift.name < b.rift.name
		end
		return a.rift.odds > b.rift.odds
	end)

	local shown = {}
	local parts = {}
	for index = 1, math.min(#entries, Config.Plot.DisplayMax) do
		table.insert(shown, entries[index].rift)
		table.insert(parts, entries[index].rift.id)
	end
	local signature = table.concat(parts, ",")
	if plot.signature == signature then
		return
	end
	plot.signature = signature

	PlotService.clearModels(plot)
	for index, rift in ipairs(shown) do
		local tier = RiftData.TierById[rift.tier]
		if tier then
			local column = (index - 1) % 3
			local row = math.floor((index - 1) / 3)
			local offset = CFrame.new((column - 1) * 14, row * 14, 0)
			local scale = 4.2 + math.min(rift.tier, 8) * 0.95
			local model = RiftModel.build(rift, tier, plot.portalCFrame * offset, scale)
			model.Parent = layout.world
			table.insert(plot.models, model)
		end
	end

	local best = nil
	if data.bestId then
		best = RiftData.RiftById[data.bestId]
	end
	if best then
		plot.signLabel.Text = string.format("%s\n%s", player.Name, Format.odds(best.odds))
	else
		plot.signLabel.Text = player.Name
	end
end

function PlotService.release(player)
	local plot = slots[player.UserId]
	if not plot then
		return
	end
	PlotService.clearModels(plot)
	plot.owner = nil
	plot.signLabel.Text = "empty plot"
	slots[player.UserId] = nil
end

function PlotService.updateBoard(playerName, rift)
	if not layout or not layout.bestLabel then
		return
	end
	local tier = RiftData.TierById[rift.tier]
	layout.bestLabel.Text = string.format(
		"SERVER BEST\n%s\n%s  (%s)",
		string.upper(rift.name),
		playerName,
		Format.odds(rift.odds)
	)
	if tier then
		layout.bestLabel.TextColor3 = tier.color
	end
end

return PlotService
