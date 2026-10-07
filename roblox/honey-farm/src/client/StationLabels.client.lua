-- Updates the floating labels over each plot's hive, bottling machine and honey stand,
-- plus the cartoon-style pressure-plate signs (context line, green action line, yellow
-- price line, progress bar) from the plot attributes, so visitors see the same numbers
-- as the owner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local player = Players.LocalPlayer

local fmt = Config.Progression.FormattedNumber

local GREEN = Color3.fromRGB(105, 255, 105)
local YELLOW = Color3.fromRGB(255, 225, 80)
local WHITE = Color3.new(1, 1, 1)

local function label(plot: Instance, station: string): TextLabel?
	local s = plot:FindFirstChild("Stations")
	local m = s and s:FindFirstChild(station)
	local gui = m and m:FindFirstChild("Label", true)
	return gui and gui:FindFirstChildOfClass("TextLabel")
end

-- Gathers every text/bar element of one pressure plate: the label painted on the floor
-- plus the floating sign rows above it (Title / Action / Cost / Bar.Fill / Bar.BarText).
local function plateSigns(plot: Instance, station: string, plateName: string)
	local s = plot:FindFirstChild("Stations")
	local m = s and s:FindFirstChild(station)
	local plate = m and m:FindFirstChild(plateName, true)
	if not plate then
		return nil
	end
	local floorGui = plate:FindFirstChild("PlateLabel")
	local gui = plate:FindFirstChild("Label")
	local bar = gui and gui:FindFirstChild("Bar")
	return {
		Floor = floorGui and floorGui:FindFirstChild("Text") :: TextLabel?,
		Title = gui and gui:FindFirstChild("Title") :: TextLabel?,
		Action = gui and gui:FindFirstChild("Action") :: TextLabel?,
		Cost = gui and gui:FindFirstChild("Cost") :: TextLabel?,
		Fill = bar and bar:FindFirstChild("Fill") :: Frame?,
		BarText = bar and bar:FindFirstChild("BarText") :: TextLabel?,
	}
end

local function put(l: TextLabel?, text: string, color: Color3)
	if l then
		l.Text = text
		l.TextColor3 = color
	end
end

local function setBar(sign, ratio: number, text: string)
	if sign.Fill then
		sign.Fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	end
	if sign.BarText then
		sign.BarText.Text = text
	end
end

local function setFloor(sign, text: string)
	if sign.Floor then
		sign.Floor.Text = text
	end
end

-- "HiveStorage:2,Production:1,..." -> { HiveStorage = 2, Production = 1 }
local function parseLevels(encoded: any): { [string]: number }
	local out = {}
	if type(encoded) == "string" then
		for _, pair in string.split(encoded, ",") do
			local id, n = string.match(pair, "^(%a+):(%d+)$")
			if id and n then
				out[id] = tonumber(n)
			end
		end
	end
	return out
end

local function watch(plot: Instance)
	local hive = label(plot, "Hive")
	local bottling = label(plot, "Bottling")
	local stand = label(plot, "SellStand")
	local sellSign = plateSigns(plot, "SellStand", "SellPressurePlate")
	local hiveSign = plateSigns(plot, "Hive", "HivePressurePlate")
	local botSign = plateSigns(plot, "Bottling", "BottlingPressurePlate")

	local function refresh()
		local owned = (plot:GetAttribute("OwnerUserId") or 0) ~= 0

		-- Big labels over the stations themselves
		if hive then
			local stored = plot:GetAttribute("HiveStored")
			hive.Text = if owned and stored then ("%s\n%s / %s 🍯"):format(Config.Stations.Hive.Label, fmt(stored), fmt(plot:GetAttribute("HiveCapacity") or 0)) else Config.Stations.Hive.Label
		end
		if bottling then
			local queue = plot:GetAttribute("BottlingQueue")
			bottling.Text = if owned and queue and queue > 0 then ("%s\nbottling %d..."):format(Config.Stations.Bottling.Label, queue) else Config.Stations.Bottling.Label
		end
		if stand then
			local cash = plot:GetAttribute("Unclaimed")
			stand.Text = if owned and cash and cash > 0 then ("%s\n$%s ready!"):format(Config.Stations.SellStand.Label, fmt(cash)) else Config.Stations.SellStand.Label
		end

		-- Sell plate: cash waiting on the stand
		if sellSign then
			local cash = plot:GetAttribute("Unclaimed") or 0
			put(sellSign.Title, "(Auto Collect)", WHITE)
			put(sellSign.Action, "COLLECT CASH", GREEN)
			put(sellSign.Cost, if owned then "$" .. fmt(cash) else "", YELLOW)
			if owned and cash > 0 then
				setBar(sellSign, 1, "STEP TO COLLECT")
				setFloor(sellSign, ("COLLECT CASH\n$%s READY"):format(fmt(cash)))
			else
				setBar(sellSign, 0, if owned then "JARS PAY OUT HERE" else "OWNER ONLY")
				setFloor(sellSign, "STEP\nCOLLECT CASH")
			end
		end

		-- Hive plate: the next Hive Storage upgrade (what you get + price) and hive fill
		if hiveSign then
			local stored = plot:GetAttribute("HiveStored") or 0
			local capacity = plot:GetAttribute("HiveCapacity") or 0
			local level = parseLevels(plot:GetAttribute("Upgrades")).HiveStorage or 1
			local upgrade = Config.Upgrades.HiveStorage
			local nextValue = upgrade.Levels[level + 1]
			local price = Config.Progression.UpgradePrice("HiveStorage", level)
			put(hiveSign.Title, "(Auto Upgrade + Collect)", WHITE)
			if owned and nextValue and price then
				put(hiveSign.Action, ("STORE %s HONEY"):format(fmt(nextValue)), GREEN)
				put(hiveSign.Cost, "$" .. fmt(price), YELLOW)
				setFloor(hiveSign, ("STORE %s HONEY\n$%s"):format(fmt(nextValue), fmt(price)))
			elseif owned then
				put(hiveSign.Action, "HIVE STORAGE MAXED", YELLOW)
				put(hiveSign.Cost, "MAX!", YELLOW)
				setFloor(hiveSign, "HIVE STORAGE MAXED\nSTEP TO COLLECT")
			else
				put(hiveSign.Action, "HIVE UPGRADE + COLLECT", GREEN)
				put(hiveSign.Cost, "", YELLOW)
				setFloor(hiveSign, "STEP\nUPGRADE + COLLECT")
			end
			local ratio = if capacity > 0 then stored / capacity else 0
			local barText = ("%s / %s"):format(fmt(stored), fmt(capacity))
			setBar(hiveSign, ratio, barText)
			if owned and nextValue and price then
				setFloor(hiveSign, hiveSign.Floor.Text .. "\n" .. barText)
			end
		end

		-- Bottling plate: what you're carrying + what the machine is making
		if botSign then
			local queue = plot:GetAttribute("BottlingQueue") or 0
			local jars = plot:GetAttribute("JarsOnBelt") or 0
			local progress = plot:GetAttribute("BottlingProgress") or 0
			local carried = player:GetAttribute("Carried") or 0
			local backpack = player:GetAttribute("BackpackCapacity") or 0
			put(botSign.Title, "(Auto Deposit)", WHITE)
			put(botSign.Action, "DEPOSIT HONEY", GREEN)
			if owned and carried > 0 and carried >= backpack then
				put(botSign.Cost, "BACKPACK FULL", YELLOW)
			else
				put(botSign.Cost, ("%s CARRIED"):format(fmt(carried)), YELLOW)
			end
			if owned and queue > 0 then
				setBar(botSign, progress, ("BOTTLING %s HONEY"):format(fmt(queue)))
				setFloor(botSign, ("DEPOSIT HONEY\nBOTTLING %s\n%d JARS ON BELT"):format(fmt(queue), jars))
			elseif owned and jars > 0 then
				setBar(botSign, 0, ("%d JARS ON BELT"):format(jars))
				setFloor(botSign, ("DEPOSIT HONEY\n%d JARS ON BELT"):format(jars))
			else
				setBar(botSign, 0, if owned then "MACHINE IDLE" else "OWNER ONLY")
				setFloor(botSign, "STEP\nDEPOSIT HONEY")
			end
		end
	end

	local plotKeys = { "OwnerUserId", "HiveStored", "HiveCapacity", "BottlingQueue", "BottlingProgress", "Unclaimed", "ProductionRate", "JarsOnBelt", "Upgrades" }
	for _, key in plotKeys do
		plot:GetAttributeChangedSignal(key):Connect(refresh)
	end
	local playerKeys = { "Carried", "BackpackCapacity" }
	for _, key in playerKeys do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

for _, plot in plots:GetChildren() do
	watch(plot)
end
plots.ChildAdded:Connect(watch)
