--!strict
local FarmState = {}
FarmState.__index = FarmState

-- Ladder bee: { Id, Tier }. Egg bee: { Id, Tier = "Variant", Variant = <VariantBees id> }.
-- Shiny = true multiplies the rate (merge results only).
export type Bee = { Id: number, Tier: string, Variant: number?, Shiny: boolean? }
-- Optional Phase 8 config: eggs, the 50 egg bees, shiny merges.
export type Extras = { Variants: any?, Eggs: any?, ShinyChance: number?, ShinyMultiplier: number?, KeepVariantsOnRebirth: boolean? }
export type EconomyConfig = { StartCash: number, StartBees: { string }, BackpackCapacity: number, HiveCapacity: number, BottlingPerSecond: number, JarValue: number, JarTravelTime: number, MaxJarsOnBelt: number, BeeSlots: number, BeeBasePrice: number, BeePriceGrowth: number }
export type BeeConfig = { [string]: any }
export type UpgradeConfig = { [string]: any }
export type TickResult = { Produced: number, Lost: number, JarsStarted: number, JarsArrived: number }
export type State = typeof(setmetatable({} :: {
	Cash: number, Rebirths: number, Carried: number, BackpackCapacity: number, HiveStored: number, HiveCapacity: number, Bees: { Bee }, ProductionAcc: number, BottlingQueue: number, BottlingAcc: number, Jars: { number }, Unclaimed: number, BottlingPerSecond: number, BeeSlots: number, ProductionMultiplier: number, RebirthMultiplier: number, Upgrades: { [string]: number }, NextBeeId: number, BeesBought: number, Discovered: { [string]: boolean }, TutorialStep: number, EggsHatched: number, Totals: { Produced: number, Lost: number, Jars: number, Earned: number, Spent: number, RebirthSpent: number }, _eco: EconomyConfig, _bees: BeeConfig, _order: { string }, _upg: UpgradeConfig?, _rebirthMultiplier: number, _progression: { [string]: any }?, _x: Extras
}, FarmState))

local function credit(self: State, amount: number)
	if amount > 0 then
		self.Cash += amount
		self.Totals.Earned += amount
	end
end

local function debit(self: State, amount: number): boolean
	if amount <= 0 or self.Cash < amount then return false end
	self.Cash -= amount
	self.Totals.Spent += amount
	return true
end

function FarmState.new(eco: EconomyConfig, bees: BeeConfig, order: { string }, upgrades: UpgradeConfig?, rebirthMultiplier: number?, progression: { [string]: any }?, extras: Extras?): State
	local self = setmetatable({
		Cash = eco.StartCash, Rebirths = 0, Carried = 0, BackpackCapacity = eco.BackpackCapacity, HiveStored = 0, HiveCapacity = eco.HiveCapacity,
		Bees = {}, ProductionAcc = 0, BottlingQueue = 0, BottlingAcc = 0, Jars = {}, Unclaimed = 0,
		BottlingPerSecond = eco.BottlingPerSecond, BeeSlots = eco.BeeSlots, ProductionMultiplier = 1, RebirthMultiplier = 1,
		Upgrades = {}, NextBeeId = 1, BeesBought = 0, Discovered = {}, TutorialStep = 1, EggsHatched = 0,
		Totals = { Produced = 0, Lost = 0, Jars = 0, Earned = eco.StartCash, Spent = 0, RebirthSpent = 0 }, _eco = eco, _bees = bees, _order = order, _upg = upgrades, _rebirthMultiplier = rebirthMultiplier or 1.75, _progression = progression, _x = extras or {}
	}, FarmState)
	if upgrades then for _, id in upgrades.Order do self.Upgrades[id] = 1 end end
	self:Recalculate()
	for _, tier in eco.StartBees do self:AddBee(tier) end
	return self
end

function FarmState.UpgradeLevel(self: State, id: string): number return self.Upgrades[id] or 1 end
function FarmState.UpgradeCost(self: State, id: string): number?
	local progression = self._progression
	if progression and progression.UpgradePrice then
		return progression.UpgradePrice(id, self:UpgradeLevel(id))
	end
	local upgrade = self._upg and self._upg[id]
	return if upgrade then upgrade.Prices[self:UpgradeLevel(id)] else nil
end
function FarmState.RecommendedSpend(self: State): (string?, number?)
	local candidates = {}
	if self:FreeSlots() > 0 then
		table.insert(candidates, { Id = "Bee", Cost = self:BeePrice(), Priority = 1 })
	end
	for _, id in self._upg and self._upg.Order or {} do
		local cost = self:UpgradeCost(id)
		if cost then
			table.insert(candidates, { Id = id, Cost = cost, Priority = if id == "Production" then 0 else 2 })
		end
	end
	table.sort(candidates, function(a, b)
		if a.Priority ~= b.Priority then return a.Priority < b.Priority end
		return a.Cost < b.Cost
	end)
	local target = candidates[1]
	return if target then target.Id else nil, if target then target.Cost else nil
end
function FarmState.UpgradeValue(self: State, id: string): number?
	local upgrade = self._upg and self._upg[id]
	return if upgrade then upgrade.Levels[self:UpgradeLevel(id)] else nil
end
function FarmState.NextUpgrade(self: State, id: string): (number?, number?)
	local upgrade = self._upg and self._upg[id]
	if not upgrade then return nil, nil end
	local level = self:UpgradeLevel(id)
	return upgrade.Levels[level + 1], self:UpgradeCost(id)
end
function FarmState.Recalculate(self: State)
	local eco = self._eco
	self.HiveCapacity = self:UpgradeValue("HiveStorage") or eco.HiveCapacity
	self.HiveStored = math.min(self.HiveStored, self.HiveCapacity)
	self.BackpackCapacity = self:UpgradeValue("Backpack") or eco.BackpackCapacity
	self.BottlingPerSecond = self:UpgradeValue("BottlingSpeed") or eco.BottlingPerSecond
	self.BeeSlots = self:UpgradeValue("BeeSlots") or eco.BeeSlots
	self.ProductionMultiplier = (self:UpgradeValue("Production") or 1) * (self:UpgradeValue("HoneyFlow") or 1)
	local progression = self._progression
	self.RebirthMultiplier = if progression and progression.RebirthMultiplier then progression.RebirthMultiplier(self.Rebirths, self._rebirthMultiplier) else self._rebirthMultiplier ^ self.Rebirths
end
function FarmState.AwardCash(self: State, amount: number): number
	local credited = math.max(0, math.floor(amount + 0.5))
	credit(self, credited)
	return credited
end

function FarmState.RebirthCost(rebirths: number, config: { [string]: any }, progression: { [string]: any }?): number
	if progression and progression.RebirthCost then
		return progression.RebirthCost(rebirths, config.BaseCost, config.CostGrowth)
	end
	return math.floor(config.BaseCost * config.CostGrowth ^ rebirths + 0.5)
end
function FarmState.Rebirth(self: State, config: { [string]: any }): boolean
	local cost = FarmState.RebirthCost(self.Rebirths, config, self._progression)
	if self.Cash < cost then return false end
	self.Cash -= cost
	self.Totals.Spent += cost
	self.Totals.RebirthSpent += cost
	local permanentDiscoveries = table.clone(self.Discovered)
	-- egg bees (the collection) survive a rebirth; ladder bees don't
	local kept = {}
	if self._x.KeepVariantsOnRebirth ~= false then
		for _, bee in self.Bees do
			if bee.Tier == "Variant" then table.insert(kept, bee) end
		end
	end
	self.Rebirths += 1
	self.Cash = self._eco.StartCash
	self.Totals.Earned += self._eco.StartCash
	self.Carried = 0
	self.HiveStored = 0
	self.BottlingQueue = 0
	self.BottlingAcc = 0
	self.ProductionAcc = 0
	self.Jars = {}
	self.Unclaimed = 0
	self.Bees = kept
	if #kept == 0 then self.NextBeeId = 1 end
	self.BeesBought = 0
	self.Discovered = permanentDiscoveries
	self.TutorialStep = 999
	self.Upgrades = {}
	if self._upg then for _, id in self._upg.Order do self.Upgrades[id] = 1 end end
	self:Recalculate()
	for _, tier in self._eco.StartBees do self:AddBee(tier) end
	return true
end
function FarmState.CanBuyUpgrade(self: State, id: string): (boolean, string?)
	if not (self._upg and self._upg[id]) then return false, "Unknown" end
	local _, price = self:NextUpgrade(id)
	if not price then return false, "Maxed" end
	if self.Cash < price then return false, "NoCash" end
	return true, nil
end
function FarmState.BuyUpgrade(self: State, id: string): (number?, string?)
	local ok, reason = self:CanBuyUpgrade(id)
	if not ok then return nil, reason end
	local _, price = self:NextUpgrade(id)
	if not debit(self, price :: number) then return nil, "NoCash" end
	self.Upgrades[id] = self:UpgradeLevel(id) + 1
	self:Recalculate()
	return self.Upgrades[id], nil
end
-- Collection key for a bee: "Clover", "Clover*" (shiny) or "V12" (egg bee #12).
function FarmState.BeeKey(bee: Bee): string
	if bee.Tier == "Variant" then return "V" .. tostring(bee.Variant) end
	return bee.Tier .. (if bee.Shiny then "*" else "")
end
-- Adds a bee (no cost, no slot check). tier is a ladder tier, or "Variant" with `variant` = a
-- VariantBees id. Returns the bee and whether it's new to the collection.
function FarmState.AddBee(self: State, tier: string, variant: number?, shiny: boolean?): (Bee, boolean)
	local bee: Bee
	if tier == "Variant" then
		assert(self._x.Variants and self._x.Variants.Get(variant :: number), "Unknown variant: " .. tostring(variant))
		bee = { Id = self.NextBeeId, Tier = "Variant", Variant = variant }
	else
		assert(self._bees[tier], "Unknown bee tier: " .. tostring(tier))
		bee = { Id = self.NextBeeId, Tier = tier }
		if shiny then bee.Shiny = true end
	end
	self.NextBeeId += 1
	table.insert(self.Bees, bee)
	local key = FarmState.BeeKey(bee)
	local isNew = not self.Discovered[key]
	self.Discovered[key] = true
	if bee.Shiny then self.Discovered[bee.Tier] = true end
	return bee, isNew
end
-- Honey per second of one bee (before farm-wide multipliers).
function FarmState.BeeRate(self: State, bee: Bee): number
	local rate
	if bee.Tier == "Variant" then
		local v = self._x.Variants and self._x.Variants.Get(bee.Variant :: number)
		rate = if v then v.HoneyPerSecond else 0
	else
		rate = self._bees[bee.Tier].HoneyPerSecond
	end
	if bee.Shiny then rate *= self._x.ShinyMultiplier or 1.5 end
	return rate
end
function FarmState.BeeName(self: State, bee: Bee): string
	if bee.Tier == "Variant" then
		local v = self._x.Variants and self._x.Variants.Get(bee.Variant :: number)
		return if v then v.Name else "Mystery Bee"
	end
	return (if bee.Shiny then "Shiny " else "") .. self._bees[bee.Tier].Name
end
function FarmState.OwnsTier(self: State, tier: string): boolean
	for _, bee in self.Bees do if bee.Tier == tier then return true end end
	return false
end
function FarmState.FindBee(self: State, id: number): (Bee?, number?)
	for i, bee in self.Bees do if bee.Id == id then return bee, i end end
	return nil, nil
end
function FarmState.TierIndex(self: State, tier: string): number? return table.find(self._order, tier) end
function FarmState.NextTier(self: State, tier: string): string? local i = table.find(self._order, tier); return if i then self._order[i + 1] else nil end
function FarmState.TierMergeGain(self: State, tier: string): number
	local index = self:TierIndex(tier)
	if not index or not self:NextTier(tier) then return 0 end
	local current = self._bees[tier].HoneyPerSecond * 2
	local nextTier = self:NextTier(tier) :: string
	local result = self._bees[nextTier].HoneyPerSecond
	return if current > 0 then result / current else 1
end
function FarmState.IsMaxTier(self: State, tier: string): boolean return self:NextTier(tier) == nil end
function FarmState.BeePrice(self: State): number
	local progression = self._progression
	if progression and progression.BeePurchaseCost then
		return progression.BeePurchaseCost(self.BeesBought, self._eco.BeeBasePrice, self._eco.BeePriceGrowth)
	end
	return math.floor(self._eco.BeeBasePrice * self._eco.BeePriceGrowth ^ self.BeesBought + 0.5)
end
function FarmState.FreeSlots(self: State): number return math.max(0, self.BeeSlots - #self.Bees) end
function FarmState.CanBuyBee(self: State): (boolean, string?)
	if self:FreeSlots() <= 0 then return false, "NoSlots" end
	if self.Cash < self:BeePrice() then return false, "NoCash" end
	return true, nil
end
function FarmState.BuyBee(self: State): (Bee?, string?)
	local ok, reason = self:CanBuyBee()
	if not ok then return nil, reason end
	local price = self:BeePrice()
	if not debit(self, price) then return nil, "NoCash" end
	self.BeesBought += 1
	local bee = self:AddBee(self._order[1])
	return bee, nil
end
function FarmState.MergePreview(self: State, idA: number, idB: number): (string?, string?)
	if idA == idB then return nil, "SameBee" end
	local a = self:FindBee(idA)
	local b = self:FindBee(idB)
	if not a or not b then return nil, "NotFound" end
	if a.Tier == "Variant" or b.Tier == "Variant" then return nil, "Variant" end
	if a.Tier ~= b.Tier then return nil, "DifferentTier" end
	local nextTier = self:NextTier(a.Tier)
	if not nextTier then return nil, "MaxTier" end
	return nextTier, nil
end
-- `roll` (0..1) decides shininess: shiny if roll < ShinyChance or either parent was shiny.
function FarmState.MergeBees(self: State, idA: number, idB: number, roll: number?): (Bee?, boolean, string?)
	local nextTier, reason = self:MergePreview(idA, idB)
	if not nextTier then return nil, false, reason end
	local a, ia = self:FindBee(idA)
	local b, ib = self:FindBee(idB)
	local shiny = (a :: Bee).Shiny == true or (b :: Bee).Shiny == true or (roll ~= nil and roll < (self._x.ShinyChance or 0))
	table.remove(self.Bees, math.max(ia :: number, ib :: number))
	table.remove(self.Bees, math.min(ia :: number, ib :: number))
	local bee, isNew = self:AddBee(nextTier, nil, shiny)
	return bee, isNew, nil
end
function FarmState.ProductionRate(self: State): number
	local rate = 0
	for _, bee in self.Bees do rate += self:BeeRate(bee) end
	return rate * self.ProductionMultiplier * self.RebirthMultiplier
end

------------------------------------------------------------------------------
-- Eggs
------------------------------------------------------------------------------
-- Chance (0..1) of each Kind in an egg, for display.
function FarmState.EggOdds(self: State, eggName: string): { { Kind: string, Chance: number } }
	local egg = self._x.Eggs and (self._x.Eggs :: any)[eggName]
	local out = {}
	if not egg then return out end
	local total = 0
	for _, o in egg.Odds do total += o.Weight end
	for _, o in egg.Odds do table.insert(out, { Kind = o.Kind, Chance = o.Weight / total }) end
	return out
end
-- Returns ok, reason ("Unknown" | "NoSlots" | "NoCash").
function FarmState.CanBuyEgg(self: State, eggName: string): (boolean, string?)
	local egg = self._x.Eggs and (self._x.Eggs :: any)[eggName]
	if not egg then return false, "Unknown" end
	if self:FreeSlots() <= 0 then return false, "NoSlots" end
	if self.Cash < egg.Price then return false, "NoCash" end
	return true, nil
end
-- Buys and hatches an egg. roll1 picks the Kind by weight, roll2 picks the variant within a
-- rarity (both 0..1). Returns the new bee, isNew, and the Kind rolled, or nil, false, reason.
function FarmState.HatchEgg(self: State, eggName: string, roll1: number, roll2: number): (Bee?, boolean, string?)
	local ok, reason = self:CanBuyEgg(eggName)
	if not ok then return nil, false, reason end
	local egg = (self._x.Eggs :: any)[eggName]
	local total = 0
	for _, o in egg.Odds do total += o.Weight end
	local pick = math.clamp(roll1, 0, 0.999999) * total
	local kind = egg.Odds[#egg.Odds].Kind
	for _, o in egg.Odds do
		pick -= o.Weight
		if pick < 0 then kind = o.Kind; break end
	end
	if not debit(self, egg.Price) then return nil, false, "NoCash" end
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
function FarmState.PotentialCashPerSecond(self: State): number
	return self:ProductionRate() * self._eco.JarValue
end
function FarmState.Tick(self: State, dt: number): TickResult
	local result: TickResult = { Produced = 0, Lost = 0, JarsStarted = 0, JarsArrived = 0 }
	if dt <= 0 then return result end
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
	if self.BottlingQueue > 0 then
		self.BottlingAcc += self.BottlingPerSecond * dt
		while self.BottlingAcc >= 1 and self.BottlingQueue > 0 do
			self.BottlingAcc -= 1
			self.BottlingQueue -= 1
			table.insert(self.Jars, self._eco.JarTravelTime)
			result.JarsStarted += 1
			self.Totals.Jars += 1
		end
		if self.BottlingQueue == 0 then self.BottlingAcc = 0 end
	else self.BottlingAcc = 0 end
	local remaining = {}
	for _, t in self.Jars do
		t -= dt
		if t <= 0 then
			self.Unclaimed += self._eco.JarValue
			self.Totals.Earned += self._eco.JarValue
			result.JarsArrived += 1
		else table.insert(remaining, t) end
	end
	self.Jars = remaining
	return result
end
function FarmState.CollectHive(self: State): number
	local amount = math.min(self.HiveStored, self.BackpackCapacity - self.Carried)
	if amount <= 0 then return 0 end
	self.HiveStored -= amount
	self.Carried += amount
	return amount
end
function FarmState.Deposit(self: State): number
	local amount = self.Carried
	if amount <= 0 then return 0 end
	self.Carried = 0
	self.BottlingQueue += amount
	return amount
end
function FarmState.CollectCash(self: State): number
	local amount = self.Unclaimed
	if amount <= 0 then return 0 end
	self.Unclaimed = 0
	self.Cash += amount
	return amount
end
function FarmState.AdvanceTutorial(self: State, step: number): boolean
	if self.TutorialStep == step then self.TutorialStep += 1; return true end
	return false
end
function FarmState.Serialize(self: State, now: number): { [string]: any }
	local bees, discovered, upgrades = {}, {}, {}
	for _, bee in self.Bees do table.insert(bees, { Id = bee.Id, Tier = bee.Tier, Variant = bee.Variant, Shiny = bee.Shiny }) end
	for key, found in self.Discovered do if found then table.insert(discovered, key) end end
	table.sort(discovered)
	for id, level in self.Upgrades do upgrades[id] = level end
	return { Version = 3, SavedAt = now, Cash = self.Cash, Rebirths = self.Rebirths, Carried = self.Carried, HiveStored = self.HiveStored, BottlingQueue = self.BottlingQueue, BottlingAcc = self.BottlingAcc, Jars = table.clone(self.Jars), Unclaimed = self.Unclaimed, Bees = bees, NextBeeId = self.NextBeeId, BeesBought = self.BeesBought, Discovered = discovered, Upgrades = upgrades, Totals = table.clone(self.Totals), TutorialStep = self.TutorialStep, EggsHatched = self.EggsHatched }
end
local function num(value: any, default: number, minimum: number?): number
	local n = tonumber(value)
	if n == nil or n ~= n then return default end
	return math.max(minimum or -math.huge, n)
end
function FarmState.Deserialize(data: { [string]: any }, eco: EconomyConfig, bees: BeeConfig, order: { string }, upgrades: UpgradeConfig?, rebirthMultiplier: number?, progression: { [string]: any }?, extras: Extras?): State
	local self = FarmState.new(eco, bees, order, upgrades, rebirthMultiplier, progression, extras)
	self.EggsHatched = math.floor(num(data.EggsHatched, 0, 0))
	self.Bees = {}
	self.Discovered = {}
	if upgrades and type(data.Upgrades) == "table" then
		for _, id in upgrades.Order do self.Upgrades[id] = math.clamp(math.floor(num(data.Upgrades[id], 1, 1)), 1, #upgrades[id].Levels) end
	end
	self.Rebirths = math.floor(num(data.Rebirths, 0, 0))
	self.Cash = num(data.Cash, eco.StartCash, 0)
	self:Recalculate()
	self.Carried = math.min(num(data.Carried, 0, 0), self.BackpackCapacity)
	self.HiveStored = math.min(num(data.HiveStored, 0, 0), self.HiveCapacity)
	self.BottlingQueue = math.floor(num(data.BottlingQueue, 0, 0))
	self.BottlingAcc = math.clamp(num(data.BottlingAcc, 0, 0), 0, 1)
	self.Unclaimed = num(data.Unclaimed, 0, 0)
	self.BeesBought = math.floor(num(data.BeesBought, 0, 0))
	if type(data.Jars) == "table" then for _, t in data.Jars do table.insert(self.Jars, math.clamp(num(t, eco.JarTravelTime, 0), 0, eco.JarTravelTime)) end end
	if type(data.Totals) == "table" then
		for key in self.Totals do
			if key == "Earned" and data.Totals[key] == nil then
				self.Totals[key] = num(data.Cash, eco.StartCash, 0)
			else
				self.Totals[key] = num(data.Totals[key], 0, 0)
			end
		end
	end
	local maxId, usedIds = 0, {}
	if type(data.Bees) == "table" then
		for _, beeData in data.Bees do
			if type(beeData) == "table" and type(beeData.Tier) == "string" then
				local isVariant = beeData.Tier == "Variant" and self._x.Variants ~= nil and self._x.Variants.Get(math.floor(num(beeData.Variant, 0, 0))) ~= nil
				if bees[beeData.Tier] or isVariant then
					local id = math.floor(num(beeData.Id, 0, 1))
					if id < 1 or usedIds[id] then id = maxId + 1 end
					usedIds[id] = true
					maxId = math.max(maxId, id)
					local bee: Bee = { Id = id, Tier = beeData.Tier }
					if isVariant then bee.Variant = math.floor(num(beeData.Variant, 0, 0)) elseif beeData.Shiny == true then bee.Shiny = true end
					table.insert(self.Bees, bee)
					self.Discovered[FarmState.BeeKey(bee)] = true
					if bee.Shiny then self.Discovered[bee.Tier] = true end
				end
			end
		end
	end
	if #self.Bees == 0 then for _, tier in eco.StartBees do local bee = { Id = maxId + 1, Tier = tier }; maxId += 1; table.insert(self.Bees, bee); self.Discovered[tier] = true end end
	self.NextBeeId = math.max(maxId + 1, math.floor(num(data.NextBeeId, 1, 1)))
	self.TutorialStep = math.floor(num(data.TutorialStep, 1, 1))
	if type(data.Discovered) == "table" then
		for _, key in data.Discovered do
			if type(key) == "string" then
				local base = key:gsub("%*$", "")
				local vid = key:match("^V(%d+)$")
				if bees[base] or (vid and self._x.Variants and self._x.Variants.Get(tonumber(vid) :: number)) then self.Discovered[key] = true end
			end
		end
	end
	return self
end
function FarmState.ApplyOffline(self: State, elapsedSeconds: number, capSeconds: number): (number, number, number)
	local counted = math.clamp(elapsedSeconds, 0, capSeconds)
	local wouldMake = math.floor(self:ProductionRate() * counted)
	local room = math.max(0, self.HiveCapacity - self.HiveStored)
	local credited = math.min(wouldMake, room)
	self.HiveStored += credited
	self.Totals.Produced += credited
	return credited, counted, wouldMake
end
function FarmState.BottlingProgress(self: State): number return if self.BottlingQueue > 0 then math.clamp(self.BottlingAcc, 0, 1) else 0 end
function FarmState.HoneyInSystem(self: State): number return self.HiveStored + self.Carried + self.BottlingQueue + #self.Jars end
return FarmState
