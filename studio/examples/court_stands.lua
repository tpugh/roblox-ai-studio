--!nonstrict
-- Builds four sets of holiday bleachers: behind both hoops on the street
-- court and behind both hoops on the Santa court. Run once in Edit mode from
-- the Assistant command bar; the crowd itself is driven by crowd_cheer.server.lua.

local Workspace = game:GetService("Workspace")

local root = Workspace:FindFirstChild("CourtStands")
if root then
	root:Destroy()
end
root = Instance.new("Model")
root.Name = "CourtStands"
root.Parent = Workspace

local WOOD = Color3.fromRGB(112, 68, 40)
local TRIM_RED = Color3.fromRGB(158, 42, 48)
local TRIM_GREEN = Color3.fromRGB(32, 104, 64)
local SNOW = Color3.fromRGB(236, 240, 248)
local SKIN = Color3.fromRGB(232, 194, 158)
local DARK = Color3.fromRGB(48, 40, 36)

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
	part.Parent = parent
	return part
end

-- Fans are built facing +Z, seated on a bench with their origin at seat level.
-- Every part is anchored and welded logically by the model pivot, so the cheer
-- script can bounce a whole fan with one PivotTo call.
local function makeFan(parent, kind, position, facing)
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("Fan", kind)

	local coat, hat
	if kind == "reindeer" then
		coat, hat = Color3.fromRGB(139, 91, 55), Color3.fromRGB(105, 66, 39)
	elseif kind == "elf" then
		coat, hat = Color3.fromRGB(36, 138, 74), Color3.fromRGB(28, 108, 58)
	else
		local coats = {
			Color3.fromRGB(178, 46, 52),
			Color3.fromRGB(44, 84, 158),
			Color3.fromRGB(122, 54, 124),
			Color3.fromRGB(196, 116, 38),
		}
		coat = coats[math.random(1, #coats)]
		hat = DARK
	end

	local torso = block("Torso", Vector3.new(1.4, 1.5, 0.85), Vector3.new(0, 1.15, 0), coat, nil, model)
	model.PrimaryPart = torso
	block("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 2.25, 0.05), kind == "reindeer" and hat or SKIN, nil, model)
	block("ArmL", Vector3.new(0.34, 1.0, 0.34), Vector3.new(-0.92, 1.15, 0.1), coat, nil, model)
	block("ArmR", Vector3.new(0.34, 1.0, 0.34), Vector3.new(0.92, 1.15, 0.1), coat, nil, model)
	block("LegL", Vector3.new(0.4, 0.75, 0.45), Vector3.new(-0.38, 0.38, 0.2), DARK, nil, model)
	block("LegR", Vector3.new(0.4, 0.75, 0.45), Vector3.new(0.38, 0.38, 0.2), DARK, nil, model)

	if kind == "reindeer" then
		block("Nose", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 2.2, 0.66), Color3.fromRGB(222, 52, 52), nil, model)
		for side = -1, 1, 2 do
			block("Ear", Vector3.new(0.32, 0.24, 0.2), Vector3.new(side * 0.62, 2.5, 0.02), hat, nil, model)
			local antler = block("Antler", Vector3.new(0.13, 0.95, 0.13), Vector3.new(side * 0.32, 3.0, 0), hat, Enum.Material.Wood, model)
			antler.CFrame = CFrame.new(antler.Position) * CFrame.Angles(0, 0, side * 0.42)
		end
	elseif kind == "elf" then
		local cap = block("Hat", Vector3.new(0.7, 0.78, 0.7), Vector3.new(0, 2.98, 0), hat, nil, model)
		cap.Shape = Enum.PartType.Cylinder
		cap.CFrame = CFrame.new(cap.Position) * CFrame.Angles(0, 0, math.pi / 2)
		local tip = block("HatTip", Vector3.new(0.28, 0.55, 0.28), Vector3.new(0, 3.55, 0), hat, nil, model)
		tip.Shape = Enum.PartType.Cylinder
		tip.CFrame = CFrame.new(tip.Position) * CFrame.Angles(0, 0, math.pi / 2)
		block("Beard", Vector3.new(0.55, 0.5, 0.4), Vector3.new(0, 1.92, 0.42), SNOW, nil, model)
		block("Belt", Vector3.new(1.45, 0.18, 0.9), Vector3.new(0, 0.78, 0), DARK, nil, model)
	else
		block("Hair", Vector3.new(1.12, 0.5, 1.02), Vector3.new(0, 2.62, -0.1), hat, nil, model)
		block("Scarf", Vector3.new(1.25, 0.24, 0.95), Vector3.new(0, 1.82, 0.05), math.random(2) == 1 and TRIM_RED or TRIM_GREEN, nil, model)
	end

	model:PivotTo(CFrame.new(position) * facing)
	model.Parent = parent
end

local function buildStand(courtName, centreX, firstZ, direction, endName)
	local stand = Instance.new("Model")
	stand.Name = courtName .. "_" .. endName
	stand:SetAttribute("Court", courtName)
	stand.Parent = root

	local fanFolder = Instance.new("Folder")
	fanFolder.Name = "Fans"
	fanFolder.Parent = stand

	block("SnowDeck", Vector3.new(36, 0.5, 17), Vector3.new(centreX, 0.25, firstZ + direction * 4.6), SNOW, Enum.Material.Snow, stand)

	for row = 0, 2 do
		local z = firstZ + direction * (row * 4.6)
		local y = 1.3 + row * 1.8
		local trim = (row % 2 == 0) and TRIM_RED or TRIM_GREEN
		block("Riser", Vector3.new(34, y, 1.8), Vector3.new(centreX, y / 2, z + direction * 1.7), WOOD, Enum.Material.Wood, stand)
		block("Bench", Vector3.new(34, 0.7, 3.2), Vector3.new(centreX, y, z), WOOD, Enum.Material.Wood, stand)
		block("BackRail", Vector3.new(34, 0.7, 0.5), Vector3.new(centreX, y + 0.9, z + direction * 1.6), trim, nil, stand)
		for side = -1, 1, 2 do
			block("SideRail", Vector3.new(0.5, 1.1, 3.2), Vector3.new(centreX + side * 17, y + 0.5, z), trim, nil, stand)
		end

		local facing = direction < 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0)
		for seat = 1, 7 do
			local kind = ({ "reindeer", "elf", "person" })[((seat + row + (courtName == "santa" and 1 or 0)) % 3) + 1]
			makeFan(fanFolder, kind, Vector3.new(centreX + (seat - 4) * 4.4, y + 0.4, z), facing)
		end
	end

	local anchor = block("SoundAnchor", Vector3.new(1, 1, 1), Vector3.new(centreX, 7, firstZ + direction * 4.6), SNOW, nil, stand)
	anchor.Transparency = 1

	local burst = Instance.new("Sound")
	burst.Name = "CheerBurst"
	burst.SoundId = "rbxassetid://7755719721"
	burst.Volume = 0.7
	burst.Parent = anchor

	local ambience = Instance.new("Sound")
	ambience.Name = "CrowdAmbience"
	ambience.SoundId = "rbxassetid://9112766176"
	ambience.Volume = 0.11
	ambience.Looped = true
	ambience.Parent = anchor

	return stand
end

buildStand("main", 39, -41, -1, "North")
buildStand("main", 39, 33, 1, "South")
buildStand("santa", 91, -41, -1, "North")
buildStand("santa", 91, 33, 1, "South")

local fans = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("Fan") then
		fans = fans + 1
	end
end
return "built " .. fans .. " fans in " .. #root:GetChildren() .. " stands"
