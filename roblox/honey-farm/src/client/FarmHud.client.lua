-- HONEY FARM HUD: Cash, carried honey, hive storage and bottling progress.
-- Everything shown here is read from attributes the server sets (see FarmService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local player = Players.LocalPlayer

local STUD = "rbxassetid://92521981645530"
local COIN = "rbxassetid://84697600263846"
local gui = Instance.new("ScreenGui")
gui.Name = "HoneyFarmStats"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function border(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Big cash readout, bottom centre, so kids can read the money they have
local cashPlate = Instance.new("Frame")
cashPlate.Name = "CashPlate"
cashPlate.AnchorPoint = Vector2.new(0.5, 1)
cashPlate.Position = UDim2.new(0.5, 0, 1, -14)
cashPlate.Size = UDim2.fromOffset(430, 92)
cashPlate.BackgroundColor3 = Color3.fromRGB(150, 100, 10)
cashPlate.BorderSizePixel = 0
cashPlate.Parent = gui
border(cashPlate, 4)

local cashFace = Instance.new("Frame")
cashFace.BackgroundColor3 = Color3.new(1, 1, 1)
cashFace.BorderSizePixel = 0
cashFace.Size = UDim2.new(1, 0, 0.9, 0)
cashFace.ZIndex = 2
cashFace.Parent = cashPlate
local cashGradient = Instance.new("UIGradient")
cashGradient.Rotation = 90
cashGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 196, 40))
cashGradient.Parent = cashFace
local cashPattern = Instance.new("ImageLabel")
cashPattern.BackgroundTransparency = 1
cashPattern.Image = STUD
cashPattern.ImageTransparency = 0.55
cashPattern.ScaleType = Enum.ScaleType.Tile
cashPattern.TileSize = UDim2.fromOffset(55, 55)
cashPattern.Size = UDim2.fromScale(1, 1)
cashPattern.ZIndex = 3
cashPattern.Parent = cashFace

local cashIcon = Instance.new("ImageLabel")
cashIcon.Name = "Icon"
cashIcon.BackgroundTransparency = 1
cashIcon.AnchorPoint = Vector2.new(0, 0.5)
cashIcon.Position = UDim2.new(0, 16, 0.5, 0)
cashIcon.Size = UDim2.fromOffset(58, 58)
cashIcon.Image = COIN
cashIcon.ScaleType = Enum.ScaleType.Fit
cashIcon.ZIndex = 5
cashIcon.Parent = cashFace
local cashIconAspect = Instance.new("UIAspectRatioConstraint")
cashIconAspect.AspectRatio = 1
cashIconAspect.Parent = cashIcon

local cashTitle = Instance.new("TextLabel")
cashTitle.Name = "Title"
cashTitle.BackgroundTransparency = 1
cashTitle.Position = UDim2.new(0, 86, 0, 8)
cashTitle.Size = UDim2.new(1, -100, 0, 22)
cashTitle.Font = Enum.Font.FredokaOne
cashTitle.TextSize = 20
cashTitle.TextXAlignment = Enum.TextXAlignment.Left
cashTitle.TextColor3 = Color3.new(1, 1, 1)
cashTitle.Text = "YOUR MONEY"
cashTitle.ZIndex = 5
cashTitle.Parent = cashFace
local cashTitleStroke = Instance.new("UIStroke")
cashTitleStroke.Color = Color3.new(0, 0, 0)
cashTitleStroke.Thickness = 2.5
cashTitleStroke.Parent = cashTitle

local cashValue = Instance.new("TextLabel")
cashValue.Name = "Value"
cashValue.BackgroundTransparency = 1
cashValue.Position = UDim2.new(0, 86, 0, 30)
cashValue.Size = UDim2.new(1, -100, 0, 46)
cashValue.Font = Enum.Font.FredokaOne
cashValue.TextSize = 42
cashValue.TextXAlignment = Enum.TextXAlignment.Left
cashValue.TextColor3 = Color3.new(1, 1, 1)
cashValue.Text = "$0"
cashValue.ZIndex = 5
cashValue.Parent = cashFace
local cashValueStroke = Instance.new("UIStroke")
cashValueStroke.Color = Color3.new(0, 0, 0)
cashValueStroke.Thickness = 3
cashValueStroke.Parent = cashValue
local cashValueGradient = Instance.new("UIGradient")
cashValueGradient.Rotation = 90
cashValueGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 214, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 70)),
})
cashValueGradient.Parent = cashValue

-- Blocky stud-textured list, anchored bottom-right so the top-right stays free for BEES / REBIRTH / UPGRADES
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -96, 1, -16)
panel.Size = UDim2.fromOffset(180, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Parent = gui
border(panel, 4)
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local function row(order: number, title: string, color: Color3, iconId: string?): (TextLabel, Frame?)
	local base = Instance.new("Frame")
	base.Name = title
	base.LayoutOrder = order
	base.Size = UDim2.new(1, 0, 0, 38)
	base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4)
	base.BorderSizePixel = 0
	base.Parent = panel
	border(base, 3)

	local face = Instance.new("Frame")
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 0.94, 0)
	face.ZIndex = 2
	face.Parent = base
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	gradient.Parent = face
	local pattern = Instance.new("ImageLabel")
	pattern.BackgroundTransparency = 1
	pattern.Image = STUD
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(30, 30)
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.ZIndex = 3
	pattern.Parent = face

	local textLeft = 8
	if iconId then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 5, 0.5, 0)
		icon.Size = UDim2.fromOffset(22, 22)
		icon.Image = iconId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 5
		icon.Parent = face
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = icon
		textLeft = 32
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, textLeft, 0, 2)
	titleLabel.Size = UDim2.new(1, -textLeft - 6, 0, 13)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.ZIndex = 5
	titleLabel.Parent = face
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.new(0, 0, 0)
	titleStroke.Thickness = 2.5
	titleStroke.Parent = titleLabel

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.new(0, textLeft, 0, 16)
	value.Size = UDim2.new(1, -textLeft - 6, 0, 18)
	value.Font = Enum.Font.FredokaOne
	value.TextSize = 16
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Text = "0"
	value.ZIndex = 5
	value.Parent = face
	local valueStroke = Instance.new("UIStroke")
	valueStroke.Color = Color3.new(0, 0, 0)
	valueStroke.Thickness = 2.5
	valueStroke.Parent = value

	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.AnchorPoint = Vector2.new(1, 1)
	track.Position = UDim2.new(1, -5, 1, -4)
	track.Size = UDim2.fromOffset(62, 6)
	track.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	track.BorderSizePixel = 0
	track.ZIndex = 5
	track.Parent = face
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 6
	fill.Parent = track
	return value, fill
end

local carryingValue = row(1, "CARRYING", Color3.fromRGB(255, 196, 40))
local hiveValue, hiveBar = row(2, "HIVE", Color3.fromRGB(255, 170, 45))
local bottlingValue, bottlingBar = row(3, "JARS", Color3.fromRGB(255, 150, 60))
local standValue = row(4, "AT THE STAND", Color3.fromRGB(90, 200, 80))

local function setBar(bar: Frame?, fraction: number, warnColor: boolean?)
	if not bar then
		return
	end
	fraction = math.clamp(fraction, 0, 1)
	TweenService:Create(bar, TweenInfo.new(0.15), { Size = UDim2.fromScale(fraction, 1) }):Play()
	bar.BackgroundColor3 = if warnColor and fraction >= 1 then Color3.fromRGB(255, 90, 70) else Color3.new(1, 1, 1)
end

local function money(n: number): string
	return "$" .. Config.Progression.FormattedNumber(n)
end

local lastCash: number? = nil
local function popCash()
	TweenService:Create(cashValue, TweenInfo.new(0.1), { TextSize = 48 }):Play()
	task.delay(0.1, function()
		TweenService:Create(cashValue, TweenInfo.new(0.15), { TextSize = 42 }):Play()
	end)
end

local function refreshPlayer()
	if player:GetAttribute("FarmLoading") then
		cashValue.Text = "loading…"
		return
	end
	local cash = player:GetAttribute("Cash") or 0
	local carried = player:GetAttribute("Carried") or 0
	local cap = player:GetAttribute("BackpackCapacity") or Config.Economy.BackpackCapacity
	cashValue.Text = money(cash)
	carryingValue.Text = ("%d / %d"):format(carried, cap)
	if lastCash and cash > lastCash then
		popCash()
	end
	lastCash = cash
end

local myPlot: Instance? = nil
local plotConns: { RBXScriptConnection } = {}

local function refreshPlot()
	local plot = myPlot
	if not plot then
		hiveValue.Text = "—"
		bottlingValue.Text = "—"
		standValue.Text = "—"
		setBar(hiveBar, 0)
		setBar(bottlingBar, 0)
		return
	end
	local stored = plot:GetAttribute("HiveStored") or 0
	local cap = plot:GetAttribute("HiveCapacity") or Config.Economy.HiveCapacity
	hiveValue.Text = ("%d / %d"):format(stored, cap)
	setBar(hiveBar, if cap > 0 then stored / cap else 0, true)

	local queue = plot:GetAttribute("BottlingQueue") or 0
	local progress = plot:GetAttribute("BottlingProgress") or 0
	local jars = plot:GetAttribute("JarsOnBelt") or 0
	if queue > 0 then
		bottlingValue.Text = ("%d wait · %d belt"):format(queue, jars)
	elseif jars > 0 then
		bottlingValue.Text = ("%d on belt"):format(jars)
	else
		bottlingValue.Text = "idle"
	end
	setBar(bottlingBar, progress)

	standValue.Text = money(plot:GetAttribute("Unclaimed") or 0)
end

local function watchPlot(plot: Instance?)
	for _, c in plotConns do
		c:Disconnect()
	end
	plotConns = {}
	myPlot = plot
	if plot then
		for _, key in { "HiveStored", "HiveCapacity", "BottlingQueue", "BottlingProgress", "JarsOnBelt", "Unclaimed" } do
			table.insert(plotConns, plot:GetAttributeChangedSignal(key):Connect(refreshPlot))
		end
	end
	refreshPlot()
end

for _, key in { "Cash", "Carried", "BackpackCapacity", "FarmLoading" } do
	player:GetAttributeChangedSignal(key):Connect(refreshPlayer)
end
refreshPlayer()

local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")
local function findMyPlot()
	local id = player:GetAttribute("PlotId")
	watchPlot(if id then plots:FindFirstChild("Plot" .. id) else nil)
end
player:GetAttributeChangedSignal("PlotId"):Connect(findMyPlot)
findMyPlot()
