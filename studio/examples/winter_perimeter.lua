--!nonstrict
-- Run once in Edit mode. Builds a snow-fenced perimeter around the playable
-- area and an aspen-winter backdrop beyond it, with a small lookout deck.
-- The walls are invisible but solid; the fence is the visible boundary.

local Workspace = game:GetService("Workspace")

local old = Workspace:FindFirstChild("WinterPerimeter")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "WinterPerimeter"
root.Parent = Workspace

local MIN_X, MAX_X = -90, 140
local MIN_Z, MAX_Z = -80, 80
local SNOW = Color3.fromRGB(238, 244, 250)

local function block(name, size, position, colour, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = colour or Color3.new(1, 1, 1)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent or root
	return part
end

-- Snow ground outside the fence ---------------------------------------------
local snowGround = Instance.new("Folder")
snowGround.Name = "SnowGround"
snowGround.Parent = root
local function snowSheet(name, size, position)
	local sheet = block(name, size, position, SNOW, Enum.Material.Snow, snowGround)
	sheet.CanTouch = true
end
snowSheet("SnowWest", Vector3.new(520, 0.3, 1600), Vector3.new(-350, 0.2, 0))
snowSheet("SnowEast", Vector3.new(470, 0.3, 1600), Vector3.new(375, 0.2, 0))
snowSheet("SnowNorth", Vector3.new(230, 0.3, 720), Vector3.new(25, 0.2, -440))
snowSheet("SnowSouth", Vector3.new(230, 0.3, 720), Vector3.new(25, 0.2, 440))

-- Invisible solid walls -----------------------------------------------------
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = root
local function wall(name, size, position)
	local part = block(name, size, position, SNOW, nil, walls)
	part.Transparency = 1
	part.CanCollide = true
end
wall("WallWest", Vector3.new(2, 20, MAX_Z - MIN_Z + 4), Vector3.new(MIN_X - 1, 10, 0))
wall("WallEast", Vector3.new(2, 20, MAX_Z - MIN_Z + 4), Vector3.new(MAX_X + 1, 10, 0))
wall("WallNorth", Vector3.new(MAX_X - MIN_X + 4, 20, 2), Vector3.new(25, 10, MIN_Z - 1))
wall("WallSouth", Vector3.new(MAX_X - MIN_X + 4, 20, 2), Vector3.new(25, 10, MAX_Z + 1))

-- Visible snow-capped rail fence --------------------------------------------
local fence = Instance.new("Folder")
fence.Name = "Fence"
fence.Parent = root
local WOOD = Color3.fromRGB(122, 74, 44)
local ICE = Color3.fromRGB(205, 226, 240)

local function rail(from, to)
	local delta = to - from
	local length = delta.Magnitude
	local part = block("Rail", Vector3.new(0.6, 0.6, length), (from + to) / 2, WOOD, Enum.Material.Wood, fence)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
end

local function fenceLine(from, to, step)
	local length = (to - from).Magnitude
	local count = math.ceil(length / step)
	for i = 0, count do
		local t = i / count
		local pos = from:Lerp(to, t)
		block("Post", Vector3.new(1, 3.2, 1), pos + Vector3.new(0, 1.6, 0), WOOD, Enum.Material.Wood, fence)
		block("PostCap", Vector3.new(1.2, 0.35, 1.2), pos + Vector3.new(0, 3.3, 0), SNOW, Enum.Material.Snow, fence)
		if i < count then
			local nextPos = from:Lerp(to, (i + 1) / count)
			for _, h in ipairs({ 1.1, 2.2 }) do
				rail(pos + Vector3.new(0, h, 0), nextPos + Vector3.new(0, h, 0))
			end
		end
	end
end

fenceLine(Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MIN_X, 0, MAX_Z), 12)
fenceLine(Vector3.new(MAX_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MAX_Z), 12)
fenceLine(Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MIN_Z), 12)
fenceLine(Vector3.new(MIN_X, 0, MAX_Z), Vector3.new(MAX_X, 0, MAX_Z), 12)

-- Aspen winter grove beyond the fence --------------------------------------
local grove = Instance.new("Folder")
grove.Name = "AspenGrove"
grove.Parent = root
local BARK = Color3.fromRGB(232, 232, 228)
local BARK_MARK = Color3.fromRGB(46, 42, 44)
local TWIG = Color3.fromRGB(72, 64, 62)

math.randomseed(2718)

local function aspen(x, z, scale)
	local height = (14 + math.random() * 8) * scale
	local trunk = block("AspenTrunk", Vector3.new(1.2 * scale, height, 1.2 * scale),
		Vector3.new(x, height / 2, z), BARK, Enum.Material.SmoothPlastic, grove)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = CFrame.new(trunk.Position) * CFrame.Angles(0, 0, math.pi / 2)
	for mark = 1, 4 do
		local y = height * (0.15 + mark * 0.16)
		local scar = block("BarkMark", Vector3.new(0.12, 0.8 * scale, 1.24 * scale),
			Vector3.new(x, y, z), BARK_MARK, nil, grove)
		scar.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.random() * math.pi, 0)
	end
	for branch = 1, 3 do
		local y = height * (0.6 + branch * 0.1)
		local side = branch % 2 == 0 and 1 or -1
		local b = block("AspenBranch", Vector3.new(0.35 * scale, 5 * scale, 0.35 * scale),
			Vector3.new(x + side * 1.6 * scale, y + 1.6 * scale, z), TWIG, Enum.Material.Wood, grove)
		b.CFrame = CFrame.new(b.Position) * CFrame.Angles(0, 0, side * 0.75)
	end
	local snowBase = block("AspenSnow", Vector3.new(3.5 * scale, 0.5, 3.5 * scale),
		Vector3.new(x, 0.25, z), SNOW, Enum.Material.Snow, grove)
	snowBase.Shape = Enum.PartType.Ball
end

local function groveLine(from, to, count, offset)
	for i = 1, count do
		local t = (i - 0.5) / count
		local base = from:Lerp(to, t)
		local out = offset + math.random() * 45
		local jitter = (math.random() - 0.5) * 14
		local pos
		if from.X == to.X then
			pos = Vector3.new(base.X + (from.X < 0 and -out or out), 0, base.Z + jitter)
		else
			pos = Vector3.new(base.X + jitter, 0, base.Z + (from.Z < 0 and -out or out))
		end
		aspen(pos.X, pos.Z, 0.8 + math.random() * 0.8)
	end
end

groveLine(Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MIN_X, 0, MAX_Z), 18, 16)
groveLine(Vector3.new(MAX_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MAX_Z), 18, 16)
groveLine(Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MIN_Z), 22, 16)
groveLine(Vector3.new(MIN_X, 0, MAX_Z), Vector3.new(MAX_X, 0, MAX_Z), 22, 16)

-- Distant snowy hills and a few evergreens on the horizon ------------------
local horizon = Instance.new("Folder")
horizon.Name = "Horizon"
horizon.Parent = root
for i = 1, 8 do
	local angle = (i / 8) * math.pi * 2
	local radius = 240 + math.random() * 90
	local x = 25 + math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local hill = block("SnowHill", Vector3.new(90 + math.random() * 60, 34 + math.random() * 22, 90),
		Vector3.new(x, -4, z), Color3.fromRGB(214, 228, 240), Enum.Material.Snow, horizon)
	hill.Shape = Enum.PartType.Ball
end
for i = 1, 24 do
	local angle = (i / 24) * math.pi * 2 + 0.1
	local radius = 150 + math.random() * 80
	local x = 25 + math.cos(angle) * radius
	local z = math.sin(angle) * radius
	for tier = 0, 2 do
		local size = (7 - tier * 1.8) * (0.8 + math.random() * 0.4)
		block("Pine", Vector3.new(size, 6, size), Vector3.new(x, 3 + tier * 4.5, z),
			Color3.fromRGB(38, 78, 62), Enum.Material.SmoothPlastic, horizon)
	end
	block("PineSnow", Vector3.new(2.2, 1.4, 2.2), Vector3.new(x, 14, z), SNOW, Enum.Material.Snow, horizon)
end

-- Viewpoint just inside the north fence ------------------------------------
local look = Instance.new("Folder")
look.Name = "Viewpoint"
look.Parent = root
local deckPos = Vector3.new(25, 0, MIN_Z + 7)
block("Deck", Vector3.new(20, 0.6, 9), deckPos + Vector3.new(0, 0.3, 0), WOOD, Enum.Material.Wood, look)
for _, side in ipairs({ -1, 1 }) do
	block("DeckRail", Vector3.new(0.5, 3, 9), deckPos + Vector3.new(side * 9.5, 1.5, 0), WOOD, Enum.Material.Wood, look)
end
block("DeckRail", Vector3.new(20, 3, 0.5), deckPos + Vector3.new(0, 1.5, -4.2), WOOD, Enum.Material.Wood, look)
local signAnchor = block("ViewSignAnchor", Vector3.new(0.3, 0.3, 0.3), deckPos + Vector3.new(0, 5, 0), SNOW, nil, look)
local gui = Instance.new("BillboardGui")
gui.Name = "ViewSign"
gui.Size = UDim2.fromOffset(420, 90)
gui.MaxDistance = 180
gui.Parent = signAnchor
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
label.BackgroundTransparency = 0.3
label.Font = Enum.Font.GothamBold
label.Text = "ASPEN WINTER VIEWPOINT"
label.TextColor3 = Color3.fromRGB(255, 226, 160)
label.TextScaled = true
label.Parent = gui

return "built snow barrier, aspen grove, hills and viewpoint"
