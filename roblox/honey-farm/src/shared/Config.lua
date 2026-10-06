--!strict
-- Shared settings for HONEY FARM. Everything you might want to tweak lives here.

local Config = {}

Config.GameName = "HONEY FARM"

-- Map layout ---------------------------------------------------------------
Config.PlotCount = 6
Config.PlotRadius = 165 -- studs from the village centre to each plot's centre
Config.PlotSize = 100 -- each plot is PlotSize x PlotSize studs
Config.GateWidth = 16 -- opening in the front fence
Config.SquareRadius = 48 -- village plaza
Config.PathWidth = 12
Config.MapHalfSize = 280 -- ground extends this far from the centre in X and Z

-- Player experience ----------------------------------------------------------
Config.ReturnCooldown = 2 -- seconds between "My Farm" teleports
Config.ReturnHotkey = Enum.KeyCode.H

-- Palette --------------------------------------------------------------------
Config.Colors = {
	Grass = Color3.fromRGB(110, 196, 84),
	PlotGrass = Color3.fromRGB(126, 210, 94),
	Path = Color3.fromRGB(233, 205, 150),
	Plaza = Color3.fromRGB(240, 218, 170),
	Wood = Color3.fromRGB(176, 120, 72),
	DarkWood = Color3.fromRGB(120, 78, 46),
	FenceWhite = Color3.fromRGB(250, 244, 228),
	Honey = Color3.fromRGB(255, 190, 40),
	DeepHoney = Color3.fromRGB(230, 150, 20),
	Cream = Color3.fromRGB(255, 246, 220),
	Soil = Color3.fromRGB(110, 72, 44),
	Leaf = Color3.fromRGB(70, 160, 70),
	Stem = Color3.fromRGB(80, 150, 60),
	Water = Color3.fromRGB(110, 200, 255),
	Stone = Color3.fromRGB(205, 200, 190),
	Text = Color3.fromRGB(70, 45, 20),
	PetalColors = {
		Color3.fromRGB(255, 120, 170),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(190, 130, 255),
		Color3.fromRGB(255, 150, 70),
		Color3.fromRGB(120, 190, 255),
		Color3.fromRGB(255, 90, 90),
	},
	RoofColors = {
		Color3.fromRGB(235, 90, 70),
		Color3.fromRGB(255, 170, 50),
		Color3.fromRGB(80, 180, 170),
		Color3.fromRGB(160, 110, 220),
		Color3.fromRGB(240, 120, 160),
		Color3.fromRGB(90, 150, 230),
	},
}

-- One accent colour per plot, used on its gate and sign.
Config.PlotAccents = {
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(150, 220, 90),
	Color3.fromRGB(190, 140, 255),
	Color3.fromRGB(255, 150, 80),
}

-- Stations on every plot. The prompt works with keyboard (E) and touch (tap).
Config.Stations = {
	Hive = { Label = "🐝 Hive", Action = "Collect Honey" },
	FlowerPatch = { Label = "🌸 Flower Patch", Action = "Inspect" },
	BeeShop = { Label = "🛒 Bee Shop", Action = "Shop" },
	Bottling = { Label = "🍯 Bottling", Action = "Deposit Honey" },
	SellStand = { Label = "💰 Honey Stand", Action = "Collect Cash" },
}
Config.PromptDistance = 12 -- studs; the server also checks this (+ a little slack)

-- Economy (Phase 2). Prices/rates live here so they're easy to rebalance. -----
Config.Economy = {
	StartCash = 25,
	StartBees = { "Starter" }, -- tiers given to a new player (see Config.Bees below)
	BackpackCapacity = 50, -- honey a player can carry
	HiveCapacity = 50, -- honey the hive stores before bees stop adding
	BottlingPerSecond = 1, -- honey -> jars per second
	JarValue = 5, -- cash added to the stand's unclaimed balance per finished jar
	JarTravelTime = 3, -- seconds a jar rides the conveyor before it counts
	MaxJarsOnBelt = 12, -- visual limit; extra jars still count, they just queue up
}

-- Bee shop + merging (Phase 3) ---------------------------------------------------
Config.Economy.BeeSlots = 8 -- active bees per player
Config.Economy.BeeBasePrice = 25 -- first Starter Bee costs this
Config.Economy.BeePriceGrowth = 1.25 -- each purchase multiplies the price by this
Config.Economy.MergeMultiplier = 2.5 -- a merged bee makes this x one bee of the previous tier

-- Bee tiers, lowest -> highest. Two bees of one tier merge into one of the next.
-- Look: Body = head + light stripes, Stripe = dark stripes, Wing, Eye, Antenna (hex colours),
--       Material / NeonStripes / Transparency / Reflectance / Glow, Accessory = the shape that
--       makes the tier recognisable (built in BeeAppearance).
Config.BeeOrder = { "Starter", "Clover", "Daisy", "Strawberry", "Panda", "Knight", "Crystal", "Storm", "Galaxy", "Royal" }
Config.Bees = {
	Starter = {
		Name = "Starter Bee",
		Description = "Where every beekeeper begins.",
		Look = { Body = "#FFFF00", Stripe = "#1B2A35", Wing = "#9FF3E9", Eye = "#111111" },
	},
	Clover = {
		Name = "Clover Bee",
		Description = "Lucky and green, with a clover sprouting from its head.",
		Look = { Body = "#7ED957", Stripe = "#1F5C2E", Wing = "#D8FFD0", Eye = "#111111", Accessory = "Clover" },
	},
	Daisy = {
		Name = "Daisy Bee",
		Description = "Wears a fresh daisy like a hat.",
		Look = { Body = "#FFFFFF", Stripe = "#FFC928", Wing = "#FFFBE0", Eye = "#111111", Antenna = "#E0A800", Accessory = "Daisy" },
	},
	Strawberry = {
		Name = "Strawberry Bee",
		Description = "Red, seeded and sweet, with a leafy cap.",
		Look = { Body = "#FF3B5C", Stripe = "#2E8B3A", Wing = "#FFD6DE", Eye = "#111111", Antenna = "#2E8B3A", Accessory = "Strawberry" },
	},
	Panda = {
		Name = "Panda Bee",
		Description = "Round ears, eye patches and a love of bamboo honey.",
		Look = { Body = "#FFFFFF", Stripe = "#111111", Wing = "#E8F4FF", Eye = "#111111", Antenna = "#111111", Accessory = "Panda" },
	},
	Knight = {
		Name = "Knight Bee",
		Description = "Armoured in steel, with a plumed helmet.",
		Look = { Body = "#B9C2CC", Stripe = "#2B3A67", Wing = "#DDE6F0", Eye = "#111111", Material = "Metal", Reflectance = 0.15, Accessory = "Knight" },
	},
	Crystal = {
		Name = "Crystal Bee",
		Description = "A see-through gem with glowing shards on its back.",
		Look = { Body = "#9FE8FF", Stripe = "#38B6FF", Wing = "#FFFFFF", Eye = "#FFFFFF", Material = "Glass", Transparency = 0.25, NeonStripes = true, Glow = "#6FD4FF", Accessory = "Crystal" },
	},
	Storm = {
		Name = "Storm Bee",
		Description = "Carries its own thundercloud and crackles with lightning.",
		Look = { Body = "#4A4F5C", Stripe = "#FFF14D", Wing = "#C9D3E0", Eye = "#FFF14D", NeonStripes = true, Glow = "#FFF14D", Accessory = "Storm" },
	},
	Galaxy = {
		Name = "Galaxy Bee",
		Description = "A ring of stars orbits this deep-space bee.",
		Look = { Body = "#2A1458", Stripe = "#FF4DF0", Wing = "#B6A8FF", Eye = "#FFFFFF", NeonStripes = true, Glow = "#C77DFF", Accessory = "Galaxy" },
	},
	Royal = {
		Name = "Royal Bee",
		Description = "Golden, crowned and caped: the queen of the farm.",
		Look = { Body = "#FFD700", Stripe = "#6A0DAD", Wing = "#FFF4C2", Eye = "#111111", Antenna = "#FFD700", Material = "Metal", Reflectance = 0.3, Glow = "#FFE37A", Accessory = "Royal" },
	},
}
-- Production doubles-and-a-half each tier; size grows a little so big bees look important.
for i, tier in Config.BeeOrder do
	local bee = Config.Bees[tier]
	bee.Tier = i
	bee.HoneyPerSecond = (1 / 5) * Config.Economy.MergeMultiplier ^ (i - 1)
	bee.Scale = 0.35 + (i - 1) * 0.025
end

-- Bee flight (client visual only)
Config.BeeFlight = {
	Speed = 9, -- studs per second
	HoverTime = 1.6, -- seconds spent at a flower / the hive
	Bob = 0.6, -- vertical wobble in studs
}

return Config
