-- Animates honey jars down a plot's conveyor when the server says a jar was made.
-- Jars are local parts (not replicated), so the visual costs nothing on the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local JarRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("JarStarted") :: RemoteEvent
local C = Config.Colors

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local jarFolder = Instance.new("Folder")
jarFolder.Name = "LocalJars"
jarFolder.Parent = workspace

local activeJars: { [number]: number } = {} -- plotId -> jars currently on the belt

local function makeJar(): Model
	local m = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Glass"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(1.6, 1.3, 1.3)
	body.Color = C.Honey
	body.Material = Enum.Material.Glass
	body.Transparency = 0.15
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = m
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Shape = Enum.PartType.Cylinder
	lid.Size = Vector3.new(0.3, 1.4, 1.4)
	lid.Color = C.Wood
	lid.Anchored = true
	lid.CanCollide = false
	lid.CanQuery = false
	lid.CanTouch = false
	lid.Parent = m
	m.PrimaryPart = body
	return m
end

local UP = CFrame.Angles(0, 0, math.pi / 2)

local function runJar(plotId: number, delay: number)
	local plot = plots:FindFirstChild("Plot" .. plotId)
	local startPart = plot and plot:FindFirstChild("ConveyorStart", true) :: BasePart?
	local endPart = plot and plot:FindFirstChild("ConveyorEnd", true) :: BasePart?
	if not startPart or not endPart then
		return
	end
	if (activeJars[plotId] or 0) >= Config.Economy.MaxJarsOnBelt then
		return -- belt is visually full; the server still counts the jar
	end
	activeJars[plotId] = (activeJars[plotId] or 0) + 1

	task.wait(delay)
	local jar = makeJar()
	local a = startPart.Position + Vector3.new(0, 0.8, 0)
	local b = endPart.Position + Vector3.new(0, 0.8, 0)
	local glass = jar.PrimaryPart :: BasePart
	local lid = jar:FindFirstChild("Lid") :: BasePart
	local function place(pos: Vector3)
		glass.CFrame = CFrame.new(pos) * UP
		lid.CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * UP
	end
	place(a)
	jar.Parent = jarFolder

	-- pop in
	glass.Size = Vector3.new(0.2, 0.2, 0.2)
	TweenService:Create(glass, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = Vector3.new(1.6, 1.3, 1.3) }):Play()

	local travel = Config.Economy.JarTravelTime
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		local alpha = math.min(1, (os.clock() - t0) / travel)
		place(a:Lerp(b, alpha))
		if alpha >= 1 then
			conn:Disconnect()
			-- hop off the belt into the stand
			TweenService:Create(glass, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.3, 0.3, 0.3) }):Play()
			TweenService:Create(lid, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			Debris:AddItem(jar, 0.3)
			activeJars[plotId] -= 1
		end
	end)
end

JarRemote.OnClientEvent:Connect(function(plotId: number, count: number)
	count = math.max(1, count or 1)
	for i = 1, count do
		task.spawn(runJar, plotId, (i - 1) * 0.15)
	end
end)
