--!nonstrict
-- Run once in Edit mode. The generated courts already have sidelines, a
-- centre circle and a north key, but no three-point line and no south key.
-- This adds FIBA-ish 3pt arcs with straight corners, free-throw (foul) lines,
-- the keys and the little semicircles above them, in the same off-white
-- 0.18-stud line style as the rest of the markings.
--
-- The street game scores 2 inside 23 studs and 3 outside it, so the arc is
-- drawn at exactly 23 studs from each rim anchor.

local Workspace = game:GetService("Workspace")

local LINE = Color3.fromRGB(249, 249, 239)
local HEIGHT = 0.32
local RIM_NORTH = -33
local RIM_SOUTH = 25
local THREE_RADIUS = 23
local CORNER_X = 17
local KEY_X = 7
local KEY_LENGTH = 12
local CIRCLE_RADIUS = 6

local function addLines(markings, cx, rimZ, toward)
	local name = "ExtraMarkings_" .. (toward > 0 and "North" or "South")
	local folder = markings:FindFirstChild(name)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = markings

	local function line(name, from, to)
		local a = Vector3.new(from.X, HEIGHT, from.Z)
		local b = Vector3.new(to.X, HEIGHT, to.Z)
		local length = (b - a).Magnitude
		if length < 0.01 then
			return
		end
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(0.18, 0.18, length)
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Color = LINE
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = folder
	end

	local dir = Vector3.new(0, 0, toward) -- from the rim toward mid-court
	local side = Vector3.new(1, 0, 0)
	local rim = Vector3.new(cx, 0, rimZ)
	local baseline = rimZ + toward * 3
	local foulZ = baseline + toward * KEY_LENGTH
	local join = math.sqrt(THREE_RADIUS * THREE_RADIUS - CORNER_X * CORNER_X)

	-- Three-point arc: straight corners then a semicircle around the rim.
	for _, s in ipairs({ -1, 1 }) do
		line("ThreeCorner", Vector3.new(cx + s * CORNER_X, 0, baseline),
			Vector3.new(cx + s * CORNER_X, 0, rimZ + toward * join))
	end
	local startAngle = -math.asin(CORNER_X / THREE_RADIUS)
	local arcSteps = 26
	local previous
	for i = 0, arcSteps do
		local angle = startAngle + (math.asin(CORNER_X / THREE_RADIUS) - startAngle) * (i / arcSteps)
		local point = rim + dir * (math.cos(angle) * THREE_RADIUS) + side * (math.sin(angle) * THREE_RADIUS)
		if previous then
			line("ThreeArc", previous, point)
		end
		previous = point
	end

	-- Free-throw line and the semicircle above the key.
	line("FreeThrow", Vector3.new(cx - KEY_X, 0, foulZ), Vector3.new(cx + KEY_X, 0, foulZ))
	previous = nil
	for i = 0, 16 do
		local angle = -math.pi / 2 + math.pi * (i / 16)
		local point = Vector3.new(cx, 0, foulZ) + dir * (math.cos(angle) * CIRCLE_RADIUS)
			+ side * (math.sin(angle) * CIRCLE_RADIUS)
		if previous then
			line("FoulCircle", previous, point)
		end
		previous = point
	end

	-- The south end did not ship with a key at all.
	if toward < 0 then
		for _, s in ipairs({ -1, 1 }) do
			line("Key", Vector3.new(cx + s * KEY_X, 0, baseline), Vector3.new(cx + s * KEY_X, 0, foulZ))
		end
	end

	return #folder:GetChildren()
end

local targets = {
	{ workspace["Christmas Wonderland"]["basketball-court"].Generated, 39 },
	{ workspace.SantaCourt.Generated, 91 },
}
local total = 0
for _, entry in ipairs(targets) do
	local markings = entry[1]:FindFirstChild("Basketball Court Markings")
	if markings then
		total = total + addLines(markings, entry[2], RIM_NORTH, 1)
		total = total + addLines(markings, entry[2], RIM_SOUTH, -1)
	end
end
return string.format("added %d line segments across both courts", total)
