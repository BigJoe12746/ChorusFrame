-- PropLibrary (ModuleScript)
-- Lets you replace the block-built scenery with real models from the Creator Store without
-- touching any code. Drop models into ReplicatedStorage.Props and name them by kind:
--
--   Flower, Flower2, Flower3...   (any name starting with the kind = a variant; picked at random)
--   Tree, Cottage, Fountain, Hive, MiniHive
--
-- When a kind has at least one prop, PropLibrary.Place clones one, strips every script out of it
-- (free models can hide malicious code), anchors it, scales it to the height the spot wants, and
-- stands it on the ground at the requested spot. When a kind has no prop, the caller's fallback
-- builds the original blocky version, so the game always works.
--
-- Optional attributes on a prop model:
--   HeightScale (number)  multiply the slot height (e.g. 1.3 for a taller tree)
--   KeepSize (boolean)    don't rescale at all
--   CanCollide (boolean)  force collisions on/off (default: kind-dependent)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropLibrary = {}

local COLLIDE_DEFAULT: { [string]: boolean } = {
	Flower = false,
	Tree = true,
	Cottage = true,
	Fountain = true,
	Hive = false,
	MiniHive = true,
}

local rng = Random.new()

local function propsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Props")
end

-- All models in Props whose name is `kind` or starts with it followed by digits/space/underscore.
function PropLibrary.Variants(kind: string): { Model }
	local folder = propsFolder()
	local out = {}
	if not folder then
		return out
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and (child.Name == kind or child.Name:match("^" .. kind .. "[%d_ ]")) then
			table.insert(out, child)
		end
	end
	return out
end

-- Leveled props: "Hive" = level 1, "Hive2" = level 2, ... Returns the model for the highest
-- level that is <= `level`, or nil when the kind has no props at all.
function PropLibrary.ForLevel(kind: string, level: number): Model?
	local best: Model? = nil
	local bestLevel = 0
	for _, m in PropLibrary.Variants(kind) do
		local n = if m.Name == kind then 1 else tonumber(m.Name:match("^" .. kind .. "(%d+)$"))
		if n and n <= level and n > bestLevel then
			best = m
			bestLevel = n
		end
	end
	return best
end

function PropLibrary.Has(kind: string): boolean
	return #PropLibrary.Variants(kind) > 0
end

local function stripScripts(model: Instance): number
	local removed = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed += 1
		end
	end
	return removed
end

local function placeSource(source: Model, kind: string, parent: Instance, cf: CFrame, height: number, nameOverride: string?): Model
	local model = source:Clone()
	local removed = stripScripts(model)
	if removed > 0 then
		warn(("[HoneyFarm Props] Removed %d script(s) from prop '%s'"):format(removed, source.Name))
	end

	local collide = model:GetAttribute("CanCollide")
	if type(collide) ~= "boolean" then
		collide = COLLIDE_DEFAULT[kind] ~= false
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
		end
	end

	-- normalise: pivot at the origin, then scale about it, then measure
	model:PivotTo(CFrame.new())
	local _, size = model:GetBoundingBox()
	if size.Y > 0.01 and model:GetAttribute("KeepSize") ~= true then
		local mult = tonumber(model:GetAttribute("HeightScale")) or 1
		model:ScaleTo(model:GetScale() * (height * mult) / size.Y)
	end
	local bcf, bsize = model:GetBoundingBox()
	local bottomCentre = bcf.Position - Vector3.new(0, bsize.Y / 2, 0)
	-- put the bottom centre of the box exactly on the ground point, facing cf's way
	model:PivotTo(cf * CFrame.new(-bottomCentre))

	model.Name = nameOverride or kind
	model:SetAttribute("Prop", source.Name)
	model.Parent = parent
	return model
end

-- Clones a random variant of `kind`, standing on the ground at `cf` (cf.Position = ground point,
-- cf rotation = facing), scaled so its bounding box is `height` studs tall.
-- Returns the model, or nil when there is no prop for this kind.
function PropLibrary.Place(parent: Instance, kind: string, cf: CFrame, height: number, nameOverride: string?): Model?
	local variants = PropLibrary.Variants(kind)
	if #variants == 0 then
		return nil
	end
	return placeSource(variants[rng:NextInteger(1, #variants)], kind, parent, cf, height, nameOverride)
end

-- Like Place, but picks the prop for an upgrade level ("Hive", "Hive2", "Hive3"...).
function PropLibrary.PlaceLevel(parent: Instance, kind: string, level: number, cf: CFrame, height: number, nameOverride: string?): Model?
	local source = PropLibrary.ForLevel(kind, level)
	if not source then
		return nil
	end
	return placeSource(source, kind, parent, cf, height, nameOverride)
end

return PropLibrary
