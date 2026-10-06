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
fakeProp("Cottage", 20, 40, 20, false).Parent = props
-- no Tree / Fountain prop: those must fall back to the block versions

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

-- upgrades: a MiniHive falls back to the Hive prop
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local s = req(game:GetService("ServerScriptService").HoneyFarm.FarmService).GetState(alice)
s.Cash = 1000
ReplicatedStorage.Remotes.UpgradeAction.OnServerEvent:Fire(alice, "HiveStorage")
local mini = plots.Plot1.Temp.Upgrades:FindFirstChild("MiniHive")
check(mini ~= nil and mini:GetAttribute("Prop") == "Hive", "mini hive uses the Hive prop when there's no MiniHive prop")
local _, msize = mini:GetBoundingBox()
check(math.abs(msize.Y - 7) < 0.05, "mini hive scaled to 7 tall")
