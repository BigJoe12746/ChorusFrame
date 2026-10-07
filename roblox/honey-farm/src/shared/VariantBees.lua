--!strict
-- VariantBees (shared ModuleScript): the 50 rare bees that hatch from eggs. They sit outside the
-- merge ladder (they can't be merged) and exist to be collected and shown off. Generated from the
-- day-one variant list; edit freely. Rates: Common ~Clover/Daisy, Uncommon ~Strawberry, Rare ~Panda/Knight,
-- Epic ~Crystal, Legendary ~Storm/Galaxy, Mythic ~Royal and beyond.

local VariantBees = {}

VariantBees.Rarities = {
	{ Name = "Common", Color = "#B0B0B0" },
	{ Name = "Uncommon", Color = "#55D46A" },
	{ Name = "Rare", Color = "#3FA9FF" },
	{ Name = "Epic", Color = "#B455FF" },
	{ Name = "Legendary", Color = "#FFB000" },
	{ Name = "Mythic", Color = "#FF3B6B" },
}

-- Index = variant id (saved as "V<id>"). Look fields match Config.Bees[...].Look.
VariantBees.List = {
	{ Id = 1, Name = "Honey Bee", Rarity = "Common", HoneyPerSecond = 0.6, Scale = 0.38, Sparkles = false, Look = { Body = "#FFFF00", Stripe = "#1B2A35", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 2, Name = "Bumble Bee", Rarity = "Common", HoneyPerSecond = 0.66, Scale = 0.38, Sparkles = false, Look = { Body = "#F2B21B", Stripe = "#222222", Wing = "#CCE8FF", Eye = "#111111" } },
	{ Id = 3, Name = "Sunny Bee", Rarity = "Common", HoneyPerSecond = 0.72, Scale = 0.38, Sparkles = false, Look = { Body = "#FFE96B", Stripe = "#5A3A10", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 4, Name = "Mint Bee", Rarity = "Common", HoneyPerSecond = 0.78, Scale = 0.38, Sparkles = false, Look = { Body = "#8EF0B5", Stripe = "#1F4D3A", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 5, Name = "Berry Bee", Rarity = "Common", HoneyPerSecond = 0.84, Scale = 0.38, Sparkles = false, Look = { Body = "#E0457B", Stripe = "#3B1028", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 6, Name = "Sky Bee", Rarity = "Common", HoneyPerSecond = 0.9, Scale = 0.38, Sparkles = false, Look = { Body = "#6EC6FF", Stripe = "#14324D", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 7, Name = "Orange Bee", Rarity = "Common", HoneyPerSecond = 0.96, Scale = 0.38, Sparkles = false, Look = { Body = "#FF8C1A", Stripe = "#3A2412", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 8, Name = "Grape Bee", Rarity = "Common", HoneyPerSecond = 1.02, Scale = 0.38, Sparkles = false, Look = { Body = "#9B5DE5", Stripe = "#2A1640", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 9, Name = "Cocoa Bee", Rarity = "Common", HoneyPerSecond = 1.08, Scale = 0.38, Sparkles = false, Look = { Body = "#8B5A2B", Stripe = "#F2D4A7", Wing = "#9FF3E9", Eye = "#111111", Antenna = "#3A2412" } },
	{ Id = 10, Name = "Peach Bee", Rarity = "Common", HoneyPerSecond = 1.14, Scale = 0.38, Sparkles = false, Look = { Body = "#FFB38A", Stripe = "#6B3A2A", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 11, Name = "Lime Bee", Rarity = "Common", HoneyPerSecond = 1.2, Scale = 0.38, Sparkles = false, Look = { Body = "#B6F23B", Stripe = "#2E4A10", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 12, Name = "Bubblegum Bee", Rarity = "Common", HoneyPerSecond = 1.26, Scale = 0.38, Sparkles = false, Look = { Body = "#FF8AD8", Stripe = "#5A2049", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 13, Name = "Stone Bee", Rarity = "Common", HoneyPerSecond = 1.32, Scale = 0.38, Sparkles = false, Look = { Body = "#9AA0A6", Stripe = "#3C4044", Wing = "#9FF3E9", Eye = "#111111", Material = "Slate" } },
	{ Id = 14, Name = "Leaf Bee", Rarity = "Common", HoneyPerSecond = 1.38, Scale = 0.38, Sparkles = false, Look = { Body = "#4CAF50", Stripe = "#1B3D1E", Wing = "#C8F7C5", Eye = "#111111" } },
	{ Id = 15, Name = "Cloud Bee", Rarity = "Common", HoneyPerSecond = 1.44, Scale = 0.38, Sparkles = false, Look = { Body = "#F5F7FA", Stripe = "#A8B5C4", Wing = "#FFFFFF", Eye = "#111111" } },
	{ Id = 16, Name = "Rose Bee", Rarity = "Uncommon", HoneyPerSecond = 3.0, Scale = 0.41, Sparkles = false, Look = { Body = "#FF5C7A", Stripe = "#FFFFFF", Wing = "#9FF3E9", Eye = "#111111", Antenna = "#7A1F33" } },
	{ Id = 17, Name = "Ocean Bee", Rarity = "Uncommon", HoneyPerSecond = 3.3, Scale = 0.41, Sparkles = false, Look = { Body = "#1E88E5", Stripe = "#0D2A4A", Wing = "#7FDBFF", Eye = "#111111" } },
	{ Id = 18, Name = "Cherry Bee", Rarity = "Uncommon", HoneyPerSecond = 3.6, Scale = 0.41, Sparkles = false, Look = { Body = "#D7263D", Stripe = "#1B1B1B", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 19, Name = "Lavender Bee", Rarity = "Uncommon", HoneyPerSecond = 3.9, Scale = 0.41, Sparkles = false, Look = { Body = "#C3A6FF", Stripe = "#4B3B78", Wing = "#E6DAFF", Eye = "#111111" } },
	{ Id = 20, Name = "Pumpkin Bee", Rarity = "Uncommon", HoneyPerSecond = 4.2, Scale = 0.41, Sparkles = false, Look = { Body = "#FF7518", Stripe = "#2F4F1F", Wing = "#9FF3E9", Eye = "#111111", Antenna = "#2F4F1F" } },
	{ Id = 21, Name = "Cactus Bee", Rarity = "Uncommon", HoneyPerSecond = 4.5, Scale = 0.41, Sparkles = false, Look = { Body = "#5BAA5B", Stripe = "#F0E68C", Wing = "#9FF3E9", Eye = "#111111", Antenna = "#2E5A2E" } },
	{ Id = 22, Name = "Coral Bee", Rarity = "Uncommon", HoneyPerSecond = 4.8, Scale = 0.41, Sparkles = false, Look = { Body = "#FF7F6A", Stripe = "#2B6E78", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 23, Name = "Banana Bee", Rarity = "Uncommon", HoneyPerSecond = 5.1, Scale = 0.41, Sparkles = false, Look = { Body = "#FFE135", Stripe = "#6B4F1D", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 24, Name = "Panda Bee", Rarity = "Uncommon", HoneyPerSecond = 5.4, Scale = 0.41, Sparkles = false, Look = { Body = "#FFFFFF", Stripe = "#111111", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 25, Name = "Tiger Bee", Rarity = "Uncommon", HoneyPerSecond = 5.7, Scale = 0.41, Sparkles = false, Look = { Body = "#FF8C00", Stripe = "#101010", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 26, Name = "Blueberry Bee", Rarity = "Uncommon", HoneyPerSecond = 6.0, Scale = 0.41, Sparkles = false, Look = { Body = "#3F51B5", Stripe = "#9FA8DA", Wing = "#9FF3E9", Eye = "#111111" } },
	{ Id = 27, Name = "Snow Bee", Rarity = "Uncommon", HoneyPerSecond = 6.3, Scale = 0.41, Sparkles = false, Look = { Body = "#E8F6FF", Stripe = "#7FB8E0", Wing = "#FFFFFF", Eye = "#111111", Material = "Ice" } },
	{ Id = 28, Name = "Ruby Bee", Rarity = "Rare", HoneyPerSecond = 12.0, Scale = 0.44, Sparkles = false, Look = { Body = "#E0115F", Stripe = "#5A0020", Wing = "#9FF3E9", Eye = "#FF9EC4", Reflectance = 0.2, Glow = "#5A0020" } },
	{ Id = 29, Name = "Sapphire Bee", Rarity = "Rare", HoneyPerSecond = 13.2, Scale = 0.44, Sparkles = false, Look = { Body = "#0F52BA", Stripe = "#08214A", Wing = "#A9D4FF", Eye = "#111111", Reflectance = 0.2 } },
	{ Id = 30, Name = "Emerald Bee", Rarity = "Rare", HoneyPerSecond = 14.4, Scale = 0.44, Sparkles = false, Look = { Body = "#50C878", Stripe = "#0B3D22", Wing = "#9FF3E9", Eye = "#111111", Reflectance = 0.2 } },
	{ Id = 31, Name = "Amethyst Bee", Rarity = "Rare", HoneyPerSecond = 15.6, Scale = 0.44, Sparkles = false, Look = { Body = "#9966CC", Stripe = "#3A1F5C", Wing = "#E0C8FF", Eye = "#111111", Reflectance = 0.2 } },
	{ Id = 32, Name = "Copper Bee", Rarity = "Rare", HoneyPerSecond = 16.8, Scale = 0.44, Sparkles = false, Look = { Body = "#B87333", Stripe = "#4A2A12", Wing = "#9FF3E9", Eye = "#111111", Material = "Metal" } },
	{ Id = 33, Name = "Frost Bee", Rarity = "Rare", HoneyPerSecond = 18.0, Scale = 0.44, Sparkles = true, Look = { Body = "#BDEFFF", Stripe = "#2D6FA3", Wing = "#FFFFFF", Eye = "#111111", Material = "Ice" } },
	{ Id = 34, Name = "Lava Bee", Rarity = "Rare", HoneyPerSecond = 19.2, Scale = 0.44, Sparkles = false, Look = { Body = "#2B1B17", Stripe = "#FF4500", Wing = "#9FF3E9", Eye = "#FF8800", NeonStripes = true, Glow = "#FF4500" } },
	{ Id = 35, Name = "Toxic Bee", Rarity = "Rare", HoneyPerSecond = 20.4, Scale = 0.44, Sparkles = false, Look = { Body = "#1A1A1A", Stripe = "#7CFC00", Wing = "#B6FF8A", Eye = "#111111", NeonStripes = true } },
	{ Id = 36, Name = "Candy Bee", Rarity = "Rare", HoneyPerSecond = 21.6, Scale = 0.44, Sparkles = false, Look = { Body = "#FF6EC7", Stripe = "#FFFFFF", Wing = "#FFD1F0", Eye = "#111111", Antenna = "#FF2E9A" } },
	{ Id = 37, Name = "Night Bee", Rarity = "Rare", HoneyPerSecond = 22.8, Scale = 0.44, Sparkles = false, Look = { Body = "#1A1A40", Stripe = "#6A5ACD", Wing = "#9FF3E9", Eye = "#FFFF66", Glow = "#6A5ACD" } },
	{ Id = 38, Name = "Gold Bee", Rarity = "Epic", HoneyPerSecond = 50.0, Scale = 0.47, Sparkles = true, Look = { Body = "#FFD700", Stripe = "#7A5C00", Wing = "#9FF3E9", Eye = "#111111", Material = "Metal", Reflectance = 0.3 } },
	{ Id = 39, Name = "Silver Bee", Rarity = "Epic", HoneyPerSecond = 55.0, Scale = 0.47, Sparkles = false, Look = { Body = "#C0C0C0", Stripe = "#404040", Wing = "#9FF3E9", Eye = "#111111", Material = "Metal", Reflectance = 0.35 } },
	{ Id = 40, Name = "Crystal Bee", Rarity = "Epic", HoneyPerSecond = 60.0, Scale = 0.47, Sparkles = false, Look = { Body = "#AEEFFF", Stripe = "#5FC8E8", Wing = "#FFFFFF", Eye = "#111111", Material = "Glass", Transparency = 0.25, Glow = "#5FC8E8" } },
	{ Id = 41, Name = "Galaxy Bee", Rarity = "Epic", HoneyPerSecond = 65.0, Scale = 0.47, Sparkles = true, Look = { Body = "#2E1A47", Stripe = "#00E5FF", Wing = "#9FF3E9", Eye = "#111111", NeonStripes = true } },
	{ Id = 42, Name = "Ghost Bee", Rarity = "Epic", HoneyPerSecond = 70.0, Scale = 0.47, Sparkles = false, Look = { Body = "#FFFFFF", Stripe = "#CFE8FF", Wing = "#FFFFFF", Eye = "#66CCFF", Transparency = 0.45, Glow = "#CFE8FF" } },
	{ Id = 43, Name = "Electric Bee", Rarity = "Epic", HoneyPerSecond = 75.0, Scale = 0.47, Sparkles = false, Look = { Body = "#1C1C3C", Stripe = "#FFFF33", Wing = "#9FF3E9", Eye = "#111111", NeonStripes = true, Glow = "#FFFF33" } },
	{ Id = 44, Name = "Shadow Bee", Rarity = "Epic", HoneyPerSecond = 80.0, Scale = 0.47, Sparkles = false, Look = { Body = "#0A0A0A", Stripe = "#3D0066", Wing = "#9FF3E9", Eye = "#FF0000", NeonStripes = true, Glow = "#3D0066" } },
	{ Id = 45, Name = "Rainbow Bee", Rarity = "Legendary", HoneyPerSecond = 200.0, Scale = 0.5, Sparkles = true, Look = { Body = "#FFFFFF", Stripe = "#FF0000", Wing = "#9FF3E9", Eye = "#111111", NeonStripes = true, Glow = "#FF0000" } },
	{ Id = 46, Name = "Phoenix Bee", Rarity = "Legendary", HoneyPerSecond = 220.0, Scale = 0.5, Sparkles = true, Look = { Body = "#FF4500", Stripe = "#FFD700", Wing = "#FFB347", Eye = "#111111", NeonStripes = true, Glow = "#FFD700" } },
	{ Id = 47, Name = "Diamond Bee", Rarity = "Legendary", HoneyPerSecond = 240.0, Scale = 0.5, Sparkles = true, Look = { Body = "#E6FBFF", Stripe = "#9BE7FF", Wing = "#FFFFFF", Eye = "#111111", Material = "Glass", Reflectance = 0.5, Glow = "#9BE7FF" } },
	{ Id = 48, Name = "Royal Bee", Rarity = "Legendary", HoneyPerSecond = 260.0, Scale = 0.56, Sparkles = true, Look = { Body = "#6A0DAD", Stripe = "#FFD700", Wing = "#9FF3E9", Eye = "#111111", Antenna = "#FFD700", Material = "SmoothPlastic" } },
	{ Id = 49, Name = "Cosmic Bee", Rarity = "Mythic", HoneyPerSecond = 900.0, Scale = 0.59, Sparkles = true, Look = { Body = "#120A2E", Stripe = "#FF00FF", Wing = "#9FF3E9", Eye = "#FFFFFF", NeonStripes = true, Glow = "#FF00FF" } },
	{ Id = 50, Name = "Golden Queen Bee", Rarity = "Mythic", HoneyPerSecond = 990.0, Scale = 0.59, Sparkles = true, Look = { Body = "#FFD700", Stripe = "#FFF4B0", Wing = "#FFF8DC", Eye = "#111111", Antenna = "#FFD700", Material = "Metal", Reflectance = 0.4, NeonStripes = true, Glow = "#FFF4B0" } },
}

VariantBees.ByName = {} :: { [string]: any }
VariantBees.ByRarity = {} :: { [string]: { number } }
for _, r in VariantBees.Rarities do
	VariantBees.ByRarity[r.Name] = {}
end
for _, v in VariantBees.List do
	VariantBees.ByName[v.Name] = v
	table.insert(VariantBees.ByRarity[v.Rarity], v.Id)
end

function VariantBees.Get(id: number)
	return VariantBees.List[id]
end

function VariantBees.RarityColor(rarity: string): string
	for _, r in VariantBees.Rarities do
		if r.Name == rarity then
			return r.Color
		end
	end
	return "#FFFFFF"
end

return VariantBees
