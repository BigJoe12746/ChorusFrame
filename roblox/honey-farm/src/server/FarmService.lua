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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local FarmState = require(Shared:WaitForChild("FarmState"))
local BeeAppearance = require(Shared:WaitForChild("BeeAppearance"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local UpgradeVisuals = require(script.Parent:WaitForChild("UpgradeVisuals"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local JarRemote = Remotes:WaitForChild("JarStarted") :: RemoteEvent
local OpenShopRemote = Remotes:WaitForChild("OpenShop") :: RemoteEvent
local ShopActionRemote = Remotes:WaitForChild("ShopAction") :: RemoteEvent
local BeeMergedRemote = Remotes:WaitForChild("BeeMerged") :: RemoteEvent
local UpgradeRemote = Remotes:WaitForChild("UpgradeAction") :: RemoteEvent

local FarmService = {}

type Farm = {
	Player: Player,
	Plot: Model,
	State: FarmState.State,
	Replicated: { [string]: any },
	Busy: boolean, -- a shop action is being processed (blocks double submits)
}

local farms: { [Player]: Farm } = {}

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function fmt(n: number): string
	return tostring(math.floor(n + 0.5))
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
		table.insert(parts, bee.Id .. ":" .. bee.Tier)
	end
	return table.concat(parts, ",")
end

local function encodeDiscovered(state: FarmState.State): string
	local parts = {}
	for _, tier in Config.BeeOrder do
		if state.Discovered[tier] then
			table.insert(parts, tier)
		end
	end
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
	setAttr(farm, farm.Player, "Carried", s.Carried)
	setAttr(farm, farm.Player, "BackpackCapacity", s.BackpackCapacity)
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
	setAttr(farm, farm.Plot, "Upgrades", encodeUpgrades(s))
	setAttr(farm, farm.Plot, "BeePrice", s:BeePrice())
	setAttr(farm, farm.Plot, "Bees", encodeBees(s))
	setAttr(farm, farm.Plot, "Discovered", encodeDiscovered(s))
end

local PLOT_KEYS = { "HiveStored", "HiveCapacity", "BottlingQueue", "BottlingProgress", "JarsOnBelt", "Unclaimed", "ProductionRate", "BeeCount", "BeeSlots", "BeePrice", "Bees", "Discovered", "BottlingSpeed", "ProductionMultiplier", "Upgrades" }
local PLAYER_KEYS = { "Cash", "Carried", "BackpackCapacity" }

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
	local model = if template then BeeAppearance.Build(template, bee.Tier) else fallbackBee(bee.Tier)
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
end

function actions.Bottling(farm: Farm)
	local s = farm.State
	if s.Carried <= 0 then
		notify(farm.Player, "You have no honey to deposit. Collect some from your hive first.", "info")
		return
	end
	local moved = s:Deposit()
	notify(farm.Player, ("Deposited %s 🍯. Bottling %s honey into jars..."):format(fmt(moved), fmt(s.BottlingQueue)), "success")
end

function actions.SellStand(farm: Farm)
	local s = farm.State
	if s.Unclaimed <= 0 then
		notify(farm.Player, "No cash to collect yet. Jars pay out when they reach the stand.", "info")
		return
	end
	local moved = s:CollectCash()
	notify(farm.Player, ("+$%s collected! You now have $%s 💰"):format(fmt(moved), fmt(s.Cash)), "success")
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
		if reason == "NoSlots" then
			notify(farm.Player, ("All %d bee slots are full. Merge two bees, or buy the Bee Slots upgrade!"):format(s.BeeSlots), "warning")
		else
			notify(farm.Player, ("You need $%s for a Starter Bee (you have $%s)."):format(fmt(price), fmt(s.Cash)), "warning")
		end
		return
	end
	spawnBeeModel(farm, bee, true)
	notify(farm.Player, ("Bought a Starter Bee for $%s! 🐝 (%d/%d slots)"):format(fmt(price), #s.Bees, s.BeeSlots), "success")
end

local MERGE_MESSAGES = {
	SameBee = "Pick two different bees to merge.",
	NotFound = "One of those bees isn't on your farm any more.",
	DifferentTier = "Only two bees of the same tier can merge.",
	MaxTier = "Royal Bees are already the top tier and can't be merged.",
}

local function mergeBees(farm: Farm, idA: any, idB: any)
	if type(idA) ~= "number" or type(idB) ~= "number" then
		return
	end
	local s = farm.State
	local bee, isNew, reason = s:MergeBees(idA, idB)
	if not bee then
		notify(farm.Player, MERGE_MESSAGES[reason] or "Those bees can't merge.", "warning")
		return
	end
	removeBeeModel(farm, idA)
	removeBeeModel(farm, idB)
	spawnBeeModel(farm, bee, true)
	BeeMergedRemote:FireAllClients(farm.Plot:GetAttribute("PlotId"), idA, idB, bee.Id, bee.Tier, isNew)
	local info = Config.Bees[bee.Tier]
	if isNew then
		notify(farm.Player, ("✨ New bee discovered: %s! It makes %.1f 🍯/s."):format(info.Name, info.HoneyPerSecond), "success")
	else
		notify(farm.Player, ("Merged into a %s (%.1f 🍯/s)."):format(info.Name, info.HoneyPerSecond), "success")
	end
end

local function onShopAction(player: Player, action: any, a: any, b: any)
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

local function onUpgradeAction(player: Player, id: any)
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
		UpgradeVisuals.Apply(farm.Plot, s)
		notify(player, ("⬆ %s upgraded to %s for $%s!"):format(u.Name, formatValue(id, nextValue :: number), fmt(price :: number)), "success")
	elseif reason == "Maxed" then
		notify(player, ("%s is already at the maximum level."):format(u.Name), "info")
	else
		notify(player, ("You need $%s to upgrade %s (you have $%s)."):format(fmt(price or 0), u.Name, fmt(s.Cash)), "warning")
	end
	replicate(farm)
	farm.Busy = false
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function startFarm(player: Player, plot: Model)
	if farms[player] then
		return
	end
	local farm: Farm = {
		Player = player,
		Plot = plot,
		State = FarmState.new(Config.Economy, Config.Bees, Config.BeeOrder, Config.Upgrades),
		Replicated = {},
		Busy = false,
	}
	farms[player] = farm
	for _, bee in farm.State.Bees do
		spawnBeeModel(farm, bee)
	end
	UpgradeVisuals.Apply(plot, farm.State)
	replicate(farm)
end

local function stopFarm(player: Player, plot: Model)
	local farm = farms[player]
	farms[player] = nil
	for _, key in PLOT_KEYS do
		plot:SetAttribute(key, nil)
	end
	if farm and farm.Player.Parent then
		for _, key in PLAYER_KEYS do
			farm.Player:SetAttribute(key, nil)
		end
	end
	-- PlotService clears plot.Temp (bee models) when it releases the plot.
end

-- Advances every farm. Called from Heartbeat; tests call it directly.
function FarmService.Tick(dt: number)
	for _, farm in farms do
		local result = farm.State:Tick(dt)
		if result.JarsStarted > 0 then
			JarRemote:FireAllClients(farm.Plot:GetAttribute("PlotId"), result.JarsStarted)
		end
		replicate(farm)
	end
end

function FarmService.GetState(player: Player): FarmState.State?
	local farm = farms[player]
	return if farm then farm.State else nil
end

function FarmService.Start()
	PlotService.PlotAssigned:Connect(startFarm)
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

	-- players who already own a plot (e.g. script reloaded)
	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then
			startFarm(player, plot)
		end
	end
end

return FarmService
