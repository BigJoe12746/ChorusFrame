--!strict
-- FarmState: one player's farm economy as plain data, with no Roblox APIs,
-- so the whole honey loop can be unit-tested and (in Phase 5) saved as-is.
--
-- Honey flow:  bees -> hive storage -> backpack (collect) -> bottling queue (deposit)
--              -> jar on conveyor (1/sec) -> unclaimed cash at the stand (+5) -> cash (collect)
-- Every transfer is a single function that moves an exact amount from one bucket to
-- another, so nothing can be counted twice.

local FarmState = {}
FarmState.__index = FarmState

export type Bee = { Id: number, Tier: string }

export type EconomyConfig = {
	StartCash: number,
	StartBees: { string },
	BackpackCapacity: number,
	HiveCapacity: number,
	BottlingPerSecond: number,
	JarValue: number,
	JarTravelTime: number,
	MaxJarsOnBelt: number,
	BeeSlots: number,
	BeeBasePrice: number,
	BeePriceGrowth: number,
}

export type BeeConfig = { [string]: any } -- Config.Bees: tier -> { Name, HoneyPerSecond, Scale }

export type TickResult = {
	Produced: number, -- whole honey added to the hive this tick
	Lost: number, -- honey the bees made while the hive was full
	JarsStarted: number, -- jars that left the bottling machine
	JarsArrived: number, -- jars that reached the stand (cash credited)
}

export type State = typeof(setmetatable(
	{} :: {
		Cash: number,
		Carried: number,
		BackpackCapacity: number,
		HiveStored: number,
		HiveCapacity: number,
		Bees: { Bee },
		ProductionAcc: number, -- fractional honey not yet whole
		BottlingQueue: number, -- honey waiting to be bottled
		BottlingAcc: number, -- progress (0..1) towards the next jar
		Jars: { number }, -- seconds left before each jar on the belt arrives
		Unclaimed: number,
		NextBeeId: number,
		BeesBought: number, -- shop purchases so far (drives the price)
		Discovered: { [string]: boolean }, -- tiers this player has owned
		Totals: { Produced: number, Lost: number, Jars: number, Earned: number },
		_eco: EconomyConfig,
		_bees: BeeConfig,
		_order: { string },
	},
	FarmState
))

function FarmState.new(eco: EconomyConfig, bees: BeeConfig, order: { string }): State
	local self = setmetatable({
		Cash = eco.StartCash,
		Carried = 0,
		BackpackCapacity = eco.BackpackCapacity,
		HiveStored = 0,
		HiveCapacity = eco.HiveCapacity,
		Bees = {},
		ProductionAcc = 0,
		BottlingQueue = 0,
		BottlingAcc = 0,
		Jars = {},
		Unclaimed = 0,
		NextBeeId = 1,
		BeesBought = 0,
		Discovered = {},
		Totals = { Produced = 0, Lost = 0, Jars = 0, Earned = 0 },
		_eco = eco,
		_bees = bees,
		_order = order,
	}, FarmState)
	for _, tier in eco.StartBees do
		self:AddBee(tier)
	end
	return self
end

-- Adds a bee (no cost, no slot check). Returns the bee and whether the tier is new to this player.
function FarmState.AddBee(self: State, tier: string): (Bee, boolean)
	assert(self._bees[tier], "Unknown bee tier: " .. tostring(tier))
	local bee: Bee = { Id = self.NextBeeId, Tier = tier }
	self.NextBeeId += 1
	table.insert(self.Bees, bee)
	local isNew = not self.Discovered[tier]
	self.Discovered[tier] = true
	return bee, isNew
end

function FarmState.FindBee(self: State, id: number): (Bee?, number?)
	for i, bee in self.Bees do
		if bee.Id == id then
			return bee, i
		end
	end
	return nil, nil
end

function FarmState.TierIndex(self: State, tier: string): number?
	return table.find(self._order, tier)
end

-- The tier two bees of `tier` merge into, or nil at the top.
function FarmState.NextTier(self: State, tier: string): string?
	local i = table.find(self._order, tier)
	return if i then self._order[i + 1] else nil
end

function FarmState.IsMaxTier(self: State, tier: string): boolean
	return self:NextTier(tier) == nil
end

------------------------------------------------------------------------------
-- Shop
------------------------------------------------------------------------------

-- Price of the next Starter Bee. Rises gradually with every purchase.
function FarmState.BeePrice(self: State): number
	return math.floor(self._eco.BeeBasePrice * self._eco.BeePriceGrowth ^ self.BeesBought + 0.5)
end

function FarmState.FreeSlots(self: State): number
	return math.max(0, self._eco.BeeSlots - #self.Bees)
end

-- Returns ok, reason ("NoSlots" | "NoCash").
function FarmState.CanBuyBee(self: State): (boolean, string?)
	if self:FreeSlots() <= 0 then
		return false, "NoSlots"
	end
	if self.Cash < self:BeePrice() then
		return false, "NoCash"
	end
	return true, nil
end

-- Buys one bee of the first tier. Returns the bee (or nil, reason).
function FarmState.BuyBee(self: State): (Bee?, string?)
	local ok, reason = self:CanBuyBee()
	if not ok then
		return nil, reason
	end
	local price = self:BeePrice()
	self.Cash -= price
	self.BeesBought += 1
	local bee = self:AddBee(self._order[1])
	return bee, nil
end

------------------------------------------------------------------------------
-- Merging
------------------------------------------------------------------------------

-- What merging bees a and b would give. Returns resultTier or nil, reason
-- ("NotFound" | "SameBee" | "DifferentTier" | "MaxTier").
function FarmState.MergePreview(self: State, idA: number, idB: number): (string?, string?)
	if idA == idB then
		return nil, "SameBee"
	end
	local a = self:FindBee(idA)
	local b = self:FindBee(idB)
	if not a or not b then
		return nil, "NotFound"
	end
	if a.Tier ~= b.Tier then
		return nil, "DifferentTier"
	end
	local nextTier = self:NextTier(a.Tier)
	if not nextTier then
		return nil, "MaxTier"
	end
	return nextTier, nil
end

-- Replaces bees a and b with one bee of the next tier.
-- Returns the new bee and whether its tier is a new discovery, or nil, reason.
function FarmState.MergeBees(self: State, idA: number, idB: number): (Bee?, boolean, string?)
	local nextTier, reason = self:MergePreview(idA, idB)
	if not nextTier then
		return nil, false, reason
	end
	local _, ia = self:FindBee(idA)
	local _, ib = self:FindBee(idB)
	-- remove the higher index first so the lower one stays valid
	table.remove(self.Bees, math.max(ia :: number, ib :: number))
	table.remove(self.Bees, math.min(ia :: number, ib :: number))
	local bee, isNew = self:AddBee(nextTier)
	return bee, isNew, nil
end

-- Honey per second from all bees.
function FarmState.ProductionRate(self: State): number
	local rate = 0
	for _, bee in self.Bees do
		rate += self._bees[bee.Tier].HoneyPerSecond
	end
	return rate
end

-- Advance the simulation by dt seconds.
function FarmState.Tick(self: State, dt: number): TickResult
	local result: TickResult = { Produced = 0, Lost = 0, JarsStarted = 0, JarsArrived = 0 }
	if dt <= 0 then
		return result
	end

	-- Bees -> hive
	self.ProductionAcc += self:ProductionRate() * dt
	local whole = math.floor(self.ProductionAcc)
	if whole > 0 then
		self.ProductionAcc -= whole
		local room = math.max(0, self.HiveCapacity - self.HiveStored)
		local added = math.min(whole, room)
		self.HiveStored += added
		result.Produced = added
		result.Lost = whole - added
		self.Totals.Produced += added
		self.Totals.Lost += result.Lost
	end

	-- Bottling queue -> jars
	if self.BottlingQueue > 0 then
		self.BottlingAcc += self._eco.BottlingPerSecond * dt
		while self.BottlingAcc >= 1 and self.BottlingQueue > 0 do
			self.BottlingAcc -= 1
			self.BottlingQueue -= 1
			table.insert(self.Jars, self._eco.JarTravelTime)
			result.JarsStarted += 1
			self.Totals.Jars += 1
		end
		if self.BottlingQueue == 0 then
			self.BottlingAcc = 0
		end
	else
		self.BottlingAcc = 0
	end

	-- Jars -> unclaimed cash
	local remaining = {}
	for _, t in self.Jars do
		t -= dt
		if t <= 0 then
			self.Unclaimed += self._eco.JarValue
			self.Totals.Earned += self._eco.JarValue
			result.JarsArrived += 1
		else
			table.insert(remaining, t)
		end
	end
	self.Jars = remaining

	return result
end

-- Hive -> backpack. Returns honey moved (0 if nothing to collect or the backpack is full).
function FarmState.CollectHive(self: State): number
	local amount = math.min(self.HiveStored, self.BackpackCapacity - self.Carried)
	if amount <= 0 then
		return 0
	end
	self.HiveStored -= amount
	self.Carried += amount
	return amount
end

-- Backpack -> bottling queue. Returns honey moved.
function FarmState.Deposit(self: State): number
	local amount = self.Carried
	if amount <= 0 then
		return 0
	end
	self.Carried = 0
	self.BottlingQueue += amount
	return amount
end

-- Unclaimed -> cash. Returns cash moved.
function FarmState.CollectCash(self: State): number
	local amount = self.Unclaimed
	if amount <= 0 then
		return 0
	end
	self.Unclaimed = 0
	self.Cash += amount
	return amount
end

-- Progress of the jar currently being made (0..1), for the HUD.
function FarmState.BottlingProgress(self: State): number
	return if self.BottlingQueue > 0 then math.clamp(self.BottlingAcc, 0, 1) else 0
end

-- Honey that exists anywhere in the loop (useful for conservation checks / tests).
function FarmState.HoneyInSystem(self: State): number
	return self.HiveStored + self.Carried + self.BottlingQueue + #self.Jars
end

return FarmState
