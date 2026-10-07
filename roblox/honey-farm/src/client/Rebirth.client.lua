-- Royal Jelly panel: explains rebirth, shows current jelly and bonus, and asks twice before resetting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RebirthAction") :: RemoteEvent

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
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = C.Text
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "Rebirth"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

-- Button: top-right row, left of 📖 Bees
local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -300, 0, 6)
toggle.Size = UDim2.fromOffset(120, 54)
toggle.BackgroundColor3 = Color3.fromRGB(255, 205, 90)
toggle.Font = Enum.Font.FredokaOne
toggle.TextColor3 = C.Text
toggle.TextSize = 22
toggle.Text = "👑 Jelly"
toggle.Parent = gui
corner(toggle, 16)
stroke(toggle, C.Text, 3)

local panel = Instance.new("Frame")
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C.Cream
panel.Parent = gui
corner(panel, 18)
stroke(panel, Color3.fromRGB(255, 205, 90), 4)
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 16)
pad.PaddingBottom = UDim.new(0, 16)
pad.PaddingLeft = UDim.new(0, 18)
pad.PaddingRight = UDim.new(0, 18)
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = panel

text(panel, { Text = "👑 ROYAL JELLY", Font = Enum.Font.FredokaOne, TextSize = 28, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 })
local status = text(panel, { Text = "", TextSize = 20, Font = Enum.Font.FredokaOne, TextColor3 = C.DeepHoney, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2 })
text(panel, {
	Text = ("Rebirth resets your farm: cash back to $%d, ladder bees and upgrades gone, honey emptied. In return you earn %d Royal Jelly, and every jelly makes all your bees produce +%d%% forever. Egg bees and your collection book are kept."):format(Config.Economy.StartCash, Config.Rebirth.JellyPerRebirth, Config.Rebirth.BonusPerJelly * 100),
	TextSize = 15,
	TextColor3 = Color3.fromRGB(110, 80, 50),
	Size = UDim2.new(1, 0, 0, 84),
	LayoutOrder = 3,
})
local requirement = text(panel, { Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 4 })

local button = Instance.new("TextButton")
button.LayoutOrder = 5
button.Size = UDim2.new(1, 0, 0, 56)
button.BackgroundColor3 = Color3.fromRGB(255, 205, 90)
button.Font = Enum.Font.FredokaOne
button.TextSize = 22
button.TextColor3 = C.Text
button.Text = "Rebirth"
button.Parent = panel
corner(button, 14)
stroke(button, C.Text, 2)

local close = Instance.new("TextButton")
close.LayoutOrder = 6
close.Size = UDim2.new(1, 0, 0, 44)
close.BackgroundColor3 = Color3.fromRGB(230, 220, 200)
close.Font = Enum.Font.FredokaOne
close.TextSize = 18
close.TextColor3 = C.Text
close.Text = "Not now"
close.Parent = panel
corner(close, 14)

local myPlot: Instance? = nil
local armed = false
local armedUntil = 0

local function refresh()
	local jelly = (myPlot and myPlot:GetAttribute("RoyalJelly")) or 0
	local rebirths = (myPlot and myPlot:GetAttribute("Rebirths")) or 0
	local can = myPlot and myPlot:GetAttribute("CanRebirth") == true
	status.Text = ("You hold %d Royal Jelly  ·  ×%.2f honey  ·  %d rebirth%s"):format(jelly, 1 + jelly * Config.Rebirth.BonusPerJelly, rebirths, if rebirths == 1 then "" else "s")
	local need = Config.Bees[Config.Rebirth.RequiresTier].Name
	requirement.Text = if can then ("✅ You own a %s. Ready to rebirth!"):format(need) else ("🔒 Needs a %s on your farm (merge your way up)."):format(need)
	requirement.TextColor3 = if can then Color3.fromRGB(40, 140, 60) else Color3.fromRGB(190, 90, 60)
	if not armed then
		button.Text = if can then ("Rebirth for +%d Jelly"):format(Config.Rebirth.JellyPerRebirth) else "Rebirth (locked)"
	end
	button.BackgroundColor3 = if can then Color3.fromRGB(255, 205, 90) else Color3.fromRGB(215, 205, 185)
	toggle.Visible = myPlot ~= nil
end

local function setOpen(open: boolean)
	panel.Visible = open
	armed = false
	if open then
		refresh()
	end
end

button.Activated:Connect(function()
	if not (myPlot and myPlot:GetAttribute("CanRebirth") == true) then
		return
	end
	if not armed or os.clock() > armedUntil then
		armed = true
		armedUntil = os.clock() + 4
		button.Text = "Tap again to confirm (resets your farm!)"
		button.BackgroundColor3 = Color3.fromRGB(240, 120, 110)
		task.delay(4, function()
			if armed and os.clock() >= armedUntil then
				armed = false
				refresh()
			end
		end)
		return
	end
	armed = false
	RebirthRemote:FireServer()
	setOpen(false)
end)
toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	end
end)

local function watchPlot()
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	if myPlot then
		for _, key in { "RoyalJelly", "Rebirths", "CanRebirth" } do
			myPlot:GetAttributeChangedSignal(key):Connect(function()
				if panel.Visible then
					refresh()
				end
				-- gentle nudge when rebirth becomes available
				if key == "CanRebirth" and myPlot and myPlot:GetAttribute("CanRebirth") == true then
					TweenService:Create(toggle, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(132, 60) }):Play()
					task.delay(0.6, function()
						TweenService:Create(toggle, TweenInfo.new(0.3), { Size = UDim2.fromOffset(120, 54) }):Play()
					end)
				end
			end)
		end
	end
	refresh()
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
watchPlot()
