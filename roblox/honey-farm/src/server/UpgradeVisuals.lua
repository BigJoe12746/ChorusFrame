-- UpgradeVisuals (ModuleScript)
-- Shows a player's upgrade levels on their plot: a blocky hive tree grows in the hive yard
-- with one branch (and one hanging hive) per Hive Storage level, extra tanks and pipes grow
-- beside the bottling machine, the flower patch gets glowing pollen, and gold bands wrap the
-- main hive. Everything is built into Plot.Temp.Upgrades, which PlotService clears when the
-- owner leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local PropLibrary = require(script.Parent:WaitForChild("PropLibrary"))
local StudStyle = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("StudStyle"))
local C = Config.Colors

local UpgradeVisuals = {}

local UP = CFrame.Angles(0, 0, math.pi / 2)

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	for k, v in props do
		(p :: any)[k] = v
	end
	StudStyle.Apply(p)
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

------------------------------------------------------------------------------
-- Hive tree: a block-built tree (cube trunk, cube branches, cube leaf clumps in the
-- studded style) that stands on the hive yard pad. The trunk gains a block and a branch
-- every Hive Storage level; each branch carries a hive hanging from its tip.
------------------------------------------------------------------------------

local BLOCK = 3 -- trunk / leaf cube size
local BRANCH_BLOCK = 2
local TRUNK_BASE_BLOCKS = 5 -- trunk blocks below the first branch
local BRANCH_REACH = 3 -- branch cubes out from the trunk
local ROPE = 1.5 -- gap between the branch tip and the hive's top
local HANGING_HIVE_HEIGHT = 7
local LEAF_COLORS = { Color3.fromRGB(70, 160, 70), Color3.fromRGB(96, 190, 82), Color3.fromRGB(58, 138, 62) }
local TRUNK_COLOR = Color3.fromRGB(96, 62, 36)
local BRANCH_COLOR = Color3.fromRGB(120, 78, 46)

local function cube(parent: Instance, cf: CFrame, size: number, color: Color3, name: string, collide: boolean?)
	return part(parent, { Name = name, Size = Vector3.one * size, CFrame = cf, Color = color, CanCollide = collide == true })
end

-- Height (studs above the pad) of branch `i` (1 = lowest).
local function branchHeight(i: number): number
	return (TRUNK_BASE_BLOCKS + i) * BLOCK - BLOCK / 2
end

-- Yaw of branch `i`: golden-angle spread so branches fan around the trunk and never stack.
local function branchYaw(i: number): number
	return i * 2.39996 + 0.6
end

-- Ground CFrame the hanging hive is built on: straight below branch `i`'s tip.
local function hangingHiveCFrame(padCF: CFrame, i: number): CFrame
	local tipY = branchHeight(i) - BRANCH_BLOCK / 2
	local reach = BRANCH_BLOCK * (BRANCH_REACH + 0.5)
	local groundY = tipY - ROPE - HANGING_HIVE_HEIGHT
	return padCF * CFrame.Angles(0, branchYaw(i), 0) * CFrame.new(0, groundY, -reach) * CFrame.Angles(0, (i % 3) * 0.3, 0)
end

-- Builds the tree for `branches` hives. Returns nil when there is nothing to show.
local function hiveTree(parent: Instance, padCF: CFrame, branches: number): Model?
	if branches < 1 then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "HiveTree"
	m:SetAttribute("Branches", branches)
	local trunkBlocks = TRUNK_BASE_BLOCKS + branches + 1
	-- roots: a ring of half-sunk cubes so the trunk reads as planted, not placed
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		cube(m, padCF * CFrame.new(math.cos(a) * BLOCK, BLOCK / 4, math.sin(a) * BLOCK), BLOCK * 0.8, TRUNK_COLOR, "Root", true)
	end
	for b = 1, trunkBlocks do
		cube(m, padCF * CFrame.new(0, (b - 0.5) * BLOCK, 0), BLOCK, TRUNK_COLOR, "Trunk", true)
	end
	-- crown: a block canopy on top that gets a little wider as the tree grows
	local crownY = trunkBlocks * BLOCK
	local crownRadius = math.min(2, 1 + math.floor(branches / 4))
	local leafIndex = 0
	for dx = -crownRadius, crownRadius do
		for dz = -crownRadius, crownRadius do
			for dy = 0, 1 do
				local corner = math.abs(dx) == crownRadius and math.abs(dz) == crownRadius
				if not (corner and dy == 1) then
					leafIndex += 1
					cube(m, padCF * CFrame.new(dx * BLOCK, crownY + (dy + 0.5) * BLOCK, dz * BLOCK), BLOCK, LEAF_COLORS[leafIndex % #LEAF_COLORS + 1], "Leaf")
				end
			end
		end
	end
	cube(m, padCF * CFrame.new(0, crownY + 2.5 * BLOCK, 0), BLOCK, LEAF_COLORS[1], "Leaf")
	-- branches
	for i = 1, branches do
		local y = branchHeight(i)
		local rot = padCF * CFrame.Angles(0, branchYaw(i), 0)
		for r = 1, BRANCH_REACH do
			cube(m, rot * CFrame.new(0, y, -(BLOCK / 2 + (r - 0.5) * BRANCH_BLOCK)), BRANCH_BLOCK, BRANCH_COLOR, "Branch")
		end
		local tipZ = -(BLOCK / 2 + BRANCH_REACH * BRANCH_BLOCK)
		-- leaf clump around the branch tip
		for _, o in { { 0, BRANCH_BLOCK, 0 }, { BRANCH_BLOCK, 0, 0 }, { -BRANCH_BLOCK, 0, 0 }, { 0, 0, -BRANCH_BLOCK }, { 0, BRANCH_BLOCK, -BRANCH_BLOCK } } do
			leafIndex += 1
			cube(m, rot * CFrame.new(o[1], y + o[2], tipZ + o[3]), BRANCH_BLOCK, LEAF_COLORS[leafIndex % #LEAF_COLORS + 1], "Leaf")
		end
		-- rope from the tip down to the hive
		part(m, { Name = "Rope", Size = Vector3.new(0.3, ROPE, 0.3), CFrame = rot * CFrame.new(0, y - BRANCH_BLOCK / 2 - ROPE / 2, tipZ + BRANCH_BLOCK / 2), Color = Color3.fromRGB(205, 170, 110) })
	end
	m.Parent = parent
	return m
end

-- Small beehive standing on `cf` (ground); hung from the hive tree it dangles under a branch.
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

	-- Hive storage: a block tree grows in the hive yard with one branch per level above 1,
	-- a hive hanging from each branch, plus gold bands on the main hive
	local hiveLevel = state:UpgradeLevel("HiveStorage")
	applyHiveModel(plot, hiveLevel)
	local usingHiveProp = PropLibrary.Has("Hive")
	local hivePad = plot:FindFirstChild("HiveExpansion", true) :: BasePart?
	if hivePad then
		local branches = math.max(0, hiveLevel - 1)
		local padCF = hivePad.CFrame * CFrame.new(0, hivePad.Size.Y / 2, 0)
		hiveTree(folder, padCF, branches)
		for i = 1, branches do
			miniHive(folder, hangingHiveCFrame(padCF, i), i)
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
