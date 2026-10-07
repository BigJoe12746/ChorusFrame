--!strict
-- BeeAppearance (shared ModuleScript)
-- Turns the one bee template (ReplicatedStorage.Assets.BeeTemplate) into any tier:
-- recolours the parts by role, bolts on the tier's accessory (clover, crown, ...),
-- re-pivots the model so "forward" is the head and "up" is the wings, then scales it.
-- Works on the server (farm bees) and on the client (shop previews in ViewportFrames).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local BeeAppearance = {}

-- Template colours (the original model)
local YELLOW = Color3.fromRGB(255, 255, 0)
local DARK = Color3.fromRGB(27, 42, 53)
local WING = Color3.fromRGB(159, 243, 233)
local EYE = Color3.fromRGB(17, 17, 17)

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

------------------------------------------------------------------------------
-- Roles: every template part is named "Part", so work out its job once.
------------------------------------------------------------------------------

local function classify(part: BasePart, root: Model): string?
	if part.Parent ~= root then
		return "Antenna" -- the two antennae are sub-models
	end
	local c = part.Color
	if same(c, WING) then
		return "Wing"
	elseif same(c, EYE) then
		return "Eye"
	elseif same(c, YELLOW) then
		return if part.Size.Z > 3 then "Head" else "BodyStripe" -- the thick yellow block is the head
	elseif same(c, DARK) then
		return "DarkStripe"
	end
	return nil
end

function BeeAppearance.PrepareTemplate(template: Model)
	if template:GetAttribute("BeePrepared") then
		return
	end
	local counts: { [string]: number } = {}
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			local role = classify(d, template)
			if role then
				counts[role] = (counts[role] or 0) + 1
				d:SetAttribute("BeeRole", role)
				d.Name = role .. counts[role]
			end
		end
	end
	template:SetAttribute("BeePrepared", true)
end

------------------------------------------------------------------------------
-- Part helpers (all accessories are built in the head's local space:
-- X = left/right, Y = up, Z = forward; head is ~7.8 wide, 5.4 tall, 3.9 deep)
------------------------------------------------------------------------------

local function newPart(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function ball(parent: Instance, cf: CFrame, d: number, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = cf, Color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return newPart(parent, props)
end

local function block(parent: Instance, cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Size = size, CFrame = cf, Color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return newPart(parent, props)
end

-- Cylinder whose axis points along the local Y of `cf`.
local function discY(parent: Instance, cf: CFrame, d: number, h: number, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return newPart(parent, props)
end

-- Cylinder whose axis points along the local Z of `cf`.
local function discZ(parent: Instance, cf: CFrame, d: number, h: number, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		props[k] = v
	end
	return newPart(parent, props)
end

------------------------------------------------------------------------------
-- Accessories
------------------------------------------------------------------------------

type Ctx = { Folder: Folder, Head: BasePart, Top: number, Look: { [string]: any }, Eyes: { BasePart } }

local accessories: { [string]: (Ctx) -> () } = {}

function accessories.Clover(c: Ctx)
	local green = Color3.fromRGB(46, 160, 67)
	local H = c.Head.CFrame
	discY(c.Folder, H * CFrame.new(0, c.Top + 1.2, 0), 0.6, 2.4, Color3.fromRGB(60, 120, 50))
	local top = H * CFrame.new(0, c.Top + 2.8, 0)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		ball(c.Folder, top * CFrame.new(math.cos(a) * 1.1, 0, math.sin(a) * 1.1), 2.1, green)
	end
end

function accessories.Daisy(c: Ctx)
	local H = c.Head.CFrame
	discY(c.Folder, H * CFrame.new(0, c.Top + 0.9, 0), 0.6, 1.8, Color3.fromRGB(90, 170, 70))
	local center = H * CFrame.new(0, c.Top + 1.9, 0)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		discY(c.Folder, center * CFrame.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6), 2.0, 0.4, Color3.new(1, 1, 1))
	end
	ball(c.Folder, center * CFrame.new(0, 0.3, 0), 1.8, Color3.fromRGB(255, 200, 40))
end

function accessories.Strawberry(c: Ctx)
	local H = c.Head.CFrame
	local seed = Color3.fromRGB(40, 30, 20)
	-- seeds on the sides and front of the head
	for _, o in { { -2.4, 1.2, 2.0 }, { 2.4, 1.2, 2.0 }, { -1.2, -0.8, 2.0 }, { 1.2, -0.8, 2.0 }, { 0, 1.8, 2.0 },
		{ -3.9, 1.0, 0.5 }, { -3.9, -1.2, -0.8 }, { 3.9, 1.0, 0.5 }, { 3.9, -1.2, -0.8 } } do
		ball(c.Folder, H * CFrame.new(o[1], o[2], o[3]), 0.7, seed)
	end
	-- leafy cap
	local leaf = Color3.fromRGB(60, 170, 70)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		block(c.Folder, H * CFrame.new(0, c.Top + 0.25, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.7, 0, 0) * CFrame.Angles(0, 0, math.rad(-18)), Vector3.new(3.2, 0.3, 1.4), leaf)
	end
	discY(c.Folder, H * CFrame.new(0, c.Top + 1.1, 0), 0.6, 1.8, Color3.fromRGB(70, 120, 50))
end

function accessories.Panda(c: Ctx)
	local black = Color3.fromRGB(20, 20, 20)
	local H = c.Head.CFrame
	for _, x in { -3.0, 3.0 } do
		ball(c.Folder, H * CFrame.new(x, c.Top + 0.6, -0.6), 2.8, black)
	end
	for _, eye in c.Eyes do
		discZ(c.Folder, eye.CFrame * CFrame.new(0, 0, -0.45), 3.6, 0.4, black)
	end
end

function accessories.Knight(c: Ctx)
	local steel = Color3.fromRGB(150, 160, 175)
	local H = c.Head.CFrame
	local size = c.Head.Size
	-- helmet shell over the top half of the head
	block(c.Folder, H * CFrame.new(0, size.Y * 0.28, -0.1), Vector3.new(size.X + 0.6, size.Y * 0.5, size.Z + 0.6), steel, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	-- visor slit
	block(c.Folder, H * CFrame.new(0, size.Y * 0.1, size.Z / 2 + 0.35), Vector3.new(size.X * 0.7, 0.5, 0.3), Color3.fromRGB(30, 30, 40))
	-- plume
	block(c.Folder, H * CFrame.new(0, c.Top + 1.5, -0.6), Vector3.new(0.7, 2.6, 3.6), Color3.fromRGB(220, 50, 60))
	ball(c.Folder, H * CFrame.new(0, c.Top + 2.9, -2.2), 1.3, Color3.fromRGB(220, 50, 60))
end

function accessories.Crystal(c: Ctx)
	local H = c.Head.CFrame
	local shard = Color3.fromRGB(120, 230, 255)
	for i, o in { { 0, c.Top, 0, 0 }, { -2, c.Top, -1.5, -0.4 }, { 2, c.Top, -1.0, 0.4 }, { -1, c.Top, -4.5, -0.25 }, { 1.2, c.Top, -6.5, 0.3 } } do
		local h = 3.4 - (i - 1) * 0.35
		block(c.Folder, H * CFrame.new(o[1], o[2] + h / 2 - 0.3, o[3]) * CFrame.Angles(math.rad(-15), 0, o[4]), Vector3.new(0.9, h, 0.9), shard, { Material = Enum.Material.Neon, Transparency = 0.15 })
	end
end

function accessories.Storm(c: Ctx)
	local H = c.Head.CFrame
	local grey = Color3.fromRGB(120, 125, 140)
	local top = H * CFrame.new(0, c.Top + 3.2, -0.5)
	ball(c.Folder, top, 3.4, grey)
	ball(c.Folder, top * CFrame.new(-2.1, -0.3, 0.2), 2.6, grey)
	ball(c.Folder, top * CFrame.new(2.1, -0.2, -0.3), 2.8, grey)
	local bolt = Color3.fromRGB(255, 241, 77)
	block(c.Folder, H * CFrame.new(0.5, c.Top + 1.4, 1.6) * CFrame.Angles(0, 0, math.rad(25)), Vector3.new(0.4, 1.8, 0.4), bolt, { Material = Enum.Material.Neon })
	block(c.Folder, H * CFrame.new(-0.2, c.Top + 0.3, 1.6) * CFrame.Angles(0, 0, math.rad(-30)), Vector3.new(0.4, 1.6, 0.4), bolt, { Material = Enum.Material.Neon })
end

function accessories.Galaxy(c: Ctx)
	local H = c.Head.CFrame
	local ring = H * CFrame.new(0, 0.6, -3.5) * CFrame.Angles(math.rad(18), 0, math.rad(8))
	discY(c.Folder, ring, 13, 0.25, Color3.fromRGB(190, 110, 255), { Material = Enum.Material.Neon, Transparency = 0.45 })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		ball(c.Folder, ring * CFrame.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5), 0.9, Color3.new(1, 1, 1), { Material = Enum.Material.Neon })
	end
end

function accessories.Royal(c: Ctx)
	local H = c.Head.CFrame
	local gold = Color3.fromRGB(255, 200, 40)
	local base = H * CFrame.new(0, c.Top + 0.6, 0)
	discY(c.Folder, base, 4.6, 1.2, gold, { Material = Enum.Material.Metal, Reflectance = 0.3 })
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		block(c.Folder, base * CFrame.new(math.cos(a) * 2.0, 1.2, math.sin(a) * 2.0), Vector3.new(0.7, 1.4, 0.7), gold, { Material = Enum.Material.Metal })
	end
	ball(c.Folder, base * CFrame.new(0, 1.5, 0), 1.2, Color3.fromRGB(230, 40, 70), { Material = Enum.Material.Neon })
	-- cape draped over the back
	block(c.Folder, H * CFrame.new(0, c.Top - 0.1, -4.6) * CFrame.Angles(math.rad(6), 0, 0), Vector3.new(c.Head.Size.X * 0.85, 0.3, 6.5), Color3.fromRGB(200, 30, 50), { Material = Enum.Material.Fabric })
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Hand-made bees: ReplicatedStorage.BeeModels
-- Drop your own models there, named after what they replace: "Starter Bee", "Clover Bee", ...
-- "Shiny Clover Bee" (optional), or an egg bee's name like "Panda Bee". They're used as-is
-- instead of the generated bee: scripts stripped, anchored, scaled to the tier's size, and
-- flown with their pivot's FRONT as the head (set the pivot in Studio so the arrow points out
-- of the face). Any name without a model falls back to the generated bee.
------------------------------------------------------------------------------

local BASE_HEIGHT = 2.0 -- studs tall for a scale-0.35 (Starter) bee; tiers grow from there

local function customModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("BeeModels")
	local m = folder and folder:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

local function prepareCustom(source: Model, scale: number, name: string, shiny: boolean?): Model
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	-- normalise: pivot at the origin, scale to the tier's height, pivot at the box centre
	model:PivotTo(CFrame.new())
	local _, size = model:GetBoundingBox()
	if size.Y > 0.01 and model:GetAttribute("KeepSize") ~= true then
		model:ScaleTo(model:GetScale() * (BASE_HEIGHT * scale / 0.35) / size.Y)
	end
	local bcf = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(bcf.Position) -- keep the author's facing (pivot front = head)
	if shiny then
		local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = hex("#FFF2B0")
			sparkles.Parent = anyPart
		end
		model:SetAttribute("Shiny", true)
	end
	model.Name = name
	model:SetAttribute("Bee", true)
	model:SetAttribute("Custom", source.Name)
	return model
end

-- Shared dressing: recolour by role, add the accessory, light, canonical pivot, scale.
local function dress(template: Model, look: { [string]: any }, scale: number, name: string, shiny: boolean?): Model
	BeeAppearance.PrepareTemplate(template)
	local model = template:Clone()
	local cam = model:FindFirstChildOfClass("Camera")
	if cam then
		cam:Destroy()
	end

	local material = (Enum.Material :: any)[look.Material or "SmoothPlastic"] :: Enum.Material
	local head: BasePart? = nil
	local eyes: { BasePart } = {}
	local bodyParts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		local role = d:GetAttribute("BeeRole")
		if role == "Head" or role == "BodyStripe" or role == "DarkStripe" then
			d.Color = hex(if role == "DarkStripe" then look.Stripe else look.Body)
			d.Material = if role == "DarkStripe" and (look.NeonStripes or shiny) then Enum.Material.Neon else material
			d.Reflectance = (look.Reflectance or 0) + (if shiny then 0.15 else 0)
			d.Transparency = look.Transparency or 0
			table.insert(bodyParts, d)
			if role == "Head" then
				head = d
			end
		elseif role == "Wing" then
			d.Color = hex(look.Wing)
		elseif role == "Eye" then
			d.Color = hex(look.Eye)
			d.Material = if look.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			table.insert(eyes, d)
		elseif role == "Antenna" then
			d.Color = hex(look.Antenna or look.Stripe)
			d.Material = if look.NeonStripes then Enum.Material.Neon else material
		end
	end

	if head then
		local folder = Instance.new("Folder")
		folder.Name = "Accessory"
		folder.Parent = model
		local build = accessories[look.Accessory or ""]
		if build then
			build({ Folder = folder, Head = head, Top = head.Size.Y / 2, Look = look, Eyes = eyes })
		end
		if look.Glow then
			local light = Instance.new("PointLight")
			light.Color = hex(look.Glow)
			light.Brightness = 1.5
			light.Range = 10
			light.Parent = head
		end
		if shiny or look.Sparkles then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = hex(if shiny then "#FFF2B0" else look.Stripe)
			sparkles.Parent = head
		end

		-- Canonical pivot: centre of the body, facing the way the head points, wings up.
		local sum = Vector3.zero
		for _, p in bodyParts do
			sum += p.Position
		end
		local centre = sum / #bodyParts
		local forward = head.CFrame.ZVector -- the eyes sit on the parts' local +Z
		local up = head.CFrame.YVector -- the wings sit on local +Y
		model.WorldPivot = CFrame.fromMatrix(centre, forward:Cross(up), up, -forward)
	end

	model:ScaleTo(scale)
	model.Name = name
	model:SetAttribute("Bee", true)
	if shiny then
		model:SetAttribute("Shiny", true)
	end
	return model
end

-- Returns a fully dressed, anchored bee model for a ladder `tier`, pivoted so that
-- model:PivotTo(CFrame.lookAt(a, b)) flies head-first with the wings up.
function BeeAppearance.Build(template: Model, tier: string, shiny: boolean?): Model
	local info = Config.Bees[tier]
	assert(info, "Unknown bee tier: " .. tostring(tier))
	local displayName = (if shiny then "Shiny " else "") .. info.Name
	local custom = (if shiny then customModel(displayName) else nil) or customModel(info.Name)
	if custom then
		local model = prepareCustom(custom, info.Scale, displayName, shiny)
		model:SetAttribute("Tier", tier)
		return model
	end
	local model = dress(template, info.Look, info.Scale, displayName, shiny)
	model:SetAttribute("Tier", tier)
	return model
end

-- Same for one of the 50 egg bees (VariantBees.List[id]).
function BeeAppearance.BuildVariant(template: Model, variant: { [string]: any }): Model
	local custom = customModel(variant.Name)
	if custom then
		local model = prepareCustom(custom, variant.Scale, variant.Name, false)
		model:SetAttribute("Tier", "Variant")
		model:SetAttribute("Variant", variant.Id)
		model:SetAttribute("Rarity", variant.Rarity)
		return model
	end
	local look = table.clone(variant.Look)
	look.Sparkles = variant.Sparkles
	local model = dress(template, look, variant.Scale, variant.Name, false)
	model:SetAttribute("Tier", "Variant")
	model:SetAttribute("Variant", variant.Id)
	model:SetAttribute("Rarity", variant.Rarity)
	return model
end

return BeeAppearance
