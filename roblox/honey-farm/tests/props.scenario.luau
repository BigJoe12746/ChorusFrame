-- Props scenario: Creator Store models dropped into ReplicatedStorage.Props replace the
-- block-built scenery, scaled to each spot, scripts stripped; missing kinds fall back.
-- Globals: M, game, workspace, boot(), check(), tick(), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Stand-ins for Creator Store models: odd sizes, off-centre pivots, and a hidden script.
local function fakeProp(name, w, h, d, withScripts)
	local m = M.Instance.new("Model")
	m.Name = name
	local a = M.Instance.new("Part")
	a.Name = "Trunk"
	a.Size = M.Vector3.new(w * 0.3, h * 0.6, d * 0.3)
	a.CFrame = M.CFrame.new(100, 50 + h * 0.3, -40) -- somewhere random in the world
	a.Parent = m
	local b = M.Instance.new("Part")
	b.Name = "Top"
	b.Size = M.Vector3.new(w, h * 0.4, d)
	b.CFrame = M.CFrame.new(100, 50 + h * 0.8, -40)
	b.Parent = m
	if withScripts then
		local s = M.Instance.new("Script")
		s.Name = "FreeModelVirus"
		s.Parent = b
		local ls = M.Instance.new("LocalScript")
		ls.Parent = m
	end
	return m
end

local props = ReplicatedStorage.Props
fakeProp("Flower", 3, 10, 3, true).Parent = props -- 10 tall; slots want 5–18
fakeProp("Flower2", 6, 2, 6, false).Parent = props -- variant
fakeProp("Hive", 8, 30, 8, true).Parent = props -- way too big; must shrink to 12
fakeProp("Hive2", 8, 20, 8, false).Parent = props -- upgraded looks for Hive Storage level 2 and 3+
fakeProp("Hive3", 8, 10, 8, false).Parent = props
fakeProp("Cottage", 20, 40, 20, false).Parent = props
-- no Tree / Fountain prop: those must fall back to the block versions

-- Hand-made bee models: a store bee renamed "Clover Bee" (with a hidden script) and a "Panda Bee"
local beeModels = ReplicatedStorage.BeeModels
fakeProp("Clover Bee", 4, 9, 6, true).Parent = beeModels
fakeProp("Panda Bee", 4, 9, 6, false).Parent = beeModels
-- the generated bees need the template (same stand-in as phase3)
local function makeTemplate()
	local m = M.Instance.new("Model")
	m.Name = "BeeTemplate"
	local function part(parent, color, size, pos)
		local p = M.Instance.new("Part")
		p.Color = M.Color3.fromRGB(color[1], color[2], color[3])
		p.Size = M.Vector3.new(size[1], size[2], size[3])
		p.CFrame = M.CFrame.new(pos[1], pos[2], pos[3])
		p.Parent = parent
		return p
	end
	local Y, D, W, E = { 255, 255, 0 }, { 27, 42, 53 }, { 159, 243, 233 }, { 17, 17, 17 }
	part(m, Y, { 7.77, 5.44, 3.89 }, { 0, 0, 0 })
	part(m, D, { 7.77, 5.44, 1.55 }, { 0, 0, -2.7 })
	part(m, Y, { 7.77, 5.44, 1.55 }, { 0, 0, -4.3 })
	part(m, W, { 3.89, 0.78, 5.44 }, { -2, 3.1, -3 })
	part(m, E, { 1.55, 3.11, 0.78 }, { -2.3, 0, 2.3 })
	return m
end
local assets = M.Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ReplicatedStorage
makeTemplate().Parent = assets

boot()
local map = workspace.HoneyFarmMap
local plots = map.Plots

local function scripts(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			n += 1
		end
	end
	return n
end

-- flowers in the flower patch use the props
local patch = plots.Plot1.Stations.FlowerPatch
local flowers = {}
for _, c in patch:GetChildren() do
	if c:IsA("Model") and c:GetAttribute("Prop") then
		table.insert(flowers, c)
	end
end
check(#flowers == 9, "all 9 flower-patch flowers are props (" .. #flowers .. ")")
local variants = {}
for _, f in flowers do
	variants[f:GetAttribute("Prop")] = true
	check(scripts(f) == 0, "prop clone has no scripts (" .. f:GetAttribute("Prop") .. ")")
	local cf, size = f:GetBoundingBox()
	check(size.Y >= 4.9 and size.Y <= 7.6, ("flower scaled to its slot height (%.2f)"):format(size.Y))
	local bottom = cf.Position.Y - size.Y / 2
	check(math.abs(bottom - 1) < 0.05, ("flower stands on the soil (bottom y=%.2f)"):format(bottom))
	check(f:FindFirstChild("Trunk") and f.Trunk.Anchored == true and f.Trunk.CanCollide == false, "flower parts anchored, non-colliding")
end
check(variants.Flower and variants.Flower2, "both flower variants get used")
check(props.Flower:FindFirstChild("FreeModelVirus", true) ~= nil, "the original prop in Props is left untouched")

-- hive: prop replaces the block layers, functional parts remain
local hive = plots.Plot1.Stations.Hive
local hiveProp = hive:FindFirstChild("HiveModel")
check(hiveProp ~= nil and hiveProp:GetAttribute("Prop") == "Hive", "hive uses the Hive prop")
check(hive:FindFirstChild("Layer") == nil and hive:FindFirstChild("Top") == nil, "block hive layers not built")
check(hive:FindFirstChild("Base") ~= nil and hive.Base:FindFirstChild("StationPrompt") ~= nil and hive:FindFirstChild("BeeExit") ~= nil, "prompt, label base and bee exit still exist")
local hcf, hsize = hiveProp:GetBoundingBox()
check(math.abs(hsize.Y - 12) < 0.05, ("hive prop shrunk from 30 to 12 tall (%.2f)"):format(hsize.Y))
check(math.abs((hcf.Position.Y - hsize.Y / 2) - 1) < 0.05, "hive prop sits on top of the base plate")
check(scripts(hiveProp) == 0, "hive prop scripts stripped")

-- cottages: prop, named by their title, with the sign label
local village = map.Village
local cottages = 0
for _, c in village:GetChildren() do
	if c:IsA("Model") and c:GetAttribute("Prop") == "Cottage" then
		cottages += 1
		check(c:FindFirstChild("Label", true) ~= nil, c.Name .. " keeps its name sign")
	end
end
check(cottages == 6, "six cottages are props")
check(village:FindFirstChild("Bakery") ~= nil, "cottage keeps its title as the model name")

-- fallbacks: no Tree / Fountain prop -> block versions
local trees, blockTrees = 0, 0
for _, c in map.Scenery:GetChildren() do
	if c.Name == "Tree" then
		trees += 1
		if c:FindFirstChild("Trunk") and c:FindFirstChild("Crown") then
			blockTrees += 1
		end
	end
end
check(trees > 0 and trees == blockTrees, "trees fall back to the block version")
check(village.HoneyFountain:FindFirstChild("HoneyPot") ~= nil, "fountain falls back to the block version")

-- hand-made bee models replace generated ones, by name
local BeeAppearance = req(ReplicatedStorage.HoneyFarm.BeeAppearance)
local VariantBees = req(ReplicatedStorage.HoneyFarm.VariantBees)
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local clover = BeeAppearance.Build(assets.BeeTemplate, "Clover")
check(clover:GetAttribute("Custom") == "Clover Bee" and clover:GetAttribute("Tier") == "Clover" and clover:GetAttribute("Bee") == true, "Clover uses the hand-made model")
check(scripts(clover) == 0, "hand-made bee's hidden script stripped")
local _, cs = clover:GetBoundingBox()
check(math.abs(cs.Y - 2.0 * Config.Bees.Clover.Scale / 0.35) < 0.05, ("hand-made bee scaled to its tier height (%.2f)"):format(cs.Y))
check(clover:FindFirstChild("Accessory") == nil, "no generated accessory on a hand-made bee")
local shinyClover = BeeAppearance.Build(assets.BeeTemplate, "Clover", true)
check(shinyClover:GetAttribute("Custom") == "Clover Bee" and shinyClover:GetAttribute("Shiny") == true and shinyClover:FindFirstChildWhichIsA("Sparkles", true) ~= nil, "shiny falls back to the normal hand-made model and adds sparkles")
local daisy = BeeAppearance.Build(assets.BeeTemplate, "Daisy")
check(daisy:GetAttribute("Custom") == nil and daisy:FindFirstChild("Accessory") ~= nil, "tiers without a hand-made model are still generated")
local panda = BeeAppearance.BuildVariant(assets.BeeTemplate, VariantBees.ByName["Panda Bee"])
check(panda:GetAttribute("Custom") == "Panda Bee" and panda:GetAttribute("Tier") == "Variant" and panda:GetAttribute("Variant") == VariantBees.ByName["Panda Bee"].Id, "egg bee uses its hand-made model")
check(beeModels["Clover Bee"]:FindFirstChild("FreeModelVirus", true) ~= nil, "original BeeModels entry untouched")

-- upgraded hive looks: Hive -> Hive2 -> Hive3 as Hive Storage levels up, growing a little each level
local hiveStation = plots.Plot1.Stations.Hive
check(hiveStation.HiveModel:GetAttribute("Prop") == "Hive", "level 1 uses the base Hive prop")
local upgradeAlice = M.newPlayer(game, 1002, "Upgrader")
upgradeAlice.spawnCharacter()
local plotU = plots["Plot" .. upgradeAlice:GetAttribute("PlotId")]
local su = req(game:GetService("ServerScriptService").HoneyFarm.FarmService).GetState(upgradeAlice)
su.Cash = 1000000
local function hiveHeight()
	local _, sz = plotU.Stations.Hive.HiveModel:GetBoundingBox()
	return sz.Y
end
check(plotU.Stations.Hive.HiveModel:GetAttribute("Prop") == "Hive" and math.abs(hiveHeight() - 12) < 0.05, "fresh owner: base hive at 12 studs")
ReplicatedStorage.Remotes.UpgradeAction.OnServerEvent:Fire(upgradeAlice, "HiveStorage")
check(plotU.Stations.Hive.HiveModel:GetAttribute("Prop") == "Hive2" and math.abs(hiveHeight() - 12 * 1.08) < 0.05, "level 2: Hive2 prop, 8% taller")
ReplicatedStorage.Remotes.UpgradeAction.OnServerEvent:Fire(upgradeAlice, "HiveStorage")
check(plotU.Stations.Hive.HiveModel:GetAttribute("Prop") == "Hive3" and math.abs(hiveHeight() - 12 * 1.16) < 0.05, "level 3: Hive3 prop, 16% taller")
ReplicatedStorage.Remotes.UpgradeAction.OnServerEvent:Fire(upgradeAlice, "HiveStorage")
check(plotU.Stations.Hive.HiveModel:GetAttribute("Prop") == "Hive3" and math.abs(hiveHeight() - 12 * 1.24) < 0.05, "level 4: no Hive4, keeps Hive3 but grows again")
check(plotU.Temp.Upgrades:FindFirstChild("GoldBand") == nil, "no block-hive gold bands on a prop hive")
check(#plotU.Stations.Hive:GetChildren() >= 2 and plotU.Stations.Hive:FindFirstChild("Base") ~= nil and plotU.Stations.Hive:FindFirstChild("BeeExit") ~= nil, "prompt base and bee exit survive the swap")
M.removePlayer(game, upgradeAlice)
check(plotU.Stations.Hive.HiveModel:GetAttribute("Prop") == "Hive" and math.abs(hiveHeight() - 12) < 0.05, "plot released: hive back to level 1 for the next owner")

-- upgrades: a MiniHive falls back to the Hive prop
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local s = req(game:GetService("ServerScriptService").HoneyFarm.FarmService).GetState(alice)
s.Cash = 1000
ReplicatedStorage.Remotes.UpgradeAction.OnServerEvent:Fire(alice, "HiveStorage")
local mini = plots.Plot1.Temp.Upgrades:FindFirstChild("MiniHive")
check(mini ~= nil and mini:GetAttribute("Prop") == "Hive", "mini hive uses the level-1 Hive prop when there's no MiniHive prop")
local _, msize = mini:GetBoundingBox()
check(math.abs(msize.Y - 7) < 0.05, "mini hive scaled to 7 tall")
