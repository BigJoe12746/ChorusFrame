-- UpgradeVisuals (ModuleScript)
-- Shows a player's upgrade levels on their plot: extra hives appear in the hive yard,
-- extra tanks and pipes grow beside the bottling machine, the flower patch gets glowing
-- pollen, and gold bands wrap the main hive. Everything is built into Plot.Temp.Upgrades,
-- which PlotService clears when the owner leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local PropLibrary = require(script.Parent:WaitForChild("PropLibrary"))
local C = Config.Colors

local UpgradeVisuals = {}

local UP = CFrame.Angles(0, 0, math.pi / 2)

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, cf: CFrame, h: number, d: number, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = cf * UP, Color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return part(parent, props)
end

-- Small beehive standing on `cf` (ground).
local function miniHive(parent: Instance, cf: CFrame, level: number)
	-- a "MiniHive" prop, or the main "Hive" prop shrunk down, replaces the block version
	local prop = if PropLibrary.Has("MiniHive") then PropLibrary.Place(parent, "MiniHive", cf, 7, "MiniHive") else PropLibrary.PlaceLevel(parent, "Hive", 1, cf, 7, "MiniHive")
	if prop then
		return
	end
	local m = Instance.new("Model")
	m.Name = "MiniHive"
	cyl(m, cf * CFrame.new(0, 0.3, 0), 0.6, 6.5, C.Wood, { Material = Enum.Material.WoodPlanks, CanCollide = true })
	for i = 0, 3 do
		cyl(m, cf * CFrame.new(0, 1.3 + i * 1.3, 0), 1.3, 5.5 - i * 1.0, if i % 2 == 0 then C.Honey else C.DeepHoney, { CanCollide = true })
	end
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = cf * CFrame.new(0, 6.3, 0), Color = C.DeepHoney })
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.2, 1.2), CFrame = cf * CFrame.new(0, 1.6, -2.6) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(60, 35, 15) })
	m.Parent = parent
end

-- Extra honey tank + pipe beside the bottling machine.
local function tankModule(parent: Instance, cf: CFrame, index: number)
	local m = Instance.new("Model")
	m.Name = "TankModule"
	part(m, { Size = Vector3.new(5, 1, 5), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal, CanCollide = true })
	cyl(m, cf * CFrame.new(0, 4.5, 0), 7, 4, C.Honey, { Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = true })
	cyl(m, cf * CFrame.new(0, 8.3, 0), 0.7, 4.6, C.DeepHoney)
	cyl(m, cf * CFrame.new(0, 7, 0), 0.5, 4.4, Color3.fromRGB(190, 190, 200), { Material = Enum.Material.Metal })
	-- pipe heading towards the machine (-X in the pad's space)
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.9, 0.9), CFrame = cf * CFrame.new(-4, 6 + (index % 2) * 0.9, 0), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal })
	-- little gauge
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.4, 1.4), CFrame = cf * CFrame.new(0, 3, 2.1) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.new(1, 1, 1) })
	m.Parent = parent
end

-- Swaps the main hive prop for the one matching `level` (Hive, Hive2, Hive3...) and grows it a
-- little per level. Does nothing when the farm uses the block-built hive.
local function applyHiveModel(plot: Model, level: number)
	local hive = plot:FindFirstChild("Hive", true)
	local cf = hive and hive:GetAttribute("PropCFrame")
	if not hive or cf == nil or not PropLibrary.Has("Hive") then
		return
	end
	local wanted = PropLibrary.ForLevel("Hive", level)
	local current = hive:FindFirstChild("HiveModel")
	local growth = 1 + math.min(0.6, (level - 1) * Config.HiveGrowthPerLevel)
	if current and current:GetAttribute("Prop") == (wanted and wanted.Name) and current:GetAttribute("Level") == level then
		return
	end
	if current then
		current:Destroy()
	end
	local model = PropLibrary.PlaceLevel(hive, "Hive", level, cf, Config.HiveHeight * growth, "HiveModel")
	if model then
		model:SetAttribute("Level", level)
	end
end

-- `state` may be nil (plot released): everything goes back to level 1.
function UpgradeVisuals.Apply(plot: Model, state: any)
	local temp = plot:FindFirstChild("Temp")
	if not temp then
		return
	end
	if state == nil then
		local old = temp:FindFirstChild("Upgrades")
		if old then
			old:Destroy()
		end
		applyHiveModel(plot, 1)
		return
	end
	local old = temp:FindFirstChild("Upgrades")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Upgrades"

	-- Hive storage: one mini hive per level above 1 in the hive yard, plus gold bands on the main hive
	local hiveLevel = state:UpgradeLevel("HiveStorage")
	applyHiveModel(plot, hiveLevel)
	local usingHiveProp = PropLibrary.Has("Hive")
	local hivePad = plot:FindFirstChild("HiveExpansion", true) :: BasePart?
	if hivePad then
		local slots = { { -7, -5 }, { 0, -5 }, { 7, -5 }, { -7, 4 }, { 0, 4 }, { 7, 4 }, { -3.5, -0.5 }, { 3.5, -0.5 }, { -9, -0.5 } }
		for i = 1, math.min(hiveLevel - 1, #slots) do
			local o = slots[i]
			miniHive(folder, hivePad.CFrame * CFrame.new(o[1], 0.1, o[2]) * CFrame.Angles(0, (i % 3) * 0.3, 0), i)
		end
	end
	local mainHive = plot:FindFirstChild("Hive", true)
	local hiveBase = mainHive and mainHive:FindFirstChild("Base") :: BasePart?
	if hiveBase and hiveLevel > 1 and not usingHiveProp then -- bands are shaped for the block hive
		for i = 1, math.min(hiveLevel - 1, 5) do
			cyl(folder, hiveBase.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, 1.0 + i * 2.2, 0), 0.5, 14.6 - (i - 1) * 2.2, Color3.fromRGB(255, 225, 120), { Name = "GoldBand", Material = Enum.Material.Metal, Reflectance = 0.3 })
		end
	end

	-- Bottling speed: tank modules on the machine pad
	local speedLevel = state:UpgradeLevel("BottlingSpeed")
	local machinePad = plot:FindFirstChild("MachineExpansion", true) :: BasePart?
	if machinePad then
		local slots = { { 3, -3.5 }, { 3, 3.5 }, { -3.5, -3.5 }, { -3.5, 3.5 }, { 3, 0 }, { -3.5, 0 }, { 0, -3.5 }, { 0, 3.5 } }
		for i = 1, math.min(speedLevel - 1, #slots) do
			local o = slots[i]
			tankModule(folder, machinePad.CFrame * CFrame.new(o[1], 0.1, o[2]), i)
		end
	end

	-- Production: glowing pollen orbs over the flower patch, one per level above 1
	local prodLevel = state:UpgradeLevel("Production")
	local spots = plot:FindFirstChild("FlowerSpots", true)
	if spots and prodLevel > 1 then
		local list = spots:GetChildren()
		for i = 1, math.min(prodLevel - 1, #list) do
			local spot = list[i]
			if spot:IsA("BasePart") then
				part(folder, { Name = "PollenOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = spot.CFrame * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(255, 230, 90), Material = Enum.Material.Neon, Transparency = 0.2 })
			end
		end
	end

	-- Bee slots: extra landing boards on the main hive
	local slotLevel = state:UpgradeLevel("BeeSlots")
	if hiveBase and slotLevel > 1 and not usingHiveProp then
		for i = 1, math.min(slotLevel - 1, 6) do
			local a = i / 7 * math.pi * 1.4 + 0.3
			cyl(folder, hiveBase.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.6 + (i % 2) * 2.2, -8.2) * CFrame.Angles(math.pi / 2, 0, 0), 0.3, 2.2, C.Wood, { Name = "LandingBoard", Material = Enum.Material.Wood })
		end
	end

	folder:SetAttribute("Levels", ("H%d S%d P%d B%d"):format(hiveLevel, speedLevel, prodLevel, slotLevel))
	folder.Parent = temp
end

return UpgradeVisuals
