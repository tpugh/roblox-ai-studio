--!nonstrict
-- Run once in Edit mode. Builds two town-crier elves beside the cocoa stand and
-- the Santa Workshop boutique. They hold megaphones and speech-bubble signs;
-- announcer_elves.server.lua rotates the sale messages and celebrates sales.

local Workspace = game:GetService("Workspace")

local station = Workspace:FindFirstChild("AnnouncerElves")
if station then
	station:Destroy()
end
station = Instance.new("Model")
station.Name = "AnnouncerElves"
station.Parent = Workspace

local WOOD = Color3.fromRGB(122, 74, 44)
local RED = Color3.fromRGB(184, 46, 52)
local GREEN = Color3.fromRGB(38, 126, 72)
local BROWN = Color3.fromRGB(112, 68, 40)
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

local function makeCrier(id, position, colour)
	local model = Instance.new("Model")
	model.Name = "Announcer_" .. id
	model:SetAttribute("Announcer", id)
	model.Parent = station

	local root = block("Root", Vector3.new(1, 1, 1), position, SKIN, nil, model)
	root.Transparency = 1
	model.PrimaryPart = root
	local function put(name, size, offset, partColor, material)
		local part = block(name, size, Vector3.new(0, 0, 0), partColor, material, model)
		part.CFrame = root.CFrame * CFrame.new(unpack(offset))
		return part
	end

	put("Coat", Vector3.new(1.8, 2, 1.1), { 0, 1.6, 0 }, colour)
	put("Belt", Vector3.new(2, 0.3, 1.2), { 0, 0.9, 0 }, WHITE)
	put("Head", Vector3.new(1.3, 1.3, 1.3), { 0, 3.1, 0 }, SKIN)
	put("Hat", Vector3.new(1.2, 1.4, 1.2), { 0, 4.1, 0 }, colour)
	put("HatBrim", Vector3.new(1.7, 0.35, 1.7), { 0, 3.6, 0 }, WHITE)
	for side = -1, 1, 2 do
		put("Arm", Vector3.new(0.45, 1.3, 0.45), { side * 1.1, 1.8, 0 }, colour)
		put("Leg", Vector3.new(0.5, 1.2, 0.5), { side * 0.5, 0.35, 0 }, RED)
		put("Ear", Vector3.new(0.45, 0.75, 0.4), { side * 0.9, 3.1, 0 }, SKIN)
	end

	-- A bright megaphone held up to the mouth.
	local horn = put("Megaphone", Vector3.new(0.9, 0.9, 1.6), { 0.9, 2.3, 1 }, GOLD, Enum.Material.Neon)
	horn.Shape = Enum.PartType.Cylinder
	horn.CFrame = root.CFrame * CFrame.new(0.9, 2.3, 1) * CFrame.Angles(math.pi / 2, 0, 0)
	put("MegaphoneGrip", Vector3.new(0.35, 0.6, 0.35), { 0.9, 1.9, 0.5 }, WOOD)

	-- Speech bubble that the server updates with sale messages.
	local anchor = put("BubbleAnchor", Vector3.new(0.3, 0.3, 0.3), { 0, 5.6, 0 }, GOLD)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(440, 130)
	gui.MaxDistance = 180
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = "HOT CHOCOLATE!"
	label.TextColor3 = GOLD
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = label

	local badge = Instance.new("BillboardGui")
	badge.Name = "NameTag"
	badge.Size = UDim2.fromOffset(220, 40)
	badge.StudsOffset = Vector3.new(0, 6.6, 0)
	badge.MaxDistance = 140
	badge.Parent = root
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = id == "Cocoa" and "COCOA CRIER" or "AVATAR CRIER"
	nameLabel.TextColor3 = GOLD
	nameLabel.TextScaled = true
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = badge

	return model
end

makeCrier("Cocoa", Vector3.new(9, 0, -45), RED)
makeCrier("Avatar", Vector3.new(-26, 0, -4), GREEN)

return "built two announcer elves with megaphones and speech bubbles"
