-- layout: centered-dialog
local TweenService = game:GetService("TweenService")
local PRESS_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local function addPressFeedback(button)
    local scale = Instance.new("UIScale")
    scale.Parent = button
    local function scaleTo(target)
        TweenService:Create(scale, PRESS_TWEEN, { Scale = target }):Play()
    end
    button.MouseEnter:Connect(function() scaleTo(1.06) end)
    button.MouseLeave:Connect(function() scaleTo(1) end)
    button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
    button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RebirthAction") :: RemoteEvent
local config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local gui = Instance.new("ScreenGui")
gui.Name = "RebirthUI"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function outline(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = thickness
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
end
local function glyph(parent, text, size, position, textSize)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = config.UI.Font
    label.TextSize = textSize or config.UI.BodySize
    label.TextWrapped = true
    label.Position = position
    label.Size = size
    label.ZIndex = 10
    label.Parent = parent
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = if (textSize or config.UI.BodySize) >= 24 then 3 else 2.5
    stroke.Parent = label
    return label
end
local function makeButton(parent, name, text, color, position, size)
    local base = Instance.new("TextButton")
    base.Name = name
    base.Text = ""
    base.AutoButtonColor = false
    base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
    base.BorderSizePixel = 0
    base.Position = position
    base.Size = size
    base.ZIndex = 5
    base.Parent = parent
    outline(base, 4)
    local face = Instance.new("Frame")
    face.BackgroundColor3 = Color3.new(1, 1, 1)
    face.BorderSizePixel = 0
    face.Size = UDim2.new(1, 0, 0.9, 0)
    face.ZIndex = 6
    face.Parent = base
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), color)
    gradient.Parent = face
    local pattern = Instance.new("ImageLabel")
    pattern.BackgroundTransparency = 1
    pattern.Image = "rbxassetid://92521981645530"
    pattern.ImageTransparency = 0.55
    pattern.ScaleType = Enum.ScaleType.Tile
    pattern.TileSize = UDim2.fromOffset(math.max(40, math.floor(size.Y.Offset * 0.9)), math.max(40, math.floor(size.Y.Offset * 0.9)))
    pattern.Size = UDim2.fromScale(1, 1)
    pattern.ZIndex = 7
    pattern.Parent = face
    glyph(face, text, UDim2.new(0.92, 0, 0.62, 0), UDim2.fromScale(0.04, 0.12), config.UI.ButtonSize)
    addPressFeedback(base)
    return base
end
local function money(value)
    return "$" .. config.Progression.FormattedNumber(value)
end

local launcher = makeButton(gui, "RebirthButton", "REBIRTH", Color3.fromRGB(245, 165, 35), config.UI.LauncherPosition(2), config.UI.LauncherSize())
launcher.AnchorPoint = Vector2.new(1, 0)
local panel = Instance.new("Frame")
panel.Name = "Dialog"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.45, 0)
panel.Size = UDim2.new(0.45, 0, 0.55, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 2
panel.Parent = gui
outline(panel, 4)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MinSize = Vector2.new(340, 380)
maxSize.MaxSize = Vector2.new(620, 600)
maxSize.Parent = panel
local title = Instance.new("Frame")
title.Name = "TitleBar"
title.BackgroundColor3 = Color3.fromRGB(185, 105, 25)
title.BorderSizePixel = 0
title.Size = UDim2.new(1, 0, 0.135, 0)
title.ZIndex = 3
title.Parent = panel
outline(title, 4)
local titlePattern = Instance.new("ImageLabel")
titlePattern.BackgroundTransparency = 1
titlePattern.Image = "rbxassetid://92521981645530"
titlePattern.ImageTransparency = 0.55
titlePattern.ScaleType = Enum.ScaleType.Tile
titlePattern.TileSize = UDim2.fromOffset(58, 58)
titlePattern.Size = UDim2.fromScale(1, 1)
titlePattern.ZIndex = 4
titlePattern.Parent = title
glyph(title, "HONEY FARM REBIRTH", UDim2.new(0.78, 0, 0.7, 0), UDim2.new(0, 18, 0.15, 0), config.UI.TitleSize)
local close = makeButton(title, "Close", "X", Color3.fromRGB(240, 35, 35), UDim2.new(1, -58, 0.18, 0), UDim2.fromOffset(46, 46))
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.new(0.06, 0, 0.18, 0)
content.Size = UDim2.new(0.88, 0, 0.76, 0)
content.ZIndex = 3
content.Parent = panel
local _info = glyph(content, ("Reset farm progress for a permanent x%.2f honey-production bonus per rebirth. Lifetime stats and bee discoveries stay."):format(config.Rebirth.ProductionMultiplier), UDim2.new(0.88, 0, 0.18, 0), UDim2.new(0.06, 0, 0.08, 0), config.UI.BodySize)
local price = glyph(content, "Current cost: loading...", UDim2.new(0.88, 0, 0.11, 0), UDim2.new(0.06, 0, 0.32, 0), config.UI.BodySize)
local boost = glyph(content, "Next rebirth increases production", UDim2.new(0.88, 0, 0.12, 0), UDim2.new(0.06, 0, 0.47, 0), config.UI.BodySize)
local timeHint = glyph(content, "Suggested pace: about 2 hours per rebirth.", UDim2.new(0.88, 0, 0.1, 0), UDim2.new(0.06, 0, 0.60, 0), config.UI.SmallSize)
local _warning = glyph(content, "Resets cash, bees, upgrades, stored honey, jars, and unclaimed cash.", UDim2.new(0.88, 0, 0.1, 0), UDim2.new(0.06, 0, 0.71, 0), config.UI.SmallSize)
local confirm = makeButton(content, "ConfirmButton", "REBIRTH", Color3.fromRGB(45, 190, 65), UDim2.new(0.48, 0, 0.91, 0), UDim2.new(0.32, 0, 0, 48))
confirm.AnchorPoint = Vector2.new(1, 0.5)
local cancel = makeButton(content, "CancelButton", "CANCEL", Color3.fromRGB(210, 130, 35), UDim2.new(0.52, 0, 0.91, 0), UDim2.new(0.32, 0, 0, 48))
cancel.AnchorPoint = Vector2.new(0, 0.5)

local function refresh()
    local count = player:GetAttribute("Rebirths") or 0
    local cost = player:GetAttribute("RebirthCost") or config.Progression.RebirthCost(count)
    local currentMultiplier = player:GetAttribute("RebirthMultiplier") or config.Progression.RebirthMultiplier(count)
    local nextMultiplier = player:GetAttribute("NextRebirthMultiplier") or config.Progression.NextRebirthMultiplier(count, config.Rebirth.ProductionMultiplier)
    price.Text = ("Cost: %s  |  Rebirths: %d"):format(money(cost), count)
    boost.Text = ("After rebirth: x%.2f production (now x%.2f)"):format(nextMultiplier, currentMultiplier)
    timeHint.Text = ("Suggested pace: about %.1f hours for this rebirth."):format(config.Progression.RebirthTargetHours(count))
    local cash = player:GetAttribute("Cash") or 0
    confirm.Active = cash >= cost
    confirm.BackgroundColor3 = if confirm.Active then Color3.fromRGB(45, 190, 65) else Color3.fromRGB(130, 130, 130)
end
launcher.Activated:Connect(function() refresh(); panel.Visible = true end)
close.Activated:Connect(function() panel.Visible = false end)
cancel.Activated:Connect(function() panel.Visible = false end)
confirm.Activated:Connect(function()
    refresh()
    if confirm.Active then remote:FireServer() end
end)
for _, attribute in { "Cash", "Rebirths", "RebirthMultiplier", "RebirthCost", "NextRebirthMultiplier" } do player:GetAttributeChangedSignal(attribute):Connect(refresh) end
player:GetAttributeChangedSignal("PlotId"):Connect(function()
    launcher.Visible = player:GetAttribute("PlotId") ~= nil
    if not launcher.Visible then panel.Visible = false end
end)
launcher.Visible = player:GetAttribute("PlotId") ~= nil
refresh()
