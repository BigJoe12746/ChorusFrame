--!strict
-- BeeBuilder (ModuleScript) — put in ReplicatedStorage next to BeeVariants.
-- Turns the template bee (BeeTemplate.rbxm) into any of the 50 variants.
--
-- The template's blocks are all called "Part", so each block's job is worked out from its
-- ORIGINAL colour/size and then renamed: Head, Stripe (yellow ones = "Body" colour),
-- Stripe (dark ones = "Stripe" colour), Wing, Eye, Antenna.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BeeVariants = require(script.Parent:WaitForChild("BeeVariants"))

local BeeBuilder = {}

local ANIMATED_TAG = "AnimatedBee"

-- Template colours (from BeeTemplate.rbxm)
local YELLOW = Color3.fromRGB(255, 255, 0)
local DARK = Color3.fromRGB(27, 42, 53)
local WING = Color3.fromRGB(159, 243, 233)
local EYE = Color3.fromRGB(17, 17, 17)

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end

-- Returns "Head" | "BodyStripe" | "DarkStripe" | "Wing" | "Eye" | "Antenna" | nil
local function classify(part: BasePart, root: Model): string?
	if part.Parent ~= root then
		return "Antenna" -- the antennae are the two sub-models
	end
	local c = part.Color
	if same(c, WING) then
		return "Wing"
	elseif same(c, EYE) then
		return "Eye"
	elseif same(c, YELLOW) then
		-- the thick yellow block is the head; thin yellow blocks are stripes
		return if part.Size.Z > 3 then "Head" else "BodyStripe"
	elseif same(c, DARK) then
		return "DarkStripe"
	end
	return nil
end

-- Tag every part with its role once (on the template), so clones keep it even after recolouring.
function BeeBuilder.PrepareTemplate(template: Model)
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
	if not template.PrimaryPart then
		template.PrimaryPart = template:FindFirstChild("Head1") :: BasePart?
	end
	template:SetAttribute("BeePrepared", true)
end

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function addEffects(model: Model, bee: BeeVariants.Bee)
	local head = model:FindFirstChild("Head1") :: BasePart?
	if not head then
		return
	end
	for _, effect in bee.Effects or {} do
		if effect == "Sparkles" then
			local s = Instance.new("Sparkles")
			s.SparkleColor = hex(bee.Stripe)
			s.Parent = head
		elseif effect == "Fire" then
			local f = Instance.new("Fire")
			f.Color = hex(bee.Body)
			f.SecondaryColor = hex(bee.Stripe)
			f.Size = 4 * (bee.Scale or 1)
			f.Heat = 3
			f.Parent = head
		elseif effect == "Light" then
			local l = Instance.new("PointLight")
			l.Color = hex(bee.Stripe)
			l.Brightness = 2
			l.Range = 12 * (bee.Scale or 1)
			l.Parent = head
		elseif effect == "Rainbow" or effect == "Float" then
			CollectionService:AddTag(model, ANIMATED_TAG)
			model:SetAttribute(effect, true)
		end
	end
end

-- Recolour/rescale a (prepared) bee model in place.
function BeeBuilder.Apply(model: Model, bee: BeeVariants.Bee)
	local material = Enum.Material[bee.Material or "SmoothPlastic"]
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local role = d:GetAttribute("BeeRole")
		if role == "Head" or role == "BodyStripe" or role == "DarkStripe" then
			d.Color = hex(if role == "DarkStripe" then bee.Stripe else bee.Body)
			d.Material = material
			d.Reflectance = bee.Reflectance or 0
			d.Transparency = bee.Transparency or 0
			if role == "DarkStripe" and bee.NeonStripes then
				d.Material = Enum.Material.Neon
			end
		elseif role == "Wing" then
			d.Color = hex(bee.Wing :: string)
		elseif role == "Eye" then
			d.Color = hex(bee.Eye :: string)
			d.Material = if bee.GlowEyes then Enum.Material.Neon else Enum.Material.SmoothPlastic
		elseif role == "Antenna" then
			d.Color = hex(bee.Antenna :: string)
			d.Material = if bee.NeonStripes then Enum.Material.Neon else material
		end
	end

	local scale = bee.Scale or 1
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end

	model.Name = bee.Name
	model:SetAttribute("BeeId", bee.Id)
	model:SetAttribute("BeeName", bee.Name)
	model:SetAttribute("Rarity", bee.Rarity)
	model:SetAttribute("HoneyPerSecond", bee.HoneyPerSecond)
	model:SetAttribute("SellValue", bee.SellValue)
	addEffects(model, bee)
end

-- Make a new bee. `which` = bee name ("Tiger Bee"), id (1-50) or a Bee table.
function BeeBuilder.Build(template: Model, which: string | number | BeeVariants.Bee): Model
	local bee: BeeVariants.Bee
	if type(which) == "string" then
		bee = BeeVariants.ByName[which]
	elseif type(which) == "number" then
		bee = BeeVariants.List[which]
	else
		bee = which
	end
	assert(bee, "Unknown bee: " .. tostring(which))

	BeeBuilder.PrepareTemplate(template)
	local model = template:Clone()
	-- the template ships with a thumbnail camera; it isn't needed on every clone
	local cam = model:FindFirstChild("ThumbnailCamera")
	if cam then
		cam:Destroy()
	end
	BeeBuilder.Apply(model, bee)
	return model
end

-- Call ONCE (server or client) to run the Rainbow + Float animations on every bee that has them.
-- Float moves the whole model, so for physics-driven/following bees, call it on the client.
local started = false
local floatBase: { [Model]: CFrame } = {}
function BeeBuilder.StartEffects()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal(ANIMATED_TAG):Connect(function(m)
		floatBase[m :: Model] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, inst in CollectionService:GetTagged(ANIMATED_TAG) do
			local model = inst :: Model
			if not model:IsDescendantOf(workspace) then
				continue
			end
			if model:GetAttribute("Rainbow") then
				local i = 0
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						local role = d:GetAttribute("BeeRole")
						if role == "DarkStripe" or role == "Antenna" then
							i += 1
							d.Color = Color3.fromHSV((t * 0.25 + i * 0.12) % 1, 0.85, 1)
						end
					end
				end
			end
			if model:GetAttribute("Float") then
				local base = floatBase[model]
				if not base then
					base = model:GetPivot()
					floatBase[model] = base
				end
				model:PivotTo((base :: CFrame) * CFrame.new(0, math.sin(t * 2) * 0.6, 0))
			end
		end
	end)
end

-- If your game moves a floating bee (e.g. it follows the player), tell the float effect its new rest position.
function BeeBuilder.SetFloatBase(model: Model, cf: CFrame)
	floatBase[model] = cf
	model:PivotTo(cf)
end

return BeeBuilder
