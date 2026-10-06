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
}
local BEES = { Starter = { Name = "Starter Bee", HoneyPerSecond = 1 / 5 } }

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
local s = FarmState.new(ECO, BEES)
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
local c = FarmState.new(ECO, BEES)
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

print(("FarmState: %d checks passed"):format(passed))
