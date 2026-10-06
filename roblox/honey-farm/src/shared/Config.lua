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

-- Stations on every plot (Phase 1 = placement only; they become usable in later phases).
Config.Stations = {
	Hive = { Label = "🐝 Hive", Action = "Open Hive" },
	FlowerPatch = { Label = "🌸 Flower Patch", Action = "Inspect" },
	BeeShop = { Label = "🛒 Bee Shop", Action = "Shop" },
	Bottling = { Label = "🍯 Bottling", Action = "Bottle Honey" },
	SellStand = { Label = "💰 Honey Stand", Action = "Collect Cash" },
}

return Config
