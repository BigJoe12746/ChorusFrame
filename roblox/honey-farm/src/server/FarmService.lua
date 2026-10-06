-- FarmService (ModuleScript)
-- Runs the honey loop for every owned plot. All economy changes happen here on the server;
-- clients only read the attributes this module writes.
--
--   Player attributes: Cash, Carried, BackpackCapacity
--   Plot attributes:   HiveStored, HiveCapacity, BottlingQueue, BottlingProgress,
--                      JarsOnBelt, Unclaimed, ProductionRate, BeeCount
--   Remotes:           JarStarted(plotId)  -> clients animate a jar down the conveyor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local FarmState = require(Shared:WaitForChild("FarmState"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local JarRemote = Remotes:WaitForChild("JarStarted") :: RemoteEvent

local FarmService = {}

type Farm = {
	Player: Player,
	Plot: Model,
	State: FarmState.State,
	Replicated: { [string]: any },
}

local farms: { [Player]: Farm } = {}

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
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
end

local PLOT_KEYS = { "HiveStored", "HiveCapacity", "BottlingQueue", "BottlingProgress", "JarsOnBelt", "Unclaimed", "ProductionRate", "BeeCount" }
local PLAYER_KEYS = { "Cash", "Carried", "BackpackCapacity" }

------------------------------------------------------------------------------
-- Bee models (visual only; flight is animated on each client)
------------------------------------------------------------------------------

local function beeTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local t = assets and assets:FindFirstChild("BeeTemplate")
	return if t and t:IsA("Model") then t else nil
end

local function spawnBeeModel(farm: Farm, index: number, tier: string)
	local temp = farm.Plot:FindFirstChild("Temp")
	local exit = farm.Plot:FindFirstChild("BeeExit", true) :: BasePart?
	if not temp or not exit then
		return
	end
	local info = Config.Bees[tier]
	local template = beeTemplate()
	local model: Model
	if template then
		model = template:Clone()
		local cam = model:FindFirstChildOfClass("Camera")
		if cam then
			cam:Destroy()
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		model:ScaleTo(model:GetScale() * (info.Scale or 0.35))
	else
		-- fallback so the game still works without the asset
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(2, 2, 2.6)
		body.Color = Color3.fromRGB(255, 200, 40)
		body.Anchored = true
		body.CanCollide = false
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = ("Bee%d"):format(index)
	model:SetAttribute("Bee", true)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("BeeIndex", index)
	model:PivotTo(exit.CFrame * CFrame.new(0, 0, -(index - 1) * 1.5))
	model.Parent = temp
end

------------------------------------------------------------------------------
-- Station actions
------------------------------------------------------------------------------

local function fmt(n: number): string
	return tostring(math.floor(n + 0.5))
end

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
	notify(farm.Player, "The Bee Shop opens in the next update! 🛒", "info")
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
		State = FarmState.new(Config.Economy, Config.Bees),
		Replicated = {},
	}
	farms[player] = farm
	for i, bee in farm.State.Bees do
		spawnBeeModel(farm, i, bee.Tier)
	end
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
	for player, farm in farms do
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

	-- players who already own a plot (e.g. script reloaded)
	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then
			startFarm(player, plot)
		end
	end
end

return FarmService
