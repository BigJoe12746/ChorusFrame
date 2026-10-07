-- PlotService (ModuleScript)
-- Gives every joining player their own farm plot, shows their name + avatar on the gate,
-- sends them home on spawn / "My Farm", enforces owner-only stations, and frees the plot
-- (clearing its Temp folder) when they leave.
--
-- Other systems should use:
--   PlotService.GetPlot(player)                 -> Model?  (the player's plot)
--   PlotService.GetPlotFromInstance(instance)   -> Model?  (which plot an object is in)
--   PlotService.IsOwner(player, instance)       -> boolean
--   PlotService.PlotAssigned / PlotReleased     -> BindableEvents (player, plot)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local PlotAllocator = require(Shared:WaitForChild("PlotAllocator"))
local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local ReturnRemote = Remotes:WaitForChild("ReturnToFarm") :: RemoteEvent

local PlotService = {}

local assignedEvent = Instance.new("BindableEvent")
local releasedEvent = Instance.new("BindableEvent")
local stationEvent = Instance.new("BindableEvent")
PlotService.PlotAssigned = assignedEvent.Event
PlotService.PlotReleased = releasedEvent.Event
-- (player, plot, stationName) — only fires after ownership and distance have been checked
PlotService.StationTriggered = stationEvent.Event
local touchCooldowns: { [BasePart]: { [Player]: number } } = {}
local TOUCH_COOLDOWN = 2

local plotsFolder: Folder
local plotModels: { [number]: Model } = {}
local allocator = PlotAllocator.new(Config.PlotCount)
local lastReturn: { [Player]: number } = {}
local promptLimiter = RateLimiter.new(Config.Limits.PromptsPerSecond, 1)

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

------------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------------

function PlotService.GetPlot(player: Player): Model?
	local id = allocator:GetPlotOf(player.UserId)
	return if id then plotModels[id] else nil
end

function PlotService.GetPlotFromInstance(inst: Instance?): Model?
	while inst and inst.Parent ~= plotsFolder do
		inst = inst.Parent
	end
	return inst :: Model?
end

function PlotService.IsOwner(player: Player, inst: Instance): boolean
	local plot = PlotService.GetPlotFromInstance(inst)
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

------------------------------------------------------------------------------
-- Owner sign
------------------------------------------------------------------------------

local function setSign(plot: Model, player: Player?)
	local sign = plot:FindFirstChild("OwnerSign", true)
	if not sign then
		return
	end
	for _, gui in sign:GetChildren() do
		if gui:IsA("SurfaceGui") then
			(gui :: any).OwnerName.Text = if player then player.DisplayName .. "'s Farm" else "Free Farm";
			(gui :: any).Subtitle.Text = if player then "@" .. player.Name else "Waiting for a beekeeper";
			(gui :: any).Avatar.Image = ""
		end
	end
	if not player then
		return
	end
	task.spawn(function()
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		-- the owner may have left while the thumbnail loaded
		if ok and plot:GetAttribute("OwnerUserId") == player.UserId then
			for _, gui in sign:GetChildren() do
				if gui:IsA("SurfaceGui") then
					(gui :: any).Avatar.Image = image
				end
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Teleporting
------------------------------------------------------------------------------

-- Moves the player's character to their farm entrance. Returns true on success.
function PlotService.SendHome(player: Player): boolean
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	if not plot or not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = plot:FindFirstChild("SpawnPoint") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root or not target then
		return false
	end
	humanoid.Sit = false
	-- slight sideways offset per call so two quick teleports never stack players inside each other
	local offset = Vector3.new(math.random(-20, 20) / 10, 0, 0)
	character:PivotTo(target.CFrame + target.CFrame:VectorToWorldSpace(offset))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- let Roblox finish placing the character at the default spawn first
	if character.Parent and player.Character == character then
		PlotService.SendHome(player)
	end
end

------------------------------------------------------------------------------
-- Assign / release
------------------------------------------------------------------------------

local function assign(player: Player, id: number)
	local plot = plotModels[id]
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.DisplayName)
	player:SetAttribute("PlotId", id)
	setSign(plot, player)
	notify(player, ("Welcome to %s! Plot %d is your farm."):format(Config.GameName, id), "success")
	assignedEvent:Fire(player, plot)
	if player.Character then
		PlotService.SendHome(player)
	end
end

local function clearPlot(plot: Model)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	setSign(plot, nil)
	local temp = plot:FindFirstChild("Temp")
	if temp then
		temp:ClearAllChildren()
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local id = allocator:Claim(player.UserId)
	if id then
		assign(player, id)
	else
		notify(player, "All farms are taken right now. You'll get the next free plot automatically!", "warning")
	end

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	lastReturn[player] = nil
	promptLimiter:Forget(player)
	local freedId, nextUserId = allocator:Release(player.UserId)
	if not freedId then
		return
	end
	local plot = plotModels[freedId]
	releasedEvent:Fire(player, plot)
	clearPlot(plot)

	-- hand the plot to the first queued player who is still in the server
	while nextUserId do
		local nextPlayer = Players:GetPlayerByUserId(nextUserId)
		if nextPlayer then
			assign(nextPlayer, freedId)
			break
		end
		_, nextUserId = allocator:Release(nextUserId)
	end
end

------------------------------------------------------------------------------
-- Remotes + station prompts
------------------------------------------------------------------------------

local function onReturnRequest(player: Player)
	local now = os.clock()
	if now - (lastReturn[player] or 0) < Config.ReturnCooldown then
		return
	end
	lastReturn[player] = now
	if not PlotService.GetPlot(player) then
		notify(player, "You don't have a farm yet. One is reserved for you as soon as it frees up.", "warning")
		return
	end
	if not PlotService.SendHome(player) then
		notify(player, "Can't travel right now. Try again after respawning.", "warning")
	end
end

-- Is the player's character close enough to this part to be using it?
local function withinReach(player: Player, part: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end
	local distance = (character:GetPivot().Position - part.Position).Magnitude
	return distance <= Config.PromptDistance + 10 -- slack for lag / big characters
end

-- Is the player close enough to one of their plot's stations to use it?
function PlotService.IsNearStation(player: Player, plot: Model, station: string): boolean
	local stations = plot:FindFirstChild("Stations")
	local model = stations and stations:FindFirstChild(station)
	local prompt = model and model:FindFirstChild("StationPrompt", true)
	local part = prompt and prompt.Parent
	return part ~= nil and part:IsA("BasePart") and withinReach(player, part)
end

local function hookPrompt(prompt: ProximityPrompt)
	prompt.Triggered:Connect(function(player)
		if not promptLimiter:Allow(player, os.clock()) then
			return -- flooding: a human can't press this fast
		end
		local plot = PlotService.GetPlotFromInstance(prompt)
		if not plot then
			return
		end
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then
			local owner = plot:GetAttribute("OwnerName")
			notify(player, if owner ~= "" then ("This is %s's farm. Only the owner can use it."):format(owner) else "This farm has no owner.", "warning")
			return
		end
		local part = prompt.Parent
		if not (part and part:IsA("BasePart") and withinReach(player, part)) then
			return -- too far away: ignore silently (likely lag or an exploit attempt)
		end
		local station = prompt:GetAttribute("Station")
		if type(station) == "string" then
			stationEvent:Fire(player, plot, station)
		end
	end)
end

local function hookStationPlate(plate: BasePart)
	-- Press-down squash (attribute-gated): the plate dips and pops back when a step
	-- registers on it. Rest pose is captured once at hook time; the debounce keeps
	-- repeated Touched events from stacking tweens mid-animation.
	local squashDebounce = false
	local restCf, restSize = plate.CFrame, plate.Size
	local function playSquash()
		if not plate:GetAttribute("SquashOnPress") or squashDebounce then
			return
		end
		squashDebounce = true
		local press = TweenService:Create(
			plate,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(restSize.X * 1.05, math.max(0.05, restSize.Y * 0.35), restSize.Z * 1.05),
				CFrame = restCf - Vector3.new(0, restSize.Y * 0.3, 0),
			}
		)
		local release = TweenService:Create(
			plate,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = restSize, CFrame = restCf }
		)
		press.Completed:Connect(function()
			task.wait(0.12)
			release.Completed:Connect(function()
				squashDebounce = false
			end)
			release:Play()
		end)
		press:Play()
	end
	plate.Touched:Connect(function(otherPart)
		local character = otherPart:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not player.Character or not character:IsDescendantOf(workspace) then
			return
		end
		local plot = PlotService.GetPlotFromInstance(plate)
		if not plot then
			return
		end
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		local now = os.clock()
		local playerCooldowns = touchCooldowns[plate]
		if not playerCooldowns then
			playerCooldowns = {}
			touchCooldowns[plate] = playerCooldowns
		end
		if now - (playerCooldowns[player] or 0) < TOUCH_COOLDOWN then
			return
		end
		playerCooldowns[player] = now
		local station = plate:GetAttribute("StationTouch")
		if type(station) == "string" then
			playSquash()
			stationEvent:Fire(player, plot, station)
		end
	end)
end

------------------------------------------------------------------------------

function PlotService.Start(map: Model)
	plotsFolder = map:WaitForChild("Plots") :: Folder
	for _, plot in plotsFolder:GetChildren() do
		local id = plot:GetAttribute("PlotId")
		if plot:IsA("Model") and type(id) == "number" then
			plotModels[id] = plot
			clearPlot(plot)
		end
	end
	for id = 1, Config.PlotCount do
		assert(plotModels[id], "Map is missing Plot" .. id)
	end

	for _, d in plotsFolder:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("OwnerOnly") then
			hookPrompt(d)
		elseif d:IsA("BasePart") and type(d:GetAttribute("StationTouch")) == "string" then
			hookStationPlate(d)
		end
	end

	ReturnRemote.OnServerEvent:Connect(onReturnRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlotService
