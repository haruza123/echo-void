-- Token bucket per pemain untuk membatasi spam RemoteEvent.
local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: { capacity: number, refill: number, buckets: { [Player]: { tokens: number, t: number } } }, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local self = setmetatable({ capacity = capacity, refill = refillPerSecond, buckets = {} }, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
	return self
end

function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local b = self.buckets[player]
	if not b then
		b = { tokens = self.capacity, t = now }
		self.buckets[player] = b
	end
	b.tokens = math.min(self.capacity, b.tokens + (now - b.t) * self.refill)
	b.t = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
