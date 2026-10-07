-- Egg hatch: an egg appears at the hive, wobbles, cracks in a burst of the rarity colour,
-- and (for your own farm) a card announces what hatched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local VariantBees = require(Shared:WaitForChild("VariantBees"))
local EggHatchedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EggHatched") :: RemoteEvent

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local fx = Instance.new("Folder")
fx.Name = "HatchFX"
fx.Parent = workspace

local gui = Instance.new("ScreenGui")
gui.Name = "Hatching"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function rarityColor(rarity: string): Color3
	if rarity == "Ladder" then
		return C.Honey
	end
	return Color3.fromHex(VariantBees.RarityColor(rarity))
end

local function eggAt(position: Vector3, color: Color3)
	local egg = Instance.new("Part")
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(2.2, 2.8, 2.2)
	egg.Color = Color3.fromRGB(250, 240, 220)
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.CFrame = CFrame.new(position)
	egg.Parent = fx
	local spots = Instance.new("Part")
	spots.Shape = Enum.PartType.Ball
	spots.Size = Vector3.new(1.2, 1.2, 1.2)
	spots.Color = color
	spots.Material = Enum.Material.SmoothPlastic
	spots.Anchored = true
	spots.CanCollide = false
	spots.CanQuery = false
	spots.CFrame = CFrame.new(position + Vector3.new(0.6, 0.5, 0.6))
	spots.Parent = fx

	-- wobble
	task.spawn(function()
		for i = 1, 6 do
			local a = (if i % 2 == 0 then 1 else -1) * math.rad(14 + i * 3)
			local t = TweenService:Create(egg, TweenInfo.new(0.14, Enum.EasingStyle.Sine), { CFrame = CFrame.new(position) * CFrame.Angles(0, 0, a) })
			t:Play()
			TweenService:Create(spots, TweenInfo.new(0.14, Enum.EasingStyle.Sine), { CFrame = CFrame.new(position) * CFrame.Angles(0, 0, a) * CFrame.new(0.6, 0.5, 0.6) }):Play()
			t.Completed:Wait()
		end
		-- crack: shell pieces fly out
		local rng = Random.new()
		for _ = 1, 10 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.6, 0.6, 0.2)
			p.Color = egg.Color
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CFrame = CFrame.new(position)
			p.Parent = fx
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.5, 1.2), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(3, 5)
			TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(position + dir) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Transparency = 1 }):Play()
			Debris:AddItem(p, 0.7)
		end
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.one
		flash.Color = color
		flash.Material = Enum.Material.Neon
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.CFrame = CFrame.new(position)
		flash.Parent = fx
		TweenService:Create(flash, TweenInfo.new(0.45), { Size = Vector3.one * 8, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.5)
		egg:Destroy()
		spots:Destroy()
	end)
end

local function card(name: string, rarity: string, isNew: boolean)
	local color = rarityColor(rarity)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -130)
	frame.Size = UDim2.fromOffset(380, 100)
	frame.BackgroundColor3 = C.Cream
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 4
	stroke.Parent = frame
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.TextColor3 = C.Text
	title.Text = if isNew then "🥚 New bee hatched!" else "🥚 Hatched!"
	title.Parent = frame
	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 0, 40)
	body.Position = UDim2.fromOffset(10, 50)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextSize = 18
	body.TextColor3 = color
	body.Text = if rarity == "Ladder" then name else ("%s  ·  %s"):format(name, rarity)
	body.Parent = frame
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 130) }):Play()
	task.delay(if isNew then 3.5 else 2.2, function()
		local out = TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -130) })
		out:Play()
		out.Completed:Wait()
		frame:Destroy()
	end)
end

EggHatchedRemote.OnClientEvent:Connect(function(plotId: number, _beeId: number, name: string, rarity: string, isNew: boolean)
	local plot = plots:FindFirstChild("Plot" .. plotId)
	local exit = plot and plot:FindFirstChild("BeeExit", true) :: BasePart?
	if exit then
		eggAt(exit.Position + Vector3.new(0, 1, 0), rarityColor(rarity))
	end
	if player:GetAttribute("PlotId") == plotId then
		task.delay(0.9, card, name, rarity, isNew)
	end
end)
