-- Collection book: the fifty bee tiers, discoveries, base income, and merge progression.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local BeeAppearance = require(Shared:WaitForChild("BeeAppearance"))
local VariantBees = require(Shared:WaitForChild("VariantBees"))

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BeeTemplate") :: Model
local gui = Instance.new("ScreenGui")
gui.Name = "CollectionBook"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function border(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end
local function makeText(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, textSize: number, z: number, alignment: Enum.TextXAlignment?)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Config.UI.Font
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = value
	label.Size = size
	label.Position = position
	label.ZIndex = z
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = if textSize >= 22 then 3 else 2.5
	outline.Parent = label
	return label
end
local function buildFace(base: GuiObject, color: Color3, height: number, tile: number, flat: boolean?)
	local face = Instance.new("Frame")
	face.BackgroundColor3 = if flat then color else Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, height, 0)
	face.ZIndex = base.ZIndex + 1
	face.Parent = base
	if not flat then
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		gradient.Parent = face
	end
	local pattern = Instance.new("ImageLabel")
	pattern.BackgroundTransparency = 1
	pattern.Image = "rbxassetid://92521981645530"
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(tile, tile)
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.ZIndex = base.ZIndex + 2
	pattern.Parent = face
	return face
end
local function makeButton(parent: Instance, name: string, value: string, color: Color3, position: UDim2, size: UDim2)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.ZIndex = 5
	button.Parent = parent
	border(button, 4)
	local face = buildFace(button, color, 0.9, math.max(40, math.floor(size.Y.Offset * 0.9 + 0.5)))
	makeText(face, "Label", value, UDim2.new(0.92, 0, 0.62, 0), UDim2.fromScale(0.04, 0.12), Config.UI.ButtonSize, face.ZIndex + 2, Enum.TextXAlignment.Center)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local function scaleTo(target: number)
		TweenService:Create(scale, tweenInfo, { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function() scaleTo(1.06) end)
	button.MouseLeave:Connect(function() scaleTo(1) end)
	button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
	button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
	return button
end

local toggle = makeButton(gui, "BeeIndexButton", "BEES", Color3.fromRGB(155, 92, 215), Config.UI.LauncherPosition(1), Config.UI.LauncherSize())
toggle.AnchorPoint = Vector2.new(1, 0)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.86, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 1
panel.Parent = gui
border(panel, 4)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MinSize = Vector2.new(540, 450)
panelLimit.MaxSize = Vector2.new(1020, 820)
panelLimit.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.BackgroundColor3 = Color3.fromRGB(112, 67, 157)
titleBar.BorderSizePixel = 0
titleBar.Size = UDim2.new(1, 0, 0, 58)
titleBar.ZIndex = 3
titleBar.Parent = panel
border(titleBar, 4)
local titleFace = buildFace(titleBar, Color3.fromRGB(112, 67, 157), 0.88, 76, true)
makeText(titleFace, "Title", "BEE COLLECTION", UDim2.new(0.74, 0, 0.7, 0), UDim2.new(0, 18, 0.12, 0), Config.UI.TitleSize, 6)
local close = makeButton(titleBar, "Close", "X", Color3.fromRGB(239, 28, 28), UDim2.new(1, -54, 0.5, -22), UDim2.fromOffset(46, 44))

local summary = Instance.new("Frame")
summary.Name = "Summary"
summary.BackgroundColor3 = Color3.fromRGB(61, 41, 87)
summary.BorderSizePixel = 0
summary.Position = UDim2.fromOffset(14, 68)
summary.Size = UDim2.new(1, -28, 0, 62)
summary.ZIndex = 3
summary.Parent = panel
border(summary, 4)
local summaryFace = buildFace(summary, Color3.fromRGB(115, 81, 154), 0.94, 48)
local progress = makeText(summaryFace, "Progress", "0 / 50 BEES", UDim2.new(0.48, -18, 0, 26), UDim2.fromOffset(12, 4), 18, 6)
local economics = makeText(summaryFace, "Economy", "Rebirth x1.00  ·  next x1.75 at $500", UDim2.new(0.48, -18, 0, 24), UDim2.fromOffset(12, 31), 14, 6)
local recommendation = makeText(summaryFace, "NextSpend", "", UDim2.new(0.48, -18, 0, 45), UDim2.new(0.51, 6, 0, 7), 14, 6)

-- Tabs: merge ladder | egg bees
local tabTiers = makeButton(panel, "TabTiers", "MERGE LADDER", Color3.fromRGB(155, 92, 215), UDim2.fromOffset(14, 138), UDim2.fromOffset(190, Config.UI.TabHeight))
local tabVariants = makeButton(panel, "TabEggs", "EGG BEES", Color3.fromRGB(110, 110, 120), UDim2.fromOffset(212, 138), UDim2.fromOffset(190, Config.UI.TabHeight))

local grid = Instance.new("ScrollingFrame")
grid.Name = "BeeGrid"
grid.Position = UDim2.fromOffset(14, 138 + Config.UI.TabHeight + 10)
grid.Size = UDim2.new(1, -28, 1, -(138 + Config.UI.TabHeight + 24))
grid.BackgroundColor3 = Color3.fromRGB(34, 24, 47)
grid.BackgroundTransparency = 0.12
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.ZIndex = 3
grid.Parent = panel
border(grid, 4)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -14, 0, 156)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

type Card = { Base: Frame, Face: Frame, Viewport: ViewportFrame, Camera: Camera, Model: Model?, Name: TextLabel, Info: TextLabel, Hint: TextLabel, Shown: boolean? }
local cards: { [string]: Card } = {}
local beeColors = { Color3.fromRGB(255, 190, 40), Color3.fromRGB(140, 205, 110), Color3.fromRGB(110, 175, 235), Color3.fromRGB(235, 130, 110), Color3.fromRGB(185, 145, 235) }

for index, tier in Config.BeeOrder do
	local info = Config.Bees[tier]
	local base = Instance.new("Frame")
	base.Name = "BeeCard_" .. tier
	base.LayoutOrder = index
	base.BackgroundColor3 = Color3.fromRGB(69, 47, 87)
	base.BorderSizePixel = 0
	base.ZIndex = 4
	base.Parent = grid
	border(base, 4)
	local face = buildFace(base, beeColors[(index - 1) % #beeColors + 1], 0.94, 76)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "BeeArt"
	viewport.Size = UDim2.fromOffset(112, 112)
	viewport.Position = UDim2.fromOffset(8, 12)
	viewport.BackgroundColor3 = Color3.fromRGB(235, 226, 247)
	viewport.BackgroundTransparency = 0.06
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.ZIndex = 7
	viewport.Parent = face
	border(viewport, 2)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local name = makeText(face, "Name", ("#%02d  %s"):format(index, info.Name), UDim2.new(1, -136, 0, 24), UDim2.fromOffset(128, 8), 17, 7)
	local _rate = makeText(face, "Income", "", UDim2.new(1, -136, 0, 22), UDim2.fromOffset(128, 37), 14, 7)
	local infoLabel = makeText(face, "Description", "", UDim2.new(1, -136, 0, 41), UDim2.fromOffset(128, 61), 12, 7)
	local hint = makeText(face, "Progression", "", UDim2.new(1, -18, 0, 34), UDim2.fromOffset(10, 118), 12, 7)
	cards[tier] = { Base = base, Face = face, Viewport = viewport, Camera = camera, Model = nil, Name = name, Info = infoLabel, Hint = hint }
end

-- Egg-bee list: compact rows grouped by rarity
local variantList = Instance.new("ScrollingFrame")
variantList.Name = "EggBees"
variantList.Visible = false
variantList.Position = UDim2.fromOffset(14, 178)
variantList.Size = UDim2.new(1, -28, 1, -192)
variantList.BackgroundColor3 = Color3.fromRGB(34, 24, 47)
variantList.BackgroundTransparency = 0.12
variantList.BorderSizePixel = 0
variantList.ScrollBarThickness = 8
variantList.CanvasSize = UDim2.new()
variantList.AutomaticCanvasSize = Enum.AutomaticSize.Y
variantList.ZIndex = 3
variantList.Parent = panel
border(variantList, 4)
local vLayout = Instance.new("UIGridLayout")
vLayout.CellSize = UDim2.new(0.5, -14, 0, 44)
vLayout.CellPadding = UDim2.fromOffset(8, 8)
vLayout.SortOrder = Enum.SortOrder.LayoutOrder
vLayout.Parent = variantList
local vPad = Instance.new("UIPadding")
vPad.PaddingTop = UDim.new(0, 8)
vPad.PaddingLeft = UDim.new(0, 8)
vPad.PaddingRight = UDim.new(0, 8)
vPad.Parent = variantList
local variantRows: { [number]: TextLabel } = {}
local rarityRank: { [string]: number } = {}
for i, r in VariantBees.Rarities do
	rarityRank[r.Name] = i
end
for _, v in VariantBees.List do
	local row = makeText(variantList, "V" .. v.Id, "", UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), 14, 4, Enum.TextXAlignment.Left)
	row.LayoutOrder = rarityRank[v.Rarity] * 100 + v.Id
	row.BackgroundTransparency = 0
	row.BackgroundColor3 = Color3.fromRGB(70, 60, 85)
	row.BorderSizePixel = 0
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.Parent = row
	local tag = Instance.new("Frame")
	tag.Size = UDim2.new(0, 6, 1, 0)
	tag.Position = UDim2.fromOffset(-14, 0)
	tag.BackgroundColor3 = Color3.fromHex(VariantBees.RarityColor(v.Rarity))
	tag.BorderSizePixel = 0
	tag.ZIndex = 5
	tag.Parent = row
	variantRows[v.Id] = row
end

local function showTab(variants: boolean)
	grid.Visible = not variants
	variantList.Visible = variants
	tabTiers.BackgroundColor3 = (if variants then Color3.fromRGB(110, 110, 120) else Color3.fromRGB(155, 92, 215)):Lerp(Color3.new(0, 0, 0), 0.35)
	tabVariants.BackgroundColor3 = (if variants then Color3.fromRGB(155, 92, 215) else Color3.fromRGB(110, 110, 120)):Lerp(Color3.new(0, 0, 0), 0.35)
end
tabTiers.Activated:Connect(function()
	showTab(false)
end)
tabVariants.Activated:Connect(function()
	showTab(true)
end)

local function showModel(card: Card, tier: string, silhouette: boolean)
	if card.Model then card.Model:Destroy(); card.Model = nil end
	local model = BeeAppearance.Build(template, tier)
	model:ScaleTo(1)
	model:PivotTo(CFrame.new())
	if silhouette then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(54, 48, 63)
				descendant.Material = Enum.Material.SmoothPlastic
				descendant.Transparency = math.max(descendant.Transparency, 0.15)
			elseif descendant:IsA("PointLight") then
				descendant:Destroy()
			end
		end
	end
	model.Parent = card.Viewport:FindFirstChildOfClass("WorldModel")
	card.Model = model
	local _, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.85
	card.Camera.CFrame = CFrame.lookAt(Vector3.new(radius * 0.8, radius * 0.45, radius * 0.8), Vector3.zero)
end
local function plotAndDiscoveries(): (Instance?, { [string]: boolean })
	local plotId = player:GetAttribute("PlotId")
	local plot = plotId and plots:FindFirstChild("Plot" .. plotId) or nil
	local discovered = {}
	for key in string.gmatch((plot and plot:GetAttribute("Discovered") :: string?) or "", "[%w%*]+") do discovered[key] = true end
	return plot, discovered
end
local function refresh()
	local _plot, discovered = plotAndDiscoveries()
	local count = 0
	for index, tier in Config.BeeOrder do
		local card = cards[tier]
		local info = Config.Bees[tier]
		local found = discovered[tier] == true
		if found then count += 1 end
		if card.Shown ~= found then
			showModel(card, tier, not found)
			card.Shown = found
		end
		card.Name.Text = if found then ("#%02d  %s"):format(index, info.Name) else ("#%02d  ???"):format(index)
		local income = Config.Progression.PotentialCashPerSecond(info.HoneyPerSecond, 1, 1)
		card.Info.Text = if found then (info.Description .. (if discovered[tier .. "*"] then "  ✨ shiny found!" else "")) else "Not discovered yet"
		card.Hint.Text = if index == 1 then ("BASE ≈$%s / sec · buy in Bee Shop"):format(Config.Progression.FormattedNumber(income)) else ("BASE ≈$%s / sec · merge two %s"):format(Config.Progression.FormattedNumber(income), Config.Bees[Config.BeeOrder[index - 1]].Name)
		local rateLabel = card.Face:FindFirstChild("Income") :: TextLabel
		rateLabel.Text = if found then ("%.2f honey/s · ≈$%s/s"):format(info.HoneyPerSecond, Config.Progression.FormattedNumber(income)) else "LOCKED · undiscovered"
		card.Face.BackgroundColor3 = if found then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 170)
	end
	local vFound = 0
	for _, v in VariantBees.List do
		local row = variantRows[v.Id]
		local hasV = discovered["V" .. v.Id] == true
		if hasV then
			vFound += 1
		end
		row.Text = if hasV then ("%s  ·  %s  ·  %s honey/s"):format(v.Name, v.Rarity, if v.HoneyPerSecond < 10 then ("%.1f"):format(v.HoneyPerSecond) else Config.Progression.FormattedNumber(v.HoneyPerSecond)) else ("???  ·  %s egg bee"):format(v.Rarity)
		row.TextColor3 = if hasV then Color3.new(1, 1, 1) else Color3.fromRGB(170, 165, 185)
		row.BackgroundColor3 = if hasV then Color3.fromRGB(95, 70, 130) else Color3.fromRGB(70, 60, 85)
	end
	progress.Text = ("%d / %d ladder  ·  %d / %d egg bees"):format(count, #Config.BeeOrder, vFound, #VariantBees.List)
	local rebirths = player:GetAttribute("Rebirths") or 0
	local multiplier = player:GetAttribute("RebirthMultiplier") or Config.Progression.RebirthMultiplier(rebirths)
	local cost = player:GetAttribute("RebirthCost") or Config.Progression.RebirthCost(rebirths)
	economics.Text = ("Rebirth x%.2f  ·  next x%.2f at %s"):format(multiplier, Config.Progression.NextRebirthMultiplier(rebirths), "$" .. Config.Progression.FormattedNumber(cost))
	local cash = player:GetAttribute("Cash") or 0
	local spend = player:GetAttribute("RecommendedSpend") or "Bee"
	local spendCost = player:GetAttribute("RecommendedSpendCost") or Config.Economy.BeeBasePrice
	recommendation.Text = ("CASH $%s\nNEXT: %s · $%s"):format(Config.Progression.FormattedNumber(cash), spend, Config.Progression.FormattedNumber(spendCost))
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then refresh() end
end
toggle.Activated:Connect(function() setOpen(not panel.Visible) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then setOpen(not panel.Visible) end
end)
for _, attribute in { "Cash", "Rebirths", "RebirthMultiplier", "RebirthCost", "RecommendedSpend", "RecommendedSpendCost", "PlotId" } do
	player:GetAttributeChangedSignal(attribute):Connect(function() if panel.Visible then refresh() end end)
end
local activePlot: Instance? = nil
local plotConnections: { RBXScriptConnection } = {}
local function watchPlot()
	for _, connection in plotConnections do connection:Disconnect() end
	table.clear(plotConnections)
	activePlot = select(1, plotAndDiscoveries())
	if activePlot then
		table.insert(plotConnections, activePlot:GetAttributeChangedSignal("Discovered"):Connect(function() if panel.Visible then refresh() end end))
	end
	if panel.Visible then refresh() end
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
watchPlot()
local angle = 0
RunService.RenderStepped:Connect(function(dt)
	if not panel.Visible then return end
	angle += dt * 0.55
	for _, card in cards do
		if card.Model and card.Model.Parent then card.Model:PivotTo(CFrame.Angles(0, angle, 0)) end
	end
end)
