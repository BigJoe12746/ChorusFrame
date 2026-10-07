local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local UpgradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeAction") :: RemoteEvent
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local gui = Instance.new("ScreenGui")
gui.Name = "Upgrades"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function border(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end
local function glyph(parent: Instance, value: string, size: UDim2, position: UDim2, textSize: number, alignment: Enum.TextXAlignment?)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.Text = value
	label.Size = size
	label.Position = position
	label.ZIndex = 6
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
local function addPressFeedback(button: TextButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local info = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local function scaleTo(value: number)
		TweenService:Create(scale, info, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function() scaleTo(1.06) end)
	button.MouseLeave:Connect(function() scaleTo(1) end)
	button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
	button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
end
local function makeButton(parent: Instance, name: string, label: string, color: Color3, position: UDim2, size: UDim2)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.ZIndex = 4
	button.Parent = parent
	border(button, 4)
	local face = buildFace(button, color, 0.9, math.max(40, math.floor(size.Y.Offset * 0.9 + 0.5)))
	glyph(face, label, UDim2.new(0.92, 0, 0.62, 0), UDim2.new(0.04, 0, 0.12, 0), 17)
	addPressFeedback(button)
	return button
end
local function makeBase(parent: Instance, name: string, color: Color3, position: UDim2, size: UDim2, z: number)
	local base = Instance.new("Frame")
	base.Name = name
	base.Position = position
	base.Size = size
	base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4)
	base.BorderSizePixel = 0
	base.ZIndex = z
	base.Parent = parent
	border(base, 4)
	local face = buildFace(base, color, 0.94, math.clamp(math.floor(size.Y.Offset * 0.6 + 0.5), 40, 110))
	return base, face
end

local launcher = makeButton(gui, "UpgradeToggle", "UPGRADES", Color3.fromRGB(90, 190, 70), UDim2.new(1, -14, 0, 124), UDim2.fromOffset(180, 48))
launcher.AnchorPoint = Vector2.new(1, 0)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.88, 0, 0.78, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 1
panel.Parent = gui
border(panel, 4)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(360, 400)
sizeLimit.MaxSize = Vector2.new(740, 640)
sizeLimit.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.BackgroundColor3 = Color3.fromRGB(35, 105, 48)
titleBar.BorderSizePixel = 0
titleBar.Size = UDim2.new(1, 0, 0, 60)
titleBar.ZIndex = 2
titleBar.Parent = panel
border(titleBar, 4)
local titleFace = buildFace(titleBar, Color3.fromRGB(35, 105, 48), 0.88, 78, true)
glyph(titleFace, "FARM UPGRADES", UDim2.new(0.78, 0, 0.72, 0), UDim2.new(0.03, 0, 0.12, 0), 27, Enum.TextXAlignment.Left)
local close = makeButton(titleBar, "Close", "X", Color3.fromRGB(239, 28, 28), UDim2.new(1, -58, 0.5, -23), UDim2.fromOffset(46, 46))

local coinIcon = Instance.new("ImageLabel")
coinIcon.Name = "CoinIcon"
coinIcon.BackgroundTransparency = 1
coinIcon.Image = "rbxassetid://84697600263846"
coinIcon.Size = UDim2.fromOffset(24, 24)
coinIcon.Position = UDim2.fromOffset(18, 68)
coinIcon.ZIndex = 6
coinIcon.Parent = panel
local coinAspect = Instance.new("UIAspectRatioConstraint")
coinAspect.AspectRatio = 1
coinAspect.Parent = coinIcon
local cashLabel = glyph(panel, "Cash: $0", UDim2.new(0.5, -60, 0, 27), UDim2.fromOffset(50, 66), 18, Enum.TextXAlignment.Left)
local potentialLabel = glyph(panel, "Income: $0 / sec", UDim2.new(0.5, -40, 0, 27), UDim2.new(0.5, 20, 0, 66), 16, Enum.TextXAlignment.Right)
local list = Instance.new("ScrollingFrame")
list.Name = "UpgradeList"
list.Position = UDim2.fromOffset(16, 104)
list.Size = UDim2.new(1, -32, 1, -120)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ZIndex = 2
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

type Row = { Current: TextLabel, Next: TextLabel, Word: TextLabel, Price: TextLabel, PriceRow: Frame, Button: TextButton, Level: TextLabel }
local rows: { [string]: Row } = {}
local lastSubmit = 0
local function money(value: number): string
	return "$" .. Config.Progression.FormattedNumber(value)
end
local function fmt(id: string, value: number): string
	return string.format(Config.Upgrades[id].Format or "%g", value)
end
local function parseLevels(value: string?): { [string]: number }
	local levels = {}
	for id, level in string.gmatch(value or "", "([%a%d]+):(%d+)") do levels[id] = tonumber(level) :: number end
	return levels
end
-- Shake + red flash when a purchase is rejected for insufficient cash.
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
local function failFlash(button: TextButton, word: TextLabel, priceText: string)
	playDeny()
	local face = button:FindFirstChildWhichIsA("Frame")
	local gradient = face and face:FindFirstChildOfClass("UIGradient")
	local originalPosition = button.Position
	local originalColor = button.BackgroundColor3
	local originalGradient = gradient and gradient.Color
	local originalWord = word.Text
	word.Text = "NEED " .. priceText
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
		word.Text = originalWord
	end)
end
-- Per-row logo art (each upgrade section gets its own image; add ids here as
-- new logos are uploaded, one per section).
local ROW_ICONS: { [string]: string } = {
	Backpack = "rbxassetid://124300905660565",
}
for order, id in Config.Upgrades.Order do
	local upgrade = Config.Upgrades[id]
	local row, face = makeBase(list, "Upgrade_" .. id, Color3.fromRGB(90, 120, 170), UDim2.new(), UDim2.new(1, -8, 0, 94), 3)
	row.LayoutOrder = order
	local iconOffset = 12
	if ROW_ICONS[id] then
		local rowIcon = Instance.new("ImageLabel")
		rowIcon.Name = "RowIcon"
		rowIcon.BackgroundTransparency = 1
		rowIcon.Image = ROW_ICONS[id]
		rowIcon.ScaleType = Enum.ScaleType.Fit
		rowIcon.Size = UDim2.fromOffset(44, 44)
		rowIcon.Position = UDim2.fromOffset(12, 25)
		rowIcon.ZIndex = 6
		rowIcon.Parent = face
		local iconAspect = Instance.new("UIAspectRatioConstraint")
		iconAspect.AspectRatio = 1
		iconAspect.Parent = rowIcon
		iconOffset = 64
	end
	glyph(face, upgrade.Name, UDim2.new(0.6, -20 - iconOffset, 0, 25), UDim2.fromOffset(iconOffset, 11), 19, Enum.TextXAlignment.Left)
	local level = glyph(face, "", UDim2.new(0.6, -20 - iconOffset, 0, 19), UDim2.fromOffset(iconOffset, 37), 13, Enum.TextXAlignment.Left)
	local current = glyph(face, "", UDim2.new(0.29, 0, 0, 22), UDim2.new(0, iconOffset, 0, 57), 15, Enum.TextXAlignment.Left)
	local nextValue = glyph(face, "", UDim2.new(0.29, 0, 0, 22), UDim2.new(0.31, iconOffset, 0, 57), 15, Enum.TextXAlignment.Left)
	local button = makeButton(row, "Buy_" .. id, "", Color3.fromRGB(50, 185, 60), UDim2.new(1, -170, 0.5, -30), UDim2.fromOffset(156, 60))
	local word = glyph(button, "", UDim2.new(0.9, 0, 0, 18), UDim2.new(0.5, 0, 0, 6), 14)
	word.AnchorPoint = Vector2.new(0.5, 0)
	local priceRow = Instance.new("Frame")
	priceRow.Name = "PriceRow"
	priceRow.BackgroundTransparency = 1
	priceRow.AnchorPoint = Vector2.new(0.5, 0.5)
	priceRow.Position = UDim2.new(0.5, 0, 0.67, 0)
	priceRow.Size = UDim2.new(1, 0, 0, 24)
	priceRow.ZIndex = 6
	priceRow.Parent = button
	local priceLayout = Instance.new("UIListLayout")
	priceLayout.FillDirection = Enum.FillDirection.Horizontal
	priceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	priceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	priceLayout.Padding = UDim.new(0, 5)
	priceLayout.Parent = priceRow
	local coin = Instance.new("ImageLabel")
	coin.Name = "Coin"
	coin.BackgroundTransparency = 1
	coin.Image = "rbxassetid://84697600263846"
	coin.Size = UDim2.fromOffset(20, 20)
	coin.ZIndex = 7
	coin.Parent = priceRow
	local rowCoinAspect = Instance.new("UIAspectRatioConstraint")
	rowCoinAspect.AspectRatio = 1
	rowCoinAspect.Parent = coin
	local price = glyph(priceRow, "", UDim2.new(0, 96, 1, 0), UDim2.new(), 17)
	price.ZIndex = 7
	rows[id] = { Current = current, Next = nextValue, Word = word, Price = price, PriceRow = priceRow, Button = button, Level = level }
	local startPrice = Config.Progression.UpgradePrice(id, 1)
	level.Text = ("LVL 1 / %d · %s"):format(#upgrade.Levels, upgrade.Description)
	current.Text = "NOW " .. fmt(id, upgrade.Levels[1])
	word.Text = "UPGRADE"
	if upgrade.Levels[2] and startPrice then
		nextValue.Text = "NEXT " .. fmt(id, upgrade.Levels[2])
		price.Text = money(startPrice)
	end
	button.Activated:Connect(function()
		local now = os.clock()
		if now - lastSubmit < 0.35 then return end
		lastSubmit = now
		local plotId = player:GetAttribute("PlotId")
		local plot = plotId and plots:FindFirstChild("Plot" .. plotId)
		local level = parseLevels(if plot then plot:GetAttribute("Upgrades") :: string? else nil)[id] or 1
		local price = Config.Progression.UpgradePrice(id, level)
		if price and (player:GetAttribute("Cash") or 0) < price then
			failFlash(button, word, money(price))
			return
		end
		UpgradeRemote:FireServer(id)
	end)
end

local myPlot: Instance? = nil
local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local income = myPlot and (myPlot:GetAttribute("PotentialCashPerSecond") or 0) or 0
	cashLabel.Text = ("Cash: %s"):format(money(cash))
	potentialLabel.Text = ("Income: %s / sec"):format(money(income))
	local levels = parseLevels(if myPlot then myPlot:GetAttribute("Upgrades") :: string? else nil)
	for id, row in rows do
		local upgrade = Config.Upgrades[id]
		local level = levels[id] or 1
		local nextValue = upgrade.Levels[level + 1]
		local price = Config.Progression.UpgradePrice(id, level)
		row.Level.Text = ("LVL %d / %d · %s"):format(level, #upgrade.Levels, upgrade.Description)
		row.Current.Text = "NOW " .. fmt(id, upgrade.Levels[level])
		if nextValue and price then
			row.Next.Text = "NEXT " .. fmt(id, nextValue)
			row.Word.Text = "UPGRADE"
			row.Word.Position = UDim2.new(0.5, 0, 0, 8)
			row.PriceRow.Visible = true
			row.Price.Text = money(price)
			row.Button.Active = true -- stays clickable: short on cash gives the fail flash instead of dead click
			row.Button.BackgroundColor3 = if cash >= price then Color3.fromRGB(50, 185, 60) else Color3.fromRGB(115, 115, 115)
		else
			row.Next.Text = "MAX LEVEL"
			row.Word.Text = "MAXED"
			row.Word.Position = UDim2.new(0.5, 0, 0.5, -8)
			row.PriceRow.Visible = false
			row.Button.Active = false
			row.Button.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
		end
	end
end

local function setOpen(value: boolean)
	panel.Visible = value
	if value then refresh() end
end
launcher.Activated:Connect(function() setOpen(not panel.Visible) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	elseif input.KeyCode == Enum.KeyCode.U then
		setOpen(not panel.Visible)
	end
end)
player:GetAttributeChangedSignal("Cash"):Connect(function() if panel.Visible then refresh() end end)
player:GetAttributeChangedSignal("PlotId"):Connect(function()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	launcher.Visible = myPlot ~= nil
	if panel.Visible then refresh() end
end)
local function watchPlot()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	launcher.Visible = myPlot ~= nil
	if myPlot then
		for _, key in { "Upgrades", "PotentialCashPerSecond" } do
			myPlot:GetAttributeChangedSignal(key):Connect(function() if panel.Visible then refresh() end end)
		end
	end
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
watchPlot()

-- Purchase feedback: when the server accepts an upgrade, pop the row's button
-- (the Feedback remote's station slot carries the upgrade id for this kind).
local FeedbackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Feedback") :: RemoteEvent
FeedbackRemote.OnClientEvent:Connect(function(kind: string, _amount: number, id: string)
	if kind ~= "Upgrade" then
		return
	end
	local row = rows[id]
	if not row or not panel.Visible then
		return
	end
	local scale = row.Button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = row.Button
	end
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.14 }):Play()
	task.delay(0.15, function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end)
