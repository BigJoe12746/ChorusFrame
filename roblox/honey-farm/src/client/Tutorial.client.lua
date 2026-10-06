-- New-player introduction: a card under the My Farm button with the current step, and a glowing
-- highlight + bobbing arrow on the station to go to next. The server owns the step
-- (player attribute TutorialStep); this script only displays it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local C = Config.Colors
local player = Players.LocalPlayer
local plots = workspace:WaitForChild("HoneyFarmMap"):WaitForChild("Plots")

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 66)
card.Size = UDim2.fromOffset(340, 78)
card.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = C.Honey
stroke.Thickness = 3
stroke.Parent = card

local stepLabel = Instance.new("TextLabel")
stepLabel.Size = UDim2.new(1, -20, 0, 18)
stepLabel.Position = UDim2.fromOffset(10, 6)
stepLabel.BackgroundTransparency = 1
stepLabel.Font = Enum.Font.GothamBold
stepLabel.TextSize = 12
stepLabel.TextColor3 = Color3.fromRGB(160, 110, 50)
stepLabel.TextXAlignment = Enum.TextXAlignment.Left
stepLabel.Parent = card

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.fromOffset(10, 20)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextSize = 21
title.TextColor3 = C.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -20, 0, 32)
body.Position = UDim2.fromOffset(10, 44)
body.BackgroundTransparency = 1
body.Font = Enum.Font.GothamBold
body.TextSize = 13
body.TextWrapped = true
body.TextColor3 = Color3.fromRGB(110, 80, 50)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = card

-- Highlight + arrow on the target station
local highlight = Instance.new("Highlight")
highlight.FillColor = C.Honey
highlight.FillTransparency = 0.75
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = gui

local arrowGui = Instance.new("BillboardGui")
arrowGui.Size = UDim2.fromOffset(60, 60)
arrowGui.AlwaysOnTop = true
arrowGui.Enabled = false
arrowGui.Parent = gui
local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromScale(1, 1)
arrow.BackgroundTransparency = 1
arrow.Font = Enum.Font.FredokaOne
arrow.TextScaled = true
arrow.TextColor3 = C.Honey
arrow.TextStrokeColor3 = C.Text
arrow.TextStrokeTransparency = 0
arrow.Text = "⬇"
arrow.Parent = arrowGui

local myPlot: Instance? = nil
local targetStation: Instance? = nil
local arrowBase = 0
local lastStep = 0

local function stationModel(name: string): Instance?
	local stations = myPlot and myPlot:FindFirstChild("Stations")
	return stations and stations:FindFirstChild(name)
end

local function refresh()
	local step = player:GetAttribute("TutorialStep")
	local info = type(step) == "number" and Config.Tutorial.Steps[step]
	if not myPlot or not info then
		card.Visible = false
		highlight.Enabled = false
		arrowGui.Enabled = false
		targetStation = nil
		return
	end
	card.Visible = true
	stepLabel.Text = ("GETTING STARTED  ·  STEP %d OF %d"):format(step, #Config.Tutorial.Steps)
	title.Text = info.Title
	-- step 1: tell them to wait while the hive is still empty
	local waiting = step == 1 and (myPlot:GetAttribute("HiveStored") or 0) <= 0 and (player:GetAttribute("Carried") or 0) <= 0
	body.Text = if waiting and info.WaitBody then info.WaitBody else info.Body

	local target = stationModel(info.Station)
	if target ~= targetStation then
		targetStation = target
		highlight.Adornee = target
		local primary = target and (target :: Model).PrimaryPart
		arrowGui.Adornee = primary
		if primary then
			local labelGui = primary:FindFirstChild("Label")
			arrowBase = (if labelGui and labelGui:IsA("BillboardGui") then labelGui.StudsOffsetWorldSpace.Y else 12) + 4
		end
	end
	highlight.Enabled = target ~= nil and not waiting
	arrowGui.Enabled = target ~= nil and not waiting

	if step ~= lastStep and lastStep ~= 0 then
		-- celebrate the step change
		card.BackgroundColor3 = Color3.fromRGB(200, 245, 180)
		TweenService:Create(card, TweenInfo.new(0.6), { BackgroundColor3 = Color3.fromRGB(255, 244, 214) }):Play()
	end
	lastStep = step
end

RunService.Heartbeat:Connect(function()
	if arrowGui.Enabled then
		arrowGui.StudsOffsetWorldSpace = Vector3.new(0, arrowBase + math.sin(os.clock() * 4) * 0.8, 0)
	end
end)

local conns: { RBXScriptConnection } = {}
local function watchPlot()
	for _, c in conns do
		c:Disconnect()
	end
	conns = {}
	local id = player:GetAttribute("PlotId")
	myPlot = if id then plots:FindFirstChild("Plot" .. id) else nil
	if myPlot then
		table.insert(conns, myPlot:GetAttributeChangedSignal("HiveStored"):Connect(refresh))
	end
	refresh()
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
player:GetAttributeChangedSignal("TutorialStep"):Connect(refresh)
player:GetAttributeChangedSignal("Carried"):Connect(refresh)
watchPlot()
