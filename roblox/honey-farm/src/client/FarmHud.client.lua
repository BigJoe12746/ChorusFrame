-- HONEY FARM HUD: Cash, carried honey, hive storage and bottling progress.
-- Everything shown here is read from attributes the server sets (see FarmService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local C = Config.Colors
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HoneyFarmStats"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end
local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

-- Panel in the top-left (the mobile thumbstick is bottom-left, the My Farm button is top-centre)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Position = UDim2.fromOffset(10, 8)
panel.Size = UDim2.fromOffset(230, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C.Cream
panel.BackgroundTransparency = 0.08
panel.Parent = gui
corner(panel, 14)
stroke(panel, C.Text, 3)
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local function row(order: number, icon: string, title: string, big: boolean?): (TextLabel, Frame?)
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, if big then 40 else 30)
	holder.BackgroundTransparency = 1
	holder.Parent = panel

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(if big then 36 else 28, holder.Size.Y.Offset)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.TextSize = if big then 28 else 20
	iconLabel.Text = icon
	iconLabel.Parent = holder

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(iconLabel.Size.X.Offset + 4, 0)
	titleLabel.Size = UDim2.new(1, -iconLabel.Size.X.Offset - 4, 0, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.fromRGB(140, 100, 60)
	titleLabel.Text = title
	titleLabel.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Position = UDim2.fromOffset(iconLabel.Size.X.Offset + 4, 13)
	value.Size = UDim2.new(1, -iconLabel.Size.X.Offset - 4, 0, if big then 26 else 17)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.FredokaOne
	value.TextSize = if big then 26 else 17
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = C.Text
	value.Text = "0"
	value.Parent = holder

	local bar: Frame? = nil
	if not big then
		local track = Instance.new("Frame")
		track.Name = "Bar"
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, 0, 0.5, 6)
		track.Size = UDim2.fromOffset(70, 10)
		track.BackgroundColor3 = Color3.fromRGB(225, 210, 180)
		track.Parent = holder
		corner(track, 5)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = C.Honey
		fill.Parent = track
		corner(fill, 5)
		bar = fill
	end
	return value, bar
end

local cashValue = row(1, "💰", "CASH", true)
local carriedValue, carriedBar = row(2, "🎒", "CARRYING")
local hiveValue, hiveBar = row(3, "🐝", "HIVE STORAGE")
local bottlingValue, bottlingBar = row(4, "🍯", "BOTTLING")
local standValue = row(5, "🏪", "AT THE STAND", true)

local function setBar(bar: Frame?, fraction: number, warnColor: boolean?)
	if not bar then
		return
	end
	fraction = math.clamp(fraction, 0, 1)
	TweenService:Create(bar, TweenInfo.new(0.15), { Size = UDim2.fromScale(fraction, 1) }):Play()
	bar.BackgroundColor3 = if warnColor and fraction >= 1 then Color3.fromRGB(235, 90, 70) else C.Honey
end

local function money(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(n)
	-- 12345 -> 12,345
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return "$" .. s
end

local lastCash: number? = nil
local function popCash()
	TweenService:Create(cashValue, TweenInfo.new(0.1), { TextSize = 32 }):Play()
	task.delay(0.1, function()
		TweenService:Create(cashValue, TweenInfo.new(0.15), { TextSize = 26 }):Play()
	end)
end

local function refreshPlayer()
	if player:GetAttribute("FarmLoading") then
		cashValue.Text = "loading…"
		carriedValue.Text = "…"
		return
	end
	local cash = player:GetAttribute("Cash") or 0
	cashValue.Text = money(cash)
	if lastCash and cash > lastCash then
		popCash()
	end
	lastCash = cash
	local carried = player:GetAttribute("Carried") or 0
	local cap = player:GetAttribute("BackpackCapacity") or Config.Economy.BackpackCapacity
	carriedValue.Text = ("%d / %d"):format(carried, cap)
	setBar(carriedBar, if cap > 0 then carried / cap else 0, true)
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
		bottlingValue.Text = ("%d waiting · %d on belt"):format(queue, jars)
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
