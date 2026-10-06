--!strict
-- Pure plot bookkeeping (no Roblox APIs) so it can be unit-tested outside Studio.
-- Players get the lowest free plot. If every plot is taken they wait in a queue
-- and get the next plot that frees up.

local PlotAllocator = {}
PlotAllocator.__index = PlotAllocator

export type Allocator = typeof(setmetatable(
	{} :: {
		count: number,
		owners: { [number]: number }, -- plotId -> userId
		byUser: { [number]: number }, -- userId -> plotId
		queue: { number }, -- waiting userIds
	},
	PlotAllocator
))

function PlotAllocator.new(count: number): Allocator
	return setmetatable({ count = count, owners = {}, byUser = {}, queue = {} }, PlotAllocator)
end

function PlotAllocator.GetPlotOf(self: Allocator, userId: number): number?
	return self.byUser[userId]
end

function PlotAllocator.GetOwner(self: Allocator, plotId: number): number?
	return self.owners[plotId]
end

function PlotAllocator.FreeCount(self: Allocator): number
	local n = 0
	for id = 1, self.count do
		if self.owners[id] == nil then
			n += 1
		end
	end
	return n
end

function PlotAllocator.IsQueued(self: Allocator, userId: number): boolean
	return table.find(self.queue, userId) ~= nil
end

-- Returns the plot id, or nil if the player was queued.
function PlotAllocator.Claim(self: Allocator, userId: number): number?
	local existing = self.byUser[userId]
	if existing then
		return existing
	end
	for id = 1, self.count do
		if self.owners[id] == nil then
			self.owners[id] = userId
			self.byUser[userId] = id
			return id
		end
	end
	if not table.find(self.queue, userId) then
		table.insert(self.queue, userId)
	end
	return nil
end

-- Frees the player's plot (or removes them from the queue).
-- Returns: freed plot id (or nil), and the queued userId that now owns it (or nil).
function PlotAllocator.Release(self: Allocator, userId: number): (number?, number?)
	local q = table.find(self.queue, userId)
	if q then
		table.remove(self.queue, q)
	end
	local id = self.byUser[userId]
	if not id then
		return nil, nil
	end
	self.byUser[userId] = nil
	self.owners[id] = nil
	local nextUser = table.remove(self.queue, 1)
	if nextUser then
		self.owners[id] = nextUser
		self.byUser[nextUser] = id
	end
	return id, nextUser
end

return PlotAllocator
