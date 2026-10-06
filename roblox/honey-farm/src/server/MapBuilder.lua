-- MapBuilder (ModuleScript)
-- Builds the whole HONEY FARM map out of parts: grass, central village square,
-- six fenced farm plots with stations, paths, giant flowers and trees.
--
-- If workspace already contains "HoneyFarmMap" (e.g. you baked it in Studio and edited it),
-- that map is kept and nothing is rebuilt. To bake it in Edit mode, run this in the command bar:
--   require(game.ServerScriptService.HoneyFarm.MapBuilder).Build()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local C = Config.Colors

local MapBuilder = {}

local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a Cylinder (X axis) upright
local SMOOTH = Enum.SurfaceType.Smooth

local rng = Random.new(20261006) -- fixed seed: same map every time

------------------------------------------------------------------------------
-- Primitive helpers
------------------------------------------------------------------------------

local function P(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Upright cylinder centred at cf.
local function cyl(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * UP,
		Color = color,
	}
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return P(parent, props)
end

local function ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cf,
		Color = color,
	}
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return P(parent, props)
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function billboard(adornee: BasePart, text: string, height: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance or 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = C.Text
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

-- Front-facing sign board with big text. Board faces cf.LookVector.
local function signBoard(parent: Instance, name: string, size: Vector3, cf: CFrame, text: string, bg: Color3)
	local board = P(parent, { Name = name, Size = size, CFrame = cf, Color = bg })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence = 0.2
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = C.Text
		label.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.05, 0)
		pad.PaddingRight = UDim.new(0.05, 0)
		pad.PaddingTop = UDim.new(0.1, 0)
		pad.PaddingBottom = UDim.new(0.1, 0)
		pad.Parent = label
		label.Parent = gui
		gui.Parent = board
	end
	return board
end

------------------------------------------------------------------------------
-- Decorations
------------------------------------------------------------------------------

-- Oversized cartoon flower standing at ground position `pos`.
local function flower(parent: Instance, pos: Vector3, height: number, petal: Color3, collide: boolean?)
	local m = model(parent, "Flower")
	local s = height / 8
	cyl(m, "Stem", height, 0.8 * s, CFrame.new(pos + Vector3.new(0, height / 2, 0)), C.Stem, { CanCollide = collide == true })
	local top = pos + Vector3.new(0, height, 0)
	local tilt = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, math.pi * 2), 0)
	local head = CFrame.new(top) * tilt
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		cyl(m, "Petal", 0.5 * s, 3 * s, head * CFrame.new(math.cos(a) * 1.8 * s, 0, math.sin(a) * 1.8 * s), petal, { CanCollide = false })
	end
	ball(m, "Center", 2.4 * s, head * CFrame.new(0, 0.3 * s, 0), C.Honey, { CanCollide = false })
	for _, side in { -1, 1 } do
		P(m, {
			Name = "Leaf",
			Size = Vector3.new(2.6 * s, 0.3 * s, 1.2 * s),
			CFrame = CFrame.new(pos + Vector3.new(side * 1.3 * s, height * 0.35, 0)) * CFrame.Angles(0, 0, side * math.rad(25)),
			Color = C.Leaf,
			CanCollide = false,
		})
	end
	return m
end

local function tree(parent: Instance, pos: Vector3, scale: number)
	local m = model(parent, "Tree")
	cyl(m, "Trunk", 10 * scale, 3 * scale, CFrame.new(pos + Vector3.new(0, 5 * scale, 0)), C.DarkWood)
	local greens = { Color3.fromRGB(80, 170, 70), Color3.fromRGB(100, 190, 80), Color3.fromRGB(70, 150, 60) }
	ball(m, "Crown", 12 * scale, CFrame.new(pos + Vector3.new(0, 13 * scale, 0)), greens[1])
	ball(m, "Crown", 8 * scale, CFrame.new(pos + Vector3.new(3.5 * scale, 11 * scale, 2 * scale)), greens[2])
	ball(m, "Crown", 8 * scale, CFrame.new(pos + Vector3.new(-3 * scale, 12 * scale, -2.5 * scale)), greens[3])
	return m
end

-- Fence between two ground points (Y = 0).
local function fence(parent: Instance, a: Vector3, b: Vector3, color: Color3)
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	local mid = a:Lerp(b, 0.5)
	local dir = CFrame.lookAt(mid, b)
	for _, y in { 1.6, 3.2 } do
		P(parent, { Name = "Rail", Size = Vector3.new(0.4, 0.6, len), CFrame = dir + Vector3.new(0, y, 0), Color = color, Material = Enum.Material.Wood })
	end
	local n = math.max(1, math.floor(len / 8))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		P(parent, { Name = "Post", Size = Vector3.new(1, 4.4, 1), CFrame = (dir - dir.Position) + p + Vector3.new(0, 2.2, 0), Color = color, Material = Enum.Material.Wood })
		ball(parent, "PostCap", 1.3, CFrame.new(p + Vector3.new(0, 4.6, 0)), color, { CanCollide = false })
	end
end

-- Round cartoon cottage at ground cf (front door faces cf.LookVector).
local function cottage(parent: Instance, cf: CFrame, roof: Color3, title: string)
	local m = model(parent, title)
	local body = cyl(m, "Body", 11, 16, cf * CFrame.new(0, 5.5, 0), C.Cream)
	cyl(m, "RoofRim", 1.2, 19, cf * CFrame.new(0, 11.4, 0), roof)
	for i = 0, 3 do
		cyl(m, "Roof", 2.2, 17 - i * 4, cf * CFrame.new(0, 12.9 + i * 2, 0), roof)
	end
	ball(m, "RoofTop", 3, cf * CFrame.new(0, 20.5, 0), C.Honey)
	-- door + windows on the front
	P(m, { Name = "Door", Size = Vector3.new(4, 6, 0.6), CFrame = cf * CFrame.new(0, 3, -7.9), Color = C.DarkWood, CanCollide = false })
	P(m, { Name = "DoorTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4, 4), CFrame = cf * CFrame.new(0, 6, -7.9) * CFrame.Angles(0, math.pi / 2, 0), Color = C.DarkWood, CanCollide = false })
	for _, x in { -5, 5 } do
		local w = cf * CFrame.new(x, 6.5, -6.2) * CFrame.Angles(0, math.rad(x > 0 and -38 or 38), 0)
		P(m, { Name = "Window", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3, 3), CFrame = w * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(150, 215, 255), Material = Enum.Material.Glass, CanCollide = false })
	end
	billboard(body, title, 14, 90)
	return m
end

------------------------------------------------------------------------------
-- Village square
------------------------------------------------------------------------------

local function buildVillage(map: Instance)
	local v = model(map, "Village")
	cyl(v, "Plaza", 1, Config.SquareRadius * 2, CFrame.new(0, -0.2, 0), C.Plaza, { Material = Enum.Material.Pebble })
	cyl(v, "PlazaRing", 0.9, Config.SquareRadius * 2 + 4, CFrame.new(0, -0.3, 0), C.Wood, { Material = Enum.Material.Wood })

	-- Honey fountain
	local f = model(v, "HoneyFountain")
	cyl(f, "Base", 2.4, 22, CFrame.new(0, 1.2, 0), C.Stone, { Material = Enum.Material.Cobblestone })
	cyl(f, "Pool", 0.4, 19, CFrame.new(0, 2.3, 0), C.Honey, { Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	cyl(f, "Pillar", 7, 3, CFrame.new(0, 5, 0), C.Stone)
	cyl(f, "Bowl", 1.2, 10, CFrame.new(0, 8.6, 0), C.Stone)
	ball(f, "HoneyPot", 6, CFrame.new(0, 11.5, 0), C.DeepHoney)
	cyl(f, "PotLid", 1, 4, CFrame.new(0, 14.6, 0), C.Wood)
	local drip = cyl(f, "Drip", 0.6, 9.4, CFrame.new(0, 9.3, 0), C.Honey, { Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false })
	billboard(drip, "🍯 " .. Config.GameName, 9, 140)

	-- Neutral spawn (players are sent to their own farm right after spawning)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "VillageSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.3, 24)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.TopSurface = SMOOTH
	spawn.Parent = v
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	-- Welcome sign facing the spawn
	-- (placed between two plot paths so it never blocks a walkway)
	local s = model(v, "WelcomeSign")
	local signAngle = math.rad(210)
	local signPos = Vector3.new(math.sin(signAngle) * 24, 0, math.cos(signAngle) * 24)
	local signCf = CFrame.lookAt(signPos, Vector3.new(0, 0, 24))
	for _, x in { -7, 7 } do
		cyl(s, "Post", 9, 1.2, signCf * CFrame.new(x, 4.5, 0), C.DarkWood)
	end
	signBoard(s, "Board", Vector3.new(16, 5, 0.8), signCf * CFrame.new(0, 8, 0), "Welcome to\n" .. Config.GameName, C.Honey)

	-- Cottages between the plot paths
	local titles = { "Village Hall", "Bakery", "Bee Museum", "Flower Shop", "Jam Cafe", "Post Office" }
	for i = 1, Config.PlotCount do
		local a = (i - 0.5) / Config.PlotCount * math.pi * 2
		local pos = Vector3.new(math.sin(a) * 82, 0, math.cos(a) * 82)
		cottage(v, CFrame.lookAt(pos, Vector3.zero), C.RoofColors[(i - 1) % #C.RoofColors + 1], titles[i] or "Cottage")
		-- flower ring near each cottage
		for k = -1, 1 do
			local fa = a + k * 0.12
			flower(v, Vector3.new(math.sin(fa) * 62, 0, math.cos(fa) * 62), rng:NextNumber(6, 9), C.PetalColors[rng:NextInteger(1, #C.PetalColors)])
		end
	end

	-- Benches around the plaza
	for i = 1, Config.PlotCount do
		local a = (i - 0.5) / Config.PlotCount * math.pi * 2
		local pos = Vector3.new(math.sin(a) * 36, 0, math.cos(a) * 36)
		local cf = CFrame.lookAt(pos, Vector3.zero)
		local seat = Instance.new("Seat")
		seat.Name = "Bench"
		seat.Anchored = true
		seat.Size = Vector3.new(7, 1, 2.4)
		seat.CFrame = cf * CFrame.new(0, 1.8, 0)
		seat.Color = C.Wood
		seat.Material = Enum.Material.Wood
		seat.TopSurface = SMOOTH
		seat.Parent = v
		P(v, { Name = "BenchBack", Size = Vector3.new(7, 2.5, 0.6), CFrame = cf * CFrame.new(0, 3.2, 1.3), Color = C.Wood, Material = Enum.Material.Wood })
		for _, x in { -3, 3 } do
			P(v, { Name = "BenchLeg", Size = Vector3.new(0.6, 1.4, 2), CFrame = cf * CFrame.new(x, 0.7, 0), Color = C.DarkWood })
		end
	end
end

------------------------------------------------------------------------------
-- Plot stations (each faces its own -Z / LookVector)
------------------------------------------------------------------------------

local function addPrompt(target: BasePart, station: string)
	local info = Config.Stations[station]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ObjectText = info.Label
	prompt.ActionText = info.Action
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt:SetAttribute("Station", station)
	prompt.Parent = target
end

local function stationModel(parent: Instance, name: string): Model
	local m = model(parent, name)
	m:SetAttribute("Station", name)
	return m
end

local function buildHive(parent: Instance, cf: CFrame)
	local m = stationModel(parent, "Hive")
	local base = cyl(m, "Base", 1, 18, cf * CFrame.new(0, 0.5, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
	for i = 0, 4 do
		cyl(m, "Layer", 2.4, 14 - i * 2.2, cf * CFrame.new(0, 2.2 + i * 2.2, 0), i % 2 == 0 and C.Honey or C.DeepHoney)
	end
	ball(m, "Top", 4, cf * CFrame.new(0, 12.6, 0), C.DeepHoney)
	P(m, { Name = "Entrance", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.8, 2.8), CFrame = cf * CFrame.new(0, 3.4, -6.4) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(60, 35, 15), CanCollide = false })
	P(m, { Name = "LandingBoard", Size = Vector3.new(4, 0.4, 2), CFrame = cf * CFrame.new(0, 2, -7.4), Color = C.Wood })
	local anchor = P(m, { Name = "BeeExit", Size = Vector3.one, CFrame = cf * CFrame.new(0, 3.4, -8), Transparency = 1, CanCollide = false, CanQuery = false })
	anchor:SetAttribute("Purpose", "Where bees leave/enter the hive (Phase 2)")
	m.PrimaryPart = base
	billboard(base, Config.Stations.Hive.Label, 16)
	addPrompt(base, "Hive")
end

local function buildFlowerPatch(parent: Instance, cf: CFrame)
	local m = stationModel(parent, "FlowerPatch")
	local soil = P(m, { Name = "Soil", Size = Vector3.new(24, 1, 20), CFrame = cf * CFrame.new(0, 0.5, 0), Color = C.Soil, Material = Enum.Material.Ground })
	for _, e in { { 0, -10.5, 25, 1 }, { 0, 10.5, 25, 1 }, { -12.5, 0, 1, 20 }, { 12.5, 0, 1, 20 } } do
		P(m, { Name = "Border", Size = Vector3.new(e[3], 1.4, e[4]), CFrame = cf * CFrame.new(e[1], 0.7, e[2]), Color = C.Wood, Material = Enum.Material.Wood })
	end
	local spots = Instance.new("Folder")
	spots.Name = "FlowerSpots" -- bees fly to these in Phase 2
	spots.Parent = m
	local i = 0
	for x = -1, 1 do
		for z = -1, 1 do
			i += 1
			local pos = (cf * CFrame.new(x * 7, 1, z * 5.5)).Position
			local fl = flower(m, pos, rng:NextNumber(5, 7.5), C.PetalColors[(i - 1) % #C.PetalColors + 1], false)
			fl.Name = "Flower" .. i
			local spot = P(spots, { Name = "Spot" .. i, Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
			spot.CanTouch = false
		end
	end
	m.PrimaryPart = soil
	billboard(soil, Config.Stations.FlowerPatch.Label, 11)
	addPrompt(soil, "FlowerPatch")
end

-- Simple market booth used by the shop and the selling stand.
local function booth(m: Model, cf: CFrame, stripeA: Color3, stripeB: Color3): BasePart
	local counter = P(m, { Name = "Counter", Size = Vector3.new(12, 3.6, 4), CFrame = cf * CFrame.new(0, 1.8, 0), Color = C.Wood, Material = Enum.Material.WoodPlanks })
	P(m, { Name = "CounterTop", Size = Vector3.new(12.6, 0.5, 4.6), CFrame = cf * CFrame.new(0, 3.85, 0), Color = C.Cream })
	P(m, { Name = "BackWall", Size = Vector3.new(12, 9, 0.6), CFrame = cf * CFrame.new(0, 4.5, 4), Color = C.Cream })
	for _, x in { -5.8, 5.8 } do
		cyl(m, "Post", 10, 0.8, cf * CFrame.new(x, 5, -2), C.DarkWood)
	end
	for i = 0, 5 do
		P(m, {
			Name = "Awning",
			Size = Vector3.new(2.2, 0.4, 7.2),
			CFrame = cf * CFrame.new(-5.5 + i * 2.2, 10.2, 0.6) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = i % 2 == 0 and stripeA or stripeB,
			CanCollide = false,
		})
	end
	return counter
end

local function buildBeeShop(parent: Instance, cf: CFrame)
	local m = stationModel(parent, "BeeShop")
	local counter = booth(m, cf, C.Honey, Color3.new(1, 1, 1))
	signBoard(m, "Sign", Vector3.new(9, 2.4, 0.4), cf * CFrame.new(0, 7.4, 3.5), "BEE SHOP", C.Honey)
	-- display bee on the counter
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("BeeTemplate")
	if template and template:IsA("Model") then
		local bee = template:Clone()
		local cam = bee:FindFirstChildOfClass("Camera")
		if cam then
			cam:Destroy()
		end
		bee.Name = "DisplayBee"
		for _, d in bee:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		bee:ScaleTo(bee:GetScale() * 0.35)
		bee:PivotTo(cf * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, math.pi / 2, 0))
		bee.Parent = m
	end
	m.PrimaryPart = counter
	billboard(counter, Config.Stations.BeeShop.Label, 13)
	addPrompt(counter, "BeeShop")
end

local function buildBottling(parent: Instance, cf: CFrame)
	local m = stationModel(parent, "Bottling")
	local body = P(m, { Name = "Machine", Size = Vector3.new(10, 7, 8), CFrame = cf * CFrame.new(0, 3.5, 0), Color = C.Cream })
	P(m, { Name = "Trim", Size = Vector3.new(10.4, 0.8, 8.4), CFrame = cf * CFrame.new(0, 7.1, 0), Color = C.DeepHoney })
	cyl(m, "Tank", 6, 6, cf * CFrame.new(-1.5, 10.4, 1), C.Honey, { Material = Enum.Material.Glass, Transparency = 0.25 })
	cyl(m, "TankLid", 0.8, 6.6, cf * CFrame.new(-1.5, 13.7, 1), C.DeepHoney)
	P(m, { Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1, 1), CFrame = cf * CFrame.new(2.5, 9.5, 1), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal })
	P(m, { Name = "Window", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3.6, 3.6), CFrame = cf * CFrame.new(0, 4, -4.05) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(150, 215, 255), Material = Enum.Material.Glass, CanCollide = false })
	P(m, { Name = "Hopper", Size = Vector3.new(4, 1.4, 3), CFrame = cf * CFrame.new(-3, 7.8, -2.5), Color = C.DeepHoney })
	local deposit = P(m, { Name = "DepositPoint", Size = Vector3.one, CFrame = cf * CFrame.new(0, 3, -5.5), Transparency = 1, CanCollide = false, CanQuery = false })
	deposit:SetAttribute("Purpose", "Where carried honey is dropped off (Phase 2)")
	m.PrimaryPart = body
	billboard(body, Config.Stations.Bottling.Label, 12)
	addPrompt(body, "Bottling")
	return m
end

local function buildSellStand(parent: Instance, cf: CFrame)
	local m = stationModel(parent, "SellStand")
	local counter = booth(m, cf, Color3.fromRGB(110, 200, 120), Color3.new(1, 1, 1))
	signBoard(m, "Sign", Vector3.new(9, 2.4, 0.4), cf * CFrame.new(0, 7.4, 3.5), "HONEY STAND", Color3.fromRGB(110, 200, 120))
	for i, x in { -4, -2.6, 3.2 } do
		cyl(m, "Jar", 1.6, 1.4, cf * CFrame.new(x, 4.9, 0.6), C.Honey, { Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false })
		cyl(m, "JarLid", 0.3, 1.5, cf * CFrame.new(x, 5.85, 0.6), i == 3 and Color3.fromRGB(230, 80, 80) or C.Wood, { CanCollide = false })
	end
	for _, x in { -7.5, 7.5 } do
		P(m, { Name = "Crate", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(x, 1.3, 1) * CFrame.Angles(0, math.rad(x * 2), 0), Color = C.Wood, Material = Enum.Material.WoodPlanks })
	end
	m.PrimaryPart = counter
	billboard(counter, Config.Stations.SellStand.Label, 13)
	addPrompt(counter, "SellStand")
end

-- Short conveyor between two plot-space points (both on the ground).
local function buildConveyor(parent: Instance, from: Vector3, to: Vector3)
	local m = model(parent, "Conveyor")
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(from:Lerp(to, 0.5), to)
	P(m, { Name = "Belt", Size = Vector3.new(3, 0.4, len), CFrame = cf + Vector3.new(0, 3.2, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Fabric })
	for _, x in { -1.8, 1.8 } do
		P(m, { Name = "Rail", Size = Vector3.new(0.4, 0.8, len), CFrame = cf * CFrame.new(x, 3.5, 0), Color = C.DeepHoney })
	end
	local n = math.max(2, math.floor(len / 5))
	for i = 0, n do
		local p = cf * CFrame.new(0, 1.5, -len / 2 + len * i / n)
		P(m, { Name = "Leg", Size = Vector3.new(2.6, 3, 0.5), CFrame = p, Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal })
	end
	for name, pos in { ConveyorStart = from, ConveyorEnd = to } do
		local a = P(m, { Name = name, Size = Vector3.one * 0.5, CFrame = CFrame.new(pos + Vector3.new(0, 3.8, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
		a.CanTouch = false
	end
end

local function expansionPad(parent: Instance, cf: CFrame, size: Vector2, text: string, purpose: string)
	local pad = P(parent, {
		Name = purpose,
		Size = Vector3.new(size.X, 0.2, size.Y),
		CFrame = cf * CFrame.new(0, 0.25, 0),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.65,
		CanCollide = false,
		CanQuery = false,
	})
	pad:SetAttribute("Reserved", true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.PixelsPerStud = 20
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.25
	label.Text = text
	label.Parent = gui
	gui.Parent = pad
end

------------------------------------------------------------------------------
-- Plot
------------------------------------------------------------------------------

local function ownerSign(parent: Instance, cf: CFrame, accent: Color3)
	local board = P(parent, { Name = "OwnerSign", Size = Vector3.new(22, 7, 1), CFrame = cf, Color = C.Cream })
	P(parent, { Name = "OwnerSignFrame", Size = Vector3.new(23, 8, 0.8), CFrame = cf, Color = accent, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Gui"
		gui.Face = face
		gui.CanvasSize = Vector2.new(660, 210)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.LightInfluence = 0.1

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.fromOffset(170, 170)
		avatar.Position = UDim2.fromOffset(20, 20)
		avatar.BackgroundColor3 = accent
		avatar.Image = ""
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = avatar
		avatar.Parent = gui

		local name = Instance.new("TextLabel")
		name.Name = "OwnerName"
		name.Size = UDim2.fromOffset(440, 110)
		name.Position = UDim2.fromOffset(205, 20)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = C.Text
		name.Text = "Free Farm"
		name.Parent = gui

		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromOffset(440, 60)
		sub.Position = UDim2.fromOffset(205, 130)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Color3.fromRGB(140, 100, 60)
		sub.Text = "Waiting for a beekeeper"
		sub.Parent = gui

		gui.Parent = board
	end
	return board
end

local function buildPlot(plots: Instance, id: number, cf: CFrame)
	local plot = model(plots, "Plot" .. id)
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot.WorldPivot = cf

	local half = Config.PlotSize / 2
	local accent = Config.PlotAccents[(id - 1) % #Config.PlotAccents + 1]
	local function L(x: number, z: number): Vector3
		return (cf * CFrame.new(x, 0, z)).Position
	end

	local ground = model(plot, "Ground")
	P(ground, { Name = "Grass", Size = Vector3.new(Config.PlotSize, 1, Config.PlotSize), CFrame = cf * CFrame.new(0, -0.35, 0), Color = C.PlotGrass, Material = Enum.Material.Grass })
	P(ground, { Name = "Path", Size = Vector3.new(10, 1, Config.PlotSize - 4), CFrame = cf * CFrame.new(0, -0.25, 0), Color = C.Path, Material = Enum.Material.Pebble })
	-- side paths to each column of stations
	for _, z in { -30, 2, 28 } do
		for _, x in { -1, 1 } do
			P(ground, { Name = "SidePath", Size = Vector3.new(18, 1, 6), CFrame = cf * CFrame.new(x * 13, -0.25, z), Color = C.Path, Material = Enum.Material.Pebble })
		end
	end

	-- Fences (gap in the front for the gate)
	local fences = model(plot, "Fences")
	local g = Config.GateWidth / 2
	fence(fences, L(-half, -half), L(-g - 1, -half), C.FenceWhite)
	fence(fences, L(g + 1, -half), L(half, -half), C.FenceWhite)
	fence(fences, L(half, -half), L(half, half), C.FenceWhite)
	fence(fences, L(half, half), L(-half, half), C.FenceWhite)
	fence(fences, L(-half, half), L(-half, -half), C.FenceWhite)

	-- Gate arch with the owner sign (faces the village)
	local gate = model(plot, "Gate")
	for _, x in { -g - 1, g + 1 } do
		cyl(gate, "Pillar", 15, 2.4, cf * CFrame.new(x, 7.5, -half), C.Wood, { Material = Enum.Material.Wood })
		ball(gate, "PillarTop", 3.2, cf * CFrame.new(x, 15.5, -half), accent)
	end
	P(gate, { Name = "Beam", Size = Vector3.new(Config.GateWidth + 4, 1.6, 1.6), CFrame = cf * CFrame.new(0, 13.5, -half), Color = C.Wood, Material = Enum.Material.Wood })
	ownerSign(gate, cf * CFrame.new(0, 18.2, -half), accent)

	-- Spawn point just inside the gate, looking into the farm
	local spawnPoint = P(plot, {
		Name = "SpawnPoint",
		Size = Vector3.new(2, 1, 2),
		CFrame = cf * CFrame.new(0, 3.5, -half + 10) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	spawnPoint:SetAttribute("Purpose", "Owner teleport target")
	cyl(plot, "WelcomeMat", 0.2, 8, cf * CFrame.new(0, 0.3, -half + 10), accent, { CanCollide = false })

	-- Stations. Left column faces +X (towards the path), right column faces -X.
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = plot
	local faceRight = CFrame.Angles(0, -math.pi / 2, 0)
	local faceLeft = CFrame.Angles(0, math.pi / 2, 0)
	buildHive(stations, cf * CFrame.new(-26, 0, 28) * faceRight)
	buildFlowerPatch(stations, cf * CFrame.new(28, 0, 30) * faceLeft)
	buildBeeShop(stations, cf * CFrame.new(-28, 0, -30) * faceRight)
	local bottling = buildBottling(stations, cf * CFrame.new(26, 0, 2) * faceLeft)
	buildSellStand(stations, cf * CFrame.new(28, 0, -30) * faceLeft)
	buildConveyor(bottling, L(26, -3), L(26, -24))

	-- Space reserved for later upgrades
	local expansion = Instance.new("Folder")
	expansion.Name = "Expansion"
	expansion.Parent = plot
	expansionPad(expansion, cf * CFrame.new(-28, 0, 2), Vector2.new(24, 18), "Future Hives", "HiveExpansion")
	expansionPad(expansion, cf * CFrame.new(38, 0, -10), Vector2.new(14, 14), "Future Machines", "MachineExpansion")

	-- A couple of giant flowers in the corners
	flower(plot, L(-half + 5, half - 5), 12, accent, true)
	flower(plot, L(half - 5, half - 5), 11, C.PetalColors[1], true)

	-- Per-plot container for temporary objects (bees, jars, effects). Cleared when the owner leaves.
	local temp = Instance.new("Folder")
	temp.Name = "Temp"
	temp.Parent = plot

	return plot
end

------------------------------------------------------------------------------
-- World
------------------------------------------------------------------------------

function MapBuilder.PlotCFrame(id: number): CFrame
	local a = (id - 1) / Config.PlotCount * math.pi * 2
	local pos = Vector3.new(math.sin(a) * Config.PlotRadius, 0, math.cos(a) * Config.PlotRadius)
	-- LookVector points at the village, so the gate (local -Z) faces the plaza
	return CFrame.lookAt(pos, Vector3.zero)
end

function MapBuilder.Build(): Model
	local existing = workspace:FindFirstChild("HoneyFarmMap")
	if existing then
		return existing :: Model
	end

	local map = Instance.new("Model")
	map.Name = "HoneyFarmMap"

	local h = Config.MapHalfSize
	P(map, { Name = "Ground", Size = Vector3.new(h * 2, 4, h * 2), CFrame = CFrame.new(0, -2, 0), Color = C.Grass, Material = Enum.Material.Grass })

	-- Invisible boundary walls
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local size = if side.X ~= 0 then Vector3.new(2, 80, h * 2) else Vector3.new(h * 2, 80, 2)
		P(map, { Name = "Boundary", Size = size, CFrame = CFrame.new(side * h + Vector3.new(0, 40, 0)), Transparency = 1, CanQuery = false })
	end

	buildVillage(map)

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	local paths = model(map, "Paths")
	local inner = Config.SquareRadius - 2
	local outer = Config.PlotRadius - Config.PlotSize / 2 + 1
	for id = 1, Config.PlotCount do
		local cf = MapBuilder.PlotCFrame(id)
		buildPlot(plots, id, cf)
		local dir = -cf.LookVector
		local a, b = dir * inner, dir * outer
		P(paths, {
			Name = "Path" .. id,
			Size = Vector3.new(Config.PathWidth, 1, (b - a).Magnitude),
			CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b) + Vector3.new(0, -0.3, 0),
			Color = C.Path,
			Material = Enum.Material.Pebble,
		})
	end

	-- Scenery in the wedges between plots and around the edge
	local scenery = model(map, "Scenery")
	for i = 1, Config.PlotCount do
		local a = (i - 0.5) / Config.PlotCount * math.pi * 2
		for _, r in { 140, 185, 225 } do
			local jitter = rng:NextNumber(-0.06, 0.06)
			local pos = Vector3.new(math.sin(a + jitter) * r, 0, math.cos(a + jitter) * r)
			if r == 185 then
				tree(scenery, pos, rng:NextNumber(1, 1.4))
			else
				flower(scenery, pos, rng:NextNumber(12, 18), C.PetalColors[rng:NextInteger(1, #C.PetalColors)], true)
			end
		end
	end
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		local r = h - 18
		local pos = Vector3.new(math.clamp(math.sin(a) * r * 1.3, -r, r), 0, math.clamp(math.cos(a) * r * 1.3, -r, r))
		tree(scenery, pos, rng:NextNumber(1.2, 1.8))
	end

	map.Parent = workspace
	return map
end

return MapBuilder
