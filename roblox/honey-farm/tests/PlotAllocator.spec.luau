-- Run from roblox/honey-farm:  luau tests/PlotAllocator.spec.luau
local PlotAllocator = require("../src/shared/PlotAllocator")

local passed = 0
local function check(cond, msg)
	assert(cond, msg)
	passed += 1
end

-- two players get separate plots
local a = PlotAllocator.new(6)
local p1 = a:Claim(101)
local p2 = a:Claim(202)
check(p1 == 1 and p2 == 2, "first two players get plots 1 and 2")
check(p1 ~= p2, "plots are separate")
check(a:GetOwner(1) == 101 and a:GetOwner(2) == 202, "owners recorded")
check(a:Claim(101) == 1, "claiming twice returns the same plot (no double assignment)")
check(a:FreeCount() == 4, "4 plots left")

-- leaving frees the plot, and the lowest free plot is reused
local freed, nextUser = a:Release(101)
check(freed == 1 and nextUser == nil, "release returns freed plot")
check(a:GetPlotOf(101) == nil and a:GetOwner(1) == nil, "plot 1 is empty again")
check(a:Claim(303) == 1, "next joiner gets the freed plot")
check(a:Release(999) == nil, "releasing someone without a plot does nothing")

-- full server: queue and hand-over
local b = PlotAllocator.new(6)
for u = 1, 6 do
	b:Claim(u)
end
check(b:FreeCount() == 0, "all six plots taken")
check(b:Claim(7) == nil and b:IsQueued(7), "7th player is queued")
check(b:Claim(8) == nil, "8th player is queued")
local f, n = b:Release(3)
check(f == 3 and n == 7, "queued player 7 receives freed plot 3")
check(b:GetPlotOf(7) == 3 and not b:IsQueued(7), "player 7 owns plot 3")
b:Release(8)
check(not b:IsQueued(8), "queued player leaving is removed from the queue")
local f2, n2 = b:Release(4)
check(f2 == 4 and n2 == nil and b:GetOwner(4) == nil, "no one waiting: plot stays free")

-- rejoin
check(b:Claim(3) == 4, "a player who left and rejoined gets a free plot again")

print(("PlotAllocator: %d checks passed"):format(passed))
