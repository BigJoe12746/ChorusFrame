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

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BeeTemplate") :: Model

------------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------------

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
	l.TextScaled = false
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end
local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = C.Text
	b.TextSize = 20
	b.AutoButtonColor = true
	b.BackgroundColor3 = C.Honey
	for k, v in props do
		(b :: any)[k] = v
	end
	b.Parent = parent
	corner(b, 12)
	stroke(b, C.Text, 2)
	return b
end

-- Shows a bee model of `tier` spinning slowly in a ViewportFrame.
local function beeViewport(parent: Instance, size: UDim2, position: UDim2): (ViewportFrame, (string?) -> ())
	local vp = Instance.new("ViewportFrame")
	vp.Size = size
	vp.Position = position
	vp.BackgroundColor3 = Color3.fromRGB(255, 251, 235)
	vp.BackgroundTransparency = 0.2
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.Parent = parent
	corner(vp, 10)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local current: Model? = nil
	local angle = 0

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
			local shiny = key:sub(-1) == "*"
			model = BeeAppearance.Build(template, key:gsub("%*$", ""), shiny)
		end
		model:ScaleTo(1) -- viewport has its own scale
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
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.84, 0)
panel.BackgroundColor3 = C.Cream
panel.Parent = gui
corner(panel, 18)
stroke(panel, C.Text, 3)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(760, 520)
maxSize.Parent = panel

text(panel, { Text = "🛒 BEE SHOP", TextSize = 30, Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(18, 6), TextXAlignment = Enum.TextXAlignment.Left })
local close = button(panel, { Text = "✕", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -56, 0, 8), BackgroundColor3 = Color3.fromRGB(240, 120, 110), TextSize = 24 })

-- Left: buy
local leftScroll = Instance.new("ScrollingFrame")
leftScroll.Position = UDim2.new(0, 14, 0, 58)
leftScroll.Size = UDim2.new(0.36, -14, 1, -72)
leftScroll.BackgroundTransparency = 1
leftScroll.ScrollBarThickness = 6
leftScroll.CanvasSize = UDim2.new()
leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
leftScroll.Parent = panel
local leftLayout = Instance.new("UIListLayout")
leftLayout.Padding = UDim.new(0, 8)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Parent = leftScroll

local left = Instance.new("Frame")
left.LayoutOrder = 1
left.Size = UDim2.new(1, -8, 0, 300)
left.BackgroundColor3 = Color3.fromRGB(255, 241, 205)
left.Parent = leftScroll
corner(left, 14)
local _, showShopBee = beeViewport(left, UDim2.new(1, -20, 0, 130), UDim2.fromOffset(10, 10))
text(left, { Text = "Starter Bee", TextSize = 24, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 146) })
local rateLabel = text(left, { Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 176) })
local slotsLabel = text(left, { Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 198) })
local buyButton = button(left, { Text = "Buy  $25", Size = UDim2.new(1, -20, 0, 54), Position = UDim2.new(0, 10, 1, -64), TextSize = 24 })

-- Egg cards with honest odds
local eggButtons: { [string]: TextButton } = {}
for order, eggName in Config.Eggs.Order do
	local egg = Config.Eggs[eggName]
	local card = Instance.new("Frame")
	card.LayoutOrder = 1 + order
	card.Size = UDim2.new(1, -8, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromHex(egg.Color)
	card.Parent = leftScroll
	corner(card, 14)
	local cpad = Instance.new("UIPadding")
	cpad.PaddingTop = UDim.new(0, 10)
	cpad.PaddingBottom = UDim.new(0, 10)
	cpad.PaddingLeft = UDim.new(0, 10)
	cpad.PaddingRight = UDim.new(0, 10)
	cpad.Parent = card
	local clayout = Instance.new("UIListLayout")
	clayout.Padding = UDim.new(0, 4)
	clayout.SortOrder = Enum.SortOrder.LayoutOrder
	clayout.Parent = card
	text(card, { LayoutOrder = 1, Text = ("%s %s"):format(egg.Icon, egg.Name), TextSize = 22, Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
	-- odds, highest first, as the player will see them
	local total = 0
	for _, o in egg.Odds do
		total += o.Weight
	end
	local lines = {}
	for _, o in egg.Odds do
		local pct = o.Weight / total * 100
		local label = if Config.Bees[o.Kind] then Config.Bees[o.Kind].Name else (o.Kind .. " rare bee")
		table.insert(lines, ("%s  %s"):format(if pct < 1 then ("%.1f%%"):format(pct) else ("%d%%"):format(math.floor(pct + 0.5)), label))
	end
	text(card, { LayoutOrder = 2, Text = table.concat(lines, "\n"), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(90, 70, 50), Size = UDim2.new(1, 0, 0, 16 * #lines), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local b = button(card, { LayoutOrder = 3, Text = ("Hatch  $%d"):format(egg.Price), Size = UDim2.new(1, 0, 0, 48), TextSize = 20 })
	eggButtons[eggName] = b
end

-- Right: my bees + merge
local right = Instance.new("Frame")
right.Position = UDim2.new(0.36, 14, 0, 58)
right.Size = UDim2.new(0.64, -28, 1, -72)
right.BackgroundTransparency = 1
right.Parent = panel
text(right, { Text = "MY BEES  ·  tap two of the same tier to merge", TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(0, 24)
grid.Size = UDim2.new(1, 0, 1, -24 - 150)
grid.BackgroundTransparency = 1
grid.ScrollBarThickness = 6
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.Parent = right
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -6, 0, 58)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

-- Merge preview
local preview = Instance.new("Frame")
preview.AnchorPoint = Vector2.new(0, 1)
preview.Position = UDim2.new(0, 0, 1, 0)
preview.Size = UDim2.new(1, 0, 0, 142)
preview.BackgroundColor3 = Color3.fromRGB(255, 241, 205)
preview.Parent = right
corner(preview, 14)
local _, showPreviewBee = beeViewport(preview, UDim2.fromOffset(122, 122), UDim2.fromOffset(10, 10))
local previewTitle = text(preview, { Text = "Select two bees of the same tier", TextSize = 20, Size = UDim2.new(1, -150, 0, 48), Position = UDim2.fromOffset(142, 8), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
local previewBody = text(preview, { Text = "", TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -150, 0, 40), Position = UDim2.fromOffset(142, 52), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
local mergeButton = button(preview, { Text = "Merge!", Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -160, 1, -54), BackgroundColor3 = Color3.fromRGB(150, 220, 120), TextSize = 22, Visible = false })

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
		local shiny = key:sub(-1) == "*"
		table.insert(out, {
			Id = tonumber(id) :: number,
			Key = key,
			Tier = if vid then "Variant" else key:gsub("%*$", ""),
			Shiny = shiny,
			Variant = if vid then tonumber(vid) else nil,
		})
	end
	return out
end

local function fmtRate(r: number): string
	return if r < 10 then ("%.1f 🍯/s"):format(r) else ("%d 🍯/s"):format(r)
end

local function rate(tier: string): string
	return fmtRate(Config.Bees[tier].HoneyPerSecond)
end

local function entryName(e: BeeEntry): string
	if e.Variant then
		return VariantBees.Get(e.Variant).Name
	end
	return (if e.Shiny then "✨ Shiny " else "") .. Config.Bees[e.Tier].Name
end

local function entryRate(e: BeeEntry): number
	if e.Variant then
		return VariantBees.Get(e.Variant).HoneyPerSecond
	end
	return Config.Bees[e.Tier].HoneyPerSecond * (if e.Shiny then Config.Economy.ShinyMultiplier else 1)
end

local function tierIndex(tier: string): number
	return table.find(Config.BeeOrder, tier) or 1
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
		card.BackgroundColor3 = if on then Color3.fromRGB(150, 220, 120) else Color3.fromRGB(255, 241, 205)
	end
	mergeButton.Visible = false
	if #selected == 0 then
		previewTitle.Text = "Select two bees of the same tier"
		previewBody.Text = "Two bees merge into one bee of the next tier that makes 2.5× the honey."
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
			previewBody.Text = ("→ %s (%s)"):format(Config.Bees[nextTier].Name, rate(nextTier))
			showPreviewBee(nextTier)
		else
			previewTitle.Text = Config.Bees[a.Tier].Name .. " is the top tier"
			previewBody.Text = "Royal Bees can't be merged any further."
			showPreviewBee(a.Tier)
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
	previewBody.Text = ("%s each → %s. %s%s"):format(fmtRate(entryRate(a)), fmtRate(Config.Bees[nextTier].HoneyPerSecond * (if shinyResult then Config.Economy.ShinyMultiplier else 1)), Config.Bees[nextTier].Description, if shinyResult then "" else (" %d%% chance of a shiny!"):format(Config.Economy.ShinyChance * 100))
	showPreviewBee(nextTier .. (if shinyResult then "*" else ""))
	mergeButton.Visible = true
end

local function refresh()
	if not myPlot then
		return
	end
	local price = myPlot:GetAttribute("BeePrice") or Config.Economy.BeeBasePrice
	local count = myPlot:GetAttribute("BeeCount") or 0
	local slots = myPlot:GetAttribute("BeeSlots") or Config.Economy.BeeSlots
	local cash = player:GetAttribute("Cash") or 0
	buyButton.Text = ("Buy  $%d"):format(price)
	local canBuy = cash >= price and count < slots
	buyButton.BackgroundColor3 = if canBuy then C.Honey else Color3.fromRGB(215, 205, 185)
	for eggName, b in eggButtons do
		local ok = cash >= Config.Eggs[eggName].Price and count < slots
		b.BackgroundColor3 = if ok then C.Honey else Color3.fromRGB(215, 205, 185)
	end
	rateLabel.Text = "Makes " .. rate(Config.BeeOrder[1])
	slotsLabel.Text = ("Bee slots: %d / %d%s"):format(count, slots, if count >= slots then "  (full — merge!)" else "")

	-- bee cards
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
		local card = button(grid, {
			LayoutOrder = i,
			Text = ("%s\n%s"):format(entryName(bee), fmtRate(entryRate(bee))),
			TextSize = 16,
			BackgroundColor3 = Color3.fromRGB(255, 241, 205),
		})
		local tagColor = if bee.Variant then Color3.fromHex(VariantBees.RarityColor(VariantBees.Get(bee.Variant).Rarity)) else Color3.fromHex(Config.Bees[bee.Tier].Look.Stripe)
		local tag = Instance.new("Frame")
		tag.Size = UDim2.new(0, 8, 1, 0)
		tag.BackgroundColor3 = tagColor
		tag.BorderSizePixel = 0
		tag.Parent = card
		corner(tag, 12)
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
		panel.Size = UDim2.new(0.8, 0, 0.7, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.new(0.92, 0, 0.84, 0) }):Play()
	else
		showShopBee(nil)
		showPreviewBee(nil)
	end
end

local function submit(...)
	local now = os.clock()
	if now - lastSubmit < 0.35 then
		return -- stops double taps sending two purchases
	end
	lastSubmit = now
	ShopActionRemote:FireServer(...)
end

buyButton.Activated:Connect(function()
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

-- Keep the panel live while it's open; close it when the player walks away
local function watchPlot()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	if myPlot then
		for _, key in { "Bees", "BeePrice", "BeeCount", "BeeSlots" } do
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
		if gui.Enabled and myPlot then
			local shop = myPlot:FindFirstChild("BeeShop", true)
			local counter = shop and shop:FindFirstChild("Counter")
			local char = player.Character
			if counter and char and (char:GetPivot().Position - counter.Position).Magnitude > Config.PromptDistance + 6 then
				setOpen(false)
			end
		end
	end
end)
