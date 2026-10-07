-- Phase 2 scenario: the honey loop, driven through the REAL server scripts.
-- Globals from run_sim.py: M, game, workspace, boot(), check(), tick(seconds), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local FarmService = req(game:GetService("ServerScriptService").HoneyFarm.FarmService)

boot()
local plots = workspace.HoneyFarmMap.Plots

local function notes(p)
	local out = {}
	for _, f in Remotes.Notify.fired do
		if f[1] == p then
			table.insert(out, f[2])
		end
	end
	return out
end
local function lastNote(p)
	local n = notes(p)
	return n[#n] or ""
end
local function has(s, needle)
	return string.find(s, needle, 1, true) ~= nil
end
local function jarEvents(plotId)
	local n = 0
	for _, f in Remotes.JarStarted.fired do
		if f[2] == plotId then
			n += f[3]
		end
	end
	return n
end
local function prompt(plot, station)
	return plot.Stations[station]:FindFirstChild("StationPrompt", true)
end
-- walk the player's character to a station and use it (plate or prompt)
local function use(player, plot, station)
	return useStation(player, plot, station)
end

-- Alice joins: 25 cash, one Starter Bee
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local plot1 = plots.Plot1
local s = FarmService.GetState(alice)
check(s ~= nil, "Alice has a farm state")
check(alice:GetAttribute("Cash") == 25, "starts with 25 Cash (replicated)")
check(alice:GetAttribute("Carried") == 0 and alice:GetAttribute("BackpackCapacity") == 50, "empty backpack, capacity 50")
check(plot1:GetAttribute("BeeCount") == 1, "one Starter Bee")
check(plot1:GetAttribute("HiveStored") == 0 and plot1:GetAttribute("HiveCapacity") == 50, "hive empty, capacity 50")
local bee = plot1.Temp:FindFirstChild("Bee1")
check(bee ~= nil and bee:GetAttribute("Bee") == true and bee:GetAttribute("Tier") == "Starter", "a bee model was spawned into Plot1.Temp")
check(bee ~= nil and bee:FindFirstChildOfClass("Camera") == nil, "bee model has no thumbnail camera")

-- Production: 1 honey every 5 s, shown in the hive
tick(5.1)
check(plot1:GetAttribute("HiveStored") == 1, "1 honey in the hive after 5 s")
use(alice, plot1, "Hive")
check(alice:GetAttribute("Carried") == 1 and plot1:GetAttribute("HiveStored") == 0, "collect moves 1 honey to the backpack")
check(has(lastNote(alice), "1 honey"), "collect message")
use(alice, plot1, "Hive")
check(alice:GetAttribute("Carried") == 1, "collecting an empty hive changes nothing")
check(has(lastNote(alice), "Nothing to collect"), "empty hive message")

-- Fill the hive to the cap and check full-storage handling
tick(300)
check(plot1:GetAttribute("HiveStored") == 50, "hive stops at 50 when full")
local lostBefore = s.Totals.Lost
check(lostBefore > 0, "honey made while full is dropped, not stored")

-- Collect into the backpack, which also caps at 50 (1 already carried -> 49 taken)
use(alice, plot1, "Hive")
check(alice:GetAttribute("Carried") == 50 and plot1:GetAttribute("HiveStored") == 1, "backpack fills to 50; 1 honey stays in the hive")
use(alice, plot1, "Hive")
check(alice:GetAttribute("Carried") == 50 and plot1:GetAttribute("HiveStored") == 1, "full backpack: nothing moves")
check(has(lastNote(alice), "backpack full"), "full backpack message")

-- Rapid double press on bottling: only one deposit
use(alice, plot1, "Bottling")
use(alice, plot1, "Bottling")
check(alice:GetAttribute("Carried") == 0 and plot1:GetAttribute("BottlingQueue") == 50, "deposit moves 50 honey to bottling exactly once")

-- Bottling: 1 jar per second; jar animations are broadcast
tick(1.05)
check(plot1:GetAttribute("BottlingQueue") == 49 and plot1:GetAttribute("JarsOnBelt") == 1, "one jar made after 1 s")
check(jarEvents(1) == 1, "clients told to animate 1 jar on plot 1")
check(plot1:GetAttribute("Unclaimed") == 0, "jar still on the belt: no cash yet")
tick(3.05)
check(plot1:GetAttribute("Unclaimed") == 5, "jar reaches the stand after 3 s: +$5 unclaimed")
check(plot1:GetAttribute("BottlingProgress") > 0, "processing progress is shown while bottling")
tick(60)
check(plot1:GetAttribute("BottlingQueue") == 0 and plot1:GetAttribute("JarsOnBelt") == 0, "all 50 honey bottled")
check(plot1:GetAttribute("Unclaimed") == 250 and jarEvents(1) == 50, "50 jars -> $250 unclaimed, 50 jar animations")
check(plot1:GetAttribute("BottlingProgress") == 0, "progress resets when idle")

-- Collect cash (twice: second does nothing)
use(alice, plot1, "SellStand")
check(alice:GetAttribute("Cash") == 275 and plot1:GetAttribute("Unclaimed") == 0, "collected $250 -> $275 cash")
use(alice, plot1, "SellStand")
check(alice:GetAttribute("Cash") == 275, "collecting again does not pay twice")

-- Conservation: everything produced is in the loop or already paid
local paid = (s.Totals.Earned - Config.Economy.StartCash) / Config.Economy.JarValue -- Earned includes the $25 start
check(s.Totals.Produced == s:HoneyInSystem() + paid, "no honey counted twice (produced == in loop + paid)")
check(s.Cash == s.Totals.Earned - s.Totals.Spent, "cash == everything earned - everything spent")

-- Distance check: pressing the shop prompt from across the map does nothing
local before = alice:GetAttribute("Cash")
alice.Character:PivotTo(M.CFrame.new(0, 3, 0)) -- village
prompt(plot1, "BeeShop").Triggered:Fire(alice)
check(#Remotes.OpenShop.fired == 0, "station press from far away is ignored")
check(alice:GetAttribute("Cash") == before, "(and changes nothing)")

-- Bob can't use Alice's stations, and has his own independent farm
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
local plot2 = plots.Plot2
local aliceCashBefore = alice:GetAttribute("Cash")
use(bob, plot1, "SellStand")
check(bob:GetAttribute("Cash") == 25 and alice:GetAttribute("Cash") == aliceCashBefore, "Bob is ignored at Alice's stand plate; nobody's cash changes")
local hive1Before = plot1:GetAttribute("HiveStored")
tick(5.1)
check(plot2:GetAttribute("HiveStored") == 1 and plot1:GetAttribute("HiveStored") == hive1Before + 1, "both farms produce independently")

-- Leaving removes the farm state and its attributes; the bee goes with Temp
M.removePlayer(game, alice)
check(FarmService.GetState(alice) == nil, "Alice's farm state is dropped when she leaves")
check(plot1:GetAttribute("HiveStored") == nil and plot1:GetAttribute("Unclaimed") == nil, "plot economy attributes cleared")
check(#plot1.Temp:GetChildren() == 0, "Alice's bee model removed")

-- New owner of plot 1 starts fresh
local cara = M.newPlayer(game, 3003, "Cara")
cara.spawnCharacter()
check(cara:GetAttribute("PlotId") == 1 and cara:GetAttribute("Cash") == 25, "Cara takes plot 1 with a fresh 25 Cash")
check(plot1:GetAttribute("HiveStored") == 0, "plot 1 hive is empty for Cara")
check(plot1.Temp:FindFirstChild("Bee1") ~= nil, "Cara gets her own bee model")

-- Pressing E at the Bee Shop opens the shop UI on the owner's client
use(cara, plot1, "BeeShop")
local opened = false
for _, f in Remotes.OpenShop.fired do
	if f[1] == cara then
		opened = true
	end
end
check(opened, "Bee Shop opens the shop UI for its owner")
