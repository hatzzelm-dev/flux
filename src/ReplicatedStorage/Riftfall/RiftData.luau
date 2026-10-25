--!nolint
-- AUTO-GENERATED FILE - DO NOT EDIT BY HAND.
-- Source of truth: data/tiers.csv and data/rarities.csv
-- Regenerate: python tools/gen_data.py
-- source_hash: 799352c6fec2035639d9bf186d983a03c2117ceeab1986c79f4d14472d5b3fa3

local RiftData = {}

RiftData.Hash = "799352c6fec2035639d9bf186d983a03c2117ceeab1986c79f4d14472d5b3fa3"
RiftData.Version = 1
RiftData.TotalWeight = 100

RiftData.Tiers = {
	{
		id = 1,
		name = "Faint",
		color = Color3.fromRGB(152, 156, 168),
		glow = 60,
		particles = 8,
	},
	{
		id = 2,
		name = "Drift",
		color = Color3.fromRGB(86, 214, 226),
		glow = 150,
		particles = 14,
	},
	{
		id = 3,
		name = "Surge",
		color = Color3.fromRGB(72, 146, 255),
		glow = 220,
		particles = 20,
	},
	{
		id = 4,
		name = "Fracture",
		color = Color3.fromRGB(166, 112, 255),
		glow = 300,
		particles = 28,
	},
	{
		id = 5,
		name = "Rupture",
		color = Color3.fromRGB(255, 86, 214),
		glow = 380,
		particles = 38,
	},
	{
		id = 6,
		name = "Collapse",
		color = Color3.fromRGB(255, 180, 74),
		glow = 460,
		particles = 48,
	},
	{
		id = 7,
		name = "Singularity",
		color = Color3.fromRGB(255, 74, 74),
		glow = 560,
		particles = 62,
	},
	{
		id = 8,
		name = "Omega",
		color = Color3.fromRGB(255, 246, 214),
		glow = 700,
		particles = 84,
	},
	{
		id = 9,
		name = "Storm",
		color = Color3.fromRGB(120, 255, 235),
		glow = 340,
		particles = 34,
	},
}

RiftData.TierById = {}
for _, tier in ipairs(RiftData.Tiers) do
	RiftData.TierById[tier.id] = tier
end

RiftData.Rifts = {
	{
		id = "spark",
		name = "Spark",
		tier = 1,
		weight = 44,
		stormWeight = 0,
		odds = 2.2727,
		income = 0.52,
		stormOnly = false,
	},
	{
		id = "haze",
		name = "Haze",
		tier = 1,
		weight = 20,
		stormWeight = 0,
		odds = 5,
		income = 0.669,
		stormOnly = false,
	},
	{
		id = "dust",
		name = "Dust Vein",
		tier = 1,
		weight = 10.5318127,
		stormWeight = 0,
		odds = 9.495,
		income = 0.822,
		stormOnly = false,
	},
	{
		id = "mist",
		name = "Mist Rift",
		tier = 2,
		weight = 12.5,
		stormWeight = 0,
		odds = 8,
		income = 0.778,
		stormOnly = false,
	},
	{
		id = "ember",
		name = "Ember Scar",
		tier = 2,
		weight = 6.6666667,
		stormWeight = 0,
		odds = 15,
		income = 0.952,
		stormOnly = false,
	},
	{
		id = "prism",
		name = "Prism Tear",
		tier = 3,
		weight = 2.8571429,
		stormWeight = 0,
		odds = 35,
		income = 1.248,
		stormOnly = false,
	},
	{
		id = "aurora",
		name = "Aurora Wisp",
		tier = 3,
		weight = 1.6666667,
		stormWeight = 0,
		odds = 60,
		income = 1.483,
		stormOnly = false,
	},
	{
		id = "static",
		name = "Static Bloom",
		tier = 3,
		weight = 1,
		stormWeight = 0,
		odds = 100,
		income = 1.746,
		stormOnly = false,
	},
	{
		id = "glass",
		name = "Glass Storm",
		tier = 4,
		weight = 0.4,
		stormWeight = 0,
		odds = 250,
		income = 2.341,
		stormOnly = false,
	},
	{
		id = "thunder",
		name = "Thunder Scar",
		tier = 4,
		weight = 0.2,
		stormWeight = 0,
		odds = 500,
		income = 2.922,
		stormOnly = false,
	},
	{
		id = "nova",
		name = "Nova Shard",
		tier = 4,
		weight = 0.1,
		stormWeight = 0,
		odds = 1000,
		income = 3.648,
		stormOnly = false,
	},
	{
		id = "chrono",
		name = "Chrono Wound",
		tier = 5,
		weight = 0.04,
		stormWeight = 0,
		odds = 2500,
		income = 4.891,
		stormOnly = false,
	},
	{
		id = "gravity",
		name = "Gravity Bloom",
		tier = 5,
		weight = 0.02,
		stormWeight = 0,
		odds = 5000,
		income = 6.106,
		stormOnly = false,
	},
	{
		id = "mirror",
		name = "Mirror Void",
		tier = 5,
		weight = 0.01,
		stormWeight = 0,
		odds = 10000,
		income = 7.622,
		stormOnly = false,
	},
	{
		id = "horizon",
		name = "Event Horizon",
		tier = 6,
		weight = 0.004,
		stormWeight = 0,
		odds = 25000,
		income = 10.219,
		stormOnly = false,
	},
	{
		id = "crown",
		name = "Hollow Crown",
		tier = 6,
		weight = 0.002,
		stormWeight = 0,
		odds = 50000,
		income = 12.756,
		stormOnly = false,
	},
	{
		id = "starfall",
		name = "Starfall Gate",
		tier = 6,
		weight = 0.001,
		stormWeight = 0,
		odds = 100000,
		income = 15.924,
		stormOnly = false,
	},
	{
		id = "genesis",
		name = "Genesis Tear",
		tier = 7,
		weight = 0.0004,
		stormWeight = 0,
		odds = 250000,
		income = 21.35,
		stormOnly = false,
	},
	{
		id = "voidbloom",
		name = "Void Bloom",
		tier = 7,
		weight = 0.0002,
		stormWeight = 0,
		odds = 500000,
		income = 26.652,
		stormOnly = false,
	},
	{
		id = "riftwyrm",
		name = "Riftwyrm",
		tier = 7,
		weight = 0.0001,
		stormWeight = 0,
		odds = 1000000,
		income = 33.271,
		stormOnly = false,
	},
	{
		id = "oblivion",
		name = "Oblivion Rift",
		tier = 8,
		weight = 0.00001,
		stormWeight = 0,
		odds = 10000000,
		income = 69.512,
		stormOnly = false,
	},
	{
		id = "firstrift",
		name = "The First Rift",
		tier = 8,
		weight = 0.000001,
		stormWeight = 0,
		odds = 100000000,
		income = 145.231,
		stormOnly = false,
	},
	{
		id = "stormglass",
		name = "Stormglass",
		tier = 9,
		weight = 0,
		stormWeight = 0.25,
		odds = 400,
		income = 2.721,
		stormOnly = true,
	},
	{
		id = "thunderhead",
		name = "Thunderhead",
		tier = 9,
		weight = 0,
		stormWeight = 0.02,
		odds = 5000,
		income = 6.106,
		stormOnly = true,
	},
	{
		id = "eye",
		name = "Eye of the Storm",
		tier = 9,
		weight = 0,
		stormWeight = 0.0004,
		odds = 250000,
		income = 21.35,
		stormOnly = true,
	},
}

RiftData.RiftById = {}
for _, rift in ipairs(RiftData.Rifts) do
	RiftData.RiftById[rift.id] = rift
end

RiftData.Count = #RiftData.Rifts

function RiftData.getTier(tierId)
	return RiftData.TierById[tierId]
end

function RiftData.getRift(riftId)
	return RiftData.RiftById[riftId]
end

return RiftData
