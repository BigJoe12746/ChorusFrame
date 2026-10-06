-- Phase 5 scenario: saving, loading, autosave and offline honey, through the REAL server scripts
-- with an in-memory DataStore (M.datastore). Globals: M, game, workspace, boot(), check(), tick(), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local SSS = game:GetService("ServerScriptService")
local SaveService = req(SSS.HoneyFarm.SaveService)
local FarmService = req(SSS.HoneyFarm.FarmService)

-- controllable clock
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
local function welcomes(p)
	local out = {}
	for _, f in Remotes.WelcomeBack.fired do
		if f[1] == p then
			table.insert(out, f[2])
		end
	end
	return out
end
local function use(player, plot, station)
	local prompt = plot.Stations[station]:FindFirstChild("StationPrompt", true)
	player.Character:PivotTo(prompt.Parent.CFrame + M.Vector3.new(0, 3, -4))
	prompt.Triggered:Fire(player)
end
local function saved(userId)
	return ds.data["player_" .. userId]
end

check(SaveService.Available == true and ds.name == Config.Save.StoreName, "DataStore opened with the configured name")

------------------------------------------------------------------------------
-- New player: nothing to load, plays, leaves -> saved
------------------------------------------------------------------------------
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local plot1 = plots.Plot1
check(FarmService.GetState(alice) ~= nil and alice:GetAttribute("FarmLoading") == nil, "new player's farm is ready after the (empty) load")
check(#welcomes(alice) == 0, "no welcome-back card for a brand-new player")
local s = FarmService.GetState(alice)
s.Cash = 500
Remotes.ReturnToFarm.OnServerEvent:Fire(alice)
Remotes.UpgradeAction.OnServerEvent:Fire(alice, "HiveStorage") -- -> 120 capacity, $420 left
tick(50) -- 10 honey in the hive
use(alice, plot1, "Hive") -- carry 10
tick(25) -- 5 more in the hive
alice.Character:PivotTo(plot1.Stations.BeeShop.Counter.CFrame + M.Vector3.new(0, 3, -4))
Remotes.ShopAction.OnServerEvent:Fire(alice, "Buy") -- $25 -> $395, 2 bees
local cashBefore, carriedBefore, hiveBefore = s.Cash, s.Carried, s.HiveStored
-- (25 s of 1/30 s frames sums to 4.999, so the hive may hold 4 with the fraction carried over)
check(cashBefore == 395 and carriedBefore == 10 and (hiveBefore == 4 or hiveBefore == 5) and #s.Bees == 2, "played a bit: $395, carrying 10, ~5 in hive, 2 bees")
check(saved(1001) ~= nil, "75 s of play already triggered one autosave")

clock += 30
M.removePlayer(game, alice)
local d = saved(1001)
check(d ~= nil and d.SavedAt == clock, "leaving saves with the current timestamp")
check(d.Cash == 395 and d.Carried == 10 and d.HiveStored == hiveBefore and #d.Bees == 2 and d.Upgrades.HiveStorage == 2, "save holds cash, carried honey, hive honey, bees and upgrades")

------------------------------------------------------------------------------
-- Rejoin after 2 hours: progress restored + offline honey, once
------------------------------------------------------------------------------
clock += 2 * 3600
local alice2 = M.newPlayer(game, 1001, "Alice")
alice2.spawnCharacter()
local s2 = FarmService.GetState(alice2)
check(s2 ~= nil and s2.Cash == 395 and s2.Carried == 10 and #s2.Bees == 2 and s2.HiveCapacity == 120, "progress restored on rejoin")
check(plot1.Temp:FindFirstChild("Bee1") ~= nil and plot1.Temp:FindFirstChild("Bee2") ~= nil, "both bee models respawned")
check(plot1.Temp.Upgrades:FindFirstChild("MiniHive") ~= nil, "upgrade visuals rebuilt from the save")
local w = welcomes(alice2)
check(#w == 1, "one welcome-back card")
-- 2 bees x 0.2/s x 7200 s = 2880 would-be honey; room was 120 - hiveBefore
local expectedCredit = 120 - hiveBefore
check(w[1].Away == 7200 and w[1].WouldMake == 2880 and w[1].Credited == expectedCredit and w[1].HiveFull == true, "offline honey uses saved rates and is capped by hive storage")
check(s2.HiveStored == 120, "hive is full after the offline credit")
check(has(lastNote(alice2), "Welcome back") and has(lastNote(alice2), tostring(expectedCredit)), "welcome message names the credited honey")

-- the credit happens once: leave and come straight back
clock += 10
M.removePlayer(game, alice2)
local alice3 = M.newPlayer(game, 1001, "Alice")
alice3.spawnCharacter()
check(#welcomes(alice3) == 0 and FarmService.GetState(alice3).HiveStored == 120, "rejoining 10 s later credits nothing again")

------------------------------------------------------------------------------
-- 8-hour cap
------------------------------------------------------------------------------
local s3 = FarmService.GetState(alice3)
s3.Cash = 100000
Remotes.ReturnToFarm.OnServerEvent:Fire(alice3)
for _ = 1, 6 do
	Remotes.UpgradeAction.OnServerEvent:Fire(alice3, "HiveStorage") -- up to 8000 capacity
end
use(alice3, plot1, "Hive") -- empty the hive into the backpack (backpack 50 -> takes 50)
s3.HiveStored = 0
M.removePlayer(game, alice3)
clock += 30 * 3600 -- away 30 hours
local alice4 = M.newPlayer(game, 1001, "Alice")
alice4.spawnCharacter()
local w4 = welcomes(alice4)[1]
check(w4 ~= nil and w4.Counted == 8 * 3600 and w4.Capped == true, "offline time capped at 8 hours")
local expectedWould = math.floor(0.4 * 8 * 3600)
check(w4.WouldMake == expectedWould, "would-make = rate x 8 h")
check(w4.Credited == math.min(expectedWould, 8000) and FarmService.GetState(alice4).HiveStored == w4.Credited, "credited = min(would-make, hive room)")

------------------------------------------------------------------------------
-- Autosave
------------------------------------------------------------------------------
local before = saved(1001).SavedAt
FarmService.GetState(alice4).Cash = 777
clock += 5
tick(Config.Save.AutosaveInterval + 1)
check(saved(1001).SavedAt == clock and saved(1001).Cash == 777, "autosave wrote after the interval")

------------------------------------------------------------------------------
-- Failed load must never overwrite progress
------------------------------------------------------------------------------
M.removePlayer(game, alice4)
local good = saved(1001)
ds.failNext = Config.Save.LoadRetries -- every retry fails
local alice5 = M.newPlayer(game, 1001, "Alice")
alice5.spawnCharacter()
local s5 = FarmService.GetState(alice5)
check(s5 ~= nil and s5.Cash == 25 and #s5.Bees == 1, "after a failed load the player gets a temporary fresh farm")
check(has(lastNote(alice5), "Couldn't load your save"), "player is told the load failed and nothing will be saved")
s5.Cash = 999999
tick(Config.Save.AutosaveInterval + 1)
M.removePlayer(game, alice5)
check(saved(1001).Cash == good.Cash and saved(1001).SavedAt == good.SavedAt, "temporary farm was never written: real save untouched")

-- a transient failure that recovers within the retries still loads fine
ds.failNext = 1
local alice6 = M.newPlayer(game, 1001, "Alice")
alice6.spawnCharacter()
check(FarmService.GetState(alice6).Cash == good.Cash, "one failed attempt then success: progress loads")
M.removePlayer(game, alice6)

------------------------------------------------------------------------------
-- Newer save elsewhere is not overwritten
------------------------------------------------------------------------------
local alice7 = M.newPlayer(game, 1001, "Alice")
alice7.spawnCharacter()
ds.data["player_1001"].SavedAt = clock + 999 -- another server saved later
ds.data["player_1001"].Cash = 4242
clock += 1
M.removePlayer(game, alice7)
check(saved(1001).Cash == 4242, "save skipped because a newer save exists")

------------------------------------------------------------------------------
-- Shutdown saves everyone
------------------------------------------------------------------------------
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
FarmService.GetState(bob).Cash = 31337
clock += 1
for _, fn in rawget(game, "_props").closeHandlers do
	fn()
end
check(saved(2002) ~= nil and saved(2002).Cash == 31337, "BindToClose saves players who are still in the game")
M.removePlayer(game, bob)

------------------------------------------------------------------------------
-- Unavailable DataStores (Studio without API access): temporary progress, clearly reported
------------------------------------------------------------------------------
ds.unavailable = true
SaveService.Start()
check(SaveService.Available == false and SaveService.Reason ~= "", "saving reports itself unavailable")
local cara = M.newPlayer(game, 3003, "Cara")
cara.spawnCharacter()
check(FarmService.GetState(cara) ~= nil and FarmService.GetState(cara).Cash == 25, "the game still plays without saving")
check(has(lastNote(cara), "Saving is unavailable"), "player is told saving is off")
FarmService.GetState(cara).Cash = 5
tick(Config.Save.AutosaveInterval + 1)
M.removePlayer(game, cara)
check(saved(3003) == nil, "nothing is written while unavailable")
