-- Run from roblox/honey-farm:  luau tests/RateLimiter.spec.luau
local RateLimiter = require("../src/server/RateLimiter")

local passed = 0
local function check(cond, msg)
	assert(cond, msg)
	passed += 1
end

local l = RateLimiter.new(3, 1)
check(l:Allow("a", 0) and l:Allow("a", 0.1) and l:Allow("a", 0.2), "first three calls allowed")
check(not l:Allow("a", 0.3), "fourth call in the window is dropped")
check(not l:Allow("a", 0.9), "still dropped later in the same window")
check(l:Allow("b", 0.9), "another key has its own bucket")
check(l:Allow("a", 1.0), "window reset after 1 s")
check(l:Allow("a", 1.1) and l:Allow("a", 1.2) and not l:Allow("a", 1.3), "new window: three more, then dropped")
l:Forget("a")
check(l:Allow("a", 1.3), "forgetting a key clears its bucket")

local burst = RateLimiter.new(25, 1)
local allowed = 0
for _ = 1, 100 do
	if burst:Allow("spam", 5) then
		allowed += 1
	end
end
check(allowed == 25, "100 calls in one instant: exactly 25 pass")

print(("RateLimiter: %d checks passed"):format(passed))
