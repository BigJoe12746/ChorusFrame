-- Juice: honey sparkles when you collect, a swirl when you deposit, coins + floating "+$X"
-- when you collect cash, a fanfare on merges, and UI click sounds. Driven by the server's
-- Feedback remote so effects only play for real, accepted actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FeedbackRemote = Remotes:WaitForChild("Feedback") :: RemoteEvent
local BeeMergedRemote = Remotes:WaitForChild("BeeMerged") :: RemoteEvent

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local fx = Instance.new("Folder")
fx.Name = "FarmFX"
fx.Parent = workspace

------------------------------------------------------------------------------
-- Sounds
------------------------------------------------------------------------------

local sounds: { [string]: Sound } = {}
local function sound(name: string, volume: number?): Sound?
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local s = sounds[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = volume or 0.5
		s.Parent = SoundService
		sounds[name] = s
	end
	return s
end

local function play(name: string, pitch: number?)
	local s = sound(name)
	if s then
		s.PlaybackSpeed = pitch or 1
		s:Play()
	end
end

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function myStationPart(station: string): BasePart?
	local id = player:GetAttribute("PlotId")
	local plot = id and plots:FindFirstChild("Plot" .. id)
	local stations = plot and plot:FindFirstChild("Stations")
	local model = stations and stations:FindFirstChild(station)
	return model and (model :: Model).PrimaryPart
end

local function rootPosition(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root :: BasePart).Position
end

local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = fx
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = C.Text
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = bb
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 1.2)
end

local rng = Random.new()

-- Little parts that burst out of `from` and fall, fading.
local function burst(from: Vector3, count: number, color: Color3, size: number, shape: Enum.PartType, material: Enum.Material?)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = Vector3.one * size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = CFrame.new(from)
		p.Parent = fx
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * rng:NextNumber(3, 6)
		local up = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(from + dir) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0) })
		up:Play()
		up.Completed:Connect(function()
			TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(from + dir * Vector3.new(1.2, 0, 1.2) - Vector3.new(0, 2, 0)), Transparency = 1 }):Play()
		end)
		Debris:AddItem(p, 0.9)
	end
end

-- Stream of honey drops from the station into the player.
local function stream(from: Vector3, to: Vector3, count: number)
	for i = 1, count do
		task.delay(i * 0.04, function()
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * 0.6
			p.Color = C.Honey
			p.Material = Enum.Material.Neon
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CFrame = CFrame.new(from + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2), rng:NextNumber(-1.5, 1.5)))
			p.Parent = fx
			TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(to), Size = Vector3.one * 0.2 }):Play()
			Debris:AddItem(p, 0.45)
		end)
	end
end

------------------------------------------------------------------------------
-- Feedback handlers
------------------------------------------------------------------------------

FeedbackRemote.OnClientEvent:Connect(function(kind: string, amount: number, station: string)
	local part = myStationPart(station)
	local at = if part then part.Position + Vector3.new(0, part.Size.Y / 2 + 1, 0) else rootPosition()
	local me = rootPosition()
	if not at then
		return
	end
	if kind == "Honey" then
		if me then
			stream(at, me + Vector3.new(0, 1, 0), math.clamp(amount, 4, 14))
		end
		floatingText(at, ("+%d 🍯"):format(amount), C.Honey)
		play("Collect", rng:NextNumber(0.95, 1.1))
	elseif kind == "Deposit" then
		if me then
			stream(me + Vector3.new(0, 1, 0), at, math.clamp(amount, 4, 14))
		end
		floatingText(at, ("%d 🍯 → jars"):format(amount), C.Cream)
		play("Deposit")
	elseif kind == "Cash" then
		burst(at, math.clamp(math.floor(amount / 5), 4, 18), Color3.fromRGB(255, 215, 60), 0.7, Enum.PartType.Cylinder, Enum.Material.Metal)
		floatingText(at, ("+$%d"):format(amount), Color3.fromRGB(120, 230, 120))
		play("Cash", 1.15)
	elseif kind == "Buy" then
		floatingText(at, ("-$%d  🐝"):format(amount), Color3.fromRGB(255, 180, 180))
		play("Click")
	end
end)

BeeMergedRemote.OnClientEvent:Connect(function(plotId: number)
	if player:GetAttribute("PlotId") == plotId then
		play("Merge", 1.2)
	end
end)

-- UI clicks: any TextButton under PlayerGui
local playerGui = player:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(function(d)
	if d:IsA("TextButton") then
		d.Activated:Connect(function()
			play("Click", rng:NextNumber(0.95, 1.05))
		end)
	end
end)
