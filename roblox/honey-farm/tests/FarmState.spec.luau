-- Run from roblox/honey-farm:  luau tests/FarmState.spec.luau
local FarmState = require("../src/shared/FarmState")

local ECO = {
	StartCash = 25,
	StartBees = { "Starter" },
	BackpackCapacity = 50,
	HiveCapacity = 50,
	BottlingPerSecond = 1,
	JarValue = 5,
	JarTravelTime = 3,
	MaxJarsOnBelt = 12,
	BeeSlots = 8,
	BeeBasePrice = 25,
	BeePriceGrowth = 1.25,
}
local ORDER = { "Starter", "Clover", "Daisy", "Royal" } -- short ladder for the test
local BEES = {}
for i, tier in ORDER do
	BEES[tier] = { Name = tier .. " Bee", HoneyPerSecond = (1 / 5) * 2.5 ^ (i - 1) }
end

local passed = 0
local function check(cond, msg)
	assert(cond, msg)
	passed += 1
end
local function ticks(s, seconds, step)
	step = step or 1 / 30
	local r = { Produced = 0, Lost = 0, JarsStarted = 0, JarsArrived = 0 }
	local t = 0
	while t < seconds - 1e-9 do
		local dt = math.min(step, seconds - t)
		local x = s:Tick(dt)
		for k, v in x do
			r[k] += v
		end
		t += dt
	end
	return r
end

-- new player
local s = FarmState.new(ECO, BEES, ORDER)
check(s.Cash == 25, "starts with 25 cash")
check(#s.Bees == 1 and s.Bees[1].Tier == "Starter", "starts with one Starter Bee")
check(math.abs(s:ProductionRate() - 0.2) < 1e-9, "starter bee makes 1 honey per 5 s")

-- production at 30 fps
local r = ticks(s, 5)
check(s.HiveStored == 1 and r.Produced == 1, "1 honey after 5 seconds")
ticks(s, 45)
check(s.HiveStored == 10, "10 honey after 50 seconds")
check(s.Totals.Produced == 10, "totals track production")

-- full hive
local r2 = ticks(s, 400)
check(s.HiveStored == 50, "hive caps at 50")
check(r2.Lost >= 39 and r2.Lost <= 40 and s.Totals.Lost == r2.Lost, "honey made while full is lost, not stored (" .. r2.Lost .. ")")

-- collect into backpack
check(s:CollectHive() == 50 and s.Carried == 50 and s.HiveStored == 0, "collect moves hive -> backpack")
check(s:CollectHive() == 0 and s.Carried == 50, "collect again does nothing (backpack full, hive empty)")
ticks(s, 10)
check(s.HiveStored == 2 and s:CollectHive() == 0 and s.HiveStored == 2, "full backpack leaves honey in the hive")

-- deposit + bottling
check(s:Deposit() == 50 and s.Carried == 0 and s.BottlingQueue == 50, "deposit moves backpack -> bottling")
check(s:Deposit() == 0, "deposit with an empty backpack does nothing")
local r3 = ticks(s, 1.02) -- tiny margin: frame-time sums are not exact
check(r3.JarsStarted == 1 and s.BottlingQueue == 49 and #s.Jars == 1, "one jar per second")
check(s.Unclaimed == 0, "jar on the belt hasn't paid out yet")
local r4 = ticks(s, 3.02)
check(r4.JarsArrived == 1 and s.Unclaimed == 5, "jar pays 5 cash when it reaches the stand")
ticks(s, 60)
check(s.BottlingQueue == 0 and #s.Jars == 0, "queue fully processed")
check(s.Unclaimed == 250 and s.Totals.Jars == 50, "50 honey -> 50 jars -> 250 cash, nothing doubled")
check(s:BottlingProgress() == 0, "progress resets when idle")

-- collect cash
check(s:CollectCash() == 250 and s.Cash == 275 and s.Unclaimed == 0, "collect cash moves unclaimed -> cash")
check(s:CollectCash() == 0 and s.Cash == 275, "collecting twice doesn't pay twice")

-- conservation over a messy run with uneven frame times
local c = FarmState.new(ECO, BEES, ORDER)
-- tiny deterministic generator (the plain luau CLI has no Random)
local seed = 7
local function nextNumber(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return a + (b - a) * seed / 2147483648
end
local produced = 0
for i = 1, 3000 do
	local x = c:Tick(nextNumber(0.01, 0.2))
	produced += x.Produced
	if i % 97 == 0 then
		c:CollectHive()
	end
	if i % 151 == 0 then
		c:Deposit()
	end
	if i % 300 == 0 then
		c:CollectCash()
	end
end
local jarsDone = c.Totals.Jars
local jarsArrived = (c.Totals.Earned) / ECO.JarValue
check(produced == c.Totals.Produced, "tick results match totals")
check(produced == c:HoneyInSystem() + jarsArrived, "every honey is either in the loop or already paid out")
check(jarsDone == #c.Jars + jarsArrived, "every jar is on the belt or paid")
check(c.Cash + c.Unclaimed == ECO.StartCash + c.Totals.Earned, "cash matches jars x 5")
check(c.Cash % 5 == 0, "cash only moves in whole jar values")

-- zero / negative dt is a no-op
local before = c:HoneyInSystem()
c:Tick(0)
c:Tick(-1)
check(c:HoneyInSystem() == before, "non-positive dt changes nothing")

-- SHOP -----------------------------------------------------------------------
local sh = FarmState.new(ECO, BEES, ORDER)
check(sh.Bees[1].Id == 1 and sh.Discovered.Starter == true, "bees get ids; starter tier is discovered")
check(sh:BeePrice() == 25 and sh:FreeSlots() == 7, "first bee costs 25, 7 free slots")
local okBuy, why = sh:CanBuyBee()
check(okBuy == true and why == nil, "can afford the first bee with 25 cash")
local bought = sh:BuyBee()
check(bought ~= nil and bought.Id == 2 and sh.Cash == 0 and #sh.Bees == 2, "buying takes 25 cash and adds bee #2")
check(sh:BeePrice() == 31, "price rises gradually: 25 -> 31")
local none, reason = sh:BuyBee()
check(none == nil and reason == "NoCash" and sh.Cash == 0 and #sh.Bees == 2, "can't buy without cash; nothing changes")
sh.Cash = 100000
local prices = {}
while #sh.Bees < 8 do
	table.insert(prices, sh:BeePrice())
	sh:BuyBee()
end
check(#sh.Bees == 8 and sh:FreeSlots() == 0, "filled all 8 slots")
check(prices[1] == 31 and prices[6] > prices[1] and prices[6] < 200, "prices climb smoothly (" .. table.concat(prices, ", ") .. ")")
local full, fullReason = sh:BuyBee()
check(full == nil and fullReason == "NoSlots" and #sh.Bees == 8, "no slots -> no purchase, no charge")
check(sh.Cash == 100000 - (31 + 39 + 49 + 61 + 76 + 95), "exact prices were charged")

-- MERGING ---------------------------------------------------------------------
local m = FarmState.new(ECO, BEES, ORDER)
m.Cash = 1000
m:BuyBee() -- ids 1, 2 both Starter
local preview, pr = m:MergePreview(1, 2)
check(preview == "Clover" and pr == nil, "preview: two Starters -> Clover")
check(select(2, m:MergePreview(1, 1)) == "SameBee", "can't merge a bee with itself")
check(select(2, m:MergePreview(1, 99)) == "NotFound", "unknown bee id is rejected")
local rateBefore = BEES.Starter.HoneyPerSecond
local merged, isNew = m:MergeBees(1, 2)
check(merged ~= nil and merged.Tier == "Clover" and merged.Id == 3, "merge gives one Clover bee with a fresh id")
check(#m.Bees == 1 and m:FindBee(1) == nil and m:FindBee(2) == nil, "both parents are gone")
check(isNew == true and m.Discovered.Clover == true, "first Clover is a discovery")
check(math.abs(m:ProductionRate() - rateBefore * 2.5) < 1e-9, "merged bee makes 2.5x one previous-tier bee")
m:BuyBee() -- id 4 Starter
check(select(2, m:MergePreview(3, 4)) == "DifferentTier", "Clover + Starter can't merge")
local c2 = m:AddBee("Clover")
local daisy, daisyNew = m:MergeBees(3, c2.Id)
check(daisy ~= nil and daisy.Tier == "Daisy" and daisyNew == true, "Clover + Clover -> Daisy")
local d2 = m:AddBee("Daisy")
local royal = m:MergeBees(daisy.Id, d2.Id)
check(royal ~= nil and royal.Tier == "Royal", "Daisy + Daisy -> Royal (top of this test ladder)")
local r2 = m:AddBee("Royal")
local blocked, _, blockReason = m:MergeBees(royal.Id, r2.Id)
check(blocked == nil and blockReason == "MaxTier" and #m.Bees == 3, "the highest tier cannot be merged")
check(m:IsMaxTier("Royal") and not m:IsMaxTier("Starter"), "IsMaxTier")
local _, againNew = m:MergeBees(m:AddBee("Clover").Id, m:AddBee("Clover").Id)
check(againNew == false, "a second Daisy is not a new discovery")

-- UPGRADES --------------------------------------------------------------------
local UPG = {
	Order = { "Production", "HiveStorage", "Backpack", "BottlingSpeed", "BeeSlots" },
	Production = { Levels = { 1, 2, 4 }, Prices = { 100, 500 } },
	HiveStorage = { Levels = { 50, 120, 250 }, Prices = { 80, 200 } },
	Backpack = { Levels = { 50, 100 }, Prices = { 60 } },
	BottlingSpeed = { Levels = { 1, 2, 5 }, Prices = { 100, 250 } },
	BeeSlots = { Levels = { 8, 10 }, Prices = { 200 } },
}
local u = FarmState.new(ECO, BEES, ORDER, UPG)
check(u:UpgradeLevel("HiveStorage") == 1 and u.HiveCapacity == 50 and u.BackpackCapacity == 50 and u.BottlingPerSecond == 1 and u.BeeSlots == 8 and u.ProductionMultiplier == 1, "level 1 everywhere = base values")
local nv, np = u:NextUpgrade("HiveStorage")
check(nv == 120 and np == 80, "next hive level shows value 120 for $80")
local okU, whyU = u:CanBuyUpgrade("HiveStorage")
check(okU == false and whyU == "NoCash", "can't afford with 25 cash")
check(select(2, u:CanBuyUpgrade("Jetpack")) == "Unknown", "unknown upgrade id is rejected")
u.Cash = 1000
local lvl = u:BuyUpgrade("HiveStorage")
check(lvl == 2 and u.Cash == 920 and u.HiveCapacity == 120, "bought hive storage: level 2, $80 charged, capacity 120")
check(u:BuyUpgrade("HiveStorage") == 3 and u.Cash == 720 and u.HiveCapacity == 250, "level 3 for $200 -> capacity 250")
local maxed, maxReason = u:BuyUpgrade("HiveStorage")
check(maxed == nil and maxReason == "Maxed" and u.Cash == 720, "maxed upgrade can't be bought, no charge")
check(u:NextUpgrade("HiveStorage") == nil, "no next level when maxed")
-- production multiplier
local base = u:ProductionRate()
u:BuyUpgrade("Production")
check(math.abs(u:ProductionRate() - base * 2) < 1e-9, "production x2 after the first production upgrade")
-- bottling speed: 2 jars per second
u:BuyUpgrade("BottlingSpeed")
u.Carried = 10
u:Deposit()
local rr = ticks(u, 1.02)
check(rr.JarsStarted == 2, "bottling speed 2 makes 2 jars in a second")
-- backpack
u:BuyUpgrade("Backpack")
u.HiveStored = 100
u.Carried = 0
check(u:CollectHive() == 100, "bigger backpack carries 100")
-- bee slots: 9th bee allowed after the upgrade
u.Cash = 100000
while #u.Bees < 8 do
	u:BuyBee()
end
check(select(2, u:BuyBee()) == "NoSlots", "8 slots full")
u:BuyUpgrade("BeeSlots")
check(u.BeeSlots == 10 and u:BuyBee() ~= nil and #u.Bees == 9, "slot upgrade allows a 9th bee")
-- shrinking capacity never happens, but stored honey is clamped to capacity if it did
u.HiveStored = 999
u:Recalculate()
check(u.HiveStored == 250, "stored honey is clamped to capacity")
-- without an upgrade table everything still works with base values
local plain = FarmState.new(ECO, BEES, ORDER)
check(plain.HiveCapacity == 50 and plain:UpgradeValue("HiveStorage") == nil and select(2, plain:BuyUpgrade("HiveStorage")) == "Unknown", "no upgrade table -> base values, purchases refused")

-- SAVING -----------------------------------------------------------------------
local sv = FarmState.new(ECO, BEES, ORDER, UPG)
sv.Cash = 1234
sv:BuyUpgrade("HiveStorage")
sv:AddBee("Clover")
sv.HiveStored = 33
sv.Carried = 7
sv.BottlingQueue = 4
sv.BottlingAcc = 0.5
sv.Jars = { 1.5, 2.5 }
sv.Unclaimed = 45
local data = sv:Serialize(1700000000)
check(data.SavedAt == 1700000000 and data.Version == 1, "save carries a timestamp and version")
check(data.Cash == 1154 and data.Carried == 7 and data.HiveStored == 33 and data.Unclaimed == 45, "save holds cash, carried, hive, unclaimed")
check(#data.Bees == 2 and data.Bees[2].Tier == "Clover" and data.Upgrades.HiveStorage == 2, "save holds bees and upgrade levels")
check(data.BottlingQueue == 4 and #data.Jars == 2 and data.BottlingAcc == 0.5, "save holds the processing inventory")
check(#data.Discovered == 2, "save holds discovered tiers")
data.Jars[1] = 99 -- mutate the copy: the live state must not change
check(sv.Jars[1] == 1.5, "serialize returns copies, not references")

local back = FarmState.Deserialize(sv:Serialize(1700000000), ECO, BEES, ORDER, UPG)
check(back.Cash == 1154 and back.Carried == 7 and back.HiveStored == 33 and back.Unclaimed == 45, "round trip: money and honey")
check(#back.Bees == 2 and back.Bees[2].Tier == "Clover" and back.Bees[2].Id == 2 and back.NextBeeId == 3, "round trip: bees keep ids; next id continues")
check(back.HiveCapacity == 120 and back:UpgradeLevel("HiveStorage") == 2, "round trip: upgrade applied to capacity")
check(back.BottlingQueue == 4 and #back.Jars == 2 and back.Discovered.Clover == true, "round trip: processing + discoveries")
check(back:HoneyInSystem() == sv:HoneyInSystem(), "round trip: honey in system identical")

-- corrupt / hostile data is clamped, not fatal
local bad = FarmState.Deserialize({
	Cash = -500,
	Carried = 9999,
	HiveStored = "lots",
	Bees = { { Id = 1, Tier = "Dragon" }, { Id = 1, Tier = "Clover" }, { Id = 1, Tier = "Starter" }, "junk" },
	Upgrades = { HiveStorage = 99, Backpack = -3 },
	Jars = { 500, -1 },
	Discovered = { "Dragon", "Royal" },
}, ECO, BEES, ORDER, UPG)
check(bad.Cash == 0, "negative cash becomes 0")
check(bad:UpgradeLevel("HiveStorage") == 3 and bad:UpgradeLevel("Backpack") == 1, "upgrade levels clamped to the table")
check(bad.Carried == bad.BackpackCapacity and bad.HiveStored == 0, "carried clamped to backpack; non-number hive = 0")
check(#bad.Bees == 2 and bad.Bees[1].Tier == "Clover" and bad.Bees[2].Tier == "Starter", "unknown tier and junk dropped")
check(bad.Bees[1].Id ~= bad.Bees[2].Id and bad.NextBeeId > math.max(bad.Bees[1].Id, bad.Bees[2].Id), "duplicate ids repaired")
check(#bad.Jars == 2 and bad.Jars[1] == ECO.JarTravelTime and bad.Jars[2] == 0, "jar timers clamped")
check(bad.Discovered.Royal == true and bad.Discovered.Dragon == nil, "discoveries: known kept, unknown dropped")
local empty = FarmState.Deserialize({}, ECO, BEES, ORDER, UPG)
check(empty.Cash == 25 and #empty.Bees == 1 and empty.Bees[1].Tier == "Starter", "empty save = new player defaults")
local noBees = FarmState.Deserialize({ Cash = 10, Bees = {} }, ECO, BEES, ORDER, UPG)
check(#noBees.Bees == 1, "a farm with no bees gets a Starter")

-- OFFLINE HONEY ------------------------------------------------------------------
local off = FarmState.new(ECO, BEES, ORDER, UPG) -- 1 starter: 0.2/s, hive 50
local credited, counted, would = off:ApplyOffline(100, 8 * 3600)
check(credited == 20 and counted == 100 and would == 20 and off.HiveStored == 20, "100 s away = 20 honey")
credited, counted, would = off:ApplyOffline(10 * 3600, 8 * 3600)
check(counted == 8 * 3600 and would == 5760, "offline time is capped at 8 hours")
check(credited == 30 and off.HiveStored == 50, "credit is capped by hive room")
check(off.Totals.Produced == 50, "offline honey counts as produced")
credited = off:ApplyOffline(3600, 8 * 3600)
check(credited == 0, "full hive: nothing more credited")
check(off:ApplyOffline(-5, 8 * 3600) == 0, "negative time credits nothing")

print(("FarmState: %d checks passed"):format(passed))
