-- LeaderboardService (ModuleScript)
-- Village-square leaderboards: Most Rebirths, Most Time Played, Most Money Made.
--
--   MoneyMade  = the farm's lifetime earnings (FarmState Totals.Earned, part of the main save)
--   TimePlayed = seconds played; the session total is merged into a small per-player profile
--   Rebirths   = the player's "Rebirths" attribute; a rebirth feature only has to increase it
--
-- Every REFRESH_INTERVAL seconds the service writes each online player's numbers into one
-- OrderedDataStore per category, then reads the global top 10 back and paints the boards.
-- Without DataStores (Studio without API access, or an outage) the boards fall back to
-- ranking the players currently in this server, so they always show something.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local FarmService = require(script.Parent:WaitForChild("FarmService"))

local LeaderboardService = {}

local C = Config.Colors

local REFRESH_INTERVAL = 45
local TOP_N = 10
local BOARD_RADIUS = 47.5 -- studs from the village centre, just inside the plaza ring beam
local PROFILE_STORE = "HoneyFarm_PlayerStats_v1"

local CATEGORIES = {
	{ Id = "Rebirths", Title = "🏆 Most Rebirths" },
	{ Id = "TimePlayed", Title = "⏱ Most Time Played" },
	{ Id = "MoneyMade", Title = "💰 Most Money Made" },
}

local MILESTONES = {
	Rebirths = { 1, 5, 10, 25, 50, 100 },
	MoneyMade = { 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000 },
}

local stores: { [string]: any } = {}
local profileStore: any = nil
local available = false

-- Per-player session data: loaded totals + this session's played time.
local stats: { [Player]: { TimePlayed: number, Rebirths: number, Session: number } } = {}

-- boards[catId] = { Faces = { { Rows = ..., Footer = ... }, ... } }  (one entry per readable face)
local boards: { [string]: { Faces: { { Rows: { { Name: TextLabel, Value: TextLabel } }, Footer: TextLabel } } } } = {}

local nameCache: { [number]: string } = {}

local function ensureLeaderstats(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	return folder :: Folder
end

------------------------------------------------------------------------------
-- Formatting
------------------------------------------------------------------------------

local function fmtMoney(n: number): string
	return "$" .. Config.Progression.FormattedNumber(n)
end

local function fmtTime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm"):format(m)
end

local function fmtValue(catId: string, value: number): string
	if catId == "MoneyMade" then
		return fmtMoney(value)
	elseif catId == "TimePlayed" then
		return fmtTime(value)
	end
	return tostring(math.floor(value + 0.5))
end

local function nameFor(userId: number?): string
	if not userId then
		return "?"
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		return online.Name
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameAsync(userId :: number)
	end)
	local out = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = out
	return out
end

------------------------------------------------------------------------------
-- Stat sources
------------------------------------------------------------------------------

local function rebirthsOf(player: Player): number
	return tonumber(player:GetAttribute("Rebirths")) or 0
end

local function moneyMadeOf(player: Player): number
	local state = FarmService.GetState(player)
	if state then
		return state.Totals.Earned
	end
	return 0
end

local function timePlayedOf(player: Player): number
	local entry = stats[player]
	if not entry then
		return 0
	end
	return entry.TimePlayed + entry.Session
end

local function valueOf(catId: string, player: Player): number
	if catId == "Rebirths" then
		return rebirthsOf(player)
	elseif catId == "TimePlayed" then
		return timePlayedOf(player)
	elseif catId == "MoneyMade" then
		return moneyMadeOf(player)
	end
	return 0
end

------------------------------------------------------------------------------
-- Boards (built like MapBuilder scenery: posts + a cream panel with a SurfaceGui)
------------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function buildBoard(parent: Instance, cat: { [string]: any }, angle: number)
	local pos = Vector3.new(math.sin(angle) * BOARD_RADIUS, 0, math.cos(angle) * BOARD_RADIUS)
	local cf = CFrame.lookAt(pos, Vector3.zero) -- The Front face is oriented toward the village paths and spawn.

	local board = Instance.new("Model")
	board.Name = "Board_" .. cat.Id

	for _, x in { -10.4, 10.4 } do
		part(board, { Name = "Post", Size = Vector3.new(1.6, 25, 1.6), CFrame = cf * CFrame.new(x, 12.5, -0.9), Color = C.DarkWood, Material = Enum.Material.Wood })
	end
	local panel = part(board, { Name = "Panel", Size = Vector3.new(19, 23, 0.8), CFrame = cf * CFrame.new(0, 12.5, 0), Color = C.Cream })
	part(board, { Name = "Trim", Size = Vector3.new(19.8, 0.7, 1), CFrame = cf * CFrame.new(0, 24.35, 0), Color = C.Honey })
	part(board, { Name = "TrimBottom", Size = Vector3.new(19.8, 0.7, 1), CFrame = cf * CFrame.new(0, 1.35, 0), Color = C.Honey })

	-- The same content is painted on BOTH faces so the board reads from either side.
	local faces = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = face -- Front (-Z) faces the village paths, Back faces outward
		gui.PixelsPerStud = 50
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence = 0.2

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 170)
		title.BackgroundColor3 = C.Honey
		title.BorderSizePixel = 0
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = C.Text
		title.Text = cat.Title
		local titlePad = Instance.new("UIPadding")
		titlePad.PaddingLeft = UDim.new(0, 20)
		titlePad.PaddingRight = UDim.new(0, 20)
		titlePad.Parent = title
		title.Parent = gui

		local rows: { { Name: TextLabel, Value: TextLabel } } = {}
		for i = 1, TOP_N do
			local rowY = 190 + (i - 1) * 76
			local name = Instance.new("TextLabel")
			name.Name = "Row" .. i
			name.Position = UDim2.new(0, 20, 0, rowY)
			name.Size = UDim2.new(0.62, -20, 0, 68)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.FredokaOne
			name.TextScaled = true
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = C.Text
			name.Text = i .. ". —"
			name.Parent = gui

			local value = Instance.new("TextLabel")
			value.Name = "RowValue" .. i
			value.Position = UDim2.new(0.62, 0, 0, rowY)
			value.Size = UDim2.new(1, -20, 0, 68)
			value.AnchorPoint = Vector2.new(1, 0)
			value.BackgroundTransparency = 1
			value.Font = Enum.Font.FredokaOne
			value.TextScaled = true
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.TextColor3 = C.Text
			value.Text = "—"
			value.Parent = gui

			if i <= 3 then
				local medal = ({ Color3.fromRGB(196, 132, 0), Color3.fromRGB(118, 118, 138), Color3.fromRGB(172, 96, 38) })[i]
				name.TextColor3 = medal
				value.TextColor3 = medal
			end
			table.insert(rows, { Name = name, Value = value })
		end

		local footer = Instance.new("TextLabel")
		footer.Name = "Footer"
		footer.Position = UDim2.new(0, 0, 1, -64)
		footer.Size = UDim2.new(1, -24, 0, 48)
		footer.AnchorPoint = Vector2.new(0, 1)
		footer.BackgroundTransparency = 1
		footer.Font = Enum.Font.FredokaOne
		footer.TextScaled = true
		footer.TextColor3 = Color3.fromRGB(140, 100, 60)
		footer.Text = "Updated every minute"
		footer.Parent = gui

		gui.Parent = panel
		table.insert(faces, { Rows = rows, Footer = footer })
	end
	boards[cat.Id] = { Faces = faces }
	board.Parent = parent
end

local function buildBoards(map: Instance)
	local old = map:FindFirstChild("Leaderboards")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = "Leaderboards"
	-- one board per category, on the plaza ring just inside a plot path, facing the fountain
	for i, cat in CATEGORIES do
		buildBoard(holder, cat, math.rad((i - 1) * 120))
	end
	holder.Parent = map
end

------------------------------------------------------------------------------
-- Painting
------------------------------------------------------------------------------

local function milestoneProgress(catId: string, currentValue: number): string?
	local milestones = MILESTONES[catId]
	if not milestones then
		return nil
	end
	for _, milestone in milestones do
		if currentValue < milestone then
			if catId == "Rebirths" then
				return ("Next: %d rebirths (%d/%d)"):format(milestone, math.floor(currentValue + 0.5), milestone)
			end
			return ("Next: %s lifetime (%s)"):format(fmtMoney(milestone), fmtMoney(currentValue))
		end
	end
	return ("All milestones reached: %s"):format(fmtValue(catId, currentValue))
end

local function paintBoard(catId: string, top: { { Name: string, Value: number } })
	local board = boards[catId]
	if not board then
		return
	end
	local leader = top[1]
	local progress = if leader then milestoneProgress(catId, leader.Value) else nil
	for _, face in board.Faces do
		for i, row in face.Rows do
			local entry = top[i]
			if entry then
				row.Name.Text = i .. ". " .. entry.Name
				row.Value.Text = fmtValue(catId, entry.Value)
			else
				row.Name.Text = i .. ". —"
				row.Value.Text = "—"
			end
		end
		face.Footer.Text = progress or "Milestones appear when players rank"
	end
end

-- Global top 10 from the OrderedDataStore, or a local ranking of online players when
-- DataStores can't be used.
local function fetchTop(cat: { [string]: any }): { { Name: string, Value: number } }
	if not available then
		local localTop = {}
		for _, player in Players:GetPlayers() do
			table.insert(localTop, { Name = player.Name, Value = valueOf(cat.Id, player) })
		end
		table.sort(localTop, function(a, b)
			return a.Value > b.Value
		end)
		local out = {}
		for i = 1, math.min(TOP_N, #localTop) do
			out[i] = localTop[i]
		end
		return out
	end

	local ok, pages = pcall(function()
		return stores[cat.Id]:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[HoneyFarm Leaderboards] GetSortedAsync failed for " .. cat.Id .. ": " .. tostring(pages))
		return {}
	end
	local out = {}
	for _, entry in pages:GetCurrentPage() do
		local value = tonumber(entry.value) or 0
		if value > 0 then
			table.insert(out, { Name = nameFor(tonumber(entry.key)), Value = value })
			if #out >= TOP_N then
				break
			end
		end
	end
	return out
end

local function flushPlayer(userId: number, player: Player?)
	-- ordered stores per category
	if available then
		for _, cat in CATEGORIES do
			local ok, err = pcall(function()
				stores[cat.Id]:SetAsync(tostring(userId), math.floor(valueOf(cat.Id, player :: Player) + 0.5))
			end)
			if not ok then
				warn("[HoneyFarm Leaderboards] SetAsync failed for " .. cat.Id .. ": " .. tostring(err))
			end
		end
		-- per-player profile (time played + rebirths survive even without a farm save)
		if player then
			local data = {
				TimePlayed = math.floor(timePlayedOf(player) + 0.5),
				Rebirths = rebirthsOf(player),
				SavedAt = os.time(),
			}
			local ok, err = pcall(function()
				profileStore:SetAsync("user_" .. userId, data)
			end)
			if not ok then
				warn("[HoneyFarm Leaderboards] Profile save failed: " .. tostring(err))
			end
		end
	end
end

------------------------------------------------------------------------------
-- Player lifecycle
------------------------------------------------------------------------------

local function ensureLeaderstatValues(player: Player)
	local folder = ensureLeaderstats(player)
	local values = {
		{ "Rebirths", rebirthsOf(player) },
		{ "TimePlayed", math.floor(timePlayedOf(player) / 60 + 0.5) }, -- minutes
		{ "MoneyMade", math.floor(moneyMadeOf(player) + 0.5) },
	}
	for _, v in values do
		local stat = folder:FindFirstChild(v[1])
		if not stat then
			stat = Instance.new("IntValue")
			stat.Name = v[1]
			stat.Parent = folder
		end
		(stat :: IntValue).Value = v[2]
	end
end

local function addPlayer(player: Player)
	local entry = { TimePlayed = 0, Rebirths = 0, Session = 0 }
	stats[player] = entry
	if available then
		local ok, data = pcall(function()
			return profileStore:GetAsync("user_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			entry.TimePlayed = tonumber(data.TimePlayed) or 0
			entry.Rebirths = tonumber(data.Rebirths) or 0
		end
	end
	player:SetAttribute("Rebirths", math.max(entry.Rebirths, rebirthsOf(player)))
	ensureLeaderstatValues(player)
end

local function removePlayer(player: Player)
	local entry = stats[player]
	stats[player] = nil
	if entry and available then
		local data = {
			TimePlayed = math.floor(entry.TimePlayed + entry.Session + 0.5),
			Rebirths = rebirthsOf(player),
			SavedAt = os.time(),
		}
		pcall(function()
			profileStore:SetAsync("user_" .. player.UserId, data)
		end)
	end
end

------------------------------------------------------------------------------
-- Loop
------------------------------------------------------------------------------

local function updateLeaderstats()
	for player, _ in stats do
		ensureLeaderstatValues(player)
	end
end

local function ensurePlayerNames()
	for _, player in Players:GetPlayers() do
		if player.Parent == Players and stats[player] then
			nameCache[player.UserId] = player.Name
		end
	end
end

local function refresh()
	for player in stats do
		flushPlayer(player.UserId, player)
	end
	for _, cat in CATEGORIES do
		paintBoard(cat.Id, fetchTop(cat))
	end
end

function LeaderboardService.Start(map: Instance)
	-- DataStores (optional)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(PROFILE_STORE)
	end)
	if ok and result then
		profileStore = result
		for _, cat in CATEGORIES do
			local okOrdered, ordered = pcall(function()
				return DataStoreService:GetOrderedDataStore("HoneyFarm_LB_" .. cat.Id .. "_v1")
			end)
			if okOrdered and ordered then
				stores[cat.Id] = ordered
			end
		end
		available = next(stores) ~= nil
		if not available then
			warn("[HoneyFarm Leaderboards] OrderedDataStores unavailable; boards show this server only")
		end
	else
		available = false
		if RunService:IsStudio() then
			warn("[HoneyFarm Leaderboards] DataStores off in Studio; boards show this server only")
		end
	end

	buildBoards(map)

	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)

	-- play time + playerlist values
	local sinceListUpdate = 0
	RunService.Heartbeat:Connect(function(dt)
		for _, entry in stats do
			entry.Session += dt
		end
		sinceListUpdate += dt
		if sinceListUpdate >= 5 then
			sinceListUpdate = 0
			updateLeaderstats()
		end
	end)

	-- Initial refresh waits for farm saves and player stats to load.
	task.spawn(function()
		task.wait(3)
		while true do
			ensurePlayerNames()
			pcall(refresh)
			task.wait(REFRESH_INTERVAL)
		end
	end)
	game:BindToClose(function()
		for player in stats do
			flushPlayer(player.UserId, player)
		end
	end)

	print("[HoneyFarm Leaderboards] started (DataStores " .. (available and "on" or "off") .. ")")
end

return LeaderboardService
