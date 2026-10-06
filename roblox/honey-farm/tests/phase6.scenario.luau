-- Phase 6 scenario: the introduction's server side and the feedback events, through the REAL
-- server scripts. Globals: M, game, workspace, boot(), check(), tick(), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local FarmService = req(game:GetService("ServerScriptService").HoneyFarm.FarmService)

boot()
local plots = workspace.HoneyFarmMap.Plots

local function lastNote(p)
	local last = ""
	for _, f in Remotes.Notify.fired do
		if f[1] == p then
			last = f[2]
		end
	end
	return last
end
local function has(s, needle)
	return string.find(s, needle, 1, true) ~= nil
end
local function feedback(p)
	local out = {}
	for _, f in Remotes.Feedback.fired do
		if f[1] == p then
			table.insert(out, { Kind = f[2], Amount = f[3], Station = f[4] })
		end
	end
	return out
end
local function use(player, plot, station)
	local prompt = plot.Stations[station]:FindFirstChild("StationPrompt", true)
	player.Character:PivotTo(prompt.Parent.CFrame + M.Vector3.new(0, 3, -4))
	prompt.Triggered:Fire(player)
end
local function shop(player, plot, ...)
	player.Character:PivotTo(plot.Stations.BeeShop.Counter.CFrame + M.Vector3.new(0, 3, -4))
	Remotes.ShopAction.OnServerEvent:Fire(player, ...)
end

-- config sanity
check(#Config.Tutorial.Steps == 5, "five introduction steps")
for i, step in Config.Tutorial.Steps do
	check(Config.Stations[step.Station] ~= nil and #step.Title > 0 and #step.Body > 0, ("step %d points at a real station and has text"):format(i))
end
for _, name in { "Collect", "Deposit", "Cash", "Merge", "Click" } do
	check(string.sub(Config.Sounds[name], 1, 18) == "rbxasset://sounds/", name .. " sound ships with the Roblox client (rbxasset://sounds/)")
end

local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local plot1 = plots.Plot1
local s = FarmService.GetState(alice)
check(alice:GetAttribute("TutorialStep") == 1, "new player starts at step 1 (collect honey)")

-- doing later steps early doesn't skip ahead (and does nothing anyway)
use(alice, plot1, "SellStand")
use(alice, plot1, "Bottling")
check(alice:GetAttribute("TutorialStep") == 1, "pressing other stations with nothing to do keeps step 1")
check(#feedback(alice) == 0, "no feedback for actions that did nothing")

-- step 1: collect
use(alice, plot1, "Hive") -- empty hive
check(alice:GetAttribute("TutorialStep") == 1, "an empty hive doesn't count as collecting")
tick(5.1)
use(alice, plot1, "Hive")
check(alice:GetAttribute("TutorialStep") == 2, "collecting honey completes step 1")
local fb = feedback(alice)
check(#fb == 1 and fb[1].Kind == "Honey" and fb[1].Amount == 1 and fb[1].Station == "Hive", "honey feedback with the amount and station")

-- step 2: deposit
use(alice, plot1, "Bottling")
check(alice:GetAttribute("TutorialStep") == 3, "depositing completes step 2")
check(feedback(alice)[2].Kind == "Deposit", "deposit feedback")

-- step 3: collect cash (after the jar arrives)
use(alice, plot1, "SellStand")
check(alice:GetAttribute("TutorialStep") == 3, "no cash yet: step 3 stays")
tick(5)
use(alice, plot1, "SellStand")
check(alice:GetAttribute("TutorialStep") == 4 and alice:GetAttribute("Cash") == 30, "collecting $5 completes step 3")
local cashFb = feedback(alice)[3]
check(cashFb.Kind == "Cash" and cashFb.Amount == 5 and cashFb.Station == "SellStand", "cash feedback")

-- step 4: buy a bee ($25 of the $30)
shop(alice, plot1, "Buy")
check(alice:GetAttribute("TutorialStep") == 5 and plot1:GetAttribute("BeeCount") == 2, "buying a bee completes step 4")
check(feedback(alice)[4].Kind == "Buy" and feedback(alice)[4].Amount == 25, "buy feedback carries the price")

-- step 5: merge -> finished + reward
local ids = {}
for id in string.gmatch(plot1:GetAttribute("Bees"), "(%d+):") do
	table.insert(ids, tonumber(id))
end
local cashBefore = alice:GetAttribute("Cash")
shop(alice, plot1, "Merge", ids[1], ids[2])
check(alice:GetAttribute("TutorialStep") == 6, "the first merge finishes the introduction")
check(alice:GetAttribute("Cash") == cashBefore + Config.Tutorial.Reward, "finishing pays the $" .. Config.Tutorial.Reward .. " bonus")
local sawComplete = false
for _, f in Remotes.Notify.fired do
	if f[1] == alice and has(f[2], "Introduction complete") then
		sawComplete = true
	end
end
check(sawComplete, "completion message")

-- finished stays finished
tick(5.1)
use(alice, plot1, "Hive")
check(alice:GetAttribute("TutorialStep") == 6, "later actions don't change a finished introduction")

-- it is saved and restored
M.removePlayer(game, alice)
check(M.datastore.data["player_1001"].TutorialStep == 6, "tutorial progress is saved")
local alice2 = M.newPlayer(game, 1001, "Alice")
alice2.spawnCharacter()
check(alice2:GetAttribute("TutorialStep") == 6, "tutorial progress is restored on rejoin")
check(plot1:GetAttribute("Discovered") == "Starter,Clover", "collection book data: Starter and Clover discovered")
M.removePlayer(game, alice2)

-- a second player has their own independent introduction
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
check(bob:GetAttribute("TutorialStep") == 1, "Bob starts his own introduction at step 1")
