-- Animates honey jars down a plot's conveyor when the server says a jar was made.
-- Jars are local parts (not replicated), so the visual costs nothing on the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local JarRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("JarStarted") :: RemoteEvent
local _C = Config.Colors

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local jarFolder = Instance.new("Folder")
jarFolder.Name = "LocalJars"
jarFolder.Parent = workspace

local activeJars: { [number]: number } = {} -- plotId -> jars currently on the belt

-- Creator Store honey jar (ReplicatedStorage/Props/Jar). If it is missing, jars simply
-- don't animate on the belt - the server still counts every jar.
local jarTemplate = (ReplicatedStorage:FindFirstChild("Props") and ReplicatedStorage.Props:FindFirstChild("Jar")) :: Model?

local function makeJar(): Model?
	local jar = jarTemplate and jarTemplate:Clone()
	if not jar then
		return nil
	end
	jar:ScaleTo(0.6)
	for _, d in jar:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return jar
end

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
	if not jar then
		activeJars[plotId] -= 1
		return
	end
	local lift = select(2, jar:GetBoundingBox()).Y / 2 -- pivot is the bbox centre, so raise by half the height
	local a = startPart.Position + Vector3.new(0, 0.9 + lift, 0)
	local b = endPart.Position + Vector3.new(0, 0.9 + lift, 0)
	local function place(pos: Vector3)
		jar:PivotTo(CFrame.new(pos))
	end
	local parts: { BasePart } = {}
	for _, d in jar:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			d.Transparency = 1
		end
	end
	place(a)
	jar.Parent = jarFolder

	-- fade in standing upright on the belt
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 0 }):Play()
	end

	local travel = Config.Economy.JarTravelTime
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		local alpha = math.min(1, (os.clock() - t0) / travel)
		place(a:Lerp(b, alpha))
		if alpha >= 1 then
			conn:Disconnect()
			-- hop off the belt into the stand
			for _, p in parts do
				TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
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
