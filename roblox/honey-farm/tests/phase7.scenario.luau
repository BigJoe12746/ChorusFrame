-- Phase 7 scenario: two players at once, every listed edge case, through the REAL server scripts.
-- Globals: M, game, workspace, boot(), check(), tick(), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local SSS = game:GetService("ServerScriptService")
local SaveService = req(SSS.HoneyFarm.SaveService)
local FarmService = req(SSS.HoneyFarm.FarmService)

local clock = 1700000000
SaveService.Now = function()
	return clock
end

boot()
local plots = workspace.HoneyFarmMap.Plots
local ds = M.datastore

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
local function press(player, plot, station)
	local prompt = plot.Stations[station]:FindFirstChild("StationPrompt", true)
	player.Character:PivotTo(prompt.Parent.CFrame + M.Vector3.new(0, 3, -4))
	prompt.Triggered:Fire(player)
end
local function atShop(player, plot)
	player.Character:PivotTo(plot.Stations.BeeShop.Counter.CFrame + M.Vector3.new(0, 3, -4))
end
local function conserved(s, injected)
	local paid = s.Totals.Earned / Config.Economy.JarValue
	return s.Totals.Produced + (injected or 0) == s:HoneyInSystem() + paid
end
local function snapshot(s)
	return { Cash = s.Cash, Carried = s.Carried, Hive = s.HiveStored, Bees = #s.Bees, Queue = s.BottlingQueue, Unclaimed = s.Unclaimed }
end
local function same(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	return true
end

------------------------------------------------------------------------------
-- Two players, two farms
------------------------------------------------------------------------------
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
local plot1, plot2 = plots.Plot1, plots.Plot2
local sa, sb = FarmService.GetState(alice), FarmService.GetState(bob)
check(sa ~= nil and sb ~= nil and sa ~= sb, "both players have their own farm state")

-- 1. Ownership: Bob presses every one of Alice's stations; nothing on either farm changes
tick(10.1) -- both hives have 2 honey
local beforeA, beforeB = snapshot(sa), snapshot(sb)
for _, station in { "Hive", "Bottling", "SellStand", "BeeShop", "FlowerPatch" } do
	press(bob, plot1, station)
	check(has(lastNote(bob), "Alice's farm"), "Bob refused at Alice's " .. station)
end
check(same(beforeA, snapshot(sa)) and same(beforeB, snapshot(sb)), "no state changed on either farm")
check(#Remotes.OpenShop.fired == 0, "Alice's shop did not open for Bob")
-- remotes have no plot argument: a shop/upgrade request can only ever hit the sender's own farm
atShop(bob, plot1)
Remotes.ShopAction.OnServerEvent:Fire(bob, "Buy")
check(#sa.Bees == 1 and #sb.Bees == 1 and sb.Cash == 25, "Bob's buy at Alice's counter: refused (not at HIS shop), neither farm changed")

-- 2. Full storage: both hives cap, lost honey is counted, collecting a full backpack leaves the rest
tick(300)
check(sa.HiveStored == 50 and sb.HiveStored == 50 and sa.Totals.Lost > 0 and sb.Totals.Lost > 0, "both hives capped at 50 and lost honey counted")
press(alice, plot1, "Hive")
check(sa.Carried == 50 and sa.HiveStored == 0, "Alice collected a full backpack")
tick(10.1)
press(alice, plot1, "Hive")
check(sa.Carried == 50 and sa.HiveStored == 2 and has(lastNote(alice), "backpack is full"), "full backpack: honey stays in the hive, clear message")

-- 3. Insufficient funds (Bob has exactly $25: one bee, then nothing)
atShop(bob, plot2)
Remotes.ShopAction.OnServerEvent:Fire(bob, "Buy")
check(sb.Cash == 0 and #sb.Bees == 2, "Bob buys a bee with his last $25")
Remotes.ShopAction.OnServerEvent:Fire(bob, "Buy")
check(sb.Cash == 0 and #sb.Bees == 2 and has(lastNote(bob), "need $31"), "second buy refused: no cash, no bee, price shown")
Remotes.ReturnToFarm.OnServerEvent:Fire(bob)
Remotes.UpgradeAction.OnServerEvent:Fire(bob, "HiveStorage")
check(sb.Cash == 0 and sb:UpgradeLevel("HiveStorage") == 1, "upgrade refused with no cash")

-- 4. Rapid interactions
--   a) 100 hive presses in one instant: at most one backpack of honey moves, the rest is dropped by the limiter
press(alice, plot1, "Bottling") -- empty the backpack the honest way
tick(260) -- hive refills to the 50 cap
check(sa.Carried == 0 and sa.HiveStored == 50, "set-up: empty backpack, full hive")
local produced = sa.Totals.Produced
for _ = 1, 100 do
	press(alice, plot1, "Hive")
end
check(sa.Carried == 50 and sa.HiveStored == 0, "100 presses moved exactly the 50 honey that existed")
check(sa.Totals.Produced == produced, "spam created no honey")
--   b) 100 Buy presses with plenty of cash: limiter passes 25; slots cap at 8; cash never negative
sa.Cash = 1000000
atShop(alice, plot1)
for _ = 1, 100 do
	Remotes.ShopAction.OnServerEvent:Fire(alice, "Buy")
end
check(#sa.Bees == 8, "slots still cap at 8 under spam")
local expectedSpend = 0
for i = 0, 6 do
	expectedSpend += math.floor(25 * 1.25 ^ i + 0.5)
end
check(sa.Cash == 1000000 - expectedSpend, "exactly 7 purchases charged at the listed prices")
--   c) 100 Upgrade presses, limited cash: levels bought == what the cash allowed, never negative
sa.Cash = 300 -- hive storage: 80 + 200 = 280 affordable, third (500) is not
Remotes.ReturnToFarm.OnServerEvent:Fire(alice)
tick(1.1) -- new limiter window
for _ = 1, 100 do
	Remotes.UpgradeAction.OnServerEvent:Fire(alice, "HiveStorage")
end
check(sa:UpgradeLevel("HiveStorage") == 3 and sa.Cash == 20, "spam bought exactly the two affordable levels; cash never negative")
--   d) the limiter is per player: Bob's presses still work during Alice's flood
tick(1.1)
for _ = 1, 100 do
	Remotes.UpgradeAction.OnServerEvent:Fire(alice, "Backpack")
end
sb.Cash = 100
Remotes.UpgradeAction.OnServerEvent:Fire(bob, "HiveStorage")
check(sb:UpgradeLevel("HiveStorage") == 2 and sb.Cash == 20, "Bob's request goes through while Alice floods")
--   e) spam merge with the same two ids: only one merge happens
tick(1.1)
local ids = {}
for id in string.gmatch(plot1:GetAttribute("Bees"), "(%d+):Starter") do
	table.insert(ids, tonumber(id))
end
local beesBefore = #sa.Bees
atShop(alice, plot1)
for _ = 1, 30 do
	Remotes.ShopAction.OnServerEvent:Fire(alice, "Merge", ids[1], ids[2])
end
check(#sa.Bees == beesBefore - 1, "30 merge presses on the same pair = one merge")
check(conserved(sa) and conserved(sb), "honey conserved on both farms after all the spam")

-- 5. Leaving and rejoining: both saved and restored independently
clock += 60
local snapA, snapB = snapshot(sa), snapshot(sb)
M.removePlayer(game, alice)
check(ds.data.player_1001 ~= nil and ds.data.player_1001.SavedAt == clock, "the leaver is saved with the current timestamp")
local bobAutosaveAt = ds.data.player_2002 and ds.data.player_2002.SavedAt
clock += 120
M.removePlayer(game, bob)
check(ds.data.player_2002 ~= nil and ds.data.player_2002.SavedAt == clock and ds.data.player_2002.SavedAt ~= bobAutosaveAt, "Bob saved on leave (newer than his autosave)")
check(plot1:GetAttribute("OwnerUserId") == 0 and plot2:GetAttribute("OwnerUserId") == 0 and #plot1.Temp:GetChildren() == 0, "both plots released and cleared")

-- 6. Offline rewards: different away times give different, independent credits
clock += 3600 -- Alice away 1h + 2min, Bob away 1h
local alice2 = M.newPlayer(game, 1001, "Alice")
alice2.spawnCharacter()
local bob2 = M.newPlayer(game, 2002, "Bob")
bob2.spawnCharacter()
local sa2, sb2 = FarmService.GetState(alice2), FarmService.GetState(bob2)
check(sa2.Cash == snapA.Cash and #sa2.Bees == snapA.Bees and sa2:UpgradeLevel("HiveStorage") == 3, "Alice's farm restored")
check(sb2.Cash == snapB.Cash and #sb2.Bees == snapB.Bees and sb2:UpgradeLevel("HiveStorage") == 2, "Bob's farm restored")
local wa, wb
for _, f in Remotes.WelcomeBack.fired do
	if f[1] == alice2 then
		wa = f[2]
	elseif f[1] == bob2 then
		wb = f[2]
	end
end
check(wa and wb and wa.Away == 3600 + 120 and wb.Away == 3600, "each player's away time is their own")
check(wa.WouldMake == math.floor(sa2:ProductionRate() * wa.Counted) and wb.WouldMake == math.floor(sb2:ProductionRate() * wb.Counted), "offline honey uses each farm's own rate")
check(sa2.HiveStored <= sa2.HiveCapacity and sb2.HiveStored <= sb2.HiveCapacity, "offline credit never exceeds hive capacity")

-- 7. Full server: a 7th player waits, then gets a freed plot and loads HIS OWN save
ds.data.player_7000 = { SavedAt = clock - 100, Cash = 999, Bees = { { Id = 1, Tier = "Panda" } }, Upgrades = { Backpack = 2 } }
local extras = {}
for i = 3, 6 do
	local p = M.newPlayer(game, 3000 + i, "P" .. i)
	p.spawnCharacter()
	table.insert(extras, p)
end
local late = M.newPlayer(game, 7000, "Late")
late.spawnCharacter()
check(late:GetAttribute("PlotId") == nil and FarmService.GetState(late) == nil, "7th player waits: no plot, no farm state yet")
M.removePlayer(game, bob2)
check(late:GetAttribute("PlotId") == 2, "the waiting player receives the freed plot")
local sl = FarmService.GetState(late)
check(sl ~= nil and sl.Cash == 999 and sl.Bees[1].Tier == "Panda" and sl.BackpackCapacity == 100, "and loads his own save, not the previous owner's")
check(plot2.Temp:FindFirstChild("Bee1") and plot2.Temp.Bee1:GetAttribute("Tier") == "Panda", "his Panda Bee model is on the plot")
check(ds.data.player_2002.Cash == snapB.Cash, "Bob's save is untouched by the hand-over")
