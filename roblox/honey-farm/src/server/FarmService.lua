-- FarmService (ModuleScript)
-- Runs the honey loop, the bee shop and merging for every owned plot. All economy
-- changes happen here on the server; clients only read the attributes this module writes.
--
--   Player attributes: Cash, Carried, BackpackCapacity
--   Plot attributes:   HiveStored, HiveCapacity, BottlingQueue, BottlingProgress, JarsOnBelt,
--                      Unclaimed, ProductionRate, BeeCount, BeeSlots, BeePrice,
--                      Bees ("id:Tier,id:Tier"), Discovered ("Starter,Clover"),
--                      Upgrades ("Production:1,HiveStorage:2,..."), BottlingSpeed, ProductionMultiplier
--   Remotes:  JarStarted(plotId, n)                   -> all clients animate jars
--             OpenShop()                              -> the owner's client opens the shop UI
--             ShopAction("Buy") / ("Merge", idA, idB) <- the owner's client
--             BeeMerged(plotId, idA, idB, newId, tier, isNew) -> all clients play the merge effect
--             UpgradeAction(id)                       <- the owner's client (must be standing on their plot)
--             WelcomeBack(summary)                    -> the owner's client shows the offline-honey summary
--             Feedback(kind, amount, station)         -> the owner's client plays effects/sounds
--   Player attribute TutorialStep (1..#Config.Tutorial.Steps, or one past = finished)
--   Player attribute FarmLoading = true while the save is being read; no economy action is
--   possible until it clears (farms[player] stays nil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local FarmState = require(Shared:WaitForChild("FarmState"))
local BeeAppearance = require(Shared:WaitForChild("BeeAppearance"))
local VariantBees = require(Shared:WaitForChild("VariantBees"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local UpgradeVisuals = require(script.Parent:WaitForChild("UpgradeVisuals"))
local SaveService = require(script.Parent:WaitForChild("SaveService"))
local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local JarRemote = Remotes:WaitForChild("JarStarted") :: RemoteEvent
local OpenShopRemote = Remotes:WaitForChild("OpenShop") :: RemoteEvent
local ShopActionRemote = Remotes:WaitForChild("ShopAction") :: RemoteEvent
local BeeMergedRemote = Remotes:WaitForChild("BeeMerged") :: RemoteEvent
local UpgradeRemote = Remotes:WaitForChild("UpgradeAction") :: RemoteEvent
local WelcomeRemote = Remotes:WaitForChild("WelcomeBack") :: RemoteEvent
local FeedbackRemote = Remotes:WaitForChild("Feedback") :: RemoteEvent
local RebirthRemote = Remotes:WaitForChild("RebirthAction") :: RemoteEvent
local RobuxShopRemote = Remotes:WaitForChild("RobuxShop") :: RemoteEvent
local EggHatchedRemote = Remotes:WaitForChild("EggHatched") :: RemoteEvent

local FarmService = {}

-- Random source for eggs and shiny rolls; tests replace it with a scripted sequence.
local rng = Random.new()
FarmService.Roll = function(): number
	return rng:NextNumber()
end

local EXTRAS = {
	Variants = VariantBees,
	Eggs = Config.Eggs,
	ShinyChance = Config.Economy.ShinyChance,
	ShinyMultiplier = Config.Economy.ShinyMultiplier,
	KeepVariantsOnRebirth = Config.Rebirth.KeepVariants,
}

type Farm = {
	Player: Player,
	Plot: Model,
	State: FarmState.State,
	Replicated: { [string]: any },
	Busy: boolean, -- a shop action is being processed (blocks double submits)
	CanSave: boolean, -- false when the load failed: never overwrite that player's real progress
	LoadedSavedAt: number, -- SavedAt of the save we loaded (0 for a new player)
}

local farms: { [Player]: Farm } = {}
local remoteLimiter = RateLimiter.new(Config.Limits.RemotesPerSecond, 1)
local flooded: { [Player]: boolean } = {}

-- True if this remote call may proceed; floods are dropped (one warning per player).
local function allowRemote(player: Player): boolean
	if remoteLimiter:Allow(player, os.clock()) then
		return true
	end
	if not flooded[player] then
		flooded[player] = true
		warn(("[HoneyFarm] Dropping flooded requests from %s (%d+/s)"):format(player.Name, Config.Limits.RemotesPerSecond))
	end
	return false
end

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function fmt(n: number): string
	return Config.Progression.FormattedNumber(n)
end

------------------------------------------------------------------------------
-- Replication (only writes attributes whose value changed)
------------------------------------------------------------------------------

local function setAttr(farm: Farm, target: Instance, key: string, value: any)
	if farm.Replicated[key] ~= value then
		farm.Replicated[key] = value
		target:SetAttribute(key, value)
	end
end

local function encodeBees(state: FarmState.State): string
	local parts = {}
	for _, bee in state.Bees do
		table.insert(parts, bee.Id .. ":" .. FarmState.BeeKey(bee))
	end
	return table.concat(parts, ",")
end

local function encodeDiscovered(state: FarmState.State): string
	local parts = {}
	for key, found in state.Discovered do
		if found then
			table.insert(parts, key)
		end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function encodeUpgrades(state: FarmState.State): string
	local parts = {}
	for _, id in Config.Upgrades.Order do
		table.insert(parts, id .. ":" .. state:UpgradeLevel(id))
	end
	return table.concat(parts, ",")
end

local function replicate(farm: Farm)
	local s = farm.State
	setAttr(farm, farm.Player, "Cash", s.Cash)
	setAttr(farm, farm.Player, "Rebirths", s.Rebirths)
	setAttr(farm, farm.Player, "RebirthMultiplier", s.RebirthMultiplier)
	setAttr(farm, farm.Player, "RebirthCost", FarmState.RebirthCost(s.Rebirths, Config.Rebirth, Config.Progression))
	setAttr(farm, farm.Player, "NextRebirthMultiplier", Config.Progression.NextRebirthMultiplier(s.Rebirths, Config.Rebirth.ProductionMultiplier))
	setAttr(farm, farm.Player, "Carried", s.Carried)
	setAttr(farm, farm.Player, "BackpackCapacity", s.BackpackCapacity)
	setAttr(farm, farm.Player, "TutorialStep", s.TutorialStep)
	setAttr(farm, farm.Plot, "HiveStored", s.HiveStored)
	setAttr(farm, farm.Plot, "HiveCapacity", s.HiveCapacity)
	setAttr(farm, farm.Plot, "BottlingQueue", s.BottlingQueue)
	setAttr(farm, farm.Plot, "BottlingProgress", math.floor(s:BottlingProgress() * 20 + 0.5) / 20)
	setAttr(farm, farm.Plot, "JarsOnBelt", #s.Jars)
	setAttr(farm, farm.Plot, "Unclaimed", s.Unclaimed)
	setAttr(farm, farm.Plot, "ProductionRate", s:ProductionRate())
	setAttr(farm, farm.Plot, "BeeCount", #s.Bees)
	setAttr(farm, farm.Plot, "BeeSlots", s.BeeSlots)
	setAttr(farm, farm.Plot, "BottlingSpeed", s.BottlingPerSecond)
	setAttr(farm, farm.Plot, "ProductionMultiplier", s.ProductionMultiplier)
	setAttr(farm, farm.Plot, "PotentialCashPerSecond", s:PotentialCashPerSecond())
	setAttr(farm, farm.Plot, "Upgrades", encodeUpgrades(s))
	setAttr(farm, farm.Plot, "BeePrice", s:BeePrice())
	setAttr(farm, farm.Plot, "BeesBought", s.BeesBought)
	local nextSpend, nextCost = s:RecommendedSpend()
	setAttr(farm, farm.Player, "RecommendedSpend", nextSpend or "None")
	setAttr(farm, farm.Player, "RecommendedSpendCost", nextCost or 0)
	setAttr(farm, farm.Plot, "Bees", encodeBees(s))
	setAttr(farm, farm.Plot, "Discovered", encodeDiscovered(s))
end

local PLOT_KEYS = { "HiveStored", "HiveCapacity", "BottlingQueue", "BottlingProgress", "JarsOnBelt", "Unclaimed", "ProductionRate", "PotentialCashPerSecond", "BeeCount", "BeeSlots", "BeePrice", "BeesBought", "Bees", "Discovered", "BottlingSpeed", "ProductionMultiplier", "Upgrades" }
local PLAYER_KEYS = { "Cash", "Rebirths", "RebirthMultiplier", "RebirthCost", "NextRebirthMultiplier", "Carried", "BackpackCapacity", "TutorialStep" }

local function feedback(farm: Farm, kind: string, amount: number, station: string)
	FeedbackRemote:FireClient(farm.Player, kind, amount, station)
end

-- Advances the introduction when its current step's action just succeeded.
local function tutorial(farm: Farm, step: number)
	local s = farm.State
	if s:AdvanceTutorial(step) then
		local finished = s.TutorialStep > #Config.Tutorial.Steps
		if finished and Config.Tutorial.Reward > 0 then
			s.Cash += Config.Tutorial.Reward
			notify(farm.Player, ("🎉 Introduction complete! Bonus: +$%s. The farm is all yours."):format(fmt(Config.Tutorial.Reward)), "success")
		end
	end
end

------------------------------------------------------------------------------
-- Bee models (visual only; flight is animated on each client)
------------------------------------------------------------------------------

local function beeTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local t = assets and assets:FindFirstChild("BeeTemplate")
	return if t and t:IsA("Model") then t else nil
end

local function fallbackBee(tier: string): Model
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2, 2.6)
	body.Color = Color3.fromHex(Config.Bees[tier].Look.Body)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body
	model:SetAttribute("Bee", true)
	model:SetAttribute("Tier", tier)
	return model
end

local function spawnBeeModel(farm: Farm, bee: FarmState.Bee, popIn: boolean?)
	local temp = farm.Plot:FindFirstChild("Temp")
	local exit = farm.Plot:FindFirstChild("BeeExit", true) :: BasePart?
	if not temp or not exit then
		return
	end
	local template = beeTemplate()
	local model: Model
	if not template then
		model = fallbackBee(if bee.Tier == "Variant" then Config.BeeOrder[1] else bee.Tier)
	elseif bee.Tier == "Variant" then
		model = BeeAppearance.BuildVariant(template, VariantBees.Get(bee.Variant :: number))
	else
		model = BeeAppearance.Build(template, bee.Tier, bee.Shiny)
	end
	model.Name = ("Bee%d"):format(bee.Id)
	model:SetAttribute("BeeId", bee.Id)
	if popIn then
		model:SetAttribute("PopIn", true)
	end
	model:PivotTo(exit.CFrame * CFrame.new(0, 0, -(bee.Id % 4) * 1.2))
	model.Parent = temp
end

local function removeBeeModel(farm: Farm, id: number)
	local temp = farm.Plot:FindFirstChild("Temp")
	local model = temp and temp:FindFirstChild(("Bee%d"):format(id))
	if model then
		model:Destroy()
	end
end

------------------------------------------------------------------------------
-- Station actions (E / tap at a station)
------------------------------------------------------------------------------

local actions: { [string]: (Farm) -> () } = {}

function actions.Hive(farm: Farm)
	local s = farm.State
	if s.HiveStored <= 0 then
		notify(farm.Player, "The hive is empty. Your bees are still working on it! 🐝", "info")
		return
	end
	if s.Carried >= s.BackpackCapacity then
		notify(farm.Player, "Your backpack is full! Deposit honey at the Bottling station.", "warning")
		return
	end
	local moved = s:CollectHive()
	notify(farm.Player, ("+%s 🍯 honey collected (%s/%s carried)"):format(fmt(moved), fmt(s.Carried), fmt(s.BackpackCapacity)), "success")
	feedback(farm, "Honey", moved, "Hive")
	tutorial(farm, 1)
end

function actions.HivePlate(farm: Farm)
	-- Collect only: upgrades are bought in the Upgrades panel so cash is never spent by accident.
	local s = farm.State
	local collectedHoney = 0
	local collectedCash = 0
	if s.HiveStored > 0 and s.Carried < s.BackpackCapacity then
		collectedHoney = s:CollectHive()
	end
	if s.Unclaimed > 0 then
		collectedCash = s:CollectCash()
	end
	if collectedHoney > 0 then
		feedback(farm, "Honey", collectedHoney, "Hive")
		tutorial(farm, 1)
	end
	if collectedCash > 0 then
		feedback(farm, "Cash", collectedCash, "Hive")
	end

	local details = {}
	if collectedHoney > 0 then
		table.insert(details, fmt(collectedHoney) .. " honey")
	elseif s.HiveStored > 0 and s.Carried >= s.BackpackCapacity then
		table.insert(details, "backpack full; honey left in hive")
	end
	if collectedCash > 0 then
		table.insert(details, "$" .. fmt(collectedCash) .. " cash")
	end
	if #details == 0 then
		notify(farm.Player, "Nothing to collect yet. Your bees are still working on it! 🐝", "info")
		return
	end
	notify(farm.Player, table.concat(details, " • "), if collectedHoney > 0 or collectedCash > 0 then "success" else "warning")
end

function actions.Bottling(farm: Farm)
	local s = farm.State
	if s.Carried <= 0 then
		notify(farm.Player, "You have no honey to deposit. Collect some from your hive first.", "info")
		return
	end
	local moved = s:Deposit()
	notify(farm.Player, ("Deposited %s 🍯. Bottling %s honey into jars..."):format(fmt(moved), fmt(s.BottlingQueue)), "success")
	feedback(farm, "Deposit", moved, "Bottling")
	tutorial(farm, 2)
end

function actions.SellStand(farm: Farm)
	local s = farm.State
	if s.Unclaimed <= 0 then
		notify(farm.Player, "No cash to collect yet. Jars pay out when they reach the stand.", "info")
		return
	end
	local moved = s:CollectCash()
	notify(farm.Player, ("+$%s collected! You now have $%s 💰"):format(fmt(moved), fmt(s.Cash)), "success")
	feedback(farm, "Cash", moved, "SellStand")
	tutorial(farm, 3)
end

function actions.FlowerPatch(farm: Farm)
	local s = farm.State
	notify(farm.Player, ("%d bee(s) visiting these flowers, making %.1f 🍯 per second."):format(#s.Bees, s:ProductionRate()), "info")
end

function actions.BeeShop(farm: Farm)
	OpenShopRemote:FireClient(farm.Player)
end

------------------------------------------------------------------------------
-- Shop actions (from the shop UI)
------------------------------------------------------------------------------

local function buyBee(farm: Farm)
	local s = farm.State
	local price = s:BeePrice()
	local bee, reason = s:BuyBee()
	if not bee then
		feedback(farm, "Deny", price, "BeeShop")
		if reason == "NoSlots" then
			notify(farm.Player, ("All %d bee slots are full. Merge two bees, or buy the Bee Slots upgrade!"):format(s.BeeSlots), "warning")
		else
			notify(farm.Player, ("You need $%s for a Starter Bee (you have $%s)."):format(fmt(price), fmt(s.Cash)), "warning")
		end
		return
	end
	spawnBeeModel(farm, bee, true)
	notify(farm.Player, ("Bought a Starter Bee for $%s! 🐝 (%d/%d slots)"):format(fmt(price), #s.Bees, s.BeeSlots), "success")
	feedback(farm, "Buy", price, "BeeShop")
	tutorial(farm, 4)
end

local MERGE_MESSAGES = {
	SameBee = "Pick two different bees to merge.",
	NotFound = "One of those bees isn't on your farm any more.",
	DifferentTier = "Only two bees of the same tier can merge.",
	MaxTier = "That bee is already the top tier and can't be merged.",
	Variant = "Egg bees are one of a kind: they can't be merged.",
}

local function mergeBees(farm: Farm, idA: any, idB: any)
	if type(idA) ~= "number" or type(idB) ~= "number" then
		return
	end
	local s = farm.State
	local bee, isNew, reason = s:MergeBees(idA, idB, FarmService.Roll())
	if not bee then
		notify(farm.Player, MERGE_MESSAGES[reason] or "Those bees can't merge.", "warning")
		return
	end
	removeBeeModel(farm, idA)
	removeBeeModel(farm, idB)
	spawnBeeModel(farm, bee, true)
	BeeMergedRemote:FireAllClients(farm.Plot:GetAttribute("PlotId"), idA, idB, bee.Id, bee.Tier, isNew)
	tutorial(farm, 5)
	local info = { Name = s:BeeName(bee), HoneyPerSecond = s:BeeRate(bee) }
	if bee.Shiny and isNew then
		notify(farm.Player, ("🌟 SHINY! You made a %s! It makes %s 🍯/s."):format(info.Name, fmt(info.HoneyPerSecond)), "success")
	elseif isNew then
		notify(farm.Player, ("✨ New bee discovered: %s! It makes %.1f 🍯/s."):format(info.Name, info.HoneyPerSecond), "success")
	else
		notify(farm.Player, ("Merged into a %s (%.1f 🍯/s)."):format(info.Name, info.HoneyPerSecond), "success")
	end
end

local function buyEgg(farm: Farm, eggName: any)
	if type(eggName) ~= "string" or not Config.Eggs[eggName] then
		return
	end
	local s = farm.State
	local egg = Config.Eggs[eggName]
	local bee, isNew, result = s:HatchEgg(eggName, FarmService.Roll(), FarmService.Roll())
	if not bee then
		feedback(farm, "Deny", egg.Price, "BeeShop")
		if result == "NoSlots" then
			notify(farm.Player, ("All %d bee slots are full. Merge two bees or buy the Bee Slots upgrade!"):format(s.BeeSlots), "warning")
		else
			notify(farm.Player, ("You need $%s for a %s (you have $%s)."):format(fmt(egg.Price), egg.Name, fmt(s.Cash)), "warning")
		end
		return
	end
	spawnBeeModel(farm, bee, true)
	local name = s:BeeName(bee)
	local rarity = if bee.Tier == "Variant" then VariantBees.Get(bee.Variant :: number).Rarity else "Ladder"
	EggHatchedRemote:FireAllClients(farm.Plot:GetAttribute("PlotId"), bee.Id, name, rarity, isNew)
	feedback(farm, "Buy", egg.Price, "BeeShop")
	if isNew then
		notify(farm.Player, ("🥚 Hatched: %s (%s) — new to your collection! %s 🍯/s"):format(name, rarity, fmt(s:BeeRate(bee))), "success")
	else
		notify(farm.Player, ("🥚 Hatched: %s (%s). %s 🍯/s"):format(name, rarity, fmt(s:BeeRate(bee))), "success")
	end
end

local function onShopAction(player: Player, action: any, a: any, b: any)
	if not allowRemote(player) then
		return
	end
	local farm = farms[player]
	if not farm or farm.Busy then
		return
	end
	if not PlotService.IsNearStation(player, farm.Plot, "BeeShop") then
		notify(player, "Walk up to your Bee Shop to trade.", "warning")
		return
	end
	farm.Busy = true
	if action == "Buy" then
		buyBee(farm)
	elseif action == "Egg" then
		buyEgg(farm, a)
	elseif action == "Merge" then
		mergeBees(farm, a, b)
	end
	replicate(farm)
	farm.Busy = false
end

------------------------------------------------------------------------------
-- Upgrades (from the Upgrades panel; the player must be on their own plot)
------------------------------------------------------------------------------

local function onPlot(player: Player, plot: Model): boolean
	local character = player.Character
	if not character then
		return false
	end
	local offset = plot:GetPivot():PointToObjectSpace(character:GetPivot().Position)
	local half = Config.PlotSize / 2 + 8
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

local function formatValue(id: string, value: number): string
	local u = Config.Upgrades[id]
	return string.format(u.Format or "%g", value)
end

local function onRebirthAction(player: Player)
	if not allowRemote(player) then return end
	local farm = farms[player]
	if not farm or farm.Busy then return end
	farm.Busy = true
	local cost = FarmState.RebirthCost(farm.State.Rebirths, Config.Rebirth, Config.Progression)
	if not farm.State:Rebirth(Config.Rebirth) then
		feedback(farm, "Deny", cost, "Rebirth")
		notify(player, ("You need $%s to rebirth (you have $%s)." ):format(fmt(cost), fmt(farm.State.Cash)), "warning")
		farm.Busy = false
		return
	end
	local temp = farm.Plot:FindFirstChild("Temp")
	if temp then
		for _, child in temp:GetChildren() do
			if child.Name == "Upgrades" or child:GetAttribute("Bee") == true or child.Name:match("^Bee%d+$") then child:Destroy() end
		end
	end
	for _, bee in farm.State.Bees do spawnBeeModel(farm, bee) end
	UpgradeVisuals.Apply(farm.Plot, farm.State)
	replicate(farm)
	notify(player, ("Rebirth %d complete! Honey production is now x%.2f."):format(farm.State.Rebirths, farm.State.RebirthMultiplier), "success")
	farm.Busy = false
end

local function onUpgradeAction(player: Player, id: any)
	if not allowRemote(player) then
		return
	end
	local farm = farms[player]
	if not farm or farm.Busy or type(id) ~= "string" or not Config.Upgrades[id] then
		return
	end
	if not onPlot(player, farm.Plot) then
		notify(player, "Go to your farm to buy upgrades.", "warning")
		return
	end
	farm.Busy = true
	local s = farm.State
	local u = Config.Upgrades[id]
	local nextValue, price = s:NextUpgrade(id)
	local level, reason = s:BuyUpgrade(id)
	if level then
		-- station slot carries the upgrade id so client UI can flash the row
		feedback(farm, "Upgrade", price :: number, id)
		UpgradeVisuals.Apply(farm.Plot, s)
		notify(player, ("⬆ %s upgraded to %s for $%s!"):format(u.Name, formatValue(id, nextValue :: number), fmt(price :: number)), "success")
	elseif reason == "Maxed" then
		notify(player, ("%s is already at the maximum level."):format(u.Name), "info")
	else
		feedback(farm, "Deny", price or 0, id)
		notify(player, ("You need $%s to upgrade %s (you have $%s)."):format(fmt(price or 0), u.Name, fmt(s.Cash)), "warning")
	end
	replicate(farm)
	farm.Busy = false
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local loading: { [Player]: boolean } = {}

local function formatDuration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm"):format(math.max(1, m))
end

local function newState(): FarmState.State
	return FarmState.new(Config.Economy, Config.Bees, Config.BeeOrder, Config.Upgrades, Config.Rebirth.ProductionMultiplier, Config.Progression, EXTRAS)
end

local function startFarm(player: Player, plot: Model)
	if farms[player] or loading[player] then
		return
	end
	loading[player] = true
	player:SetAttribute("FarmLoading", true)

	-- Load BEFORE the farm exists, so nothing can be bought, collected or sold on unloaded data.
	local data, ok = SaveService.Load(player)

	-- the player may have left (or lost the plot) while we waited on the DataStore
	loading[player] = nil
	if not player.Parent or PlotService.GetPlot(player) ~= plot then
		return
	end

	local state: FarmState.State
	local canSave = ok
	local loadedSavedAt = 0
	local welcome: { [string]: any }? = nil

	if ok and data then
		state = FarmState.Deserialize(data, Config.Economy, Config.Bees, Config.BeeOrder, Config.Upgrades, Config.Rebirth.ProductionMultiplier, Config.Progression, EXTRAS)
		loadedSavedAt = tonumber(data.SavedAt) or 0
		local away = math.max(0, SaveService.Now() - loadedSavedAt)
		if loadedSavedAt > 0 and away >= 60 then
			local credited, counted, wouldMake = state:ApplyOffline(away, Config.Save.OfflineCapHours * 3600)
			welcome = {
				Away = away,
				Counted = counted,
				Credited = credited,
				WouldMake = wouldMake,
				HiveFull = credited < wouldMake,
				Capped = counted < away,
				HiveStored = state.HiveStored,
				HiveCapacity = state.HiveCapacity,
			}
		end
	else
		state = newState()
	end

	local farm: Farm = {
		Player = player,
		Plot = plot,
		State = state,
		Replicated = {},
		Busy = false,
		CanSave = canSave,
		LoadedSavedAt = loadedSavedAt,
	}
	farms[player] = farm
	for _, bee in farm.State.Bees do
		spawnBeeModel(farm, bee)
	end
	UpgradeVisuals.Apply(plot, farm.State)
	replicate(farm)
	player:SetAttribute("FarmLoading", nil)

	if not SaveService.Available then
		notify(player, "⚠ Saving is unavailable this session, so progress is temporary. " .. SaveService.Reason, "warning")
	elseif not ok then
		notify(player, "⚠ Couldn't load your save. You're playing on a temporary farm and nothing will be saved, so your real progress stays safe. Rejoin to try again.", "warning")
	elseif welcome then
		WelcomeRemote:FireClient(player, welcome)
		local w = welcome :: { [string]: any }
		notify(player, ("Welcome back! Away %s: your bees made %d 🍯%s"):format(formatDuration(w.Away), w.Credited, if w.HiveFull then " (hive full)" else ""), "success")
	end
end

-- Writes the farm to the DataStore. Returns true if it was saved.
local function saveFarm(farm: Farm): boolean
	if not farm.CanSave or not SaveService.Available then
		return false
	end
	local data = farm.State:Serialize(SaveService.Now())
	local saved = SaveService.Save(farm.Player, data, farm.LoadedSavedAt)
	if saved then
		farm.LoadedSavedAt = data.SavedAt
	end
	return saved
end

local function stopFarm(player: Player, plot: Model)
	local farm = farms[player]
	farms[player] = nil
	loading[player] = nil
	remoteLimiter:Forget(player)
	flooded[player] = nil
	if farm then
		saveFarm(farm)
	end
	for _, key in PLOT_KEYS do
		plot:SetAttribute(key, nil)
	end
	if farm and farm.Player.Parent then
		for _, key in PLAYER_KEYS do
			farm.Player:SetAttribute(key, nil)
		end
	end
	UpgradeVisuals.Apply(plot, nil) -- hive back to level 1 for the next owner
	-- PlotService clears plot.Temp (bee models) when it releases the plot.
end

local sinceAutosave = 0

-- Advances every farm. Called from Heartbeat; tests call it directly.
function FarmService.Tick(dt: number)
	for _, farm in farms do
		local result = farm.State:Tick(dt)
		if result.JarsStarted > 0 then
			JarRemote:FireAllClients(farm.Plot:GetAttribute("PlotId"), result.JarsStarted)
		end
		replicate(farm)
	end
	sinceAutosave += dt
	if sinceAutosave >= Config.Save.AutosaveInterval then
		sinceAutosave = 0
		for _, farm in farms do
			task.spawn(saveFarm, farm)
		end
	end
end

-- Saves every farm now (used on shutdown). Returns how many were written.
function FarmService.SaveAll(): number
	local n = 0
	for _, farm in farms do
		if saveFarm(farm) then
			n += 1
		end
	end
	return n
end

function FarmService.GetState(player: Player): FarmState.State?
	local farm = farms[player]
	return if farm then farm.State else nil
end

------------------------------------------------------------------------------
-- Robux cash shop. The client prompts the purchase; Roblox calls back here only
-- after the player actually pays, and the cash lands in the saved farm state.
------------------------------------------------------------------------------

local productOffers: { [number]: { [string]: any } } = {}
for _, offer in Config.Shop do
	if offer.ProductId ~= 0 then
		productOffers[offer.ProductId] = offer
	end
end

local function grantOffer(player: Player, offer: { [string]: any }): boolean
	local farm = farms[player]
	if not farm then
		return false
	end
	farm.State.Cash += offer.Amount
	farm.State.Totals.Earned += offer.Amount
	replicate(farm)
	feedback(farm, "Cash", offer.Amount, "Shop")
	notify(player, ("+$%s added! Thanks for supporting the farm."):format(fmt(offer.Amount)), "success")
	task.spawn(saveFarm, farm)
	return true
end

local function hookRobuxShop()
	RobuxShopRemote.OnServerEvent:Connect(function(player: Player, offerId: any)
		if not allowRemote(player) or type(offerId) ~= "string" then
			return
		end
		local offer: { [string]: any }? = nil
		for _, candidate in Config.Shop do
			if candidate.Id == offerId then
				offer = candidate
				break
			end
		end
		if not offer or offer.ProductId ~= 0 then
			return
		end
		if RunService:IsStudio() then
			grantOffer(player, offer)
		else
			notify(player, "This pack isn't for sale yet.", "info")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local offer = productOffers[receipt.ProductId]
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not offer or not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(grantOffer, player, offer)
		if ok and granted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function FarmService.Start()
	SaveService.Start()
	PlotService.PlotAssigned:Connect(function(player, plot)
		task.spawn(startFarm, player, plot)
	end)
	game:BindToClose(function()
		FarmService.SaveAll()
	end)
	PlotService.PlotReleased:Connect(stopFarm)
	PlotService.StationTriggered:Connect(function(player: Player, plot: Model, station: string)
		local farm = farms[player]
		if not farm or farm.Plot ~= plot then
			return
		end
		local action = actions[station]
		if action then
			action(farm)
			replicate(farm)
		end
	end)
	ShopActionRemote.OnServerEvent:Connect(onShopAction)
	UpgradeRemote.OnServerEvent:Connect(onUpgradeAction)
	RebirthRemote.OnServerEvent:Connect(onRebirthAction)
	hookRobuxShop()

	-- players who already own a plot (e.g. script reloaded)
	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then
			startFarm(player, plot)
		end
	end
end

return FarmService
