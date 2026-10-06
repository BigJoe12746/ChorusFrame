-- HONEY FARM server entry point.
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local map = MapBuilder.Build()
PlotService.Start(map)

print("[HoneyFarm] Phase 1 ready: map built, plots waiting for players")
