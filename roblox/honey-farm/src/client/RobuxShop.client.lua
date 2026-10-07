-- LEMONADE_UI_SCALE_CONVERTER (managed by Lemonade, do not edit or remove)
-- Rewrites pixel (Offset) sizing on every GuiObject under the ScreenGuis this
-- script creates into Scale relative to the parent, so the UI keeps its
-- authored proportions on phones, tablets and other resolutions. Absolute
-- geometry is read first and written second, so the result is pixel-identical
-- at the viewport it was built for.
local lemonadeUiScale_LAYOUT_CLASSES = { "UIListLayout", "UIGridLayout", "UIPageLayout", "UITableLayout" }

local function lemonadeUiScale_resolve(udim: UDim, extent: number): number
	return udim.Scale * extent + udim.Offset
end

local function lemonadeUiScale_hasLayout(parent: Instance): boolean
	for _, className in lemonadeUiScale_LAYOUT_CLASSES do
		if parent:FindFirstChildWhichIsA(className) then
			return true
		end
	end
	return false
end

local function lemonadeUiScale_contentBox(parent: GuiBase2d): (Vector2, Vector2)
	local size = parent.AbsoluteSize
	local origin = parent.AbsolutePosition
	local padding = parent:FindFirstChildWhichIsA("UIPadding")
	if not padding then
		return origin, size
	end
	local left = lemonadeUiScale_resolve(padding.PaddingLeft, size.X)
	local right = lemonadeUiScale_resolve(padding.PaddingRight, size.X)
	local top = lemonadeUiScale_resolve(padding.PaddingTop, size.Y)
	local bottom = lemonadeUiScale_resolve(padding.PaddingBottom, size.Y)
	return origin + Vector2.new(left, top), size - Vector2.new(left + right, top + bottom)
end

local function lemonadeUiScale_toScale(absolute: Vector2, content: Vector2): UDim2
	return UDim2.fromScale(absolute.X / content.X, absolute.Y / content.Y)
end

local function lemonadeUiScale_planObject(object: GuiObject, plan: { () -> () })
	local parent = object.Parent
	if not (parent and parent:IsA("GuiBase2d")) then
		return
	end
	if parent:FindFirstChildWhichIsA("UIGridLayout") then
		return
	end
	local contentOrigin, content = lemonadeUiScale_contentBox(parent)
	if content.X <= 0 or content.Y <= 0 then
		return
	end
	local absoluteSize = object.AbsoluteSize
	local size = object.Size
	local automatic = object.AutomaticSize
	local scaled = lemonadeUiScale_toScale(absoluteSize, content)
	local keepX = automatic == Enum.AutomaticSize.X or automatic == Enum.AutomaticSize.XY
	local keepY = automatic == Enum.AutomaticSize.Y or automatic == Enum.AutomaticSize.XY
	local newSize = UDim2.new(if keepX then size.X else scaled.X, if keepY then size.Y else scaled.Y)
	local positionManaged = lemonadeUiScale_hasLayout(parent)
	local anchored = object.AbsolutePosition - contentOrigin + object.AnchorPoint * absoluteSize
	local newPosition = lemonadeUiScale_toScale(anchored, content)
	local pureOffset = size.X.Scale == 0 and size.Y.Scale == 0 and absoluteSize.X > 0 and absoluteSize.Y > 0
	local fixedShape = pureOffset and automatic == Enum.AutomaticSize.None
	local aspect = if fixedShape and not object:FindFirstChildWhichIsA("UIAspectRatioConstraint")
		then absoluteSize.X / absoluteSize.Y
		else nil
	table.insert(plan, function()
		object.Size = newSize
		if not positionManaged then
			object.Position = newPosition
		end
		if aspect then
			local constraint = Instance.new("UIAspectRatioConstraint")
			constraint.AspectRatio = aspect
			constraint.Parent = object
		end
	end)
end

local function lemonadeUiScale_planHelpers(object: GuiBase2d, plan: { () -> () })
	local _, content = lemonadeUiScale_contentBox(object)
	local size = object.AbsoluteSize
	for _, child in object:GetChildren() do
		if child:IsA("UIGridLayout") then
			local cell = Vector2.new(
				lemonadeUiScale_resolve(child.CellSize.X, content.X),
				lemonadeUiScale_resolve(child.CellSize.Y, content.Y)
			)
			local gap = Vector2.new(
				lemonadeUiScale_resolve(child.CellPadding.X, content.X),
				lemonadeUiScale_resolve(child.CellPadding.Y, content.Y)
			)
			table.insert(plan, function()
				child.CellSize = lemonadeUiScale_toScale(cell, content)
				child.CellPadding = lemonadeUiScale_toScale(gap, content)
			end)
		elseif child:IsA("UIListLayout") then
			local extent = if child.FillDirection == Enum.FillDirection.Horizontal then content.X else content.Y
			local gap = lemonadeUiScale_resolve(child.Padding, extent)
			table.insert(plan, function()
				child.Padding = UDim.new(gap / extent, 0)
			end)
		elseif child:IsA("UIPadding") then
			local left = lemonadeUiScale_resolve(child.PaddingLeft, size.X)
			local right = lemonadeUiScale_resolve(child.PaddingRight, size.X)
			local top = lemonadeUiScale_resolve(child.PaddingTop, size.Y)
			local bottom = lemonadeUiScale_resolve(child.PaddingBottom, size.Y)
			table.insert(plan, function()
				child.PaddingLeft = UDim.new(left / size.X, 0)
				child.PaddingRight = UDim.new(right / size.X, 0)
				child.PaddingTop = UDim.new(top / size.Y, 0)
				child.PaddingBottom = UDim.new(bottom / size.Y, 0)
			end)
		elseif child:IsA("UICorner") then
			local shortest = math.min(size.X, size.Y)
			local radius = lemonadeUiScale_resolve(child.CornerRadius, shortest)
			table.insert(plan, function()
				child.CornerRadius = UDim.new(radius / shortest, 0)
			end)
		end
	end
end

local function lemonadeUiScale_hasOwnScale(screenGui: ScreenGui): boolean
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("UIScale") and not descendant.Parent:IsA("GuiButton") then
			return true
		end
	end
	return false
end

local function lemonadeUiScale_convert(screenGui: ScreenGui)
	if screenGui.AbsoluteSize.X <= 0 or screenGui.AbsoluteSize.Y <= 0 then
		return
	end
	-- A UIScale is the tree's own responsiveness: AbsoluteSize already carries
	-- its factor, so rewriting to Scale would apply it twice on the next
	-- viewport change while fixed TextSizes only get it once.
	if lemonadeUiScale_hasOwnScale(screenGui) then
		return
	end
	local plan: { () -> () } = {}
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("GuiObject") then
			lemonadeUiScale_planObject(descendant, plan)
			if descendant.AbsoluteSize.X > 0 and descendant.AbsoluteSize.Y > 0 then
				lemonadeUiScale_planHelpers(descendant, plan)
			end
		end
	end
	for _, apply in plan do
		apply()
	end
end

local lemonadeUiScale_RunService = game:GetService("RunService")
if lemonadeUiScale_RunService:IsRunning() and lemonadeUiScale_RunService:IsClient() then
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child)
		if not child:IsA("ScreenGui") or child.Name ~= "RobuxShop" then
			return
		end
		task.defer(function()
			lemonadeUiScale_RunService.RenderStepped:Wait()
			lemonadeUiScale_convert(child)
		end)
	end)
end

-- Robux cash shop. Buttons prompt a Developer Product; the server grants the cash after Roblox confirms payment.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
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

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local RobuxShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RobuxShop") :: RemoteEvent
local player = Players.LocalPlayer

local STUD = "rbxassetid://92521981645530"
local COIN = "rbxassetid://84697600263846"
local ROBUX = "rbxassetid://87608142780557"
local BASKET = "rbxassetid://110972987269284"
local GOLD = Color3.fromRGB(255, 196, 40)
local GREEN = Color3.fromRGB(70, 200, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "RobuxShop"
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

local function studs(face: Frame, tile: number)
	local pattern = Instance.new("ImageLabel")
	pattern.BackgroundTransparency = 1
	pattern.Image = STUD
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(tile, tile)
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.ZIndex = face.ZIndex + 1
	pattern.Parent = face
end

local function glyph(parent: GuiObject, text: string, size: UDim2, position: UDim2, textSize: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.ZIndex = parent.ZIndex + 2
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = if textSize >= 24 then 3 else 2.5
	stroke.Parent = label
	return label
end

-- SHOP launcher, stacked under BEES / REBIRTH / UPGRADES on the right edge
local launcher = Instance.new("TextButton")
launcher.Name = "ShopButton"
launcher.Text = ""
launcher.AutoButtonColor = false
launcher.AnchorPoint = Vector2.new(1, 0)
launcher.Position = UDim2.new(1, -14, 0, 252)
launcher.Size = UDim2.fromOffset(180, 48)
launcher.BackgroundColor3 = Color3.fromRGB(20, 110, 40)
launcher.BorderSizePixel = 0
launcher.Parent = gui
border(launcher, 4)
local launcherFace = Instance.new("Frame")
launcherFace.BackgroundColor3 = Color3.new(1, 1, 1)
launcherFace.BorderSizePixel = 0
launcherFace.Size = UDim2.new(1, 0, 0.9, 0)
launcherFace.ZIndex = 2
launcherFace.Parent = launcher
local launcherGradient = Instance.new("UIGradient")
launcherGradient.Rotation = 90
launcherGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.1, Color3.fromRGB(170, 255, 170)),
	ColorSequenceKeypoint.new(1, GREEN),
})
launcherGradient.Parent = launcherFace
studs(launcherFace, 43)
glyph(launcherFace, "SHOP", UDim2.new(1, 0, 0.62, 0), UDim2.fromScale(0, 0.16), 26).TextXAlignment = Enum.TextXAlignment.Center
addPressFeedback(launcher)

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.56, 0, 0.52, 0)
panel.Position = UDim2.new(0.5, 0, 0.44, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
border(panel, 4)

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0.14, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(150, 100, 10)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
border(titleBar, 4)
local titleFace = Instance.new("Frame")
titleFace.BackgroundColor3 = GOLD
titleFace.BorderSizePixel = 0
titleFace.Size = UDim2.new(1, 0, 0.88, 0)
titleFace.ZIndex = 2
titleFace.Parent = titleBar
studs(titleFace, 66)
local basket = Instance.new("ImageLabel")
basket.BackgroundTransparency = 1
basket.Image = BASKET
basket.ScaleType = Enum.ScaleType.Fit
basket.Size = UDim2.fromOffset(40, 40)
basket.Position = UDim2.new(0, 12, 0.5, -20)
basket.ZIndex = 4
basket.Parent = titleFace
local basketAspect = Instance.new("UIAspectRatioConstraint")
basketAspect.AspectRatio = 1
basketAspect.Parent = basket
local titleLabel = glyph(titleFace, "CASH SHOP", UDim2.new(0.6, 0, 0.7, 0), UDim2.new(0, 72, 0.12, 0), 30)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Name = "Close"
close.Text = ""
close.AutoButtonColor = false
close.Size = UDim2.new(0.08, 0, 0.68, 0)
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -6, 0.5, 0)
close.BackgroundColor3 = Color3.fromRGB(120, 14, 14)
close.BorderSizePixel = 0
close.Parent = titleBar
local closeAspect = Instance.new("UIAspectRatioConstraint")
closeAspect.AspectRatio = 1
closeAspect.DominantAxis = Enum.DominantAxis.Height
closeAspect.Parent = close
border(close, 4)
local closeFace = Instance.new("Frame")
closeFace.BackgroundColor3 = Color3.new(1, 1, 1)
closeFace.BorderSizePixel = 0
closeFace.Size = UDim2.new(1, 0, 0.9, 0)
closeFace.ZIndex = 3
closeFace.Parent = close
local closeGradient = Instance.new("UIGradient")
closeGradient.Rotation = 90
closeGradient.Color = ColorSequence.new(Color3.fromRGB(255, 130, 130), Color3.fromRGB(239, 28, 28))
closeGradient.Parent = closeFace
local closeX = glyph(closeFace, "X", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.12), 24)
closeX.TextXAlignment = Enum.TextXAlignment.Center
addPressFeedback(close)

local list = Instance.new("Frame")
list.Name = "Offers"
list.Position = UDim2.new(0, 14, 0.14, 10)
list.Size = UDim2.new(1, -28, 0.86, -24)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function money(n: number): string
	return "$" .. Config.Progression.FormattedNumber(n)
end

for index, offer in Config.Shop do
	local row = Instance.new("Frame")
	row.Name = offer.Id
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0.17, 0)
	row.BackgroundColor3 = GOLD:Lerp(Color3.new(0, 0, 0), 0.45)
	row.BorderSizePixel = 0
	row.Parent = list
	border(row, 3)
	local face = Instance.new("Frame")
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 0.94, 0)
	face.ZIndex = 2
	face.Parent = row
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	gradient.Parent = face
	studs(face, 46)

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Size = UDim2.fromOffset(46, 46)
	icon.Image = COIN
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 5
	icon.Parent = face
	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = icon

	local nameLabel = glyph(face, offer.Name, UDim2.new(0.42, 0, 0.4, 0), UDim2.new(0, 66, 0.06, 0), 20)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	local amountLabel = glyph(face, money(offer.Amount), UDim2.new(0.42, 0, 0.42, 0), UDim2.new(0, 66, 0.48, 0), 26)
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Text = ""
	buy.AutoButtonColor = false
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)
	buy.Size = UDim2.fromOffset(150, 48)
	buy.BackgroundColor3 = Color3.fromRGB(20, 110, 40)
	buy.BorderSizePixel = 0
	buy.ZIndex = 5
	buy.Parent = face
	border(buy, 4)
	local buyFace = Instance.new("Frame")
	buyFace.BackgroundColor3 = Color3.new(1, 1, 1)
	buyFace.BorderSizePixel = 0
	buyFace.Size = UDim2.new(1, 0, 0.9, 0)
	buyFace.ZIndex = 6
	buyFace.Parent = buy
	local buyGradient = Instance.new("UIGradient")
	buyGradient.Rotation = 90
	buyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.1, Color3.fromRGB(170, 255, 170)),
		ColorSequenceKeypoint.new(1, GREEN),
	})
	buyGradient.Parent = buyFace
	studs(buyFace, 43)
	local buyRow = Instance.new("Frame")
	buyRow.BackgroundTransparency = 1
	buyRow.AnchorPoint = Vector2.new(0.5, 0.5)
	buyRow.Position = UDim2.fromScale(0.5, 0.5)
	buyRow.Size = UDim2.new(1, 0, 0.62, 0)
	buyRow.ZIndex = 8
	buyRow.Parent = buyFace
	local buyLayout = Instance.new("UIListLayout")
	buyLayout.FillDirection = Enum.FillDirection.Horizontal
	buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buyLayout.Padding = UDim.new(0, 6)
	buyLayout.Parent = buyRow
	local robuxIcon = Instance.new("ImageLabel")
	robuxIcon.BackgroundTransparency = 1
	robuxIcon.Image = ROBUX
	robuxIcon.ScaleType = Enum.ScaleType.Fit
	robuxIcon.Size = UDim2.fromOffset(26, 26)
	robuxIcon.ZIndex = 9
	robuxIcon.Parent = buyRow
	local robuxAspect = Instance.new("UIAspectRatioConstraint")
	robuxAspect.AspectRatio = 1
	robuxAspect.Parent = robuxIcon
	local priceLabel = glyph(buyRow, tostring(offer.Robux), UDim2.new(0.5, 0, 1, 0), UDim2.fromScale(0, 0), 22)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	addPressFeedback(buy)

	buy.Activated:Connect(function()
		if offer.ProductId == 0 then
			if RunService:IsStudio() then
				RobuxShopRemote:FireServer(offer.Id)
			else
				priceLabel.Text = "SOON"
				task.delay(1.2, function()
					priceLabel.Text = tostring(offer.Robux)
				end)
			end
			return
		end
		MarketplaceService:PromptProductPurchase(player, offer.ProductId)
	end)
end

launcher.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
