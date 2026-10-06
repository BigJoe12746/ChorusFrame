-- Upgrades panel: an "Upgrades" button under the My Farm button opens a list of the five
-- farm upgrades with current value, next value and price. The server checks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local UpgradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeAction") :: RemoteEvent

local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

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
gui.Name = "Upgrades"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

-- Toggle button: top-right, clear of the My Farm button (top-centre) and the stats panel (top-left)
local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -10, 0, 6)
toggle.Size = UDim2.fromOffset(150, 54)
toggle.BackgroundColor3 = Color3.fromRGB(150, 220, 120)
toggle.Font = Enum.Font.FredokaOne
toggle.TextColor3 = C.Text
toggle.TextSize = 24
toggle.Text = "⬆ Upgrades"
toggle.Parent = gui
corner(toggle, 16)
stroke(toggle, C.Text, 3)

local panel = Instance.new("Frame")
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.82, 0)
panel.BackgroundColor3 = C.Cream
panel.Parent = gui
corner(panel, 18)
stroke(panel, C.Text, 3)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(640, 560)
maxSize.Parent = panel

text(panel, { Text = "⬆ FARM UPGRADES", TextSize = 30, Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(18, 6), TextXAlignment = Enum.TextXAlignment.Left })
local cashLabel = text(panel, { Text = "", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -120, 0, 20), Position = UDim2.fromOffset(20, 46), TextXAlignment = Enum.TextXAlignment.Left })
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

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 72)
list.Size = UDim2.new(1, -28, 1, -86)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

type Row = { Frame: Frame, Current: TextLabel, Next: TextLabel, Button: TextButton, Level: TextLabel }
local rows: { [string]: Row } = {}
local lastSubmit = 0

for order, id in Config.Upgrades.Order do
	local u = Config.Upgrades[id]
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 84)
	row.BackgroundColor3 = Color3.fromRGB(255, 241, 205)
	row.Parent = list
	corner(row, 14)
	text(row, { Text = u.Icon, TextSize = 34, Size = UDim2.fromOffset(50, 84), Position = UDim2.fromOffset(6, 0) })
	text(row, { Text = u.Name, TextSize = 21, Size = UDim2.new(1, -230, 0, 26), Position = UDim2.fromOffset(60, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local level = text(row, { Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(140, 100, 60), Size = UDim2.new(1, -230, 0, 16), Position = UDim2.fromOffset(60, 30), TextXAlignment = Enum.TextXAlignment.Left })
	local current = text(row, { Text = "", TextSize = 16, Font = Enum.Font.GothamBold, Size = UDim2.new(0.5, -60, 0, 20), Position = UDim2.fromOffset(60, 52), TextXAlignment = Enum.TextXAlignment.Left })
	local nextL = text(row, { Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(40, 140, 60), Size = UDim2.new(0.5, -110, 0, 20), Position = UDim2.new(0.5, 10, 0, 52), TextXAlignment = Enum.TextXAlignment.Left })
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.fromOffset(150, 54)
	btn.BackgroundColor3 = C.Honey
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 19
	btn.TextColor3 = C.Text
	btn.Text = ""
	btn.Parent = row
	corner(btn, 12)
	stroke(btn, C.Text, 2)
	btn.Activated:Connect(function()
		local now = os.clock()
		if now - lastSubmit < 0.35 then
			return
		end
		lastSubmit = now
		UpgradeRemote:FireServer(id)
	end)
	rows[id] = { Frame = row, Current = current, Next = nextL, Button = btn, Level = level }
end

local function fmt(id: string, value: number): string
	return string.format(Config.Upgrades[id].Format or "%g", value)
end

local function money(n: number): string
	return "$" .. tostring(math.floor(n + 0.5))
end

local myPlot: Instance? = nil

local function parseLevels(s: string?): { [string]: number }
	local out = {}
	for id, lvl in string.gmatch(s or "", "(%a+):(%d+)") do
		out[id] = tonumber(lvl) :: number
	end
	return out
end

local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	cashLabel.Text = ("You have %s"):format(money(cash))
	local levels = parseLevels(if myPlot then myPlot:GetAttribute("Upgrades") :: string? else nil)
	for id, row in rows do
		local u = Config.Upgrades[id]
		local lvl = levels[id] or 1
		local maxLvl = #u.Levels
		row.Level.Text = ("Level %d / %d  ·  %s"):format(lvl, maxLvl, u.Description)
		row.Current.Text = "Now: " .. fmt(id, u.Levels[lvl])
		local nextValue = u.Levels[lvl + 1]
		local price = u.Prices[lvl]
		if nextValue and price then
			row.Next.Text = "Next: " .. fmt(id, nextValue)
			row.Button.Text = ("Upgrade\n%s"):format(money(price))
			row.Button.BackgroundColor3 = if cash >= price then C.Honey else Color3.fromRGB(215, 205, 185)
			row.Button.AutoButtonColor = true
		else
			row.Next.Text = "Maxed out!"
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			row.Button.AutoButtonColor = false
		end
	end
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		refresh()
		panel.Size = UDim2.new(0.8, 0, 0.7, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.new(0.92, 0, 0.82, 0) }):Play()
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
	elseif input.KeyCode == Enum.KeyCode.U then
		setOpen(not panel.Visible)
	end
end)

local function watchPlot()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	toggle.Visible = myPlot ~= nil
	if myPlot then
		myPlot:GetAttributeChangedSignal("Upgrades"):Connect(function()
			if panel.Visible then
				refresh()
			end
		end)
	end
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
player:GetAttributeChangedSignal("Cash"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)
watchPlot()
