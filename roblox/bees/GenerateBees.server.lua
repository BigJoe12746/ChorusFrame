-- GenerateBees (Script) — put in ServerScriptService.
-- 1) Bakes all 50 bees into ReplicatedStorage.Bees (one Model per bee, with attributes)
-- 2) Lines them up in a "BeeShowroom" in front of spawn so you can look at them in Play mode.
-- Set SHOWROOM = false once you're happy; keep BAKE so the rest of your game can clone
-- ReplicatedStorage.Bees["Tiger Bee"] etc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeeVariants = require(ReplicatedStorage:WaitForChild("BeeVariants"))
local BeeBuilder = require(ReplicatedStorage:WaitForChild("BeeBuilder"))

local SHOWROOM = true
local PER_ROW = 10
local SPACING = 14

local template = ReplicatedStorage:WaitForChild("BeeTemplate") :: Model

local folder = ReplicatedStorage:FindFirstChild("Bees") or Instance.new("Folder")
folder.Name = "Bees"
folder:ClearAllChildren()
folder.Parent = ReplicatedStorage

for _, bee in BeeVariants.List do
	local model = BeeBuilder.Build(template, bee)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
		end
	end
	model.Parent = folder
end

if SHOWROOM then
	local room = workspace:FindFirstChild("BeeShowroom") or Instance.new("Model")
	room.Name = "BeeShowroom"
	room:ClearAllChildren()
	room.Parent = workspace

	for i, bee in BeeVariants.List do
		local model = (folder:FindFirstChild(bee.Name) :: Model):Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local col = (i - 1) % PER_ROW
		local row = (i - 1) // PER_ROW
		model:PivotTo(CFrame.new(col * SPACING - PER_ROW * SPACING / 2, 8, 40 + row * SPACING))

		-- name tag
		local head = model:FindFirstChild("Head1") :: BasePart
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 44)
		gui.StudsOffset = Vector3.new(0, 6 * (bee.Scale or 1), 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromHex(BeeVariants.GetRarity(bee.Rarity).Color)
		label.TextStrokeTransparency = 0
		label.Text = string.format("%s\n%s · %s/s", bee.Name, bee.Rarity, tostring(bee.HoneyPerSecond))
		label.Parent = gui
		gui.Parent = head

		model.Parent = room
	end
end

BeeBuilder.StartEffects()
print(("[Bees] built %d bees into ReplicatedStorage.Bees"):format(#BeeVariants.List))
