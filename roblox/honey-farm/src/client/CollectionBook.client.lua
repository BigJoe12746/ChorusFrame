-- Collection book: the ten bee tiers, discovered ones as spinning models with their stats,
-- undiscovered ones as dark silhouettes with a hint on how to get them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local BeeAppearance = require(Shared:WaitForChild("BeeAppearance"))

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BeeTemplate") :: Model

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end
local function stroke(parent: Instance, color: Color3, t: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t
	s.Parent = parent
end
local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = C.Text
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "CollectionBook"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

-- Button: top-right, left of the Upgrades button
local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -170, 0, 6)
toggle.Size = UDim2.fromOffset(120, 54)
toggle.BackgroundColor3 = Color3.fromRGB(190, 150, 255)
toggle.Font = Enum.Font.FredokaOne
toggle.TextColor3 = C.Text
toggle.TextSize = 24
toggle.Text = "📖 Bees"
toggle.Parent = gui
corner(toggle, 16)
stroke(toggle, C.Text, 3)

local panel = Instance.new("Frame")
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.94, 0, 0.86, 0)
panel.BackgroundColor3 = C.Cream
panel.Parent = gui
corner(panel, 18)
stroke(panel, C.Text, 3)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(820, 600)
maxSize.Parent = panel

local _header = text(panel, { Text = "📖 BEE COLLECTION", TextSize = 30, Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(18, 6), TextXAlignment = Enum.TextXAlignment.Left })
local progress = text(panel, { Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -120, 0, 20), Position = UDim2.fromOffset(20, 46), TextXAlignment = Enum.TextXAlignment.Left })
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(46, 46)
close.Position = UDim2.new(1, -56, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(240, 120, 110)
close.Font = Enum.Font.FredokaOne
close.TextSize = 24
close.TextColor3 = C.Text
close.Text = "✕"
close.Parent = panel
corner(close, 12)
stroke(close, C.Text, 2)

local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(14, 72)
grid.Size = UDim2.new(1, -28, 1, -86)
grid.BackgroundTransparency = 1
grid.ScrollBarThickness = 6
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0.5, -6, 0, 150)
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

type Card = { Frame: Frame, Viewport: ViewportFrame, World: WorldModel, Camera: Camera, Model: Model?, Name: TextLabel, Info: TextLabel, Hint: TextLabel, Shown: boolean? }
local cards: { [string]: Card } = {}

for i, tier in Config.BeeOrder do
	local info = Config.Bees[tier]
	local frame = Instance.new("Frame")
	frame.LayoutOrder = i
	frame.BackgroundColor3 = Color3.fromRGB(255, 241, 205)
	frame.Parent = grid
	corner(frame, 14)

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(126, 126)
	vp.Position = UDim2.fromOffset(10, 12)
	vp.BackgroundColor3 = Color3.fromRGB(255, 251, 235)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.Parent = frame
	corner(vp, 10)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = vp

	local nameL = text(frame, { Text = ("#%d  %s"):format(i, info.Name), TextSize = 20, Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(146, 12), TextXAlignment = Enum.TextXAlignment.Left })
	local infoL = text(frame, { Text = "", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -150, 0, 60), Position = UDim2.fromOffset(146, 40), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local hintL = text(frame, { Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(40, 140, 60), Size = UDim2.new(1, -150, 0, 34), Position = UDim2.fromOffset(146, 104), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	cards[tier] = { Frame = frame, Viewport = vp, World = world, Camera = camera, Model = nil, Name = nameL, Info = infoL, Hint = hintL }
end

local function showModel(card: Card, tier: string, silhouette: boolean)
	if card.Model then
		card.Model:Destroy()
		card.Model = nil
	end
	local model = BeeAppearance.Build(template, tier)
	model:ScaleTo(1)
	model:PivotTo(CFrame.new())
	if silhouette then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(60, 50, 45)
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = math.max(d.Transparency, 0.1)
			elseif d:IsA("PointLight") then
				d:Destroy()
			end
		end
	end
	model.Parent = card.World
	card.Model = model
	local _, size = model:GetBoundingBox()
	local r = size.Magnitude * 0.9
	card.Camera.CFrame = CFrame.lookAt(Vector3.new(r * 0.8, r * 0.45, r * 0.8), Vector3.zero)
end

local function discoveredSet(): { [string]: boolean }
	local id = player:GetAttribute("PlotId")
	local plot = id and plots:FindFirstChild("Plot" .. id)
	local set = {}
	for tier in string.gmatch((plot and plot:GetAttribute("Discovered") :: string?) or "", "%a+") do
		set[tier] = true
	end
	return set
end

local function refresh()
	local found = discoveredSet()
	local n = 0
	for i, tier in Config.BeeOrder do
		local info = Config.Bees[tier]
		local card = cards[tier]
		local has = found[tier] == true
		if has then
			n += 1
		end
		local wantSilhouette = not has
		if card.Shown == nil or card.Shown ~= has then
			showModel(card, tier, wantSilhouette)
			card.Shown = has
		end
		card.Frame.BackgroundColor3 = if has then Color3.fromRGB(255, 241, 205) else Color3.fromRGB(226, 220, 205)
		card.Name.Text = if has then ("#%d  %s"):format(i, info.Name) else ("#%d  ???"):format(i)
		local rate = info.HoneyPerSecond
		card.Info.Text = if has then ("%s\n%s honey/s"):format(info.Description, if rate < 10 then ("%.1f"):format(rate) else ("%d"):format(rate)) else "Not discovered yet."
		local prev = Config.BeeOrder[i - 1]
		card.Hint.Text = if has then "" elseif prev then ("Merge two %ss to find it."):format(Config.Bees[prev].Name) else "Buy one in the Bee Shop."
	end
	progress.Text = ("%d of %d bees discovered"):format(n, #Config.BeeOrder)
end

-- gentle spin for the visible models
local angle = 0
RunService.RenderStepped:Connect(function(dt)
	if not panel.Visible then
		return
	end
	angle += dt * 0.7
	for _, card in cards do
		if card.Model then
			card.Model:PivotTo(CFrame.Angles(0, angle, 0))
		end
	end
end)

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		refresh()
		panel.Size = UDim2.new(0.8, 0, 0.7, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.new(0.94, 0, 0.86, 0) }):Play()
	end
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	elseif input.KeyCode == Enum.KeyCode.B then
		setOpen(not panel.Visible)
	end
end)

local function watchPlot()
	local id = player:GetAttribute("PlotId")
	local plot = id and plots:FindFirstChild("Plot" .. id)
	if plot then
		plot:GetAttributeChangedSignal("Discovered"):Connect(function()
			if panel.Visible then
				refresh()
			end
		end)
	end
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
watchPlot()
