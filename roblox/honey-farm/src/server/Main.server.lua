-- HONEY FARM server entry point.
local RunService = game:GetService("RunService")

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local FarmService = require(script.Parent:WaitForChild("FarmService"))

local map = MapBuilder.Build()
FarmService.Start() -- listen for plots before players are assigned
PlotService.Start(map)

RunService.Heartbeat:Connect(function(dt)
	FarmService.Tick(dt)
end)

print("[HoneyFarm] Phase 4 ready: map, honey loop, bee shop + merging, upgrades")
