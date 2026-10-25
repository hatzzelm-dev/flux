--!nolint
-- RIFTFALL tunables. Every balance number that is not a rift lives here so the
-- simulator (tools/simulate_balance.py) and the game can be compared directly.

local Config = {}

Config.Version = 2

Config.Roll = {
	BaseCooldown = 1.15,
	MinCooldown = 0.45,
	SpeedStep = 0.055,
	LuckPerLevel = 0.06,
	-- Weight multiplier per tier: weight * luck ^ (tier * exponent).
	-- Capped at tier 8 so storm-exclusive rifts do not become common.
	LuckTierExponent = 0.25,
	LuckTierCap = 8,
	PassCooldownMult = 0.8,
	MaxRollsPerWindow = 30,
	RateWindow = 10,
	ServerCooldownSlack = 0.05,
}

Config.Upgrades = {
	luck = {
		name = "Resonance",
		description = "+6% luck. Rarer tiers gain more weight.",
		baseCost = 120,
		growth = 2.05,
		maxLevel = 15,
	},
	speed = {
		name = "Tempo",
		description = "Tears open faster (-0.055s cooldown).",
		baseCost = 90,
		growth = 2.2,
		maxLevel = 6,
	},
	auto = {
		name = "Auto-Tear",
		description = "Tears rifts automatically while you are idle.",
		cost = 3000,
		maxLevel = 1,
	},
}

Config.Milestones = {
	{ unique = 5, flux = 500, luckBonus = 0.02 },
	{ unique = 10, flux = 2500, luckBonus = 0.02 },
	{ unique = 15, flux = 12000, luckBonus = 0.03 },
	{ unique = 20, flux = 60000, luckBonus = 0.03 },
	{ unique = 25, flux = 400000, luckBonus = 0.05 },
}

Config.Storm = {
	-- First storm lands inside the first minute so every new player sees one.
	FirstDelay = 60,
	-- Seconds of "incoming" warning broadcast before the storm starts.
	WarningLead = 10,
	MinInterval = 210,
	MaxInterval = 330,
	Duration = 90,
	LuckMultiplier = 2.2,
	BroadcastTier = 6,
}

Config.Audio = {
	MasterVolume = 0.55,
	Haptics = true,
	-- Tier at which a reveal adds the screen sting (flash + shake + rare cue).
	StingTier = 4,
}

Config.Onboarding = {
	Enabled = true,
}

Config.Plot = {
	Count = 12,
	Radius = 122,
	Size = 46,
	DisplayMax = 6,
	PedestalHeight = 15,
}

Config.Rewards = {
	StartingFlux = 0,
	RareBroadcastOdds = 100000,
}

Config.Products = {
	RiftRunner = {
		id = 2053584066,
		kind = "pass",
		name = "Rift Runner",
		description = "Auto-tear always available, 20% faster cooldown.",
		price = 99,
	},
	OmegaAura = {
		id = 2053260006,
		kind = "pass",
		name = "Omega Aura",
		description = "Cosmetic omega aura, title and portal trim.",
		price = 149,
	},
	FluxPack = {
		id = 0,
		kind = "product",
		name = "Flux Pack",
		description = "A fixed bundle of Flux.",
		price = 29,
		flux = 2500,
	},
}

Config.Sounds = {
	-- Built-in client sounds: no marketplace asset can be moderated or removed,
	-- so these always load. Empty strings disable a cue.
	-- Swap in rbxassetid:// values here to re-voice the game.
	Roll = "rbxasset://sounds/electronicpingshort.wav",
	Reveal = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/switch3.wav",
	Storm = "rbxasset://sounds/impact_water.mp3",
	Milestone = "rbxasset://sounds/switch3.wav",
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	UI = "rbxasset://sounds/switch3.wav",
}

Config.Data = {
	StoreName = "Riftfall_Data_v1",
	KeyPrefix = "Player_",
	LockTtl = 120,
	AutosaveInterval = 90,
	StateInterval = 0.5,
	-- A join never waits longer than this for DataStores. If the request has not
	-- answered by then the session plays read-only instead of hanging on a
	-- black screen (Studio without API access is the common case).
	LoadTimeout = 5,
	MaxPurchaseLog = 50,
}

Config.Analytics = {
	Enabled = true,
	Throttle = 1,
}

Config.UI = {
	Background = Color3.fromRGB(10, 12, 22),
	Panel = Color3.fromRGB(16, 20, 36),
	PanelLight = Color3.fromRGB(24, 30, 52),
	Accent = Color3.fromRGB(120, 220, 255),
	AccentWarm = Color3.fromRGB(255, 196, 96),
	Text = Color3.fromRGB(236, 240, 255),
	Muted = Color3.fromRGB(150, 160, 190),
	Good = Color3.fromRGB(120, 255, 180),
	Bad = Color3.fromRGB(255, 120, 120),
}

return Config
