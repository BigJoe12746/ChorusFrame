-- StudStyle (ModuleScript)
-- Classic studded-plastic look for the map: bright Enum.Material.Plastic with square studs
-- (Enum.SurfaceType.Studs) on all six flat faces of every compatible environmental Part.
--
-- Not compatible (left untouched, so they keep working and looking as intended):
--   * MeshParts and UnionOperations  - Roblox does not render surface studs on custom geometry;
--                                      those need image-based stud Textures instead.
--   * Transparent parts              - invisible triggers, glass jars/tanks, expansion pads.
--   * Glass and Neon materials       - windows, honey tanks, glowing accents.
--
-- Use StudStyle.Apply(part) on any BasePart; it is safe to call on anything.

local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

local StudStyle = {}

-- True when surface studs can actually render on this part.
function StudStyle.IsCompatible(part: BasePart): boolean
	return not part:IsA("MeshPart")
		and not part:IsA("UnionOperation")
		and part.Transparency <= 0
		and part.Material ~= Enum.Material.Glass
		and part.Material ~= Enum.Material.Neon
end

-- Applies plastic + studs when the part supports them; returns true when it was applied.
function StudStyle.Apply(part: BasePart): boolean
	if part:IsA("MeshPart") or part:IsA("UnionOperation") then
		return false -- custom geometry: surface studs don't render; needs image textures
	end
	if part.Transparency <= 0 and part.Material ~= Enum.Material.Glass and part.Material ~= Enum.Material.Neon then
		part.Material = Enum.Material.Plastic
		for _, face in STUD_FACES do
			part[face] = Enum.SurfaceType.Studs
		end
		return true
	end
	-- glass / neon / transparent: keep the material and look, but stay smooth like before
	for _, face in STUD_FACES do
		part[face] = Enum.SurfaceType.Smooth
	end
	return false
end

return StudStyle
