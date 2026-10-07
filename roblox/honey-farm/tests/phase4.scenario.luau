-- Phase 4 scenario: farm upgrades, through the REAL server scripts.
-- Globals from run_sim.py: M, game, workspace, boot(), check(), tick(seconds), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local FarmService = req(game:GetService("ServerScriptService").HoneyFarm.FarmService)

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
local function upgrade(player, id)
	Remotes.UpgradeAction.OnServerEvent:Fire(player, id)
end
local function levels(plot)
	local out = {}
	for id, lvl in string.gmatch(plot:GetAttribute("Upgrades") or "", "(%a+):(%d+)") do
		out[id] = tonumber(lvl)
	end
	return out
end
local function visuals(plot)
	local f = plot.Temp:FindFirstChild("Upgrades")
	local counts = {}
	if f then
		for _, d in f:GetChildren() do
			counts[d.Name] = (counts[d.Name] or 0) + 1
		end
	end
	return counts
end

-- config sanity: every upgrade has prices for every step and values that only go up
for _, id in Config.Upgrades.Order do
	local u = Config.Upgrades[id]
	check(#u.Prices == #u.Levels - 1, id .. ": one price per level step")
	local rising = true
	for i = 2, #u.Levels do
		if u.Levels[i] <= u.Levels[i - 1] or (i <= #u.Prices and u.Prices[i] <= u.Prices[i - 1]) then
			rising = false
		end
	end
	check(rising, id .. ": values and prices rise every level")
end

local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter() -- spawns on her plot
local plot1 = plots.Plot1
local s = FarmService.GetState(alice)
local lv = levels(plot1)
check(lv.Production == 1 and lv.HiveStorage == 1 and lv.Backpack == 1 and lv.BottlingSpeed == 1 and lv.BeeSlots == 1, "all upgrades start at level 1")
check(plot1:GetAttribute("HiveCapacity") == 50 and alice:GetAttribute("BackpackCapacity") == 50 and plot1:GetAttribute("BottlingSpeed") == 1 and plot1:GetAttribute("BeeSlots") == 8 and plot1:GetAttribute("ProductionMultiplier") == 1, "base values replicated")
check(plot1.Temp:FindFirstChild("Upgrades") ~= nil and next(visuals(plot1)) == nil, "no upgrade visuals at level 1")

-- can't afford
upgrade(alice, "HiveStorage")
check(levels(plot1).HiveStorage == 1 and alice:GetAttribute("Cash") == 25, "refused with $25; nothing charged")
check(has(lastNote(alice), "need $80"), "told the price")

-- must be on your plot
s.Cash = 5000
alice.Character:PivotTo(M.CFrame.new(0, 3, 0)) -- village square
upgrade(alice, "HiveStorage")
check(levels(plot1).HiveStorage == 1 and s.Cash == 5000, "refused from the village")
check(has(lastNote(alice), "Go to your farm"), "told to go home")
Remotes.ReturnToFarm.OnServerEvent:Fire(alice)

-- hive storage: value, charge, visuals
upgrade(alice, "HiveStorage")
check(levels(plot1).HiveStorage == 2 and plot1:GetAttribute("HiveCapacity") == 120, "hive storage level 2 -> capacity 120")
check(s.Cash == 5000 - 80, "$80 charged")
check(has(lastNote(alice), "Hive Storage upgraded to 120 honey"), "upgrade message shows the new value")
local v = visuals(plot1)
check(v.MiniHive == 1, "one hive appears in the hive yard")
-- the hive yard grows a block tree; hives hang from its branches instead of standing on the pad
local function treeStats(plot)
	local tree = plot.Temp.Upgrades:FindFirstChild("HiveTree")
	local out = { Trunk = 0, Branch = 0, Leaf = 0, Rope = 0, Root = 0, top = 0 }
	if tree then
		for _, d in tree:GetChildren() do
			out[d.Name] = (out[d.Name] or 0) + 1
			out.top = math.max(out.top, d.Position.Y + d.Size.Y / 2)
		end
	end
	return tree, out
end
local pad = plot1:FindFirstChild("HiveExpansion", true)
local padTop = pad.Position.Y + pad.Size.Y / 2
local tree, t2 = treeStats(plot1)
check(tree ~= nil and tree:GetAttribute("Branches") == 1 and t2.Branch == 3 and t2.Rope == 1, "level 2: a hive tree with one branch and one rope")
check(t2.Trunk >= 6 and t2.Leaf > 5 and t2.Root == 4, "the tree has a block trunk, a leaf crown and roots")
local function hivesHang(plot)
	local ok, lowest = true, math.huge
	for _, d in plot.Temp.Upgrades:GetChildren() do
		if d.Name == "MiniHive" then
			local cf, size = d:GetBoundingBox()
			local bottom = cf.Position.Y - size.Y / 2
			lowest = math.min(lowest, bottom)
			-- hanging: clearly above the pad, and below the tree top
			if bottom < padTop + 3 then
				ok = false
			end
		end
	end
	return ok, lowest
end
local hang2, low2 = hivesHang(plot1)
check(hang2 and low2 < t2.top, "the hive hangs in the air under its branch, not on the pad")
upgrade(alice, "HiveStorage")
local hp = Config.Upgrades.HiveStorage.Prices
check(plot1:GetAttribute("HiveCapacity") == 250 and visuals(plot1).MiniHive == 2 and s.Cash == 5000 - hp[1] - hp[2], ("level 3: capacity 250, two hanging hives, $%d charged"):format(hp[2]))
local tree3, t3 = treeStats(plot1)
check(tree3:GetAttribute("Branches") == 2 and t3.Branch == 6 and t3.Rope == 2 and t3.Trunk == t2.Trunk + 1 and t3.top > t2.top, "level 3: the tree gains a trunk block and a second branch")
local hang3 = hivesHang(plot1)
check(hang3 and visuals(plot1).HiveTree == 1, "both hives hang from the one tree")

-- bottling speed: tanks appear and jars really come out faster
upgrade(alice, "BottlingSpeed")
check(plot1:GetAttribute("BottlingSpeed") == 2 and visuals(plot1).TankModule == 1, "bottling speed 2 adds a tank module")
s.Carried = 20 -- test shortcut: 20 honey conjured straight into the backpack (accounted for below)
local injected = 20
s:Deposit()
tick(1.02)
check(plot1:GetAttribute("JarsOnBelt") == 2 and plot1:GetAttribute("BottlingQueue") == 18, "2 jars per second now")
tick(20)

-- production multiplier
local rateBefore = plot1:GetAttribute("ProductionRate")
upgrade(alice, "Production")
check(math.abs(plot1:GetAttribute("ProductionRate") - rateBefore * 1.25) < 1e-9, "production x1.25 after one upgrade")
check(plot1:GetAttribute("ProductionMultiplier") == 1.25, "multiplier replicated")
check(visuals(plot1).PollenOrb == 1 and visuals(plot1).GoldBand == 2, "a pollen orb appears over the flower patch (and 2 gold bands from hive level 3)")

-- backpack
upgrade(alice, "Backpack")
check(alice:GetAttribute("BackpackCapacity") == 100, "backpack 100")

-- bee slots: 9 bees become possible
s.Cash = 100000
local shopCounter = plot1.Stations.BeeShop.Counter
alice.Character:PivotTo(shopCounter.CFrame + M.Vector3.new(0, 3, -4))
for _ = 1, 8 do
	Remotes.ShopAction.OnServerEvent:Fire(alice, "Buy")
end
check(plot1:GetAttribute("BeeCount") == 8 and has(lastNote(alice), "Bee Slots upgrade"), "8/8 slots: the full message points at the upgrade")
upgrade(alice, "BeeSlots")
check(plot1:GetAttribute("BeeSlots") == 10 and visuals(plot1).LandingBoard == 1, "bee slots 10, one extra landing board")
Remotes.ShopAction.OnServerEvent:Fire(alice, "Buy")
check(plot1:GetAttribute("BeeCount") == 9, "a 9th bee can be bought")

-- rapid presses buy one level each, never skipping or double charging
local before = s.Cash
local lvBefore = levels(plot1).Backpack
upgrade(alice, "Backpack")
upgrade(alice, "Backpack")
local lvAfter = levels(plot1).Backpack
check(lvAfter == lvBefore + 2 and s.Cash == before - Config.Upgrades.Backpack.Prices[lvBefore] - Config.Upgrades.Backpack.Prices[lvBefore + 1], "two presses = two levels at the exact listed prices")

-- max out
local u = Config.Upgrades.Backpack
while levels(plot1).Backpack < #u.Levels do
	s.Cash = 10000000
	upgrade(alice, "Backpack")
end
local cashAtMax = s.Cash
upgrade(alice, "Backpack")
check(levels(plot1).Backpack == #u.Levels and s.Cash == cashAtMax, "maxed upgrade is refused with no charge")
check(has(lastNote(alice), "maximum level"), "maxed message")

-- bad ids are ignored
upgrade(alice, "Jetpack")
upgrade(alice, 42)
upgrade(alice, nil)
check(s.Cash == cashAtMax, "unknown / garbage upgrade ids change nothing")

-- conservation still holds with upgrades in play
local paid = (s.Totals.Earned - Config.Economy.StartCash) / Config.Economy.JarValue
check(s.Totals.Produced + injected == s:HoneyInSystem() + paid, "no honey counted twice with upgrades active")

-- another player can't upgrade Alice's farm, and starts at level 1 himself
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
bob.Character:PivotTo(plot1.SpawnPoint.CFrame)
upgrade(bob, "HiveStorage")
check(levels(plots.Plot2).HiveStorage == 1 and bob:GetAttribute("Cash") == 25, "Bob's press applies to Bob's farm only (refused: not on his plot)")
check(levels(plot1).HiveStorage == 3, "Alice's levels untouched")

-- leaving clears visuals and attributes
M.removePlayer(game, alice)
check(plot1:GetAttribute("Upgrades") == nil and plot1.Temp:FindFirstChild("Upgrades") == nil, "upgrade state and visuals cleared on leave")
local cara = M.newPlayer(game, 3003, "Cara")
cara.spawnCharacter()
check(levels(plot1).HiveStorage == 1 and plot1:GetAttribute("HiveCapacity") == 50, "next owner starts at level 1")
