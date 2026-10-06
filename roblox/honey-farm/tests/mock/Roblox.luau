-- Tiny stand-in for the Roblox engine so server code can run under the plain `luau` CLI.
-- Covers only what HONEY FARM uses. It is NOT a physics/rendering engine: it lets us check
-- that scripts run without errors and produce the expected instances/state.

local M = {}

------------------------------------------------------------------------------
-- Vector3
------------------------------------------------------------------------------
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return V3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V3[k]
end
function V3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, V3)
end
V3.__add = function(a, b)
	return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return V3.new(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return V3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return V3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	return V3.new(a.X / b, a.Y / b, a.Z / b)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3.Cross(a, b)
	return V3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
V3.zero = V3.new(0, 0, 0)
V3.one = V3.new(1, 1, 1)
V3.xAxis = V3.new(1, 0, 0)
V3.yAxis = V3.new(0, 1, 0)
V3.zAxis = V3.new(0, 0, 1)
M.Vector3 = V3

local Vector2 = { new = function(x, y)
	return { X = x, Y = y }
end }
M.Vector2 = Vector2

------------------------------------------------------------------------------
-- CFrame: position p + rotation columns rx, ry, rz
------------------------------------------------------------------------------
local CF = {}
local function mk(p, rx, ry, rz)
	return setmetatable({ p = p, rx = rx, ry = ry, rz = rz, __type = "CFrame" }, CF)
end
local function rot(cf, v)
	return cf.rx * v.X + cf.ry * v.Y + cf.rz * v.Z
end
CF.__index = function(cf, k)
	if k == "Position" then
		return cf.p
	elseif k == "LookVector" then
		return -cf.rz
	elseif k == "RightVector" then
		return cf.rx
	elseif k == "UpVector" or k == "YVector" then
		return cf.ry
	elseif k == "XVector" then
		return cf.rx
	elseif k == "ZVector" then
		return cf.rz
	elseif k == "Rotation" then
		return mk(V3.zero, cf.rx, cf.ry, cf.rz)
	elseif k == "X" then
		return cf.p.X
	elseif k == "Y" then
		return cf.p.Y
	elseif k == "Z" then
		return cf.p.Z
	end
	return CF[k]
end
function CF.new(x, y, z)
	local p = if type(x) == "table" then x else V3.new(x or 0, y or 0, z or 0)
	return mk(p, V3.xAxis, V3.yAxis, V3.zAxis)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(V3.zero, V3.new(1, 0, 0), V3.new(0, c, s), V3.new(0, -s, c))
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(V3.zero, V3.new(c, 0, -s), V3.new(0, 1, 0), V3.new(s, 0, c))
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(V3.zero, V3.new(c, s, 0), V3.new(-s, c, 0), V3.new(0, 0, 1))
end
function CF.Angles(x, y, z)
	return rx(x) * ry(y) * rz(z)
end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.lookAt(pos, target)
	local look = (target - pos).Unit
	local right = look:Cross(V3.yAxis).Unit
	local up = right:Cross(look)
	return mk(pos, right, up, -look)
end
function CF.fromMatrix(pos, vx, vy, vz)
	return mk(pos, vx, vy, vz or vx:Cross(vy))
end
CF.__mul = function(a, b)
	if b.__type == "Vector3" then
		return a.p + rot(a, b)
	end
	return mk(a.p + rot(a, b.p), rot(a, b.rx), rot(a, b.ry), rot(a, b.rz))
end
CF.__add = function(a, v)
	return mk(a.p + v, a.rx, a.ry, a.rz)
end
CF.__sub = function(a, v)
	return mk(a.p - v, a.rx, a.ry, a.rz)
end
function CF.Inverse(cf)
	-- transpose of the rotation, position = -R^T p
	local rx, ry, rz = cf.rx, cf.ry, cf.rz
	local nrx = V3.new(rx.X, ry.X, rz.X)
	local nry = V3.new(rx.Y, ry.Y, rz.Y)
	local nrz = V3.new(rx.Z, ry.Z, rz.Z)
	local p = cf.p
	local np = V3.new(-(nrx.X * p.X + nry.X * p.Y + nrz.X * p.Z), -(nrx.Y * p.X + nry.Y * p.Y + nrz.Y * p.Z), -(nrx.Z * p.X + nry.Z * p.Y + nrz.Z * p.Z))
	return mk(np, nrx, nry, nrz)
end
function CF.VectorToWorldSpace(cf, v)
	return rot(cf, v)
end
function CF.PointToWorldSpace(cf, v)
	return cf * v
end
function CF.PointToObjectSpace(cf, v)
	local d = v - cf.p
	return V3.new(d:Dot(cf.rx), d:Dot(cf.ry), d:Dot(cf.rz))
end
function CF.VectorToObjectSpace(cf, v)
	return V3.new(v:Dot(cf.rx), v:Dot(cf.ry), v:Dot(cf.rz))
end
CF.identity = CF.new()
M.CFrame = CF

------------------------------------------------------------------------------
-- Small datatypes
------------------------------------------------------------------------------
M.Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	fromHex = function(h)
		h = h:gsub("#", "")
		return { R = tonumber(h:sub(1, 2), 16) / 255, G = tonumber(h:sub(3, 4), 16) / 255, B = tonumber(h:sub(5, 6), 16) / 255 }
	end,
}
M.UDim = { new = function(s, o)
	return { Scale = s, Offset = o }
end }
M.UDim2 = {
	new = function(a, b, c, d)
		return { a, b, c, d }
	end,
	fromOffset = function(x, y)
		return { 0, x, 0, y }
	end,
	fromScale = function(x, y)
		return { x, 0, y, 0 }
	end,
}
M.TweenInfo = { new = function(...)
	return { ... }
end }
M.Random = {
	new = function(seed)
		local s = seed or 1
		local function nxt()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * nxt()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nxt() * (b - a + 1))
			end,
		}
	end,
}

-- Enum.X.Y -> { Name = "Y", EnumType = "X" }
M.Enum = setmetatable({}, {
	__index = function(_, typ)
		return setmetatable({}, {
			__index = function(_, name)
				return { Name = name, EnumType = typ }
			end,
		})
	end,
})

------------------------------------------------------------------------------
-- Signals
------------------------------------------------------------------------------
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, h in self.handlers do
			h(...)
		end
	end
	function s:Wait() end
	return s
end
M.Signal = Signal

------------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------------
local BASEPARTS = { Part = true, SpawnLocation = true, Seat = true }
local ISA = {
	BasePart = BASEPARTS,
	Model = { Model = true },
	Folder = { Folder = true },
	SurfaceGui = { SurfaceGui = true },
	ProximityPrompt = { ProximityPrompt = true },
	Decal = { Decal = true },
	TextLabel = { TextLabel = true },
	Camera = { Camera = true },
	Humanoid = { Humanoid = true },
	LuaSourceContainer = { Script = true, LocalScript = true, ModuleScript = true },
}

local Instance = {}
M.Instance = Instance
M.created = 0

local InstMT = {}
function InstMT.__index(self, k)
	local raw = rawget(self, "_props")
	if raw[k] ~= nil then
		return raw[k]
	end
	local method = Instance[k]
	if method then
		return method
	end
	if k == "Parent" then
		return nil
	end
	local child = Instance.FindFirstChild(self, k)
	if child then
		return child
	end
	return nil
end
function InstMT.__newindex(self, k, v)
	local raw = rawget(self, "_props")
	if k == "Parent" then
		local old = raw.Parent
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		raw.Parent = v
		if v then
			table.insert(rawget(v, "_children"), self)
			local p = v
			while p do
				rawget(p, "_descAdded"):Fire(self)
				p = rawget(p, "_props").Parent
			end
			rawget(v, "_childAdded"):Fire(self)
		end
		return
	end
	raw[k] = v
	if k == "CFrame" and raw.ClassName ~= "Model" then
		raw.Position = v.Position
	end
end
InstMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

function Instance.new(className)
	M.created += 1
	local self = setmetatable({
		_props = { ClassName = className, Name = className },
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_descAdded = Signal(),
		_childAdded = Signal(),
	}, InstMT)
	local raw = rawget(self, "_props")
	if className == "BindableEvent" or className == "RemoteEvent" then
		local ev = Signal()
		raw.Event = ev
		raw.OnServerEvent = Signal()
		raw.OnClientEvent = Signal()
		raw.fired = {}
		raw.Fire = function(_, ...)
			ev:Fire(...)
		end
		raw.FireClient = function(_, player, ...)
			table.insert(raw.fired, { player, ... })
		end
		raw.FireAllClients = function(_, ...)
			table.insert(raw.fired, { "all", ... })
		end
	elseif className == "ProximityPrompt" then
		raw.Triggered = Signal()
		raw.Enabled = true
	elseif BASEPARTS[className] then
		raw.Size = V3.new(4, 1, 2)
		raw.CFrame = CF.new()
		raw.Transparency = 0
		raw.CanCollide = true
	end
	raw.ChildAdded = rawget(self, "_childAdded")
	raw.DescendantAdded = rawget(self, "_descAdded")
	return self
end

function Instance.IsA(self, class)
	local c = rawget(self, "_props").ClassName
	return c == class or (ISA[class] ~= nil and ISA[class][c] == true)
end
function Instance.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Instance.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Instance.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local f = Instance.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Instance.FindFirstChildOfClass(self, class)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").ClassName == class then
			return c
		end
	end
	return nil
end
function Instance.WaitForChild(self, name)
	local c = Instance.FindFirstChild(self, name)
	assert(c, "WaitForChild would hang forever: " .. tostring(self) .. "." .. name)
	return c
end
function Instance.ClearAllChildren(self)
	for _, c in Instance.GetChildren(self) do
		c.Parent = nil
	end
end
function Instance.Destroy(self)
	self.Parent = nil
end
function Instance.Clone(self)
	local copy = Instance.new(rawget(self, "_props").ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" and k ~= "ChildAdded" and k ~= "DescendantAdded" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		local cc = Instance.Clone(c)
		cc.Parent = copy
	end
	return copy
end
function Instance.GetPivot(self)
	local raw = rawget(self, "_props")
	if raw.ClassName == "Model" then
		if raw.Pivot then
			return raw.Pivot
		end
		if raw.PrimaryPart then
			return raw.PrimaryPart.CFrame
		end
		return raw.WorldPivot or CF.new()
	end
	return raw.CFrame
end
function Instance.GetScale(self)
	return rawget(self, "_props").Scale or 1
end
function Instance.ScaleTo(self, s)
	rawget(self, "_props").Scale = s
end
function Instance.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
	local sig = rawget(self, "_attrSignals")[k]
	if sig then
		sig:Fire()
	end
end
function Instance.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function Instance.GetAttributeChangedSignal(self, k)
	local sigs = rawget(self, "_attrSignals")
	sigs[k] = sigs[k] or Signal()
	return sigs[k]
end
function Instance.IsDescendantOf(self, other)
	local p = rawget(self, "_props").Parent
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "_props").Parent
	end
	return false
end
function Instance.PivotTo(self, cf)
	local raw = rawget(self, "_props")
	if raw.ClassName ~= "Model" then
		raw.CFrame = cf
		raw.Position = cf.Position
		return
	end
	-- like Roblox: move every part by the same transform the pivot moves by
	local old = Instance.GetPivot(self)
	local delta = cf * CF.Inverse(old)
	for _, d in Instance.GetDescendants(self) do
		local dr = rawget(d, "_props")
		if BASEPARTS[dr.ClassName] and dr.CFrame then
			dr.CFrame = delta * dr.CFrame
			dr.Position = dr.CFrame.Position
		end
	end
	raw.Pivot = cf
end
-- Axis-aligned box around all parts (ignores part rotation), scaled about the pivot.
function Instance.GetBoundingBox(self)
	local scale = rawget(self, "_props").Scale or 1
	local pivot = Instance.GetPivot(self).Position
	local minV, maxV
	for _, d in Instance.GetDescendants(self) do
		local dr = rawget(d, "_props")
		if BASEPARTS[dr.ClassName] and dr.CFrame then
			local pos = pivot + (dr.CFrame.Position - pivot) * scale
			local half = dr.Size * (scale / 2)
			local lo, hi = pos - half, pos + half
			if not minV then
				minV, maxV = lo, hi
			else
				minV = V3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z))
				maxV = V3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z))
			end
		end
	end
	if not minV then
		return CF.new(), V3.zero
	end
	return CF.new((minV + maxV) / 2), maxV - minV
end
function Instance.GetExtentsSize(self)
	local _, size = Instance.GetBoundingBox(self)
	return size
end
function Instance.FindFirstChildWhichIsA(self, class, recursive)
	local list = if recursive then Instance.GetDescendants(self) else rawget(self, "_children")
	for _, c in list do
		if Instance.IsA(c, class) then
			return c
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- DataModel
------------------------------------------------------------------------------
function M.newGame()
	local game = Instance.new("DataModel")
	local workspace = Instance.new("Workspace")
	workspace.Name = "Workspace"
	workspace.Parent = game
	local services = {}
	for _, name in { "ReplicatedStorage", "ServerScriptService", "Players", "TweenService", "UserInputService", "RunService", "DataStoreService" } do
		local s = Instance.new(name)
		s.Name = name
		s.Parent = game
		services[name] = s
	end
	rawget(game, "_props").GetService = function(_, n)
		return services[n]
	end

	rawget(services.RunService, "_props").Heartbeat = Signal()
	rawget(services.RunService, "_props").IsStudio = function()
		return true
	end
	rawget(game, "_props").BindToClose = function(_, fn)
		rawget(game, "_props").closeHandlers = rawget(game, "_props").closeHandlers or {}
		table.insert(rawget(game, "_props").closeHandlers, fn)
	end

	-- In-memory DataStore. Test knobs on M.datastore: unavailable, failNext, calls, data[key]
	local ds = { data = {}, calls = 0, failNext = 0, unavailable = false }
	M.datastore = ds
	local function deepcopy(v)
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in v do
			out[k] = deepcopy(x)
		end
		return out
	end
	local store = {}
	function store:GetAsync(key)
		ds.calls += 1
		if ds.failNext > 0 then
			ds.failNext -= 1
			error("DataStore request failed (simulated)")
		end
		return deepcopy(ds.data[key])
	end
	function store:UpdateAsync(key, fn)
		ds.calls += 1
		if ds.failNext > 0 then
			ds.failNext -= 1
			error("DataStore request failed (simulated)")
		end
		local new = fn(deepcopy(ds.data[key]))
		if new ~= nil then
			ds.data[key] = deepcopy(new)
		end
		return deepcopy(ds.data[key])
	end
	rawget(services.DataStoreService, "_props").GetDataStore = function(_, name)
		if ds.unavailable then
			error("DataStore API access is not enabled (simulated Studio)")
		end
		ds.name = name
		return store
	end

	-- Players service
	local Players = services.Players
	local PP = rawget(Players, "_props")
	PP.PlayerAdded = Signal()
	PP.PlayerRemoving = Signal()
	PP.list = {}
	PP.GetPlayers = function()
		return table.clone(PP.list)
	end
	PP.GetPlayerByUserId = function(_, id)
		for _, p in PP.list do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	PP.GetUserThumbnailAsync = function(_, id)
		return "rbxthumb://type=AvatarHeadShot&id=" .. id .. "&w=180&h=180", true
	end

	return game, workspace, services
end

-- A fake player with a character standing at the default spawn.
function M.newPlayer(game, userId, name)
	local Players = game:GetService("Players")
	local p = Instance.new("Player")
	local raw = rawget(p, "_props")
	raw.UserId = userId
	raw.Name = name
	raw.DisplayName = name
	raw.CharacterAdded = Signal()
	function raw.spawnCharacter()
		local char = Instance.new("Model")
		char.Name = name
		local hum = Instance.new("Humanoid")
		rawget(hum, "_props").Health = 100
		hum.Parent = char
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = char
		char:PivotTo(M.CFrame.new(0, 3, 24))
		-- like Roblox: the character is already in workspace when CharacterAdded fires
		char.Parent = game:FindFirstChild("Workspace")
		raw.Character = char
		raw.CharacterAdded:Fire(char)
		return char
	end
	table.insert(rawget(Players, "_props").list, p)
	p.Parent = Players
	rawget(Players, "_props").PlayerAdded:Fire(p)
	return p
end

function M.removePlayer(game, p)
	local Players = game:GetService("Players")
	local PP = rawget(Players, "_props")
	PP.PlayerRemoving:Fire(p)
	table.remove(PP.list, table.find(PP.list, p))
	p.Parent = nil
end

-- Synchronous task library (good enough for logic tests)
M.task = {
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function() end,
	wait = function()
		return 0
	end,
}

return M
