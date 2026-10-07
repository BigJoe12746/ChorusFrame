-- HONEY FARM client: "My Farm" button, notifications, and owner-only prompt visibility.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReturnRemote = Remotes:WaitForChild("ReturnToFarm") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer
local C = Config.Colors

------------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HoneyFarmHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- stays clear of the Roblox top bar / notches
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
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- "My Farm" button: top centre, away from the mobile thumbstick (bottom-left) and jump button (bottom-right).
local button = Instance.new("TextButton")
button.Name = "MyFarmButton"
button.AnchorPoint = Vector2.new(0.5, 0)
button.Position = UDim2.new(0.5, 0, 0, 6)
button.Size = Config.UI.LauncherSize()
button.BackgroundColor3 = C.Honey
button.AutoButtonColor = true
button.Font = Config.UI.Font
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = Config.UI.ButtonSize
button.Text = "MY FARM"
button.Parent = gui
corner(button, 16)
stroke(button, Color3.new(0, 0, 0), 4)
local glyph = Instance.new("UIStroke")
glyph.Color = Color3.new(0, 0, 0)
glyph.Thickness = 2.5
glyph.Parent = button

local hint = Instance.new("TextLabel")
hint.Name = "KeyHint"
hint.AnchorPoint = Vector2.new(1, 0.5)
hint.Position = UDim2.new(1, -8, 0, 0)
hint.Size = UDim2.fromOffset(28, 22)
hint.BackgroundColor3 = C.Cream
hint.Font = Config.UI.Font
hint.TextSize = Config.UI.SmallSize
hint.TextColor3 = C.Text
hint.Text = Config.ReturnHotkey.Name
hint.Visible = UserInputService.KeyboardEnabled
hint.Parent = button
corner(hint, 6)
stroke(hint, C.Text, 2)

-- Notifications stack under the button
local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.AnchorPoint = Vector2.new(0.5, 0)
toasts.Position = UDim2.new(0.5, 0, 0, 150) -- below the My Farm button and the tutorial card
toasts.Size = UDim2.new(0.9, 0, 0, 200)
toasts.BackgroundTransparency = 1
toasts.Parent = gui
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = toasts
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(520, math.huge)
sizeLimit.Parent = toasts

local KIND_COLORS = {
	info = C.Cream,
	success = Color3.fromRGB(200, 245, 180),
	warning = Color3.fromRGB(255, 220, 170),
}

local toastOrder = 0
local function showToast(text: string, kind: string?)
	toastOrder += 1
	local t = Instance.new("TextLabel")
	t.LayoutOrder = toastOrder
	t.Size = UDim2.new(1, 0, 0, 44)
	t.BackgroundColor3 = KIND_COLORS[kind or "info"] or C.Cream
	t.Font = Config.UI.Font
	t.TextSize = Config.UI.BodySize
	t.TextWrapped = true
	t.TextColor3 = C.Text
	t.Text = text
	t.Parent = toasts
	corner(t, 12)
	stroke(t, C.Text, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = t

	-- keep at most 3 on screen
	local shown = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #shown - 3 do
		shown[i]:Destroy()
	end

	task.delay(3.5, function()
		if t.Parent then
			local fade = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			t:Destroy()
		end
	end)
end

NotifyRemote.OnClientEvent:Connect(showToast)

------------------------------------------------------------------------------
-- Return to farm
------------------------------------------------------------------------------

local lastPress = 0
local function goHome()
	local now = os.clock()
	if now - lastPress < Config.ReturnCooldown then
		return
	end
	lastPress = now
	ReturnRemote:FireServer()
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0.4
	task.delay(Config.ReturnCooldown, function()
		button.AutoButtonColor = true
		button.BackgroundTransparency = 0
	end)
end

button.Activated:Connect(goHome)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Config.ReturnHotkey then
		goHome()
	end
end)

------------------------------------------------------------------------------
-- Only show station prompts on your own farm
------------------------------------------------------------------------------

local map = workspace:WaitForChild("HoneyFarmMap")
local plots = map:WaitForChild("Plots")

local function plotOf(inst: Instance): Instance?
	local cur: Instance? = inst
	while cur and cur.Parent ~= plots do
		cur = cur.Parent
	end
	return cur
end

local function refreshPrompt(prompt: ProximityPrompt)
	local plot = plotOf(prompt)
	if plot then
		prompt.Enabled = plot:GetAttribute("OwnerUserId") == player.UserId
	end
end

local function refreshPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("OwnerOnly") then
			refreshPrompt(d)
		end
	end
end

local function watchPlot(plot: Instance)
	refreshPlot(plot)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshPlot(plot)
	end)
end

for _, plot in plots:GetChildren() do
	watchPlot(plot)
end
plots.ChildAdded:Connect(watchPlot)
plots.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") and d:GetAttribute("OwnerOnly") then
		refreshPrompt(d)
	end
end)
