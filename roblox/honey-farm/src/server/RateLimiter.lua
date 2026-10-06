--!strict
-- RateLimiter: at most `max` calls per `window` seconds for each key (a player).
-- Pure (the clock is injected) so it can be unit-tested. Used to drop remote/prompt floods
-- before they reach the economy code; the economy itself is already atomic, this just
-- keeps an exploiter from burning server time.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { start: number, count: number }

export type Limiter = typeof(setmetatable(
	{} :: {
		max: number,
		window: number,
		buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(max: number, window: number): Limiter
	return setmetatable({ max = max, window = window, buckets = {} }, RateLimiter)
end

-- Returns true if the call is allowed (and counts it), false if it should be dropped.
function RateLimiter.Allow(self: Limiter, key: any, now: number): boolean
	local existing: Bucket? = self.buckets[key]
	local b: Bucket
	if existing and now - existing.start < self.window then
		b = existing
	else
		b = { start = now, count = 0 }
		self.buckets[key] = b
	end
	if b.count >= self.max then
		return false
	end
	b.count += 1
	return true
end

function RateLimiter.Forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
