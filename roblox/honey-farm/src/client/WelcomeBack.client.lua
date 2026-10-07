-- "Welcome back" card: how long you were away and what your bees made meanwhile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))
local WelcomeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WelcomeBack") :: RemoteEvent

local C = Config.Colors
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WelcomeBack"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function duration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h >= 24 then
		return ("%dd %dh"):format(math.floor(h / 24), h % 24)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%d min"):format(math.max(1, m))
end

WelcomeRemote.OnClientEvent:Connect(function(w: { [string]: any })
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(380, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = C.Cream
	card.BackgroundTransparency = 1
	card.Parent = gui
	corner(card, 20)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Honey
	stroke.Thickness = 4
	stroke.Transparency = 1
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card

	local function line(txt: string, size: number, color: Color3?, font: Enum.Font?)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.BackgroundTransparency = 1
		l.Font = font or Config.UI.Font
		l.TextSize = size
		l.TextWrapped = true
		l.TextColor3 = color or C.Text
		l.TextTransparency = 1
		l.Text = txt
		l.Parent = card
		return l
	end

	local labels = {
		line("🐝 Welcome back!", 30, C.Text, Config.UI.Font),
		line(("You were away for %s."):format(duration(w.Away or 0)), 18, Color3.fromRGB(140, 100, 60)),
		line(("Your bees made %d 🍯"):format(w.Credited or 0), 36, C.DeepHoney, Config.UI.Font),
	}
	if w.HiveFull then
		table.insert(labels, line(("The hive filled up (%d / %d). Upgrade Hive Storage to keep more!"):format(w.HiveStored or 0, w.HiveCapacity or 0), 15, Color3.fromRGB(190, 90, 60)))
	elseif w.Capped then
		table.insert(labels, line(("Offline honey counts for up to %d hours."):format(Config.Save.OfflineCapHours), 15, Color3.fromRGB(140, 100, 60)))
	end
	table.insert(labels, line("Collect it at your hive. Tap to close.", 14, Color3.fromRGB(140, 100, 60)))

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromScale(1, 1)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = ""
	closeBtn.ZIndex = 5
	closeBtn.Parent = card

	-- fade in
	TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 0 }):Play()
	for i, l in labels do
		task.delay(0.1 * i, function()
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end)
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local t = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		t:Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		for _, l in labels do
			TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		end
		t.Completed:Wait()
		card:Destroy()
	end
	closeBtn.Activated:Connect(close)
	task.delay(8, close)
end)
