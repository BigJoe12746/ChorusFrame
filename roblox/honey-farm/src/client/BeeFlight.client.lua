-- Flies every bee model (Plot.Temp.Bee*) between its plot's flowers and hive.
-- Purely visual and local: the server never moves bees, so there is no network cost.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local F = Config.BeeFlight

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local rng = Random.new()

type Flyer = {
	Model: Model,
	Spots: { BasePart },
	Hive: BasePart,
	Target: Vector3,
	AtHive: boolean,
	Hover: number,
	Phase: number,
}

local flyers: { [Model]: Flyer } = {}

local function pickTarget(f: Flyer)
	if f.AtHive or #f.Spots == 0 then
		local spot = f.Spots[rng:NextInteger(1, math.max(1, #f.Spots))]
		f.Target = if spot then spot.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 1.5), rng:NextNumber(-1.5, 1.5)) else f.Hive.Position
		f.AtHive = false
	else
		f.Target = f.Hive.Position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1))
		f.AtHive = true
	end
	f.Hover = F.HoverTime * rng:NextNumber(0.7, 1.3)
end

local function track(model: Instance, plot: Instance)
	if not model:IsA("Model") or not model:GetAttribute("Bee") then
		return
	end
	local hive = plot:FindFirstChild("BeeExit", true) :: BasePart?
	local spotsFolder = plot:FindFirstChild("FlowerSpots", true)
	if not hive then
		return
	end
	local spots = {}
	if spotsFolder then
		for _, s in spotsFolder:GetChildren() do
			if s:IsA("BasePart") then
				table.insert(spots, s)
			end
		end
	end
	local f: Flyer = {
		Model = model,
		Spots = spots,
		Hive = hive,
		Target = hive.Position,
		AtHive = true,
		Hover = rng:NextNumber(0, 1),
		Phase = rng:NextNumber(0, math.pi * 2),
	}
	flyers[model] = f
	model.Destroying:Connect(function()
		flyers[model] = nil
	end)
end

local function watchPlot(plot: Instance)
	local temp = plot:WaitForChild("Temp", 10)
	if not temp then
		return
	end
	for _, m in temp:GetChildren() do
		track(m, plot)
	end
	temp.ChildAdded:Connect(function(m)
		-- attributes are set before the model is parented, so this is safe
		track(m, plot)
	end)
	temp.ChildRemoved:Connect(function(m)
		flyers[m :: Model] = nil
	end)
	-- a merge replaces bee models; a freshly spawned bee pops in from nothing
	temp.ChildAdded:Connect(function(m)
		if m:IsA("Model") and m:GetAttribute("Bee") and m:GetAttribute("PopIn") then
			local target = m:GetScale()
			m:ScaleTo(math.max(0.05, target * 0.1))
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local a = math.min(1, (os.clock() - t0) / 0.45)
				local ease = 1 - (1 - a) ^ 3
				if m.Parent then
					m:ScaleTo(math.max(0.05, target * (0.1 + 0.9 * ease)))
				end
				if a >= 1 or not m.Parent then
					conn:Disconnect()
				end
			end)
		end
	end)
end

for _, plot in plots:GetChildren() do
	task.spawn(watchPlot, plot)
end
plots.ChildAdded:Connect(function(plot)
	task.spawn(watchPlot, plot)
end)

local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	for model, f in flyers do
		if not model.Parent then
			flyers[model] = nil
			continue
		end
		local pivot = model:GetPivot()
		local pos = pivot.Position
		local to = f.Target - pos
		local flat = Vector3.new(to.X, 0, to.Z)
		local bob = Vector3.new(0, math.sin(t * 6 + f.Phase) * F.Bob * dt, 0)

		if to.Magnitude < 1.2 then
			-- hovering at the flower / hive
			f.Hover -= dt
			model:PivotTo(pivot + bob)
			if f.Hover <= 0 then
				pickTarget(f)
			end
		else
			local step = math.min(F.Speed * dt, to.Magnitude)
			local newPos = pos + to.Unit * step + bob
			local look = if flat.Magnitude > 0.05 then CFrame.lookAt(newPos, newPos + flat.Unit) else CFrame.new(newPos) * pivot.Rotation
			local tilt = CFrame.Angles(0, 0, math.sin(t * 6 + f.Phase) * 0.08)
			model:PivotTo(look * tilt)
		end
	end
end)
