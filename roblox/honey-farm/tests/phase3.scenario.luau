-- Phase 3 scenario: Bee Shop + merging, through the REAL server scripts.
-- Globals from run_sim.py: M, game, workspace, boot(), check(), tick(seconds), req()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Config = req(ReplicatedStorage.HoneyFarm.Config)
local BeeAppearance = req(ReplicatedStorage.HoneyFarm.BeeAppearance)
local FarmService = req(game:GetService("ServerScriptService").HoneyFarm.FarmService)

------------------------------------------------------------------------------
-- A stand-in for BeeTemplate.rbxm with the real part colours/sizes/layout,
-- so role classification and accessory placement run exactly as in Studio.
------------------------------------------------------------------------------
local function makeTemplate()
	local m = M.Instance.new("Model")
	m.Name = "BeeTemplate"
	local function part(parent, color, size, pos)
		local p = M.Instance.new("Part")
		p.Color = M.Color3.fromRGB(color[1], color[2], color[3])
		p.Size = M.Vector3.new(size[1], size[2], size[3])
		p.CFrame = M.CFrame.new(pos[1], pos[2], pos[3])
		p.Parent = parent
		return p
	end
	local Y, D, W, E = { 255, 255, 0 }, { 27, 42, 53 }, { 159, 243, 233 }, { 17, 17, 17 }
	part(m, Y, { 7.77, 5.44, 3.89 }, { 0, 0, 0 }) -- head
	part(m, D, { 7.77, 5.44, 1.55 }, { 0, 0, -2.7 })
	part(m, Y, { 7.77, 5.44, 1.55 }, { 0, 0, -4.3 })
	part(m, D, { 7.77, 5.44, 1.55 }, { 0, 0, -5.8 })
	part(m, Y, { 7.77, 5.44, 1.55 }, { 0, 0, -7.4 })
	part(m, W, { 3.89, 0.78, 5.44 }, { -2, 3.1, -3 })
	part(m, W, { 3.89, 0.78, 5.44 }, { 2, 3.1, -3 })
	part(m, E, { 1.55, 3.11, 0.78 }, { -2.3, 0, 2.3 })
	part(m, E, { 1.55, 3.11, 0.78 }, { 2.3, 0, 2.3 })
	for _, x in { -1.5, 1.5 } do
		local a = M.Instance.new("Model")
		a.Parent = m
		part(a, D, { 0.78, 2.33, 0.78 }, { x, 3.9, 0 })
		part(a, D, { 1.55, 0.78, 1.55 }, { x, 5.4, 0 })
	end
	local cam = M.Instance.new("Camera")
	cam.Name = "ThumbnailCamera"
	cam.Parent = m
	return m
end
local assets = M.Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ReplicatedStorage
makeTemplate().Parent = assets

boot()
local plots = workspace.HoneyFarmMap.Plots

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
local function has(s, needle)
	return string.find(s, needle, 1, true) ~= nil
end
local function countFired(remote, pred)
	local n = 0
	for _, f in remote.fired do
		if pred == nil or pred(f) then
			n += 1
		end
	end
	return n
end
local function atShop(player, plot)
	local counter = plot.Stations.BeeShop.Counter
	player.Character:PivotTo(counter.CFrame + M.Vector3.new(0, 3, -4))
end
local function shop(player, ...)
	Remotes.ShopAction.OnServerEvent:Fire(player, ...)
end
local function beeIds(plot)
	local ids = {}
	for id, tier in string.gmatch(plot:GetAttribute("Bees") or "", "(%d+):(%a+)") do
		table.insert(ids, { Id = tonumber(id), Tier = tier })
	end
	return ids
end
local function modelsIn(plot)
	local n = 0
	for _, m in plot.Temp:GetChildren() do
		if m:GetAttribute("Bee") then
			n += 1
		end
	end
	return n
end

------------------------------------------------------------------------------
-- All ten tiers build from the template
------------------------------------------------------------------------------
local template = assets.BeeTemplate
local seen = {}
for i, tier in Config.BeeOrder do
	local ok, model = pcall(BeeAppearance.Build, template, tier)
	check(ok, "builds " .. tier .. (ok and "" or (": " .. tostring(model))))
	if ok then
		check(model:GetAttribute("Tier") == tier and model.Name == Config.Bees[tier].Name, tier .. " model is tagged and named")
		local accessory = model:FindFirstChild("Accessory")
		local extra = accessory and #accessory:GetChildren() or 0
		if i == 1 then
			check(extra == 0, "Starter has no accessory (it's the original bee)")
		else
			check(extra >= 2, tier .. " has a recognisable accessory (" .. extra .. " parts)")
		end
		check(model:FindFirstChildOfClass("Camera") == nil, tier .. " has no thumbnail camera")
		local heads = 0
		for _, d in model:GetDescendants() do
			if d:GetAttribute("BeeRole") == "Head" then
				heads += 1
			end
		end
		check(heads == 1, tier .. " has exactly one head")
		check(math.abs(model:GetScale() - Config.Bees[tier].Scale) < 1e-6, tier .. " is scaled to its tier size")
		-- every tier looks different from every other one
		local key = Config.Bees[tier].Look.Body .. "/" .. Config.Bees[tier].Look.Stripe .. "/" .. tostring(Config.Bees[tier].Look.Accessory)
		check(not seen[key], tier .. " look is unique")
		seen[key] = true
	end
end
check(template:GetAttribute("BeePrepared") == true, "template roles were classified once")
check(template:FindFirstChild("Head1") ~= nil and template:FindFirstChild("Wing2") ~= nil and template:FindFirstChild("Eye2") ~= nil, "template parts were named by role")
for i = 2, #Config.BeeOrder do
	local a, b = Config.Bees[Config.BeeOrder[i - 1]], Config.Bees[Config.BeeOrder[i]]
	check(math.abs(b.HoneyPerSecond / a.HoneyPerSecond - 2.5) < 1e-9, Config.BeeOrder[i] .. " makes 2.5x " .. Config.BeeOrder[i - 1])
end

------------------------------------------------------------------------------
-- Shop
------------------------------------------------------------------------------
local alice = M.newPlayer(game, 1001, "Alice")
alice.spawnCharacter()
local plot1 = plots.Plot1
local s = FarmService.GetState(alice)
check(plot1:GetAttribute("BeePrice") == 25 and plot1:GetAttribute("BeeSlots") == 8 and plot1:GetAttribute("BeeCount") == 1, "shop shows price 25, 1/8 slots")
check(plot1:GetAttribute("Bees") == "1:Starter", "bee list is replicated as id:tier")
check(plot1:GetAttribute("Discovered") == "Starter", "Starter is discovered from the start")
check(modelsIn(plot1) == 1 and plot1.Temp.Bee1:GetAttribute("Tier") == "Starter", "one dressed bee model on the farm")

-- opening the shop from the prompt
local shopPrompt = plot1.Stations.BeeShop:FindFirstChild("StationPrompt", true)
atShop(alice, plot1)
shopPrompt.Triggered:Fire(alice)
check(countFired(Remotes.OpenShop, function(f)
	return f[1] == alice
end) == 1, "pressing E at the Bee Shop opens the shop UI")

-- buy with exactly 25 cash
shop(alice, "Buy")
check(alice:GetAttribute("Cash") == 0 and plot1:GetAttribute("BeeCount") == 2, "bought a bee for $25")
check(plot1:GetAttribute("BeePrice") == 31, "price went up to $31")
check(plot1:GetAttribute("Bees") == "1:Starter,2:Starter" and modelsIn(plot1) == 2, "second bee replicated and spawned")
check(plot1.Temp.Bee2:GetAttribute("PopIn") == true, "new bee pops in")

-- insufficient funds
shop(alice, "Buy")
check(alice:GetAttribute("Cash") == 0 and plot1:GetAttribute("BeeCount") == 2, "can't buy with $0")
check(has(lastNote(alice), "need $31"), "told the price and current cash")

-- must be at the shop
s.Cash = 1000
alice.Character:PivotTo(M.CFrame.new(0, 3, 0))
shop(alice, "Buy")
check(plot1:GetAttribute("BeeCount") == 2, "shop action from the village is refused")
check(has(lastNote(alice), "Walk up"), "told to walk to the shop")

-- rapid presses: each is checked on its own, so 6 presses buy 6 bees and then stop at 8 slots
atShop(alice, plot1)
for _ = 1, 10 do
	shop(alice, "Buy")
end
check(plot1:GetAttribute("BeeCount") == 8 and modelsIn(plot1) == 8, "slots cap at 8 bees")
check(has(lastNote(alice), "slots are full"), "full-slots message")
local spent = 31 + 39 + 49 + 61 + 76 + 95
check(s.Cash == 1000 - spent, "charged exactly the rising prices (" .. spent .. ")")
check(math.abs(plot1:GetAttribute("ProductionRate") - 1.6) < 1e-9, "8 Starter Bees make 1.6 honey/s")

------------------------------------------------------------------------------
-- Merging
------------------------------------------------------------------------------
local ids = beeIds(plot1)
shop(alice, "Merge", ids[1].Id, ids[2].Id)
local after = beeIds(plot1)
check(#after == 7 and plot1:GetAttribute("BeeCount") == 7, "two bees became one")
check(after[7].Tier == "Clover" and after[7].Id == 9, "the new bee is a Clover with a fresh id")
check(plot1.Temp:FindFirstChild("Bee1") == nil and plot1.Temp:FindFirstChild("Bee2") == nil and plot1.Temp:FindFirstChild("Bee9") ~= nil, "parent models removed, Clover model spawned")
check(plot1.Temp.Bee9:GetAttribute("Tier") == "Clover" and plot1.Temp.Bee9.Accessory ~= nil, "Clover model has its clover")
check(math.abs(plot1:GetAttribute("ProductionRate") - (6 * 0.2 + 0.5)) < 1e-9, "production: 6 starters + 1 clover (2.5x)")
check(has(plot1:GetAttribute("Discovered"), "Starter") and has(plot1:GetAttribute("Discovered"), "Clover"), "Clover added to discoveries")
local mergeEvt = Remotes.BeeMerged.fired[#Remotes.BeeMerged.fired]
check(mergeEvt and mergeEvt[2] == 1 and mergeEvt[6] == "Clover" and mergeEvt[7] == true, "clients told to play the merge effect + discovery")
check(has(lastNote(alice), "New bee discovered: Clover Bee"), "discovery notification")

-- bad merges change nothing
local cloverId = after[7].Id
local starterId = after[1].Id
shop(alice, "Merge", cloverId, starterId)
check(plot1:GetAttribute("BeeCount") == 7 and has(lastNote(alice), "same tier"), "different tiers can't merge")
shop(alice, "Merge", starterId, starterId)
check(plot1:GetAttribute("BeeCount") == 7 and has(lastNote(alice), "two different"), "a bee can't merge with itself")
shop(alice, "Merge", 1, 2)
check(plot1:GetAttribute("BeeCount") == 7 and has(lastNote(alice), "any more"), "merging bees that no longer exist is refused")
shop(alice, "Merge", "x", {})
check(plot1:GetAttribute("BeeCount") == 7, "garbage arguments are ignored")

-- second Clover is not a discovery
local b = beeIds(plot1)
shop(alice, "Merge", b[1].Id, b[2].Id)
check(plot1:GetAttribute("BeeCount") == 6 and has(lastNote(alice), "Merged into a Clover"), "second Clover: merged, not discovered")

-- climb to the top and try to merge two Royals
s.Bees = {}
s:AddBee("Royal")
s:AddBee("Royal")
FarmService.Tick(0.01) -- replicates
local royals = beeIds(plot1)
check(#royals == 2 and royals[1].Tier == "Royal", "two Royal Bees on the farm")
shop(alice, "Merge", royals[1].Id, royals[2].Id)
check(plot1:GetAttribute("BeeCount") == 2 and has(lastNote(alice), "top tier"), "the highest tier cannot be merged")

-- another player can't touch Alice's shop
local bob = M.newPlayer(game, 2002, "Bob")
bob.spawnCharacter()
atShop(bob, plot1)
shop(bob, "Buy")
check(plots.Plot2:GetAttribute("BeeCount") == 1 and plot1:GetAttribute("BeeCount") == 2, "Bob's buy only ever applies to Bob's own farm (refused: he's not at his shop)")
check(bob:GetAttribute("Cash") == 25, "Bob wasn't charged")

-- leaving clears everything
M.removePlayer(game, alice)
check(plot1:GetAttribute("Bees") == nil and plot1:GetAttribute("BeePrice") == nil, "shop attributes cleared on leave")
check(#plot1.Temp:GetChildren() == 0, "bee models removed on leave")
