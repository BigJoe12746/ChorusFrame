-- Merge animation at the hive and the "New bee discovered!" banner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local BeeMergedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BeeMerged") :: RemoteEvent

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

------------------------------------------------------------------------------
-- Burst of sparkles where the new bee appears
------------------------------------------------------------------------------

local fx = Instance.new("Folder")
fx.Name = "MergeFX"
fx.Parent = workspace

local function burst(position: Vector3, color: Color3)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1, 1, 1)
	core.Material = Enum.Material.Neon
	core.Color = color
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CFrame = CFrame.new(position)
	core.Parent = fx
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(core, 0.6)

	local rng = Random.new()
	for _ = 1, 14 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.5, 0.5, 0.5)
		p.Material = Enum.Material.Neon
		p.Color = if rng:NextNumber() < 0.5 then color else C.Honey
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = CFrame.new(position)
		p.Parent = fx
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(4, 7)
		TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + dir) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}):Play()
		Debris:AddItem(p, 0.8)
	end
end

------------------------------------------------------------------------------
-- Discovery banner (only for your own farm)
------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Discovery"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function banner(tier: string, isNew: boolean)
	local info = Config.Bees[tier]
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -120)
	frame.Size = UDim2.fromOffset(360, 96)
	frame.BackgroundColor3 = if isNew then Color3.fromRGB(255, 236, 170) else C.Cream
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex(info.Look.Stripe)
	stroke.Thickness = 4
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.TextColor3 = C.Text
	title.Text = if isNew then "✨ New bee discovered!" else "Merged!"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 0, 40)
	body.Position = UDim2.fromOffset(10, 48)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextSize = 17
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(140, 100, 60)
	body.Text = ("%s  ·  %.1f 🍯/s"):format(info.Name, info.HoneyPerSecond)
	body.Parent = frame

	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 130) }):Play()
	task.delay(if isNew then 3.5 else 2, function()
		local out = TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -120) })
		out:Play()
		out.Completed:Wait()
		frame:Destroy()
	end)
end

------------------------------------------------------------------------------

BeeMergedRemote.OnClientEvent:Connect(function(plotId: number, _idA: number, _idB: number, _newId: number, tier: string, isNew: boolean)
	local plot = plots:FindFirstChild("Plot" .. plotId)
	local exit = plot and plot:FindFirstChild("BeeExit", true) :: BasePart?
	if exit then
		burst(exit.Position, Color3.fromHex(Config.Bees[tier].Look.Stripe))
	end
	if player:GetAttribute("PlotId") == plotId then
		banner(tier, isNew)
	end
end)
