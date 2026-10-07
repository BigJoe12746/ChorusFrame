-- Pulses the hive pressure plate when your hive has honey you can collect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local C = Config.Colors

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local plate: BasePart? = nil
local pulseConn: RBXScriptConnection? = nil
local baseColor = C.Honey
local brightColor = Color3.fromRGB(255, 248, 160)

local function pressurePlate(plot: Instance): BasePart?
	local stations = plot:FindFirstChild("Stations")
	local hive = stations and stations:FindFirstChild("Hive")
	return hive and hive:FindFirstChild("HivePressurePlate", true) :: BasePart?
end

local function canCollectHoney(plot: Instance): boolean
	if (plot:GetAttribute("OwnerUserId") or 0) ~= player.UserId then
		return false
	end
	local stored = plot:GetAttribute("HiveStored")
	if type(stored) ~= "number" or stored <= 0 then
		return false
	end
	local carried = player:GetAttribute("Carried")
	local capacity = player:GetAttribute("BackpackCapacity")
	if type(carried) ~= "number" or type(capacity) ~= "number" then
		return stored > 0
	end
	return carried < capacity
end

local function setPulsing(active: boolean)
	if active then
		if pulseConn or not plate then
			return
		end
		pulseConn = RunService.Heartbeat:Connect(function()
			if not plate or not plate.Parent then
				return
			end
			local wave = (math.sin(os.clock() * 5) + 1) * 0.5
			plate.Color = baseColor:Lerp(brightColor, wave)
			plate.Transparency = wave * 0.12
		end)
	elseif pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
		if plate then
			plate.Color = baseColor
			plate.Transparency = 0
		end
	end
end

local myPlot: Instance? = nil

local function refresh()
	local shouldPulse = myPlot ~= nil and plate ~= nil and plate.Parent ~= nil and canCollectHoney(myPlot)
	setPulsing(shouldPulse)
end

local conns: { RBXScriptConnection } = {}

local function clearConns()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
end

local function watchPlot(plot: Instance?)
	clearConns()
	setPulsing(false)
	myPlot = plot
	plate = if plot then pressurePlate(plot) else nil
	if not plot or not plate then
		return
	end
	local function hook(attr: string, inst: Instance)
		table.insert(conns, inst:GetAttributeChangedSignal(attr):Connect(refresh))
	end
	hook("HiveStored", plot)
	hook("OwnerUserId", plot)
	hook("Carried", player)
	hook("BackpackCapacity", player)
	refresh()
end

local function onPlotId()
	local id = player:GetAttribute("PlotId")
	watchPlot(if type(id) == "number" then plots:FindFirstChild("Plot" .. id) else nil)
end

player:GetAttributeChangedSignal("PlotId"):Connect(onPlotId)
onPlotId()
