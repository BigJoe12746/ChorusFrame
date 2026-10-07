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

-- Ladder bee: { Id, Tier }. Egg bee: { Id, Tier = "Variant", Variant = <VariantBees id> }.
-- Shiny = true multiplies the rate (merge results only).
export type Bee = { Id: number, Tier: string, Variant: number?, Shiny: boolean? }

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
export type UpgradeConfig = { [string]: any } -- Config.Upgrades: Order + id -> { Levels, Prices, ... }
export type Extras = { -- optional Phase 8 config: eggs, variants, shiny, rebirth
	Variants: any?, -- VariantBees module
	Eggs: any?, -- Config.Eggs
	Rebirth: any?, -- Config.Rebirth
	ShinyChance: number?,
	ShinyMultiplier: number?,
}

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
		BottlingPerSecond: number, -- derived from upgrades
		BeeSlots: number, -- derived from upgrades
		ProductionMultiplier: number, -- derived from upgrades
		Upgrades: { [string]: number }, -- upgrade id -> level (1 = base)
		NextBeeId: number,
		BeesBought: number, -- shop purchases so far (drives the price)
		Discovered: { [string]: boolean }, -- tiers this player has owned
		TutorialStep: number, -- 1-based index into Config.Tutorial.Steps; past the end = finished
		RoyalJelly: number, -- permanent production bonus earned by rebirths
		Rebirths: number,
		EggsHatched: number,
		Totals: { Produced: number, Lost: number, Jars: number, Earned: number },
		_eco: EconomyConfig,
		_bees: BeeConfig,
		_order: { string },
		_upg: UpgradeConfig?,
		_x: Extras,
	},
	FarmState
))

function FarmState.new(eco: EconomyConfig, bees: BeeConfig, order: { string }, upgrades: UpgradeConfig?, extras: Extras?): State
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
		BottlingPerSecond = eco.BottlingPerSecond,
		BeeSlots = eco.BeeSlots,
		ProductionMultiplier = 1,
		Upgrades = {},
		NextBeeId = 1,
		BeesBought = 0,
		Discovered = {},
		TutorialStep = 1,
		RoyalJelly = 0,
		Rebirths = 0,
		EggsHatched = 0,
		Totals = { Produced = 0, Lost = 0, Jars = 0, Earned = 0 },
		_eco = eco,
		_bees = bees,
		_order = order,
		_upg = upgrades,
		_x = extras or {},
	}, FarmState)
	if upgrades then
		for _, id in upgrades.Order do
			self.Upgrades[id] = 1
		end
	end
	self:Recalculate()
	for _, tier in eco.StartBees do
		self:AddBee(tier)
	end
	return self
end

------------------------------------------------------------------------------
-- Upgrades
------------------------------------------------------------------------------

function FarmState.UpgradeLevel(self: State, id: string): number
	return self.Upgrades[id] or 1
end

-- Current value of an upgrade (e.g. hive capacity in honey).
function FarmState.UpgradeValue(self: State, id: string): number?
	local u = self._upg and self._upg[id]
	if not u then
		return nil
	end
	return u.Levels[self:UpgradeLevel(id)]
end

-- The next level's value and price, or nil when maxed out.
function FarmState.NextUpgrade(self: State, id: string): (number?, number?)
	local u = self._upg and self._upg[id]
	if not u then
		return nil, nil
	end
	local level = self:UpgradeLevel(id)
	local value = u.Levels[level + 1]
	local price = u.Prices[level]
	if value == nil or price == nil then
		return nil, nil
	end
	return value, price
end

-- Re-derives capacities from upgrade levels (base values when there's no upgrade table).
function FarmState.Recalculate(self: State)
	local eco = self._eco
	local hive = self:UpgradeValue("HiveStorage") or eco.HiveCapacity
	self.HiveCapacity = hive
	self.HiveStored = math.min(self.HiveStored, hive)
	self.BackpackCapacity = self:UpgradeValue("Backpack") or eco.BackpackCapacity
	self.BottlingPerSecond = self:UpgradeValue("BottlingSpeed") or eco.BottlingPerSecond
	self.BeeSlots = self:UpgradeValue("BeeSlots") or eco.BeeSlots
	self.ProductionMultiplier = self:UpgradeValue("Production") or 1
end

-- Returns ok, reason ("Unknown" | "Maxed" | "NoCash").
function FarmState.CanBuyUpgrade(self: State, id: string): (boolean, string?)
	if not (self._upg and self._upg[id]) then
		return false, "Unknown"
	end
	local _, price = self:NextUpgrade(id)
	if not price then
		return false, "Maxed"
	end
	if self.Cash < price then
		return false, "NoCash"
	end
	return true, nil
end

-- Buys the next level. Returns the new level (or nil, reason).
function FarmState.BuyUpgrade(self: State, id: string): (number?, string?)
	local ok, reason = self:CanBuyUpgrade(id)
	if not ok then
		return nil, reason
	end
	local _, price = self:NextUpgrade(id)
	self.Cash -= price :: number
	self.Upgrades[id] = self:UpgradeLevel(id) + 1
	self:Recalculate()
	return self.Upgrades[id], nil
end

-- Collection key for a bee: "Clover", "Clover*" (shiny) or "V12" (variant #12).
function FarmState.BeeKey(bee: Bee): string
	if bee.Tier == "Variant" then
		return "V" .. tostring(bee.Variant)
	end
	return bee.Tier .. (if bee.Shiny then "*" else "")
end

-- Adds a bee (no cost, no slot check). Returns the bee and whether it's new to the collection.
-- tier is a ladder tier, or "Variant" with `variant` = a VariantBees id.
function FarmState.AddBee(self: State, tier: string, variant: number?, shiny: boolean?): (Bee, boolean)
	local bee: Bee
	if tier == "Variant" then
		assert(self._x.Variants and self._x.Variants.Get(variant :: number), "Unknown variant: " .. tostring(variant))
		bee = { Id = self.NextBeeId, Tier = "Variant", Variant = variant }
	else
		assert(self._bees[tier], "Unknown bee tier: " .. tostring(tier))
		bee = { Id = self.NextBeeId, Tier = tier }
		if shiny then
			bee.Shiny = true
		end
	end
	self.NextBeeId += 1
	table.insert(self.Bees, bee)
	local key = FarmState.BeeKey(bee)
	local isNew = not self.Discovered[key]
	self.Discovered[key] = true
	if bee.Shiny then
		self.Discovered[bee.Tier] = true -- a shiny Clover also counts as having found Clover
	end
	return bee, isNew
end

-- Honey per second of one bee (before the farm-wide multiplier).
function FarmState.BeeRate(self: State, bee: Bee): number
	local rate
	if bee.Tier == "Variant" then
		local v = self._x.Variants and self._x.Variants.Get(bee.Variant :: number)
		rate = if v then v.HoneyPerSecond else 0
	else
		rate = self._bees[bee.Tier].HoneyPerSecond
	end
	if bee.Shiny then
		rate *= self._x.ShinyMultiplier or 1.5
	end
	return rate
end

-- Display name of a bee.
function FarmState.BeeName(self: State, bee: Bee): string
	if bee.Tier == "Variant" then
		local v = self._x.Variants and self._x.Variants.Get(bee.Variant :: number)
		return if v then v.Name else "Mystery Bee"
	end
	return (if bee.Shiny then "Shiny " else "") .. self._bees[bee.Tier].Name
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
	return math.max(0, self.BeeSlots - #self.Bees)
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
	if a.Tier == "Variant" or b.Tier == "Variant" then
		return nil, "Variant"
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

-- Replaces bees a and b with one bee of the next tier. `roll` (0..1) decides shininess:
-- the result is shiny if roll < ShinyChance or either parent was shiny.
-- Returns the new bee and whether it's a new discovery, or nil, reason.
function FarmState.MergeBees(self: State, idA: number, idB: number, roll: number?): (Bee?, boolean, string?)
	local nextTier, reason = self:MergePreview(idA, idB)
	if not nextTier then
		return nil, false, reason
	end
	local a, ia = self:FindBee(idA)
	local b, ib = self:FindBee(idB)
	local shiny = (a :: Bee).Shiny == true or (b :: Bee).Shiny == true or (roll ~= nil and roll < (self._x.ShinyChance or 0))
	-- remove the higher index first so the lower one stays valid
	table.remove(self.Bees, math.max(ia :: number, ib :: number))
	table.remove(self.Bees, math.min(ia :: number, ib :: number))
	local bee, isNew = self:AddBee(nextTier, nil, shiny)
	return bee, isNew, nil
end

------------------------------------------------------------------------------
-- Eggs
------------------------------------------------------------------------------

-- Chance (0..1) of each Kind in an egg, for display.
function FarmState.EggOdds(self: State, eggName: string): { { Kind: string, Chance: number } }
	local egg = self._x.Eggs and self._x.Eggs[eggName]
	local out = {}
	if not egg then
		return out
	end
	local total = 0
	for _, o in egg.Odds do
		total += o.Weight
	end
	for _, o in egg.Odds do
		table.insert(out, { Kind = o.Kind, Chance = o.Weight / total })
	end
	return out
end

-- Returns ok, reason ("Unknown" | "NoSlots" | "NoCash").
function FarmState.CanBuyEgg(self: State, eggName: string): (boolean, string?)
	local egg = self._x.Eggs and self._x.Eggs[eggName]
	if not egg then
		return false, "Unknown"
	end
	if self:FreeSlots() <= 0 then
		return false, "NoSlots"
	end
	if self.Cash < egg.Price then
		return false, "NoCash"
	end
	return true, nil
end

-- Buys and hatches an egg. roll1 picks the Kind, roll2 picks the variant within a rarity (both 0..1).
-- Returns the new bee, isNew, and the Kind that was rolled, or nil, false, reason.
function FarmState.HatchEgg(self: State, eggName: string, roll1: number, roll2: number): (Bee?, boolean, string?)
	local ok, reason = self:CanBuyEgg(eggName)
	if not ok then
		return nil, false, reason
	end
	local egg = (self._x.Eggs :: any)[eggName]
	local total = 0
	for _, o in egg.Odds do
		total += o.Weight
	end
	local pick = math.clamp(roll1, 0, 0.999999) * total
	local kind = egg.Odds[#egg.Odds].Kind
	for _, o in egg.Odds do
		pick -= o.Weight
		if pick < 0 then
			kind = o.Kind
			break
		end
	end
	self.Cash -= egg.Price
	self.EggsHatched += 1
	local bee, isNew
	if self._bees[kind] then
		bee, isNew = self:AddBee(kind)
	else
		local ids = self._x.Variants.ByRarity[kind]
		assert(ids and #ids > 0, "Egg kind has no variants: " .. tostring(kind))
		local index = math.clamp(math.floor(roll2 * #ids) + 1, 1, #ids)
		bee, isNew = self:AddBee("Variant", ids[index])
	end
	return bee, isNew, kind
end

------------------------------------------------------------------------------
-- Rebirth (Royal Jelly)
------------------------------------------------------------------------------

function FarmState.OwnsTier(self: State, tier: string): boolean
	for _, bee in self.Bees do
		if bee.Tier == tier then
			return true
		end
	end
	return false
end

function FarmState.CanRebirth(self: State): (boolean, string?)
	local cfg = self._x.Rebirth
	if not cfg then
		return false, "Unknown"
	end
	if not self:OwnsTier(cfg.RequiresTier) then
		return false, "NeedsTier"
	end
	return true, nil
end

-- Resets the farm (cash, ladder bees, upgrades, honey everywhere) and grants Royal Jelly.
-- Egg bees and the collection survive. Returns the new jelly total, or nil, reason.
function FarmState.Rebirth(self: State): (number?, string?)
	local ok, reason = self:CanRebirth()
	if not ok then
		return nil, reason
	end
	local cfg = self._x.Rebirth
	local kept = {}
	if cfg.KeepVariants then
		for _, bee in self.Bees do
			if bee.Tier == "Variant" then
				table.insert(kept, bee)
			end
		end
	end
	self.Bees = kept
	self.Cash = self._eco.StartCash
	self.Carried = 0
	self.HiveStored = 0
	self.ProductionAcc = 0
	self.BottlingQueue = 0
	self.BottlingAcc = 0
	self.Jars = {}
	self.Unclaimed = 0
	self.BeesBought = 0
	for id in self.Upgrades do
		self.Upgrades[id] = 1
	end
	self.RoyalJelly += cfg.JellyPerRebirth
	self.Rebirths += 1
	self:Recalculate()
	for _, tier in self._eco.StartBees do
		self:AddBee(tier)
	end
	return self.RoyalJelly, nil
end

function FarmState.JellyMultiplier(self: State): number
	local cfg = self._x.Rebirth
	return 1 + self.RoyalJelly * (if cfg then cfg.BonusPerJelly else 0)
end

-- Honey per second from all bees.
function FarmState.ProductionRate(self: State): number
	local rate = 0
	for _, bee in self.Bees do
		rate += self:BeeRate(bee)
	end
	return rate * self.ProductionMultiplier * self:JellyMultiplier()
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
		self.BottlingAcc += self.BottlingPerSecond * dt
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

------------------------------------------------------------------------------
-- Introduction
------------------------------------------------------------------------------

-- Moves to the next step if the player is currently on `step`. Returns true if it advanced.
function FarmState.AdvanceTutorial(self: State, step: number): boolean
	if self.TutorialStep == step then
		self.TutorialStep += 1
		return true
	end
	return false
end

------------------------------------------------------------------------------
-- Saving
------------------------------------------------------------------------------

export type SaveData = { [string]: any }

-- Plain table with everything worth keeping. `now` is the save timestamp (os.time()).
function FarmState.Serialize(self: State, now: number): SaveData
	local bees = {}
	for _, bee in self.Bees do
		table.insert(bees, { Id = bee.Id, Tier = bee.Tier, Variant = bee.Variant, Shiny = bee.Shiny })
	end
	local discovered = {}
	for key, found in self.Discovered do
		if found then
			table.insert(discovered, key)
		end
	end
	table.sort(discovered)
	local upgrades = {}
	for id, level in self.Upgrades do
		upgrades[id] = level
	end
	return {
		Version = 1,
		SavedAt = now,
		Cash = self.Cash,
		Carried = self.Carried,
		HiveStored = self.HiveStored,
		BottlingQueue = self.BottlingQueue,
		BottlingAcc = self.BottlingAcc,
		Jars = table.clone(self.Jars),
		Unclaimed = self.Unclaimed,
		Bees = bees,
		NextBeeId = self.NextBeeId,
		BeesBought = self.BeesBought,
		Discovered = discovered,
		Upgrades = upgrades,
		Totals = table.clone(self.Totals),
		TutorialStep = self.TutorialStep,
		RoyalJelly = self.RoyalJelly,
		Rebirths = self.Rebirths,
		EggsHatched = self.EggsHatched,
	}
end

local function num(v: any, default: number, min: number?): number
	local n = tonumber(v)
	if n == nil or n ~= n then
		return default
	end
	return math.max(min or -math.huge, n)
end

-- Rebuilds a state from saved data. Anything odd (unknown tiers, negative numbers,
-- levels past the table) is clamped or dropped rather than crashing.
function FarmState.Deserialize(data: SaveData, eco: EconomyConfig, bees: BeeConfig, order: { string }, upgrades: UpgradeConfig?, extras: Extras?): State
	local self = FarmState.new(eco, bees, order, upgrades, extras)
	self.RoyalJelly = math.floor(num(data.RoyalJelly, 0, 0))
	self.Rebirths = math.floor(num(data.Rebirths, 0, 0))
	self.EggsHatched = math.floor(num(data.EggsHatched, 0, 0))
	self.Bees = {}
	self.Discovered = {}

	if upgrades and type(data.Upgrades) == "table" then
		for _, id in upgrades.Order do
			local level = math.floor(num(data.Upgrades[id], 1, 1))
			self.Upgrades[id] = math.clamp(level, 1, #upgrades[id].Levels)
		end
	end
	self:Recalculate()

	self.Cash = num(data.Cash, eco.StartCash, 0)
	self.Carried = math.min(num(data.Carried, 0, 0), self.BackpackCapacity)
	self.HiveStored = math.min(num(data.HiveStored, 0, 0), self.HiveCapacity)
	self.BottlingQueue = math.floor(num(data.BottlingQueue, 0, 0))
	self.BottlingAcc = math.clamp(num(data.BottlingAcc, 0, 0), 0, 1)
	self.Unclaimed = num(data.Unclaimed, 0, 0)
	self.BeesBought = math.floor(num(data.BeesBought, 0, 0))
	self.Jars = {}
	if type(data.Jars) == "table" then
		for _, t in data.Jars do
			table.insert(self.Jars, math.clamp(num(t, eco.JarTravelTime, 0), 0, eco.JarTravelTime))
		end
	end
	if type(data.Totals) == "table" then
		for k, _ in self.Totals do
			self.Totals[k] = num(data.Totals[k], 0, 0)
		end
	end

	local maxId = 0
	local usedIds: { [number]: boolean } = {}
	if type(data.Bees) == "table" then
		for _, b in data.Bees do
			if type(b) == "table" and type(b.Tier) == "string" then
				local isVariant = b.Tier == "Variant" and self._x.Variants ~= nil and self._x.Variants.Get(math.floor(num(b.Variant, 0, 0))) ~= nil
				if bees[b.Tier] or isVariant then
					local id = math.floor(num(b.Id, 0, 1))
					if id < 1 or usedIds[id] then
						id = maxId + 1
					end
					usedIds[id] = true
					maxId = math.max(maxId, id)
					local bee: Bee = { Id = id, Tier = b.Tier }
					if isVariant then
						bee.Variant = math.floor(num(b.Variant, 0, 0))
					elseif b.Shiny == true then
						bee.Shiny = true
					end
					table.insert(self.Bees, bee)
					self.Discovered[FarmState.BeeKey(bee)] = true
					if bee.Shiny then
						self.Discovered[bee.Tier] = true
					end
				end
			end
		end
	end
	if #self.Bees == 0 then
		-- a farm always has at least one bee
		for _, tier in eco.StartBees do
			local bee = { Id = maxId + 1, Tier = tier }
			maxId += 1
			table.insert(self.Bees, bee)
			self.Discovered[tier] = true
		end
	end
	self.NextBeeId = math.max(maxId + 1, math.floor(num(data.NextBeeId, 1, 1)))
	self.TutorialStep = math.floor(num(data.TutorialStep, 1, 1))
	if type(data.Discovered) == "table" then
		for _, key in data.Discovered do
			if type(key) == "string" then
				local base = key:gsub("%*$", "")
				local vid = key:match("^V(%d+)$")
				if bees[base] or (vid and self._x.Variants and self._x.Variants.Get(tonumber(vid) :: number)) then
					self.Discovered[key] = true
				end
			end
		end
	end
	return self
end

-- Credits honey the bees would have made while the player was away.
-- Returns credited honey, the seconds actually counted (after the cap), and what the bees
-- would have made without the hive limit.
function FarmState.ApplyOffline(self: State, elapsedSeconds: number, capSeconds: number): (number, number, number)
	local counted = math.clamp(elapsedSeconds, 0, capSeconds)
	local wouldMake = math.floor(self:ProductionRate() * counted)
	local room = math.max(0, self.HiveCapacity - self.HiveStored)
	local credited = math.min(wouldMake, room)
	self.HiveStored += credited
	self.Totals.Produced += credited
	return credited, counted, wouldMake
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
