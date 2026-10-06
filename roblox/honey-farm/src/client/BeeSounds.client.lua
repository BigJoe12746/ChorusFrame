-- Subtle bee hum: a quiet looping sound on every bee model, slightly different pitch per bee,
-- audible only up close. Does nothing until Config.Sounds.Buzz has an asset id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local buzzId = Config.Sounds.Buzz
if not buzzId or buzzId == "" then
	return
end

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local rng = Random.new()

local function attach(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("Bee") then
		return
	end
	local head = model:FindFirstChild("Head1") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not head or head:FindFirstChild("Buzz") then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Buzz"
	s.SoundId = buzzId
	s.Looped = true
	s.Volume = Config.Sounds.BuzzVolume or 0.12
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.PlaybackSpeed = rng:NextNumber(0.9, 1.15)
	s.Parent = head
	s:Play()
end

local function watchPlot(plot: Instance)
	local temp = plot:WaitForChild("Temp", 10)
	if not temp then
		return
	end
	for _, m in temp:GetChildren() do
		attach(m)
	end
	temp.ChildAdded:Connect(attach)
end

for _, plot in plots:GetChildren() do
	task.spawn(watchPlot, plot)
end
plots.ChildAdded:Connect(function(plot)
	task.spawn(watchPlot, plot)
end)
