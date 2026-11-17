--!nonstrict
-- Run once in Edit mode. Builds the Elf Ball Crew station beside the street
-- court: a ball rack, three little referee elves and a status sign. The crew
-- keeps the court stocked with balls; logic lives in elf_ball_crew.server.lua.

local Workspace = game:GetService("Workspace")

local station = Workspace:FindFirstChild("ElfBallCrew")
if station then
	station:Destroy()
end
station = Instance.new("Model")
station.Name = "ElfBallCrew"
station.Parent = Workspace

local RACK = Vector3.new(12, 0, 10)
local WOOD = Color3.fromRGB(122, 74, 44)
local GREEN = Color3.fromRGB(38, 126, 72)
local RED = Color3.fromRGB(184, 46, 52)
local WHITE = Color3.fromRGB(245, 245, 240)
local SKIN = Color3.fromRGB(235, 196, 160)
local GOLD = Color3.fromRGB(255, 214, 120)

local function block(name, size, position, colour, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = colour
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent or station
	return part
end

-- Ball rack -----------------------------------------------------------------
block("RackBase", Vector3.new(9, 0.4, 3.5), RACK + Vector3.new(0, 0.2, 0), WOOD, Enum.Material.Wood)
for _, x in ipairs({ -3, 0, 3 }) do
	block("RackPost", Vector3.new(0.5, 3.4, 0.5), RACK + Vector3.new(x, 1.7, -1.3), WOOD, Enum.Material.Wood)
	block("RackPost", Vector3.new(0.5, 3.4, 0.5), RACK + Vector3.new(x, 1.7, 1.3), WOOD, Enum.Material.Wood)
	for row = 0, 1 do
		local ball = block("RackBall", Vector3.new(1.3, 1.3, 1.3),
			RACK + Vector3.new(x, 1 + row * 1.5, 0), Color3.fromRGB(212, 108, 44))
		ball.Shape = Enum.PartType.Ball
	end
end
block("RackTop", Vector3.new(9, 0.35, 3.5), RACK + Vector3.new(0, 3.5, 0), GREEN)

-- Elves ---------------------------------------------------------------------
local function makeElf(index, offset)
	local model = Instance.new("Model")
	model.Name = "ElfRef_" .. index
	model:SetAttribute("Elf", index)
	model.Parent = station
	local root = block("Root", Vector3.new(1, 1, 1), RACK + offset, SKIN, nil, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local body = block("Coat", Vector3.new(1.6, 1.9, 1), Vector3.new(0, 1.6, 0), GREEN, nil, model)
	body.CFrame = root.CFrame * CFrame.new(0, 1.6, 0)
	block("Belt", Vector3.new(1.8, 0.28, 1.1), Vector3.new(0, 0.9, 0), WHITE, nil, model).CFrame = root.CFrame * CFrame.new(0, 0.9, 0)
	block("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 3, 0), SKIN, nil, model).CFrame = root.CFrame * CFrame.new(0, 3, 0)
	block("Hat", Vector3.new(1.1, 1.3, 1.1), Vector3.new(0, 4, 0), RED, nil, model).CFrame = root.CFrame * CFrame.new(0, 4, 0)
	block("HatBrim", Vector3.new(1.5, 0.3, 1.5), Vector3.new(0, 3.5, 0), WHITE, nil, model).CFrame = root.CFrame * CFrame.new(0, 3.5, 0)
	block("Whistle", Vector3.new(0.35, 0.35, 0.35), Vector3.new(0, 2.1, 0.8), GOLD, Enum.Material.Neon, model).CFrame =
		root.CFrame * CFrame.new(0, 2.1, 0.8)
	for side = -1, 1, 2 do
		block("Arm", Vector3.new(0.4, 1.2, 0.4), Vector3.new(0, 0, 0), GREEN, nil, model).CFrame =
			root.CFrame * CFrame.new(side * 1, 1.8, 0)
		block("Leg", Vector3.new(0.45, 1.1, 0.45), Vector3.new(0, 0, 0), RED, nil, model).CFrame =
			root.CFrame * CFrame.new(side * 0.45, 0.35, 0)
		block("Ear", Vector3.new(0.4, 0.7, 0.35), Vector3.new(0, 0, 0), SKIN, nil, model).CFrame =
			root.CFrame * CFrame.new(side * 0.8, 3, 0)
	end

	local badge = Instance.new("BillboardGui")
	badge.Name = "RefBadge"
	badge.Size = UDim2.fromOffset(120, 40)
	badge.StudsOffset = Vector3.new(0, 5, 0)
	badge.MaxDistance = 120
	badge.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
	label.BackgroundTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.Text = "REF " .. index
	label.TextColor3 = GOLD
	label.TextScaled = true
	label.Parent = badge
	return model
end

makeElf(1, Vector3.new(-5, 0, 3))
makeElf(2, Vector3.new(0, 0, 4))
makeElf(3, Vector3.new(5, 0, 3))

-- Status sign ---------------------------------------------------------------
local signAnchor = block("SignAnchor", Vector3.new(0.3, 0.3, 0.3), RACK + Vector3.new(0, 6, 0), GOLD)
local gui = Instance.new("BillboardGui")
gui.Name = "CrewSign"
gui.Size = UDim2.fromOffset(460, 110)
gui.MaxDistance = 160
gui.Parent = signAnchor
local label = Instance.new("TextLabel")
label.Name = "Status"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
label.BackgroundTransparency = 0.25
label.Font = Enum.Font.GothamBold
label.Text = "ELF BALL CREW  ·  BALLS ON COURT 1 / 2"
label.TextColor3 = GOLD
label.TextScaled = true
label.Parent = gui

return "built elf ball crew with rack, three elves and status sign"
