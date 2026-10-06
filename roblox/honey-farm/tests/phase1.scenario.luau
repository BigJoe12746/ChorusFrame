-- Phase 1 scenario, run by tests/run_sim.py against the mock engine.
-- Uses the REAL Main/MapBuilder/PlotService/Config/PlotAllocator sources.
-- Globals provided by the runner: M (mock), game, workspace, boot(), check(), dumpParts()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes

boot() -- runs ServerScriptService.HoneyFarm.Main

local map = workspace:FindFirstChild("HoneyFarmMap")
check(map ~= nil, "map is built into workspace")
local plots = map.Plots
check(#plots:GetChildren() == 6, "six plots exist")

for id = 1, 6 do
	local plot = plots:FindFirstChild("Plot" .. id)
	check(plot ~= nil, "Plot" .. id .. " exists")
	check(plot:FindFirstChild("SpawnPoint") ~= nil, "Plot" .. id .. " has a spawn point")
	check(plot:FindFirstChild("OwnerSign", true) ~= nil, "Plot" .. id .. " has an owner sign")
	check(plot:FindFirstChild("Temp") ~= nil, "Plot" .. id .. " has a Temp folder")
	check(#plot.Expansion:GetChildren() >= 2, "Plot" .. id .. " has reserved expansion space")
	for _, s in { "Hive", "FlowerPatch", "BeeShop", "Bottling", "SellStand" } do
		local st = plot.Stations:FindFirstChild(s)
		check(st ~= nil, ("Plot%d has %s"):format(id, s))
		local prompt = st:FindFirstChild("StationPrompt", true)
		check(prompt ~= nil and prompt:GetAttribute("OwnerOnly") == true, ("Plot%d %s has an owner-only prompt"):format(id, s))
	end
	check(plot:GetAttribute("OwnerUserId") == 0, "Plot" .. id .. " starts unowned")
end

local function dist(a, b)
	return (a - b).Magnitude
end
local function charPos(p)
	return p.Character.Pivot.Position
end
local function spawnPos(id)
	return plots["Plot" .. id].SpawnPoint.CFrame.Position
end
local function notes(p)
	local out = {}
	for _, f in Remotes.Notify.fired do
		if f[1] == p then
			table.insert(out, f[2])
		end
	end
	return out
end
local function lastNote(p)
	local n = notes(p)
	return n[#n] or ""
end

-- Two players join
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()

check(alice:GetAttribute("PlotId") == 1 and bob:GetAttribute("PlotId") == 2, "Alice gets plot 1, Bob gets plot 2")
check(plots.Plot1:GetAttribute("OwnerUserId") == 1001 and plots.Plot2:GetAttribute("OwnerUserId") == 2002, "plot owner attributes set")
local sign1 = plots.Plot1:FindFirstChild("OwnerSign", true)
check(sign1.FrontGui.OwnerName.Text == "Alice's Farm", "Plot1 sign shows Alice's name")
check(sign1.BackGui.OwnerName.Text == "Alice's Farm", "Plot1 sign readable from inside too")
check(string.find(sign1.FrontGui.Avatar.Image, "1001") ~= nil, "Plot1 sign shows Alice's avatar")
check(plots.Plot2:FindFirstChild("OwnerSign", true).FrontGui.OwnerName.Text == "Bob's Farm", "Plot2 sign shows Bob")
check(dist(charPos(alice), spawnPos(1)) < 3, "Alice spawned at her farm")
check(dist(charPos(bob), spawnPos(2)) < 3, "Bob spawned at his farm")
check(dist(charPos(alice), charPos(bob)) > 100, "their farms are far apart")
check(string.find(lastNote(alice), "Plot 1") ~= nil, "Alice told which plot is hers")

-- My Farm button
alice.Character:PivotTo(M.CFrame.new(0, 3, 0)) -- walk to the village
Remotes.ReturnToFarm.OnServerEvent:Fire(alice)
check(dist(charPos(alice), spawnPos(1)) < 3, "My Farm returns Alice to plot 1")
alice.Character:PivotTo(M.CFrame.new(0, 3, 0))
Remotes.ReturnToFarm.OnServerEvent:Fire(alice) -- spam
check(dist(charPos(alice), spawnPos(1)) > 50, "My Farm spam is rate-limited")
bob.Character:PivotTo(plots.Plot1.SpawnPoint.CFrame) -- Bob visits Alice
Remotes.ReturnToFarm.OnServerEvent:Fire(bob)
check(dist(charPos(bob), spawnPos(2)) < 3, "My Farm returns Bob to plot 2, not Alice's")

-- Respawn sends you home
alice.spawnCharacter()
check(dist(charPos(alice), spawnPos(1)) < 3, "respawning puts Alice back on her farm")

-- Ownership of stations
local aliceHivePrompt = plots.Plot1.Stations.Hive:FindFirstChild("StationPrompt", true)
aliceHivePrompt.Triggered:Fire(bob)
check(string.find(lastNote(bob), "Alice's farm") ~= nil, "Bob can't use Alice's hive")
alice.Character:PivotTo(aliceHivePrompt.Parent.CFrame + M.Vector3.new(0, 3, -4))
aliceHivePrompt.Triggered:Fire(alice)
check(string.find(lastNote(alice), "Alice's farm") == nil, "Alice can use her own hive")

-- Leaving frees the plot and clears temporary objects
local junk = M.Instance.new("Part")
junk.Parent = plots.Plot1.Temp
M.removePlayer(game, alice)
check(plots.Plot1:GetAttribute("OwnerUserId") == 0, "Alice's plot is released")
check(#plots.Plot1.Temp:GetChildren() == 0, "Alice's temporary objects are removed")
check(sign1.FrontGui.OwnerName.Text == "Free Farm" and sign1.FrontGui.Avatar.Image == "", "Plot1 sign reset")

-- Rejoin + full server
local alice2 = M.newPlayer(game, 1001, "Alice")
alice2.spawnCharacter()
check(alice2:GetAttribute("PlotId") == 1, "Alice rejoins and gets a plot again")
local extra = {}
for i = 1, 4 do
	local p = M.newPlayer(game, 3000 + i, "P" .. i)
	p.spawnCharacter()
	table.insert(extra, p)
end
local late = M.newPlayer(game, 4000, "Late")
late.spawnCharacter()
check(late:GetAttribute("PlotId") == nil, "7th player waits when all 6 plots are taken")
check(string.find(lastNote(late), "All farms are taken") ~= nil, "7th player is told they're queued")
Remotes.ReturnToFarm.OnServerEvent:Fire(late)
check(string.find(lastNote(late), "don't have a farm") ~= nil, "My Farm without a plot gives a clear message")
M.removePlayer(game, bob)
check(late:GetAttribute("PlotId") == 2, "queued player gets Bob's freed plot")
check(dist(charPos(late), spawnPos(2)) < 3, "queued player is moved onto the new farm")

print(("PARTS %d instances created"):format(M.created))
dumpParts(map)
