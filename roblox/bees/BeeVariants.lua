--!strict
-- BeeVariants (ModuleScript) — put in ReplicatedStorage.
-- The 50 launch bees. Every bee is the same template model, recoloured and dressed up.
--
-- Fields per bee:
--   Body    head + "yellow" stripes          Stripe   the "dark" stripes
--   Wing    wing colour                      Eye      eye colour
--   Antenna antennae colour (defaults to Stripe)
--   Material       Enum.Material name for body/stripes (default "SmoothPlastic")
--   Reflectance    0..1 shine on body/stripes
--   Transparency   0..1 for body/stripes (ghost / crystal bees)
--   Scale          size multiplier (1 = template size)
--   NeonStripes    stripes glow          GlowEyes  eyes glow
--   Effects        any of "Sparkles", "Fire", "Light", "Rainbow", "Float"
--
-- Honey per second, sell value and hatch chance are derived from rarity + position in the tier,
-- so you can rebalance the whole game from the Rarities table.

export type Bee = {
	Id: number,
	Name: string,
	Rarity: string,
	Body: string,
	Stripe: string,
	Wing: string?,
	Eye: string?,
	Antenna: string?,
	Material: string?,
	Reflectance: number?,
	Transparency: number?,
	Scale: number?,
	NeonStripes: boolean?,
	GlowEyes: boolean?,
	Effects: { string }?,
	-- filled in below
	HoneyPerSecond: number,
	SellValue: number,
	HatchWeight: number,
}

local BeeVariants = {}

-- Order matters (lowest -> highest). Weight = total hatch weight shared by the whole tier.
BeeVariants.Rarities = {
	{ Name = "Common", Color = "#B0B0B0", Weight = 60, BaseHoney = 1 },
	{ Name = "Uncommon", Color = "#55D46A", Weight = 25, BaseHoney = 5 },
	{ Name = "Rare", Color = "#3FA9FF", Weight = 10, BaseHoney = 15 },
	{ Name = "Epic", Color = "#B455FF", Weight = 4, BaseHoney = 45 },
	{ Name = "Legendary", Color = "#FFB000", Weight = 0.9, BaseHoney = 150 },
	{ Name = "Mythic", Color = "#FF3B6B", Weight = 0.1, BaseHoney = 600 },
}

local W = "#9FF3E9" -- template wing colour
local E = "#111111" -- template eye colour

local list: { any } = {
	-- COMMON (15)
	{ Name = "Honey Bee", Rarity = "Common", Body = "#FFFF00", Stripe = "#1B2A35" }, -- the original
	{ Name = "Bumble Bee", Rarity = "Common", Body = "#F2B21B", Stripe = "#222222", Wing = "#CCE8FF", Scale = 1.15 },
	{ Name = "Sunny Bee", Rarity = "Common", Body = "#FFE96B", Stripe = "#5A3A10" },
	{ Name = "Mint Bee", Rarity = "Common", Body = "#8EF0B5", Stripe = "#1F4D3A" },
	{ Name = "Berry Bee", Rarity = "Common", Body = "#E0457B", Stripe = "#3B1028" },
	{ Name = "Sky Bee", Rarity = "Common", Body = "#6EC6FF", Stripe = "#14324D" },
	{ Name = "Orange Bee", Rarity = "Common", Body = "#FF8C1A", Stripe = "#3A2412" },
	{ Name = "Grape Bee", Rarity = "Common", Body = "#9B5DE5", Stripe = "#2A1640" },
	{ Name = "Cocoa Bee", Rarity = "Common", Body = "#8B5A2B", Stripe = "#F2D4A7", Antenna = "#3A2412" },
	{ Name = "Peach Bee", Rarity = "Common", Body = "#FFB38A", Stripe = "#6B3A2A" },
	{ Name = "Lime Bee", Rarity = "Common", Body = "#B6F23B", Stripe = "#2E4A10" },
	{ Name = "Bubblegum Bee", Rarity = "Common", Body = "#FF8AD8", Stripe = "#5A2049" },
	{ Name = "Stone Bee", Rarity = "Common", Body = "#9AA0A6", Stripe = "#3C4044", Material = "Slate" },
	{ Name = "Leaf Bee", Rarity = "Common", Body = "#4CAF50", Stripe = "#1B3D1E", Wing = "#C8F7C5" },
	{ Name = "Cloud Bee", Rarity = "Common", Body = "#F5F7FA", Stripe = "#A8B5C4", Wing = "#FFFFFF" },

	-- UNCOMMON (12)
	{ Name = "Rose Bee", Rarity = "Uncommon", Body = "#FF5C7A", Stripe = "#FFFFFF", Antenna = "#7A1F33" },
	{ Name = "Ocean Bee", Rarity = "Uncommon", Body = "#1E88E5", Stripe = "#0D2A4A", Wing = "#7FDBFF" },
	{ Name = "Cherry Bee", Rarity = "Uncommon", Body = "#D7263D", Stripe = "#1B1B1B" },
	{ Name = "Lavender Bee", Rarity = "Uncommon", Body = "#C3A6FF", Stripe = "#4B3B78", Wing = "#E6DAFF" },
	{ Name = "Pumpkin Bee", Rarity = "Uncommon", Body = "#FF7518", Stripe = "#2F4F1F", Antenna = "#2F4F1F" },
	{ Name = "Cactus Bee", Rarity = "Uncommon", Body = "#5BAA5B", Stripe = "#F0E68C", Antenna = "#2E5A2E" },
	{ Name = "Coral Bee", Rarity = "Uncommon", Body = "#FF7F6A", Stripe = "#2B6E78" },
	{ Name = "Banana Bee", Rarity = "Uncommon", Body = "#FFE135", Stripe = "#6B4F1D", Scale = 1.05 },
	{ Name = "Panda Bee", Rarity = "Uncommon", Body = "#FFFFFF", Stripe = "#111111", Scale = 1.1 },
	{ Name = "Tiger Bee", Rarity = "Uncommon", Body = "#FF8C00", Stripe = "#101010", Scale = 1.1 },
	{ Name = "Blueberry Bee", Rarity = "Uncommon", Body = "#3F51B5", Stripe = "#9FA8DA" },
	{ Name = "Snow Bee", Rarity = "Uncommon", Body = "#E8F6FF", Stripe = "#7FB8E0", Material = "Ice", Wing = "#FFFFFF" },

	-- RARE (10)
	{ Name = "Ruby Bee", Rarity = "Rare", Body = "#E0115F", Stripe = "#5A0020", Reflectance = 0.2, GlowEyes = true, Eye = "#FF9EC4" },
	{ Name = "Sapphire Bee", Rarity = "Rare", Body = "#0F52BA", Stripe = "#08214A", Reflectance = 0.2, Wing = "#A9D4FF" },
	{ Name = "Emerald Bee", Rarity = "Rare", Body = "#50C878", Stripe = "#0B3D22", Reflectance = 0.2 },
	{ Name = "Amethyst Bee", Rarity = "Rare", Body = "#9966CC", Stripe = "#3A1F5C", Reflectance = 0.2, Wing = "#E0C8FF" },
	{ Name = "Copper Bee", Rarity = "Rare", Body = "#B87333", Stripe = "#4A2A12", Material = "Metal" },
	{ Name = "Frost Bee", Rarity = "Rare", Body = "#BDEFFF", Stripe = "#2D6FA3", Material = "Ice", Wing = "#FFFFFF", Effects = { "Sparkles" } },
	{ Name = "Lava Bee", Rarity = "Rare", Body = "#2B1B17", Stripe = "#FF4500", NeonStripes = true, Eye = "#FF8800", GlowEyes = true },
	{ Name = "Toxic Bee", Rarity = "Rare", Body = "#1A1A1A", Stripe = "#7CFC00", NeonStripes = true, Wing = "#B6FF8A" },
	{ Name = "Candy Bee", Rarity = "Rare", Body = "#FF6EC7", Stripe = "#FFFFFF", Wing = "#FFD1F0", Antenna = "#FF2E9A" },
	{ Name = "Night Bee", Rarity = "Rare", Body = "#1A1A40", Stripe = "#6A5ACD", Eye = "#FFFF66", GlowEyes = true },

	-- EPIC (7)
	{ Name = "Gold Bee", Rarity = "Epic", Body = "#FFD700", Stripe = "#7A5C00", Material = "Metal", Reflectance = 0.3, Effects = { "Sparkles" } },
	{ Name = "Silver Bee", Rarity = "Epic", Body = "#C0C0C0", Stripe = "#404040", Material = "Metal", Reflectance = 0.35 },
	{ Name = "Crystal Bee", Rarity = "Epic", Body = "#AEEFFF", Stripe = "#5FC8E8", Material = "Glass", Transparency = 0.25, Wing = "#FFFFFF", Effects = { "Light" } },
	{ Name = "Galaxy Bee", Rarity = "Epic", Body = "#2E1A47", Stripe = "#00E5FF", NeonStripes = true, Effects = { "Sparkles" } },
	{ Name = "Ghost Bee", Rarity = "Epic", Body = "#FFFFFF", Stripe = "#CFE8FF", Transparency = 0.45, Wing = "#FFFFFF", Eye = "#66CCFF", GlowEyes = true, Effects = { "Float" } },
	{ Name = "Electric Bee", Rarity = "Epic", Body = "#1C1C3C", Stripe = "#FFFF33", NeonStripes = true, Effects = { "Light" } },
	{ Name = "Shadow Bee", Rarity = "Epic", Body = "#0A0A0A", Stripe = "#3D0066", NeonStripes = true, Eye = "#FF0000", GlowEyes = true },

	-- LEGENDARY (4)
	{ Name = "Rainbow Bee", Rarity = "Legendary", Body = "#FFFFFF", Stripe = "#FF0000", NeonStripes = true, Scale = 1.2, Effects = { "Rainbow", "Sparkles" } },
	{ Name = "Phoenix Bee", Rarity = "Legendary", Body = "#FF4500", Stripe = "#FFD700", NeonStripes = true, Wing = "#FFB347", Scale = 1.2, Effects = { "Fire", "Light" } },
	{ Name = "Diamond Bee", Rarity = "Legendary", Body = "#E6FBFF", Stripe = "#9BE7FF", Material = "Glass", Reflectance = 0.5, Wing = "#FFFFFF", Scale = 1.2, Effects = { "Sparkles", "Light" } },
	{ Name = "Royal Bee", Rarity = "Legendary", Body = "#6A0DAD", Stripe = "#FFD700", Antenna = "#FFD700", Material = "SmoothPlastic", Scale = 1.3, Effects = { "Sparkles" } },

	-- MYTHIC (2)
	{ Name = "Cosmic Bee", Rarity = "Mythic", Body = "#120A2E", Stripe = "#FF00FF", NeonStripes = true, Eye = "#FFFFFF", GlowEyes = true, Scale = 1.4, Effects = { "Rainbow", "Sparkles", "Light", "Float" } },
	{ Name = "Golden Queen Bee", Rarity = "Mythic", Body = "#FFD700", Stripe = "#FFF4B0", NeonStripes = true, Material = "Metal", Reflectance = 0.4, Antenna = "#FFD700", Wing = "#FFF8DC", Scale = 1.5, Effects = { "Sparkles", "Fire", "Light", "Float" } },
}

-- Derive id + economy numbers.
local rarityIndex: { [string]: any } = {}
local tierCount: { [string]: number } = {}
for _, r in BeeVariants.Rarities do
	rarityIndex[r.Name] = r
	tierCount[r.Name] = 0
end
for _, b in list do
	assert(rarityIndex[b.Rarity], "Unknown rarity on " .. b.Name)
	tierCount[b.Rarity] += 1
end

local seen: { [string]: number } = {}
BeeVariants.List = {} :: { Bee }
BeeVariants.ByName = {} :: { [string]: Bee }
for i, b in list do
	local r = rarityIndex[b.Rarity]
	seen[b.Rarity] = (seen[b.Rarity] or 0) + 1
	local step = seen[b.Rarity] - 1 -- later bees in a tier are a little better
	b.Id = i
	b.Wing = b.Wing or W
	b.Eye = b.Eye or E
	b.Antenna = b.Antenna or b.Stripe
	b.HoneyPerSecond = math.floor(r.BaseHoney * (1 + step * 0.15) * 10 + 0.5) / 10
	b.SellValue = math.floor(b.HoneyPerSecond * 60)
	b.HatchWeight = r.Weight / tierCount[b.Rarity]
	BeeVariants.List[i] = b
	BeeVariants.ByName[b.Name] = b
end

function BeeVariants.GetRarity(name: string)
	return rarityIndex[name]
end

-- Weighted random roll (e.g. when an egg hatches). Pass your own Random for luck boosts/tests.
function BeeVariants.Roll(rng: Random?, luck: number?): Bee
	rng = rng or Random.new()
	luck = luck or 1 -- >1 shifts odds toward rarer bees
	local total = 0
	local weights = table.create(#BeeVariants.List)
	for i, b in BeeVariants.List do
		local tier = table.find(BeeVariants.Rarities, rarityIndex[b.Rarity]) :: number
		local w = b.HatchWeight * ((luck :: number) ^ (tier - 1))
		weights[i] = w
		total += w
	end
	local pick = (rng :: Random):NextNumber() * total
	for i, w in weights do
		pick -= w
		if pick <= 0 then
			return BeeVariants.List[i]
		end
	end
	return BeeVariants.List[#BeeVariants.List]
end

return BeeVariants
