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

local Shared = ReplicatedStorage:WaitForChild("HoneyFarm")
local Config = require(Shared:WaitForChild("Config"))
local PlotAllocator = require(Shared:WaitForChild("PlotAllocator"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local ReturnRemote = Remotes:WaitForChild("ReturnToFarm") :: RemoteEvent

local PlotService = {}

local assignedEvent = Instance.new("BindableEvent")
local releasedEvent = Instance.new("BindableEvent")
PlotService.PlotAssigned = assignedEvent.Event
PlotService.PlotReleased = releasedEvent.Event

local plotsFolder: Folder
local plotModels: { [number]: Model } = {}
local allocator = PlotAllocator.new(Config.PlotCount)
local lastReturn: { [Player]: number } = {}

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

local function hookPrompt(prompt: ProximityPrompt)
	prompt.Triggered:Connect(function(player)
		local plot = PlotService.GetPlotFromInstance(prompt)
		if not plot then
			return
		end
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then
			local owner = plot:GetAttribute("OwnerName")
			notify(player, if owner ~= "" then ("This is %s's farm. Only the owner can use it."):format(owner) else "This farm has no owner.", "warning")
			return
		end
		-- Phase 1: stations are placed but not functional yet.
		local station = prompt:GetAttribute("Station")
		local info = Config.Stations[station]
		notify(player, ((info and info.Label) or "This station") .. " opens in the next update!", "info")
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
