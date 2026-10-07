-- Bee Shop UI: buy Starter Bees, see your bees, and merge two of the same tier.
-- Opens when the owner presses E / taps at their Bee Shop. Closes with the X,
-- the Escape key, or by walking away. All prices and rules are enforced by the server;
-- this file only displays and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local BeeAppearance = require(Shared:WaitForChild("BeeAppearance"))
local VariantBees = require(Shared:WaitForChild("VariantBees"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenShopRemote = Remotes:WaitForChild("OpenShop") :: RemoteEvent
local ShopActionRemote = Remotes:WaitForChild("ShopAction") :: RemoteEvent

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BeeTemplate") :: Model

local STUD = "rbxassetid://92521981645530"
local HONEY = Color3.fromRGB(255, 176, 42)
local CREAM = Color3.fromRGB(255, 214, 120)
local GREEN = Color3.fromRGB(78, 196, 72)
local PRESS_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

------------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------------

local function border(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function glyph(parent: Instance, value: string, size: UDim2, position: UDim2, textSize: number, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = value
	label.Size = size
	label.Position = position
	label.ZIndex = 8
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = if textSize >= 22 then 3 else 2.5
	outline.Parent = label
	return label
end

local function buildFace(base: GuiObject, color: Color3, height: number, tile: number, flat: boolean?): Frame
	local face = Instance.new("Frame")
	face.Name = "Face"
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
	pattern.Name = "Studs"
	pattern.BackgroundTransparency = 1
	pattern.Image = STUD
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(tile, tile)
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.ZIndex = base.ZIndex + 2
	pattern.Parent = face
	return face
end

local function addPressFeedback(button: TextButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function scaleTo(target: number)
		TweenService:Create(scale, PRESS_TWEEN, { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function() scaleTo(1.06) end)
	button.MouseLeave:Connect(function() scaleTo(1) end)
	button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
	button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
end

local function makeButton(parent: Instance, name: string, label: string, color: Color3, position: UDim2, size: UDim2): TextButton
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
	glyph(face, label, UDim2.new(0.9, 0, 0.62, 0), UDim2.fromScale(0.05, 0.14), 20, Enum.TextXAlignment.Center)
	addPressFeedback(button)
	return button
end

-- Shows a bee model of `tier` spinning slowly in a ViewportFrame.
local function beeViewport(parent: Instance, size: UDim2, position: UDim2): (ViewportFrame, (string?) -> ())
	local vp = Instance.new("ViewportFrame")
	vp.Size = size
	vp.Position = position
	vp.BackgroundColor3 = Color3.fromRGB(255, 236, 190)
	vp.BackgroundTransparency = 0.05
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.ZIndex = 7
	vp.Parent = parent
	border(vp, 3)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local current: Model? = nil
	local angle = 0

	-- key: a tier ("Clover"), a shiny tier ("Clover*") or an egg bee ("V12")
	local function show(key: string?)
		if current then
			current:Destroy()
			current = nil
		end
		if not key then
			return
		end
		local vid = key:match("^V(%d+)$")
		local model
		if vid then
			model = BeeAppearance.BuildVariant(template, VariantBees.Get(tonumber(vid) :: number))
		else
			model = BeeAppearance.Build(template, (key:gsub("%*$", "")), key:sub(-1) == "*")
		end
		model:ScaleTo(1)
		model:PivotTo(CFrame.new())
		model.Parent = world
		current = model
		local _, boxSize = model:GetBoundingBox()
		local radius = boxSize.Magnitude * 0.9
		camera.CFrame = CFrame.lookAt(Vector3.new(radius * 0.8, radius * 0.45, radius * 0.8), Vector3.new(0, 0, 0))
	end

	RunService.RenderStepped:Connect(function(dt)
		if current and current.Parent and vp.Visible then
			angle += dt * 0.8
			current:PivotTo(CFrame.Angles(0, angle, 0))
		end
	end)
	return vp, show
end

------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "BeeShop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0.82, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Parent = gui
border(panel, 4)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(860, 620)
maxSize.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.BackgroundColor3 = Color3.fromRGB(168, 92, 18)
titleBar.BorderSizePixel = 0
titleBar.Size = UDim2.new(1, 0, 0, 58)
titleBar.ZIndex = 2
titleBar.Parent = panel
border(titleBar, 4)
local titleFace = buildFace(titleBar, Color3.fromRGB(168, 92, 18), 0.88, 76, true)
local basket = Instance.new("ImageLabel")
basket.Name = "Basket"
basket.BackgroundTransparency = 1
basket.Image = "rbxassetid://110972987269284"
basket.ScaleType = Enum.ScaleType.Fit
basket.Size = UDim2.fromOffset(42, 42)
basket.Position = UDim2.fromOffset(12, 5)
basket.ZIndex = 8
basket.Parent = titleFace
local basketAspect = Instance.new("UIAspectRatioConstraint")
basketAspect.AspectRatio = 1
basketAspect.Parent = basket
glyph(titleFace, "BEE SHOP", UDim2.new(0.62, 0, 0.68, 0), UDim2.fromOffset(64, 8), 26)
local close = makeButton(titleBar, "Close", "X", Color3.fromRGB(239, 28, 28), UDim2.new(1, -54, 0.5, -21), UDim2.fromOffset(42, 42))

-- Left: buy
local left = Instance.new("Frame")
left.Name = "BuyPane"
left.Position = UDim2.fromOffset(14, 72)
left.Size = UDim2.new(0.38, -20, 1, -86)
left.BackgroundColor3 = HONEY:Lerp(Color3.new(0, 0, 0), 0.45)
left.BorderSizePixel = 0
left.ZIndex = 2
left.Parent = panel
border(left, 4)
local leftFace = buildFace(left, HONEY, 0.94, 72)
local _, showShopBee = beeViewport(leftFace, UDim2.new(1, -24, 0, 112), UDim2.fromOffset(12, 10))
local nameLabel = glyph(leftFace, "Starter Bee", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 128), 20)
local rateLabel = glyph(leftFace, "", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 158), 16)
rateLabel.TextYAlignment = Enum.TextYAlignment.Top
local slotsLabel = glyph(leftFace, "", UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 196), 16)
slotsLabel.TextYAlignment = Enum.TextYAlignment.Top
local buyButton = makeButton(left, "Buy", "BUY", GREEN, UDim2.new(0, 12, 1, -64), UDim2.new(1, -24, 0, 50))

-- Eggs: one button per egg with its honest odds underneath (weights shown as percentages)
local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Name = "Eggs"
eggScroll.Position = UDim2.fromOffset(12, 240)
eggScroll.Size = UDim2.new(1, -24, 1, -240 - 70)
eggScroll.BackgroundTransparency = 1
eggScroll.BorderSizePixel = 0
eggScroll.ScrollBarThickness = 6
eggScroll.CanvasSize = UDim2.new()
eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggScroll.ZIndex = 7
eggScroll.Parent = leftFace
local eggLayout = Instance.new("UIListLayout")
eggLayout.Padding = UDim.new(0, 6)
eggLayout.SortOrder = Enum.SortOrder.LayoutOrder
eggLayout.Parent = eggScroll
local eggButtons: { [string]: TextButton } = {}
for order, eggName in Config.Eggs.Order do
	local egg = Config.Eggs[eggName]
	local holder = Instance.new("Frame")
	holder.Name = eggName
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, -8, 0, 44 + 15 * #egg.Odds)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 7
	holder.Parent = eggScroll
	local b = makeButton(holder, "Hatch", ("%s %s  $%s"):format(egg.Icon, egg.Name, Config.Progression.FormattedNumber(egg.Price)), Color3.fromHex(egg.Color), UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 40))
	local total = 0
	for _, o in egg.Odds do
		total += o.Weight
	end
	local lines = {}
	for _, o in egg.Odds do
		local pct = o.Weight / total * 100
		local label = if Config.Bees[o.Kind] then Config.Bees[o.Kind].Name else (o.Kind .. " egg bee")
		table.insert(lines, ("%s  %s"):format(if pct < 1 then ("%.1f%%"):format(pct) else ("%d%%"):format(math.floor(pct + 0.5)), label))
	end
	local odds = glyph(holder, table.concat(lines, "\n"), UDim2.new(1, 0, 0, 15 * #egg.Odds), UDim2.fromOffset(4, 42), 12)
	odds.TextYAlignment = Enum.TextYAlignment.Top
	eggButtons[eggName] = b
end

-- Right: my bees + merge
local right = Instance.new("Frame")
right.Name = "MyBees"
right.Position = UDim2.new(0.38, 8, 0, 72)
right.Size = UDim2.new(0.62, -22, 1, -86)
right.BackgroundTransparency = 1
right.ZIndex = 2
right.Parent = panel
glyph(right, "MY BEES", UDim2.new(0.42, 0, 0, 26), UDim2.fromOffset(2, 0), 20)
glyph(right, "tap two matching bees to merge", UDim2.new(0.56, 0, 0, 26), UDim2.new(0.44, 0, 0, 0), 16, Enum.TextXAlignment.Right)

local grid = Instance.new("ScrollingFrame")
grid.Name = "BeeGrid"
grid.Position = UDim2.fromOffset(0, 32)
grid.Size = UDim2.new(1, 0, 1, -176)
grid.BackgroundColor3 = Color3.fromRGB(92, 52, 16)
grid.BackgroundTransparency = 0.15
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ZIndex = 3
grid.Parent = right
border(grid, 3)
local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 8)
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.PaddingLeft = UDim.new(0, 8)
gridPad.PaddingRight = UDim.new(0, 8)
gridPad.Parent = grid
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -6, 0, 64)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local preview = Instance.new("Frame")
preview.Name = "MergePreview"
preview.AnchorPoint = Vector2.new(0, 1)
preview.Position = UDim2.new(0, 0, 1, 0)
preview.Size = UDim2.new(1, 0, 0, 136)
preview.BackgroundColor3 = CREAM:Lerp(Color3.new(0, 0, 0), 0.4)
preview.BorderSizePixel = 0
preview.ZIndex = 3
preview.Parent = right
border(preview, 4)
local previewFace = buildFace(preview, CREAM, 0.94, 64)
local _, showPreviewBee = beeViewport(previewFace, UDim2.fromOffset(112, 112), UDim2.fromOffset(10, 8))
local previewTitle = glyph(previewFace, "Select two bees of the same tier", UDim2.new(1, -138, 0, 48), UDim2.fromOffset(130, 8), 18)
previewTitle.TextYAlignment = Enum.TextYAlignment.Top
local previewBody = glyph(previewFace, "", UDim2.new(1, -138, 0, 40), UDim2.fromOffset(130, 56), 16)
previewBody.TextYAlignment = Enum.TextYAlignment.Top
local mergeButton = makeButton(preview, "Merge", "MERGE", GREEN, UDim2.new(1, -168, 1, -52), UDim2.fromOffset(156, 42))
mergeButton.Visible = false

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local myPlot: Instance? = nil
local selected: { number } = {}
local cards: { [number]: TextButton } = {}
local lastSubmit = 0

type BeeEntry = { Id: number, Key: string, Tier: string, Shiny: boolean, Variant: number? }

-- "3:Clover", "4:Clover*" (shiny), "5:V12" (egg bee #12)
local function parseBees(s: string?): { BeeEntry }
	local out = {}
	for id, key in string.gmatch(s or "", "(%d+):([%w%*]+)") do
		local vid = key:match("^V(%d+)$")
		table.insert(out, {
			Id = tonumber(id) :: number,
			Key = key,
			Tier = if vid then "Variant" else (key:gsub("%*$", "")),
			Shiny = key:sub(-1) == "*",
			Variant = if vid then tonumber(vid) else nil,
		})
	end
	return out
end

local function rateText(r: number): string
	local cashRate = Config.Progression.PotentialCashPerSecond(r, 1, 1)
	local honeyText = if r < 10 then ("%.1f honey/s"):format(r) else ("%s honey/s"):format(Config.Progression.FormattedNumber(r))
	return ("%s  ·  $%s/s"):format(honeyText, Config.Progression.FormattedNumber(cashRate))
end

local function rate(tier: string): string
	return rateText(Config.Bees[tier].HoneyPerSecond)
end

local function entryRate(e: BeeEntry): number
	if e.Variant then
		return VariantBees.Get(e.Variant).HoneyPerSecond
	end
	return Config.Bees[e.Tier].HoneyPerSecond * (if e.Shiny then Config.Economy.ShinyMultiplier else 1)
end

local function entryName(e: BeeEntry): string
	if e.Variant then
		return VariantBees.Get(e.Variant).Name
	end
	return (if e.Shiny then "✨ Shiny " else "") .. Config.Bees[e.Tier].Name
end

local function entryStripe(e: BeeEntry): Color3
	if e.Variant then
		return Color3.fromHex(VariantBees.RarityColor(VariantBees.Get(e.Variant).Rarity))
	end
	return Color3.fromHex(Config.Bees[e.Tier].Look.Stripe)
end

local function tierIndex(tier: string): number
	return table.find(Config.BeeOrder, tier) or 1
end

local function setBuyLabel(label: string, affordable: boolean)
	local face = buyButton:FindFirstChild("Face")
	local word = face and face:FindFirstChildWhichIsA("TextLabel")
	if word then
		word.Text = label
	end
	buyButton.Active = true -- stays clickable: short on cash gives the fail flash instead of a dead click
	buyButton.BackgroundColor3 = (if affordable then GREEN else Color3.fromRGB(120, 120, 120)):Lerp(Color3.new(0, 0, 0), 0.35)
end

-- Shake + red flash when a buy is rejected (short on cash).
local SoundService = game:GetService("SoundService")
local denySound: Sound? = nil
local function playDeny()
	local id = Config.Sounds.Deny
	if not id or id == "" then
		return
	end
	local sound = denySound or Instance.new("Sound")
	denySound = sound
	sound.Name = "DenyBuzz"
	sound.SoundId = id
	sound.Volume = 0.6
	sound.PlaybackSpeed = 0.55
	sound.Parent = SoundService
	sound:Play()
end
local function failFlash(button: TextButton, message: string?)
	playDeny()
	local face = button:FindFirstChild("Face")
	local gradient = face and face:FindFirstChildOfClass("UIGradient")
	local word = face and face:FindFirstChildWhichIsA("TextLabel")
	local originalPosition = button.Position
	local originalColor = button.BackgroundColor3
	local originalGradient = gradient and gradient.Color
	local originalWord = word and word.Text
	if word and message then
		word.Text = message
	end
	if gradient then
		gradient.Color = ColorSequence.new(Color3.fromRGB(255, 92, 92), Color3.fromRGB(146, 16, 16))
	end
	button.BackgroundColor3 = Color3.fromRGB(150, 22, 22)
	task.spawn(function()
		for _, dx in { 7, -7, 5, -5, 3, -3, 0 } do
			local tween = TweenService:Create(button, TweenInfo.new(0.045), { Position = originalPosition + UDim2.new(0, dx, 0, 0) })
			tween:Play()
			tween.Completed:Wait()
		end
		button.Position = originalPosition
		if gradient and originalGradient then
			gradient.Color = originalGradient
		end
		button.BackgroundColor3 = originalColor
		if word and originalWord then
			word.Text = originalWord
		end
	end)
end

local function refreshPreview()
	local bees = parseBees(if myPlot then myPlot:GetAttribute("Bees") :: string? else nil)
	local function find(id)
		for _, b in bees do
			if b.Id == id then
				return b
			end
		end
		return nil
	end
	for id, card in cards do
		local on = table.find(selected, id) ~= nil
		card.BackgroundColor3 = (if on then GREEN else CREAM):Lerp(Color3.new(0, 0, 0), 0.35)
		local face = card:FindFirstChild("Face")
		local gradient = face and face:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), if on then GREEN else CREAM)
		end
	end
	mergeButton.Visible = false
	if #selected == 0 then
		previewTitle.Text = "Select two bees of the same tier"
		previewBody.Text = "Two bees merge into the next tier and make 2.5x the honey."
		showPreviewBee(nil)
		return
	end
	local a = find(selected[1])
	if not a then
		selected = {}
		refreshPreview()
		return
	end
	if a.Variant then
		previewTitle.Text = entryName(a) .. " is one of a kind"
		previewBody.Text = "Egg bees can't be merged. They're yours to keep and show off."
		showPreviewBee(a.Key)
		return
	end
	if #selected == 1 then
		local nextTier = Config.BeeOrder[tierIndex(a.Tier) + 1]
		if nextTier then
			previewTitle.Text = ("Pick another %s"):format(Config.Bees[a.Tier].Name)
			local mergeGain = Config.Progression.TierMergeGain(tierIndex(a.Tier))
			previewBody.Text = ("%s  ·  merge gain x%.2f"):format(Config.Bees[nextTier].Name, mergeGain)
			showPreviewBee(nextTier)
		else
			previewTitle.Text = Config.Bees[a.Tier].Name .. " is the top tier"
			previewBody.Text = "This bee can't be merged any further."
			showPreviewBee(a.Key)
		end
		return
	end
	local b = find(selected[2])
	if b and b.Variant then
		previewTitle.Text = entryName(b) .. " is one of a kind"
		previewBody.Text = "Egg bees can't be merged."
		showPreviewBee(nil)
		return
	end
	if not b or a.Tier ~= b.Tier then
		previewTitle.Text = "Those two don't match"
		previewBody.Text = "Only two bees of the same tier can merge."
		showPreviewBee(nil)
		return
	end
	local nextTier = Config.BeeOrder[tierIndex(a.Tier) + 1]
	if not nextTier then
		previewTitle.Text = "Already the top tier"
		previewBody.Text = "Royal Bees can't be merged."
		showPreviewBee(nil)
		return
	end
	local shinyResult = a.Shiny or b.Shiny
	previewTitle.Text = ("%s + %s → %s%s"):format(Config.Bees[a.Tier].Name, Config.Bees[a.Tier].Name, if shinyResult then "✨ Shiny " else "", Config.Bees[nextTier].Name)
	local mergeGain = Config.Progression.TierMergeGain(tierIndex(a.Tier))
	previewBody.Text = ("Becomes %s  ·  gain x%.2f%s"):format(rateText(Config.Bees[nextTier].HoneyPerSecond * (if shinyResult then Config.Economy.ShinyMultiplier else 1)), mergeGain, if shinyResult then "" else ("  ·  %d%% shiny chance"):format(Config.Economy.ShinyChance * 100))
	showPreviewBee(nextTier .. (if shinyResult then "*" else ""))
	mergeButton.Visible = true
end

local function refresh()
	if not myPlot then
		return
	end
	local price = myPlot:GetAttribute("BeePrice") or Config.Economy.BeeBasePrice
	local nextPrice = Config.Progression.BeePurchaseCost((myPlot:GetAttribute("BeesBought") or 0) :: number)
	local count = myPlot:GetAttribute("BeeCount") or 0
	local slots = myPlot:GetAttribute("BeeSlots") or Config.Economy.BeeSlots
	local cash = player:GetAttribute("Cash") or 0
	local starter = Config.Bees[Config.BeeOrder[1]]
	nameLabel.Text = starter.Name
	setBuyLabel(("BUY  $%s"):format(Config.Progression.FormattedNumber(price)), cash >= price and count < slots)
	rateLabel.Text = ("Makes %s"):format(rate(Config.BeeOrder[1]))
	slotsLabel.Text = ("Slots  %d / %d%s\nNext bee  $%s"):format(count, slots, if count >= slots then "  ·  FULL" else "", Config.Progression.FormattedNumber(nextPrice))
	for eggName, b in eggButtons do
		local ok = cash >= Config.Eggs[eggName].Price and count < slots
		b.BackgroundColor3 = (if ok then Color3.fromHex(Config.Eggs[eggName].Color) else Color3.fromRGB(120, 120, 120)):Lerp(Color3.new(0, 0, 0), 0.35)
	end

	for _, card in cards do
		card:Destroy()
	end
	cards = {}
	local bees = parseBees(myPlot:GetAttribute("Bees") :: string?)
	table.sort(bees, function(x, y)
		local rx, ry = entryRate(x), entryRate(y)
		return if rx ~= ry then rx > ry else x.Id < y.Id
	end)
	for i, bee in bees do
		local card = Instance.new("TextButton")
		card.Name = "Bee_" .. bee.Id
		card.LayoutOrder = i
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = CREAM:Lerp(Color3.new(0, 0, 0), 0.35)
		card.BorderSizePixel = 0
		card.ZIndex = 4
		card.Parent = grid
		border(card, 3)
		local face = buildFace(card, CREAM, 0.94, 48)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 8, 1, 0)
		stripe.BackgroundColor3 = entryStripe(bee)
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 7
		stripe.Parent = face
		glyph(face, entryName(bee), UDim2.new(1, -22, 0, 26), UDim2.fromOffset(16, 6), 16)
		glyph(face, rateText(entryRate(bee)), UDim2.new(1, -22, 0, 22), UDim2.fromOffset(16, 34), 14)
		addPressFeedback(card)
		cards[bee.Id] = card
		card.Activated:Connect(function()
			local at = table.find(selected, bee.Id)
			if at then
				table.remove(selected, at)
			else
				if #selected >= 2 then
					table.remove(selected, 1)
				end
				table.insert(selected, bee.Id)
			end
			refreshPreview()
		end)
	end
	refreshPreview()
end

local function setOpen(open: boolean)
	if gui.Enabled == open then
		return
	end
	gui.Enabled = open
	if open then
		selected = {}
		showShopBee(Config.BeeOrder[1])
		refresh()
		panel.Size = UDim2.new(0.78, 0, 0.68, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.new(0.9, 0, 0.82, 0) }):Play()
	else
		showShopBee(nil)
		showPreviewBee(nil)
	end
end

local function submit(...)
	local now = os.clock()
	if now - lastSubmit < 0.35 then
		return
	end
	lastSubmit = now
	ShopActionRemote:FireServer(...)
end

buyButton.Activated:Connect(function()
	local price = (myPlot and myPlot:GetAttribute("BeePrice")) or Config.Economy.BeeBasePrice
	if (player:GetAttribute("Cash") or 0) < price then
		failFlash(buyButton, ("NEED $%s"):format(Config.Progression.FormattedNumber(price)))
		return
	end
	submit("Buy")
end)
for eggName, b in eggButtons do
	b.Activated:Connect(function()
		submit("Egg", eggName)
	end)
end
mergeButton.Activated:Connect(function()
	if #selected == 2 then
		submit("Merge", selected[1], selected[2])
		selected = {}
	end
end)
close.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		setOpen(false)
	end
end)

OpenShopRemote.OnClientEvent:Connect(function()
	setOpen(true)
end)

local function watchPlot()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	if myPlot then
		for _, key in { "Bees", "BeePrice", "BeesBought", "BeeCount", "BeeSlots" } do
			myPlot:GetAttributeChangedSignal(key):Connect(function()
				if gui.Enabled then
					refresh()
				end
			end)
		end
	end
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
player:GetAttributeChangedSignal("Cash"):Connect(function()
	if gui.Enabled then
		refresh()
	end
end)
watchPlot()

task.spawn(function()
	while true do
		task.wait(0.5)
		if gui.Enabled and myPlot and gui:GetAttribute("StayOpen") ~= true then
			local shop = myPlot:FindFirstChild("BeeShop", true)
			local counter = shop and shop:FindFirstChild("Counter")
			local char = player.Character
			if counter and char and (char:GetPivot().Position - counter.Position).Magnitude > Config.PromptDistance + 6 then
				setOpen(false)
			end
		end
	end
end)

print("[BeeShop] block shop ready")
