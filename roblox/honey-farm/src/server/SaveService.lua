-- SaveService (ModuleScript)
-- Loads and saves each player's farm with DataStores.
--
--   SaveService.Load(player)  -> data?, ok      ok=false means the load FAILED (not "new player")
--   SaveService.Save(player, data, loadedAt)    writes with UpdateAsync; refuses to overwrite a
--                                               newer save (another server wrote after we loaded)
--   SaveService.Available                       false when DataStores can't be used (Studio without
--                                               API access, or an outage at startup)
--
-- Rules that keep progress safe:
--   * A player whose load failed is never saved (that would overwrite their real progress).
--   * Writes compare SavedAt and give up if the stored save is newer than the one we loaded.
--   * Retries with backoff; every error is pcall'd and logged, never thrown at callers.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local SaveService = {}
SaveService.Available = false
SaveService.Reason = "not started"
SaveService.Now = os.time -- tests override this to simulate time passing

local store: any = nil

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function tryCall(label: string, fn: () -> any, retries: number): (boolean, any)
	local delay = 1
	for attempt = 1, retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[HoneyFarm Save] %s failed (attempt %d/%d): %s"):format(label, attempt, retries, tostring(result)))
		if attempt < retries then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

function SaveService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.StoreName)
	end)
	if ok and result then
		store = result
		SaveService.Available = true
		SaveService.Reason = ""
	else
		store = nil
		SaveService.Available = false
		SaveService.Reason = if RunService:IsStudio()
			then "Studio: turn on Game Settings → Security → Enable Studio Access to API Services"
			else "DataStores unavailable: " .. tostring(result)
		warn("[HoneyFarm Save] Saving is OFF this session. " .. SaveService.Reason)
	end
end

-- Returns (data, true) on success (data is nil for a brand-new player) or (nil, false) if the
-- load failed and the player's progress must not be overwritten this session.
function SaveService.Load(player: Player): (any, boolean)
	if not SaveService.Available then
		return nil, false
	end
	local ok, data = tryCall("load " .. player.Name, function()
		return store:GetAsync(key(player))
	end, Config.Save.LoadRetries)
	if not ok then
		return nil, false
	end
	if data ~= nil and type(data) ~= "table" then
		warn("[HoneyFarm Save] Corrupt save for " .. player.Name .. "; starting fresh without saving")
		return nil, false
	end
	return data, true
end

-- `loadedSavedAt` is the SavedAt of the data this session loaded (0 for a new player).
-- Returns true if the save was written.
function SaveService.Save(player: Player, data: { [string]: any }, loadedSavedAt: number): boolean
	if not SaveService.Available then
		return false
	end
	local skipped = false
	local ok = tryCall("save " .. player.Name, function()
		return store:UpdateAsync(key(player), function(old)
			if type(old) == "table" and type(old.SavedAt) == "number" and old.SavedAt > loadedSavedAt and old.SavedAt > (data.SavedAt or 0) then
				-- another server saved this player after we loaded them: keep theirs
				skipped = true
				return nil
			end
			return data
		end)
	end, 2)
	if skipped then
		warn("[HoneyFarm Save] Skipped saving " .. player.Name .. ": a newer save exists")
		return false
	end
	return ok
end

return SaveService
