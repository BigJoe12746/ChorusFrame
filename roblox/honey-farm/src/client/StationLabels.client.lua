-- Updates the floating labels over each plot's hive, bottling machine and honey stand
-- from the plot attributes, so visitors see the same numbers as the owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local function label(plot: Instance, station: string): TextLabel?
	local s = plot:FindFirstChild("Stations")
	local m = s and s:FindFirstChild(station)
	local gui = m and m:FindFirstChild("Label", true)
	return gui and gui:FindFirstChildOfClass("TextLabel")
end

local function watch(plot: Instance)
	local hive = label(plot, "Hive")
	local bottling = label(plot, "Bottling")
	local stand = label(plot, "SellStand")

	local function refresh()
		local owned = (plot:GetAttribute("OwnerUserId") or 0) ~= 0
		if hive then
			local stored = plot:GetAttribute("HiveStored")
			hive.Text = if owned and stored then ("%s\n%d / %d 🍯"):format(Config.Stations.Hive.Label, stored, (plot:GetAttribute("HiveCapacity") or 0) :: number) else Config.Stations.Hive.Label
		end
		if bottling then
			local queue = plot:GetAttribute("BottlingQueue")
			bottling.Text = if owned and queue and queue > 0 then ("%s\nbottling %d..."):format(Config.Stations.Bottling.Label, queue) else Config.Stations.Bottling.Label
		end
		if stand then
			local cash = plot:GetAttribute("Unclaimed")
			stand.Text = if owned and cash and cash > 0 then ("%s\n$%d ready!"):format(Config.Stations.SellStand.Label, cash) else Config.Stations.SellStand.Label
		end
	end

	for _, key in { "OwnerUserId", "HiveStored", "HiveCapacity", "BottlingQueue", "Unclaimed" } do
		plot:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

for _, plot in plots:GetChildren() do
	watch(plot)
end
plots.ChildAdded:Connect(watch)
