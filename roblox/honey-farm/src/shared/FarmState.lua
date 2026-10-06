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

export type Bee = { Tier: string }

export type EconomyConfig = {
	StartCash: number,
	StartBees: { string },
	BackpackCapacity: number,
	HiveCapacity: number,
	BottlingPerSecond: number,
	JarValue: number,
	JarTravelTime: number,
	MaxJarsOnBelt: number,
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
		Totals: { Produced: number, Lost: number, Jars: number, Earned: number },
		_eco: EconomyConfig,
		_bees: BeeConfig,
	},
	FarmState
))

function FarmState.new(eco: EconomyConfig, bees: BeeConfig): State
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
		Totals = { Produced = 0, Lost = 0, Jars = 0, Earned = 0 },
		_eco = eco,
		_bees = bees,
	}, FarmState)
	for _, tier in eco.StartBees do
		self:AddBee(tier)
	end
	return self
end

function FarmState.AddBee(self: State, tier: string): Bee
	assert(self._bees[tier], "Unknown bee tier: " .. tostring(tier))
	local bee = { Tier = tier }
	table.insert(self.Bees, bee)
	return bee
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
