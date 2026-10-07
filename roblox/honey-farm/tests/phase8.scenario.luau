-- Phase 8 scenario: eggs, egg bees, shiny merges and Royal Jelly, through the REAL server scripts.
-- Globals: M, game, workspace, boot(), check(), tick(), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local VariantBees = req(ReplicatedStorage.HoneyFarm.VariantBees)
local BeeAppearance = req(ReplicatedStorage.HoneyFarm.BeeAppearance)
local FarmService = req(game:GetService("ServerScriptService").HoneyFarm.FarmService)

-- a stand-in template so variant models really build (same layout as phase3)
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
	part(m, D, { 7.77, 5.44, 1.55 }, { 0, 0, -5.8 })
	part(m, W, { 3.89, 0.78, 5.44 }, { -2, 3.1, -3 })
	part(m, W, { 3.89, 0.78, 5.44 }, { 2, 3.1, -3 })
	part(m, E, { 1.55, 3.11, 0.78 }, { -2.3, 0, 2.3 })
	part(m, E, { 1.55, 3.11, 0.78 }, { 2.3, 0, 2.3 })
	return m
end
local assets = M.Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ReplicatedStorage
makeTemplate().Parent = assets

-- scripted dice: the server calls FarmService.Roll() for egg kind, egg variant and shiny
local rolls = {}
FarmService.Roll = function()
	return table.remove(rolls, 1) or 0.5
end
local function dice(...)
	rolls = { ... }
end

boot()
local plots = workspace.HoneyFarmMap.Plots

local function lastNote(p)
	local last = ""
	for _, f in Remotes.Notify.fired do
		if f[1] == p then
			last = f[2]
		end
	end
	return last
end
local function has(s, needle)
	return string.find(s, needle, 1, true) ~= nil
end
local function atShop(player, plot)
	player.Character:PivotTo(plot.Stations.BeeShop.Counter.CFrame + M.Vector3.new(0, 3, -4))
end
local function bees(plot)
	local out = {}
	for id, key in string.gmatch(plot:GetAttribute("Bees") or "", "(%d+):([%w%*]+)") do
		table.insert(out, { Id = tonumber(id), Key = key })
	end
	return out
end
local function hatches()
	return Remotes.EggHatched.fired
end

-- config sanity: all 50 variants build, every egg kind resolves
check(#VariantBees.List == 50, "50 egg bees")
local okAll = true
for _, v in VariantBees.List do
	local ok, model = pcall(BeeAppearance.BuildVariant, assets.BeeTemplate, v)
	if not ok or model:GetAttribute("Variant") ~= v.Id then
		okAll = false
		print("  variant failed:", v.Name, model)
	end
end
check(okAll, "all 50 variant models build from the template")
for _, eggName in Config.Eggs.Order do
	for _, o in Config.Eggs[eggName].Odds do
		check(Config.Bees[o.Kind] ~= nil or (VariantBees.ByRarity[o.Kind] and #VariantBees.ByRarity[o.Kind] > 0), ("%s egg: kind %s exists"):format(eggName, o.Kind))
	end
end
local shinyModel = BeeAppearance.Build(assets.BeeTemplate, "Clover", true)
check(shinyModel:GetAttribute("Shiny") == true and shinyModel.Name == "Shiny Clover Bee" and shinyModel:FindFirstChildWhichIsA("Sparkles", true) ~= nil, "shiny model is tagged, named and sparkles")

------------------------------------------------------------------------------
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local plot1 = plots.Plot1
local s = FarmService.GetState(alice)
check(alice:GetAttribute("Rebirths") == 0 and alice:GetAttribute("RebirthCost") == 500, "no rebirths yet; first costs $500")

-- eggs: refused without cash, then hatch a scripted result
atShop(alice, plot1)
Remotes.ShopAction.OnServerEvent:Fire(alice, "Egg", "Basic")
check(#bees(plot1) == 1 and has(lastNote(alice), "need $100"), "egg refused with $25")
s.Cash = 100000
dice(0.998, 0.0) -- Basic odds total 100: Rare is the last 0.5, so 99.8 lands in it; first Rare variant
Remotes.ShopAction.OnServerEvent:Fire(alice, "Egg", "Basic")
local list = bees(plot1)
local rareId = VariantBees.ByRarity.Rare[1]
check(#list == 2 and list[2].Key == "V" .. rareId, "hatched the first Rare variant (V" .. rareId .. ")")
check(s.Cash == 100000 - 100, "$100 charged")
local h = hatches()[#hatches()]
check(h and h[2] == 1 and h[4] == VariantBees.Get(rareId).Name and h[5] == "Rare" and h[6] == true, "EggHatched event: plot, name, rarity, new")
local model = plot1.Temp:FindFirstChild("Bee" .. list[2].Id)
check(model ~= nil and model:GetAttribute("Tier") == "Variant" and model:GetAttribute("Variant") == rareId and model:GetAttribute("PopIn") == true, "variant model spawned on the farm")
check(has(lastNote(alice), "Hatched") and has(lastNote(alice), "new to your collection"), "hatch message")
check(has(plot1:GetAttribute("Discovered"), "V" .. rareId), "variant in the collection attribute")

-- unknown egg / garbage ignored
Remotes.ShopAction.OnServerEvent:Fire(alice, "Egg", "Dragon")
Remotes.ShopAction.OnServerEvent:Fire(alice, "Egg", 42)
check(#bees(plot1) == 2 and s.Cash == 99900, "bad egg names change nothing")

-- egg bee can't merge
Remotes.ShopAction.OnServerEvent:Fire(alice, "Merge", list[1].Id, list[2].Id)
check(#bees(plot1) == 2 and has(lastNote(alice), "one of a kind"), "merging an egg bee is refused")

-- shiny merge with a scripted low roll
Remotes.ShopAction.OnServerEvent:Fire(alice, "Buy") -- second Starter
local starters = {}
for _, b in bees(plot1) do
	if b.Key == "Starter" then
		table.insert(starters, b.Id)
	end
end
dice(0.01)
Remotes.ShopAction.OnServerEvent:Fire(alice, "Merge", starters[1], starters[2])
local afterMerge = bees(plot1)
local shinyKey
for _, b in afterMerge do
	if b.Key == "Clover*" then
		shinyKey = b
	end
end
check(shinyKey ~= nil, "low roll made a shiny Clover")
check(has(lastNote(alice), "SHINY"), "shiny message")
local shinyM = plot1.Temp:FindFirstChild("Bee" .. shinyKey.Id)
check(shinyM and shinyM:GetAttribute("Shiny") == true, "shiny model on the farm")
check(math.abs(plot1:GetAttribute("ProductionRate") - (VariantBees.Get(rareId).HoneyPerSecond + 0.5 * 1.5)) < 1e-9, "production: rare variant + shiny clover (x1.5)")
check(has(plot1:GetAttribute("Discovered"), "Clover*"), "shiny discovery tracked")

-- rebirth: costs cash ($500 first), x1.75 production per rebirth, egg bees survive
Remotes.ReturnToFarm.OnServerEvent:Fire(alice)
s.Cash = 100
Remotes.RebirthAction.OnServerEvent:Fire(alice)
check(alice:GetAttribute("Rebirths") == 0 and has(lastNote(alice), "need $500"), "rebirth refused without $500")
s.Cash = 5000
Remotes.UpgradeAction.OnServerEvent:Fire(alice, "HiveStorage")
FarmService.Tick(0.01)
check(alice:GetAttribute("RebirthCost") == 500, "rebirth cost shown as $500")
Remotes.RebirthAction.OnServerEvent:Fire(alice)
check(alice:GetAttribute("Rebirths") == 1 and math.abs(alice:GetAttribute("RebirthMultiplier") - 1.75) < 1e-9, "rebirth counted; production x1.75")
check(alice:GetAttribute("Cash") == 25, "cash reset to $25")
check(plot1:GetAttribute("HiveCapacity") == 50, "upgrades reset")
local afterRb = bees(plot1)
check(#afterRb == 2 and afterRb[1].Key == "V" .. rareId and afterRb[2].Key == "Starter", "egg bee kept; ladder bees replaced by one Starter")
check(plot1.Temp:FindFirstChild("Bee" .. shinyKey.Id) == nil and plot1.Temp:FindFirstChild("Bee" .. list[2].Id) ~= nil, "shiny model removed, variant model kept (respawned)")
check(plot1.Temp.Upgrades:FindFirstChild("MiniHive") == nil, "upgrade visuals reset")
check(math.abs(plot1:GetAttribute("ProductionRate") - (VariantBees.Get(rareId).HoneyPerSecond + 0.2) * 1.75) < 1e-6, "all bees make x1.75 after rebirth")
check(has(lastNote(alice), "Rebirth 1"), "rebirth message")
check(has(plot1:GetAttribute("Discovered"), "Clover*"), "collection survives rebirth")
check(alice:GetAttribute("RebirthCost") == 900, "next rebirth costs $900")

-- saved and restored
M.removePlayer(game, alice)
local saved = M.datastore.data.player_1001
check(saved.Rebirths == 1 and saved.Bees[1].Variant == rareId, "rebirths and egg bee saved")
local alice2 = M.newPlayer(game, 1001, "Alice")
alice2.spawnCharacter()
check(alice2:GetAttribute("Rebirths") == 1 and bees(plot1)[1].Key == "V" .. rareId and plot1.Temp:FindFirstChild("Bee" .. list[2].Id) ~= nil, "restored: rebirths, egg bee and its model")
check(has(plot1:GetAttribute("Discovered"), "Clover*"), "shiny discovery restored")
