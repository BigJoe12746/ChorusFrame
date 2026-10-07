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
-- One type scale for the whole interface. Every panel title, launcher "tab", in-panel tab,
-- action button, body line and hint reads these, so the UI uses one font and the same sizes
-- everywhere. The launchers stack down the right edge in fixed slots.
Config.UI = {
	Font = Enum.Font.FredokaOne,
	TitleSize = 26, -- panel title bars
	ButtonSize = 22, -- launcher tabs, in-panel tabs, action buttons
	BodySize = 16, -- descriptions and values
	SmallSize = 14, -- hints, footnotes, key badges
	Launcher = { Width = 180, Height = 48, Right = 14, Top = 12, Gap = 8 },
	TabHeight = 44, -- tabs inside panels
}
function Config.UI.LauncherPosition(slot: number): UDim2
	local l = Config.UI.Launcher
	return UDim2.new(1, -l.Right, 0, l.Top + (slot - 1) * (l.Height + l.Gap))
end
function Config.UI.LauncherSize(): UDim2
	return UDim2.fromOffset(Config.UI.Launcher.Width, Config.UI.Launcher.Height)
end

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
Config.HiveHeight = 12 -- a Creator Store hive prop is scaled to this at level 1...
Config.HiveGrowthPerLevel = 0.08 -- ...and grows this much per Hive Storage level (max +60%)
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

Config.Rebirth = {
	BaseCost = 500,
	CostGrowth = 1.8,
	ProductionMultiplier = 1.75,
	KeepVariants = true, -- egg bees (the collection) survive a rebirth
}

-- Eggs, shiny merges (Phase 8) ------------------------------------------------------
Config.Economy.ShinyChance = 0.05 -- a merge result is shiny this often (or if a parent was shiny)
Config.Economy.ShinyMultiplier = 1.5 -- shiny bees make this x the normal rate

-- Eggs sold in the Bee Shop. Odds are weights: a "Kind" is a ladder tier (Starter, Clover, ...)
-- or a variant rarity (Common, Uncommon, Rare, Epic, Legendary, Mythic) that hatches one of the
-- 50 VariantBees of that rarity. The shop shows these odds to the player as percentages.
Config.Eggs = {
	Order = { "Basic", "Golden", "Royal" },
	Basic = {
		Name = "Basic Egg", Icon = "🥚", Price = 100, Color = "#F5EBD8",
		Odds = { { Kind = "Starter", Weight = 55 }, { Kind = "Clover", Weight = 25 }, { Kind = "Common", Weight = 15 }, { Kind = "Uncommon", Weight = 4.5 }, { Kind = "Rare", Weight = 0.5 } },
	},
	Golden = {
		Name = "Golden Egg", Icon = "🟡", Price = 2500, Color = "#FFD75E",
		Odds = { { Kind = "Daisy", Weight = 35 }, { Kind = "Strawberry", Weight = 25 }, { Kind = "Uncommon", Weight = 20 }, { Kind = "Rare", Weight = 15 }, { Kind = "Epic", Weight = 4.5 }, { Kind = "Legendary", Weight = 0.5 } },
	},
	Royal = {
		Name = "Royal Egg", Icon = "👑", Price = 40000, Color = "#C58CFF",
		Odds = { { Kind = "Knight", Weight = 30 }, { Kind = "Crystal", Weight = 25 }, { Kind = "Rare", Weight = 20 }, { Kind = "Epic", Weight = 15 }, { Kind = "Legendary", Weight = 8 }, { Kind = "Mythic", Weight = 2 } },
	},
}

Config.Progression = {
	CashPerJar = Config.Economy.JarValue,
	HoneyPerSecondBase = 0.2,
	BeeTierGrowth = Config.Economy.MergeMultiplier,
	BeeMergeInputs = 2,
	BeeMergeMultiplier = Config.Economy.MergeMultiplier,
	StarterBeeCostBase = Config.Economy.BeeBasePrice,
	StarterBeeCostGrowth = Config.Economy.BeePriceGrowth,
	LifetimeLedgerVersion = 3,
}
Config.Progression.BeeTierGrowth = Config.Economy.MergeMultiplier

function Config.Progression.TierHoneyPerSecond(tierIndex: number): number
	return Config.Progression.HoneyPerSecondBase * Config.Progression.BeeTierGrowth ^ math.max(0, tierIndex - 1)
end

function Config.Progression.PotentialCashPerSecond(honeyPerSecond: number, productionMultiplier: number, rebirthMultiplier: number): number
	return honeyPerSecond * productionMultiplier * rebirthMultiplier * Config.Progression.CashPerJar
end

function Config.Progression.RebirthMultiplier(rebirths: number, multiplier: number?): number
	return (multiplier or Config.Rebirth.ProductionMultiplier) ^ math.max(0, rebirths)
end

function Config.Progression.RebirthCost(rebirths: number, baseCost: number?, growth: number?): number
	return math.floor((baseCost or Config.Rebirth.BaseCost) * (growth or Config.Rebirth.CostGrowth) ^ math.max(0, rebirths) + 0.5)
end

function Config.Progression.NextRebirthMultiplier(rebirths: number, multiplier: number?): number
	return Config.Progression.RebirthMultiplier(rebirths + 1, multiplier)
end

function Config.Progression.BeePurchaseCost(purchases: number, basePrice: number?, growth: number?): number
	return math.floor((basePrice or Config.Economy.BeeBasePrice) * (growth or Config.Economy.BeePriceGrowth) ^ math.max(0, purchases) + 0.5)
end

function Config.Progression.UpgradePrice(id: string, level: number): number?
	local upgrade = Config.Upgrades[id]
	if not upgrade or level < 1 or level >= #upgrade.Levels then return nil end
	return upgrade.Prices[level]
end

function Config.Progression.TierMergeGain(tierIndex: number): number
	local current = Config.Progression.TierHoneyPerSecond(tierIndex) * Config.Progression.BeeMergeInputs
	local merged = Config.Progression.TierHoneyPerSecond(tierIndex + 1)
	return if current > 0 then merged / current else 1
end

function Config.Progression.NextTierIndex(tierIndex: number): number?
	return if tierIndex < #Config.BeeOrder then tierIndex + 1 else nil
end

function Config.Progression.TierMergeCost(tierIndex: number): number
	local base = Config.Economy.BeeBasePrice
	return math.floor(base * Config.Progression.BeeMergeMultiplier ^ math.max(0, tierIndex - 1) + 0.5)
end

function Config.Progression.ExpectedTierBeeCount(tierIndex: number): number
	return Config.Progression.BeeMergeInputs ^ math.max(0, tierIndex - 1)
end

function Config.Progression.ExpectedTierBeeInvestment(tierIndex: number): number
	local count = 0
	for purchase = 0, Config.Progression.ExpectedTierBeeCount(tierIndex) - 1 do
		count += Config.Progression.BeePurchaseCost(purchase)
	end
	return count
end

function Config.Progression.RebirthTargetHours(rebirths: number): number
	local cost = Config.Progression.RebirthCost(rebirths)
	local productionRate = Config.Progression.HoneyPerSecondBase * Config.Progression.RebirthMultiplier(rebirths)
	local sustainableRate = math.min(productionRate, Config.Economy.BottlingPerSecond)
	local cashPerSecond = sustainableRate * Config.Progression.CashPerJar
	local expectedHours = cost / math.max(cashPerSecond, 0.001) / 3600
	return math.floor(expectedHours * 10 + 0.5) / 10
end

function Config.Progression.FormattedNumber(value: number): string
	value = math.floor(value + 0.5)
	if value < 1_000 then
		return tostring(value)
	end
	-- Simulator-style ladder: K M B T Qd Qn Sx Sp Oc No Dc (1e3 per step)
	local suffixes = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }
	local scale = 1_000
	for _, suffix in suffixes do
		if value < scale * 1_000 or suffix == "Dc" then
			local text = ("%.2f"):format(value / scale)
			text = text:gsub("0+$", ""):gsub("%.$", "")
			return text .. suffix
		end
		scale *= 1_000
	end
	return tostring(value)
end

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

local advancedBeeNames = {
	"Coral", "Tide", "Frost", "Aurora", "Comet", "Meteor", "Nebula", "Void", "Prism", "Opal",
	"Sapphire", "Ruby", "Emerald", "Topaz", "Amethyst", "Obsidian", "Titan", "Phoenix", "Solar", "Lunar",
	"Tempest", "Inferno", "Glacier", "Thunder", "Spirit", "Phantom", "Shadow", "Radiant", "Celestial", "Eclipse",
	"Infinity", "Ancient", "Mythic", "Divine", "Ethereal", "Ascendant", "Eternal", "Supreme", "Cosmic", "Overlord",
}
local advancedBeeColors = {
	{ "#FF6B35", "#682A20", "#FFD3A5" }, { "#E34234", "#5A1515", "#FFB36A" }, { "#FF7F8A", "#8D2947", "#FFE3E5" }, { "#29B6C8", "#126375", "#B4F6FF" },
	{ "#9CEBFF", "#3B73A8", "#F1FCFF" }, { "#7BE6C4", "#4268A8", "#D9FFF2" }, { "#FF8C42", "#713C9E", "#FFE6B8" }, { "#D7DDE8", "#596579", "#FFFFFF" },
	{ "#7557C8", "#34205F", "#C8B4FF" }, { "#25233D", "#12111E", "#8884B2" }, { "#F4F1FF", "#8657D6", "#E1D4FF" }, { "#B7F1FF", "#5796C8", "#FFFFFF" },
	{ "#246BCE", "#12305E", "#B9DBFF" }, { "#E84855", "#7B2030", "#FFD0C6" }, { "#36B37E", "#165B42", "#C4FFE4" }, { "#FFC247", "#91601E", "#FFF0B8" },
	{ "#A978D1", "#573477", "#E8D1FF" }, { "#474552", "#20202B", "#BEBBCB" }, { "#A8B3C4", "#43506A", "#F2F5FA" }, { "#FF5D73", "#802C45", "#FFD6A4" },
	{ "#FFD34D", "#9B641C", "#FFF4B0" }, { "#8894FF", "#45448F", "#E2E5FF" }, { "#5A87B8", "#283D59", "#C9DDF4" }, { "#FF4D35", "#742513", "#FFC65C" },
	{ "#75DFFF", "#356A9C", "#E0FAFF" }, { "#FFE34F", "#79651C", "#FFF8B8" }, { "#54C7A2", "#276A5A", "#D5FFF1" }, { "#AAA7C7", "#56536F", "#EEEAFE" },
	{ "#4A3B62", "#1D172B", "#B29CDF" }, { "#FFED8A", "#B85A3C", "#FFF9D7" }, { "#67E2D0", "#356B92", "#E4FFFB" }, { "#B694FF", "#583F98", "#E9DEFF" },
	{ "#D2F65A", "#597629", "#F4FFD1" }, { "#4FD1E8", "#255C88", "#D7FAFF" }, { "#F1B0FF", "#763A8C", "#FFE6FF" }, { "#FFB457", "#844B25", "#FFF0D2" },
	{ "#B5F6D1", "#3F8163", "#E7FFF1" }, { "#F6E7A1", "#82713D", "#FFFAE0" }, { "#FFFFFF", "#A96B35", "#FFF1C9" }, { "#FFDF55", "#593C8F", "#FFF4BB" },
}
for index, name in advancedBeeNames do
	local colors = advancedBeeColors[index]
	local tierName = name
	table.insert(Config.BeeOrder, tierName)
	Config.Bees[tierName] = {
		Name = name .. " Bee",
		Description = if index == 1 then name .. "-tier bee. Merge two Royal Bees to discover it." else name .. "-tier bee. Merge two " .. advancedBeeNames[index - 1] .. " bees to discover it.",
		Look = { Body = colors[1], Stripe = colors[2], Wing = colors[3], Eye = "#111111", Antenna = colors[2], Glow = colors[1] },
	}
end

-- Merging two bees into the next tier preserves the total base production of both inputs.
for i, tier in Config.BeeOrder do
	local bee = Config.Bees[tier]
	bee.Tier = i
	bee.HoneyPerSecond = Config.Progression.TierHoneyPerSecond(i)
	bee.Scale = 0.35 + (i - 1) * 0.025
end

-- Farm upgrades (Phase 4). Levels[1] is the starting value (free); Prices[i] is the
-- cost of going from level i to level i+1. Edit these two lists to rebalance.
Config.Upgrades = {
	Order = { "Production", "HoneyFlow", "HiveStorage", "Backpack", "BottlingSpeed", "BeeSlots" },
	-- Image: the upgrade's logo (assets/ui/upgrades/<Id>.png). Upload each PNG in Studio
	-- (Asset Manager → Import) and paste its id here as "rbxassetid://<id>"; an empty
	-- string shows the emoji Icon instead.
	Production = {
		Name = "Bee Production",
		Icon = "🐝",
		Image = "", -- assets/ui/upgrades/Production.png (bee + honey drop + arrow)
		Description = "Every bee makes more honey.",
		Format = "x%.2g",
		Levels = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6.5, 8 },
		Prices = { 120, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000 },
	},
	HoneyFlow = {
		Name = "Honey Flow",
		Icon = "🍯",
		Image = "", -- no logo yet
		Description = "All honey production is boosted.",
		Format = "x%.2g",
		Levels = { 1, 1.15, 1.3, 1.5, 1.75, 2, 2.4, 3 },
		Prices = { 150, 350, 800, 1800, 4000, 9000, 20000 },
	},
	HiveStorage = {
		Name = "Hive Storage",
		Icon = "🏠",
		Image = "", -- assets/ui/upgrades/HiveStorage.png (hive + arrow)
		Description = "The hive holds more honey before the bees stop.",
		Format = "%d honey",
		Levels = { 50, 120, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000 },
		Prices = { 80, 160, 320, 650, 1300, 2600, 5200, 10400, 20800 },
	},
	Backpack = {
		Name = "Backpack",
		Icon = "🎒",
		Image = "rbxassetid://124300905660565", -- assets/ui/upgrades/Backpack.png (uploaded by Lemonade)
		Description = "Carry more honey per trip.",
		Format = "%d honey",
		Levels = { 50, 100, 200, 400, 800, 1600, 3200, 6400, 12800 },
		Prices = { 60, 120, 240, 480, 960, 1920, 3840, 7680 },
	},
	BottlingSpeed = {
		Name = "Bottling Speed",
		Icon = "🍯",
		Image = "", -- assets/ui/upgrades/BottlingSpeed.png (jar on conveyor + lightning)
		Description = "The machine fills jars faster.",
		Format = "%g jars/s",
		Levels = { 1, 2, 3, 5, 8, 12, 20, 30, 50 },
		Prices = { 100, 220, 450, 900, 1800, 3600, 7200, 14400 },
	},
	BeeSlots = {
		Name = "Bee Slots",
		Icon = "➕",
		Image = "", -- assets/ui/upgrades/BeeSlots.png (two bees + plus)
		Description = "Keep more bees on the farm at once.",
		Format = "%d bees",
		Levels = { 8, 10, 12, 14, 16, 18, 20 },
		Prices = { 200, 600, 1500, 3500, 7500, 15000 },
	},
}

-- Saving (Phase 5)
Config.Save = {
	StoreName = "HoneyFarm_v1", -- change to wipe everyone's progress (e.g. a reset)
	Version = 1, -- bump when the save format changes
	AutosaveInterval = 60, -- seconds
	OfflineCapHours = 8, -- offline honey is credited for at most this long
	LoadRetries = 3,
}

-- New-player introduction (Phase 6). The server advances the step when the real action
-- succeeds; the client highlights `Station` and shows the text.
export type TutorialStep = { Station: string, Title: string, Body: string, WaitBody: string? }
Config.Tutorial = {
	Reward = 50, -- cash for finishing the introduction
	Steps = {
		{ Station = "Hive", Title = "Collect your honey", Body = "Your bee is filling the hive. Step on the glowing floor plate beside the hive to collect (it also upgrades hive storage).", WaitBody = "Your bee is making honey… the hive fills 1 honey every 5 seconds." },
		{ Station = "Bottling", Title = "Bottle it", Body = "Take the honey to the Bottling machine and step on its glowing floor plate to deposit it. Jars ride the belt to the stand." },
		{ Station = "SellStand", Title = "Collect your cash", Body = "Every jar is worth $5 at the Honey Stand. Step on the floor plate in front of the stand to collect." },
		{ Station = "BeeShop", Title = "Buy a second bee", Body = "Open the Bee Shop and buy another Starter Bee for $25. Keep collecting if you're short!" },
		{ Station = "BeeShop", Title = "Make your first merge", Body = "In the Bee Shop, tap both Starter Bees and press Merge to make a Clover Bee (2.5× honey)." },
	} :: { TutorialStep },
}

-- Sounds. The rbxasset:// ones ship inside the Roblox client, so they always play.
-- Buzz is empty by default: paste an asset id from the Creator Store (search "bee buzz loop")
-- as "rbxassetid://123456" to give the bees a gentle hum.
Config.Sounds = {
	Collect = "rbxasset://sounds/electronicpingshort.wav",
	Deposit = "rbxasset://sounds/swoosh.wav",
	Cash = "rbxasset://sounds/snap.mp3",
	Merge = "rbxasset://sounds/victory.wav",
	Click = "rbxasset://sounds/button.wav",
	Deny = "rbxasset://sounds/electronicpingshort.wav", -- played at low pitch as the "can't afford" buzz
	Buzz = "", -- e.g. "rbxassetid://..." (looping bee hum), left off until you pick one
	BuzzVolume = 0.12,
	-- Background music (assets/audio/Honey_Harvest.mp3). Upload it in Studio (Asset Manager →
	-- Import, audio) and paste the id as "rbxassetid://<id>"; empty = no music.
	Music = "",
	MusicVolume = 0.35,
}

-- Robux cash shop. Amounts are the cash granted; Robux prices are what the player pays.
-- ProductId stays 0 until a Developer Product is created on the Roblox site and its id is pasted here.
Config.Shop = {
	{ Id = "Handful", Name = "Handful of Cash", Amount = 1000, Robux = 25, ProductId = 0 },
	{ Id = "Jar", Name = "Jar of Cash", Amount = 10000, Robux = 99, ProductId = 0 },
	{ Id = "Barrel", Name = "Barrel of Cash", Amount = 100000, Robux = 249, ProductId = 0 },
	{ Id = "Vault", Name = "Honey Vault", Amount = 1000000, Robux = 499, ProductId = 0 },
	{ Id = "Mountain", Name = "Cash Mountain", Amount = 10000000, Robux = 999, ProductId = 0 },
}

-- Flood protection (Phase 7). A human can't press more than ~10 times a second; anything
-- past these limits is dropped before it reaches the economy code.
Config.Limits = {
	RemotesPerSecond = 25, -- shop / upgrade requests per player
	PromptsPerSecond = 25, -- station presses per player
}

-- Bee flight (client visual only)
Config.BeeFlight = {
	Speed = 9, -- studs per second
	HoverTime = 1.6, -- seconds spent at a flower / the hive
	Bob = 0.6, -- vertical wobble in studs
}

return Config
