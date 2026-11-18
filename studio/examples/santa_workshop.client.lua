--!nonstrict
-- Santa Workshop boutique UI: a gallery of avatar cards with live 3D previews,
-- a detail panel for the selected outfit, purchase feedback and unequip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SantaWorkshopRemotes", 10)
if not remotes then
	return
end
local OpenShop = remotes:WaitForChild("OpenShop")
local Purchase = remotes:WaitForChild("Purchase")
local Unequip = remotes:WaitForChild("Unequip")
local Result = remotes:WaitForChild("Result")

local RED = Color3.fromRGB(190, 38, 46)
local DARK_RED = Color3.fromRGB(138, 28, 36)
local GREEN = Color3.fromRGB(32, 116, 70)
local WHITE = Color3.fromRGB(245, 245, 240)
local BLACK = Color3.fromRGB(32, 28, 30)
local BROWN = Color3.fromRGB(129, 84, 52)
local SKIN = Color3.fromRGB(232, 194, 158)
local GOLD = Color3.fromRGB(255, 226, 160)
local ORANGE = Color3.fromRGB(236, 132, 40)

local AVATARS = {
	{ id = "santa", name = "Classic Santa", price = 60, blurb = "Red suit, hat, beard and belt",
		coat = RED, pants = RED, hat = RED, head = SKIN, boots = BLACK, beard = true, belt = true },
	{ id = "mrs", name = "Mrs Claus", price = 50, blurb = "Red dress, white hair and boots",
		coat = RED, pants = DARK_RED, hat = RED, head = SKIN, boots = BLACK, hair = true, apron = true },
	{ id = "elf", name = "Workshop Elf", price = 40, blurb = "Green suit, hat and pointy ears",
		coat = GREEN, pants = GREEN, hat = GREEN, head = SKIN, boots = BLACK, ears = true },
	{ id = "reindeer", name = "Reindeer", price = 55, blurb = "Brown coat, antlers and red nose",
		coat = BROWN, pants = BROWN, hat = BROWN, head = BROWN, boots = BROWN, antlers = true, nose = true },
	{ id = "snowman", name = "Snowman", price = 50, blurb = "White suit, top hat and carrot nose",
		coat = WHITE, pants = WHITE, hat = BLACK, head = WHITE, boots = BLACK, topHat = true, carrot = true },
	{ id = "goldwings", name = "Golden Wing Boots", price = 70, blurb = "Gold suit with flapping wings",
		coat = Color3.fromRGB(120, 80, 30), pants = Color3.fromRGB(90, 60, 20), hat = GOLD,
		head = SKIN, boots = GOLD, wings = true },
}

-- Builds a miniature mannequin wearing the selected outfit inside a
-- ViewportFrame, so shoppers can see exactly what they are buying.
local function makeAvatarPreview(avatar, parent, size)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = size
	viewport.BackgroundColor3 = Color3.fromRGB(52, 38, 44)
	viewport.BorderSizePixel = 2
	viewport.BorderColor3 = Color3.fromRGB(38, 28, 32)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.8, 4.8), Vector3.new(0, 1.5, 0))
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	local lightHost = Instance.new("Part")
	lightHost.Size = Vector3.new(1, 1, 1)
	lightHost.Position = Vector3.new(2, 4, 4)
	lightHost.Transparency = 1
	lightHost.Parent = world
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 244, 228)
	light.Brightness = 2.4
	light.Range = 18
	light.Parent = lightHost

	local function put(name, shape, partSize, pos, colour)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = partSize
		p.Position = pos
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = world
		return p
	end

	put("Stand", Enum.PartType.Cylinder, Vector3.new(0.12, 1.5, 1.5), Vector3.new(0, 0.07, 0),
		Color3.fromRGB(84, 62, 52))
	for _, side in ipairs({ -1, 1 }) do
		put("Boot", Enum.PartType.Block, Vector3.new(0.36, 0.26, 0.56), Vector3.new(side * 0.22, 0.2, 0.04), avatar.boots)
		put("Leg", Enum.PartType.Block, Vector3.new(0.34, 0.86, 0.34), Vector3.new(side * 0.22, 0.72, 0), avatar.pants)
		put("Arm", Enum.PartType.Block, Vector3.new(0.28, 0.92, 0.3), Vector3.new(side * 0.68, 1.55, 0), avatar.coat)
		put("Hand", Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28), Vector3.new(side * 0.68, 1.04, 0), avatar.head)
	end
	put("Torso", Enum.PartType.Block, Vector3.new(1.0, 1.05, 0.56), Vector3.new(0, 1.62, 0), avatar.coat)
	if avatar.belt then
		put("Belt", Enum.PartType.Block, Vector3.new(1.04, 0.18, 0.6), Vector3.new(0, 1.16, 0), BLACK)
		put("Buckle", Enum.PartType.Block, Vector3.new(0.22, 0.22, 0.1), Vector3.new(0, 1.16, 0.34), GOLD)
	end
	if avatar.wings then
		for _, side in ipairs({ -1, 1 }) do
			local wing = put("Wing" .. (side == -1 and "L" or "R"), Enum.PartType.Block, Vector3.new(1.7, 0.14, 1.05), Vector3.new(side * 0.35, 0.6, -0.25), GOLD)
			wing.CFrame = CFrame.new(side * 0.35, 0.6, -0.25) * CFrame.Angles(math.rad(-30), side * math.rad(22), side * math.rad(35))
		end
	end
	if avatar.apron then
		put("Apron", Enum.PartType.Block, Vector3.new(0.95, 1.0, 0.18), Vector3.new(0, 1.1, 0.4), WHITE)
	end
	put("Head", Enum.PartType.Ball, Vector3.new(0.74, 0.74, 0.74), Vector3.new(0, 2.5, 0), avatar.head)
	for _, side in ipairs({ -1, 1 }) do
		put("Eye", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1), Vector3.new(side * 0.15, 2.58, 0.34), BLACK)
	end

	if avatar.topHat then
		put("HatBrim", Enum.PartType.Cylinder, Vector3.new(0.9, 0.08, 0.9), Vector3.new(0, 2.86, 0), avatar.hat)
		put("HatTop", Enum.PartType.Cylinder, Vector3.new(0.62, 0.62, 0.62), Vector3.new(0, 3.18, 0), avatar.hat)
		put("HatBand", Enum.PartType.Cylinder, Vector3.new(0.95, 0.16, 0.95), Vector3.new(0, 2.78, 0), RED)
		if avatar.id == "snowman" then
			for i = 0, 2 do
				put("CoalButton" .. i, Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16), Vector3.new(0, 1.45 - i * 0.3, 0.32), BLACK)
			end
			put("Scarf", Enum.PartType.Block, Vector3.new(0.95, 0.18, 0.85), Vector3.new(0, 1.05, 0.32), RED)
		end
	else
		put("Hat", Enum.PartType.Cylinder, Vector3.new(0.66, 0.5, 0.66), Vector3.new(0, 2.96, 0), avatar.hat)
		put("HatTrim", Enum.PartType.Cylinder, Vector3.new(0.7, 0.16, 0.7), Vector3.new(0, 2.76, 0),
			avatar.id == "elf" and GREEN or WHITE)
		if avatar.id == "elf" then
			put("HatTip", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 3.3, 0), GREEN)
			put("JingleBell", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 3.3, 0), GOLD)
		end
	end

	if avatar.beard then
		put("Beard", Enum.PartType.Ball, Vector3.new(0.56, 0.52, 0.3), Vector3.new(0, 2.3, -0.34), WHITE)
		put("BeardLower", Enum.PartType.Ball, Vector3.new(0.5, 0.4, 0.25), Vector3.new(0, 2.18, -0.3), WHITE)
		put("Moustache", Enum.PartType.Ball, Vector3.new(0.34, 0.16, 0.2), Vector3.new(0, 2.44, -0.38), WHITE)
	end
	if avatar.hair then
		put("Hair", Enum.PartType.Ball, Vector3.new(0.82, 0.5, 0.82), Vector3.new(0, 2.78, 0), WHITE)
	end
	if avatar.ears then
		for _, side in ipairs({ -1, 1 }) do
			put("Ear", Enum.PartType.Ball, Vector3.new(0.24, 0.46, 0.24), Vector3.new(side * 0.46, 2.55, 0), SKIN).CFrame =
				CFrame.new(side * 0.46, 2.55, 0) * CFrame.Angles(0, 0, side * math.rad(-70))
		end
	end
	if avatar.antlers then
		for _, side in ipairs({ -1, 1 }) do
			put("Antler", Enum.PartType.Block, Vector3.new(0.12, 0.72, 0.12), Vector3.new(side * 0.3, 3.16, 0), BROWN).CFrame =
				CFrame.new(side * 0.3, 3.16, 0) * CFrame.Angles(0, 0, side * math.rad(-28))
			put("AntlerBranch", Enum.PartType.Block, Vector3.new(0.1, 0.36, 0.1), Vector3.new(side * 0.52, 3.32, 0), BROWN).CFrame =
				CFrame.new(side * 0.52, 3.32, 0) * CFrame.Angles(0, 0, side * math.rad(-55))
		end
	end
	if avatar.nose then
		put("Nose", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 2.44, 0.4), RED)
	end
	if avatar.carrot then
		put("Carrot", Enum.PartType.Ball, Vector3.new(0.16, 0.46, 0.16), Vector3.new(0, 2.46, 0.48), ORANGE).CFrame =
			CFrame.new(0, 2.46, 0.48) * CFrame.Angles(math.rad(90), 0, 0)
	end
	if avatar.wings then
		for _, side in ipairs({ -1, 1 }) do
			local wing = put("Wing" .. (side == -1 and "L" or "R"), Enum.PartType.Block, Vector3.new(1.7, 0.14, 1.05), Vector3.new(side * 0.35, 0.6, -0.25), GOLD)
			wing.CFrame = CFrame.new(side * 0.35, 0.6, -0.25) * CFrame.Angles(math.rad(-30), side * math.rad(22), side * math.rad(35))
		end
		put("Cape", Enum.PartType.Block, Vector3.new(0.95, 1.2, 0.18), Vector3.new(0, 1.0, -0.9), Color3.fromRGB(120, 80, 30))
		put("CapeTrim", Enum.PartType.Block, Vector3.new(1.0, 0.18, 0.22), Vector3.new(0, 1.6, -0.9), GOLD)
	end

	return viewport
end

local gui = Instance.new("ScreenGui")
gui.Name = "SantaWorkshopUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Menu"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(720, 550)
frame.BackgroundColor3 = Color3.fromRGB(32, 24, 28)
frame.BackgroundTransparency = 0.08
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 54)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.Text = "SANTA WORKSHOP BOUTIQUE"
title.TextColor3 = GOLD
title.Parent = frame

local wallet = Instance.new("TextLabel")
wallet.Position = UDim2.fromOffset(0, 52)
wallet.Size = UDim2.new(1, 0, 0, 28)
wallet.BackgroundTransparency = 1
wallet.Font = Enum.Font.GothamBold
wallet.TextSize = 18
wallet.TextColor3 = Color3.fromRGB(230, 220, 210)
wallet.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(0, 82)
status.Size = UDim2.new(1, 0, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 17
status.Text = ""
status.TextColor3 = Color3.fromRGB(180, 240, 190)
status.Parent = frame

local function refresh()
	wallet.Text = "COCOA BUCKS  " .. tostring(player:GetAttribute("CocoaBucks") or 0)
		.. "      WEARING  " .. tostring(player:GetAttribute("SantaOutfit") or "none")
end
refresh()
player:GetAttributeChangedSignal("CocoaBucks"):Connect(refresh)
player:GetAttributeChangedSignal("SantaOutfit"):Connect(refresh)

local close = Instance.new("TextButton")
close.Position = UDim2.fromOffset(624, 12)
close.Size = UDim2.fromOffset(80, 38)
close.BackgroundColor3 = Color3.fromRGB(150, 44, 52)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 20
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Parent = frame
close.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Gallery of avatar cards
local selected = 0
local detailPreview = nil
local buyButton

local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.Position = UDim2.fromOffset(18, 292)
detail.Size = UDim2.fromOffset(684, 180)
detail.BackgroundColor3 = Color3.fromRGB(44, 32, 38)
detail.BorderSizePixel = 1
detail.BorderColor3 = Color3.fromRGB(92, 70, 62)
detail.Parent = frame

local detailName = Instance.new("TextLabel")
detailName.Position = UDim2.fromOffset(176, 10)
detailName.Size = UDim2.fromOffset(494, 38)
detailName.BackgroundTransparency = 1
detailName.Font = Enum.Font.GothamBlack
detailName.TextSize = 28
detailName.TextColor3 = GOLD
detailName.Parent = detail

local detailBlurb = Instance.new("TextLabel")
detailBlurb.Position = UDim2.fromOffset(176, 50)
detailBlurb.Size = UDim2.fromOffset(494, 30)
detailBlurb.BackgroundTransparency = 1
detailBlurb.Font = Enum.Font.Gotham
detailBlurb.TextSize = 18
detailBlurb.TextColor3 = Color3.fromRGB(232, 224, 216)
detailBlurb.Parent = detail

local detailHint = Instance.new("TextLabel")
detailHint.Position = UDim2.fromOffset(176, 84)
detailHint.Size = UDim2.fromOffset(494, 26)
detailHint.BackgroundTransparency = 1
detailHint.Font = Enum.Font.GothamBold
detailHint.TextSize = 16
detailHint.TextColor3 = Color3.fromRGB(170, 214, 248)
detailHint.Text = "Instantly wear this outfit in the courts"
detailHint.Parent = detail

buyButton = Instance.new("TextButton")
buyButton.Position = UDim2.fromOffset(176, 120)
buyButton.Size = UDim2.fromOffset(300, 46)
buyButton.BackgroundColor3 = Color3.fromRGB(138, 44, 50)
buyButton.BorderSizePixel = 0
buyButton.Font = Enum.Font.GothamBold
buyButton.TextSize = 19
buyButton.TextColor3 = Color3.new(1, 1, 1)
buyButton.Parent = detail

local function select(index)
	selected = index
	local avatar = AVATARS[index]
	detailName.Text = avatar.name
	detailBlurb.Text = avatar.blurb
	buyButton.Text = string.format("BUY  ·  %d COCOA BUCKS", avatar.price)
	if detailPreview then
		detailPreview:Destroy()
	end
	detailPreview = makeAvatarPreview(avatar, detail, UDim2.fromOffset(160, 160))
	detailPreview.Position = UDim2.fromOffset(6, 10)
end

for index, avatar in ipairs(AVATARS) do
	local card = Instance.new("TextButton")
	card.Name = avatar.id
	card.Position = UDim2.fromOffset(18 + (index - 1) * 134, 120)
	card.Size = UDim2.fromOffset(126, 158)
	card.BackgroundColor3 = Color3.fromRGB(58, 40, 46)
	card.BorderSizePixel = 2
	card.BorderColor3 = Color3.fromRGB(104, 78, 66)
	card.Text = ""
	card.Parent = frame

	local preview = makeAvatarPreview(avatar, card, UDim2.fromOffset(122, 100))
	preview.Position = UDim2.fromOffset(2, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(2, 104)
	nameLabel.Size = UDim2.fromOffset(122, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(255, 245, 230)
	nameLabel.Text = avatar.name
	nameLabel.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Position = UDim2.fromOffset(2, 128)
	priceLabel.Size = UDim2.fromOffset(122, 24)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 15
	priceLabel.TextColor3 = GOLD
	priceLabel.Text = avatar.price .. " BUCKS"
	priceLabel.Parent = card

	card.MouseButton1Click:Connect(function()
		select(index)
	end)
end
buyButton.MouseButton1Click:Connect(function()
	if selected > 0 then
		Purchase:FireServer(AVATARS[selected].id)
	end
end)

local remove = Instance.new("TextButton")
remove.Position = UDim2.fromOffset(18, 486)
remove.Size = UDim2.fromOffset(684, 44)
remove.BackgroundColor3 = Color3.fromRGB(60, 70, 80)
remove.BorderSizePixel = 0
remove.Font = Enum.Font.GothamBold
remove.TextSize = 17
remove.TextColor3 = Color3.new(1, 1, 1)
remove.Text = "REMOVE OUTFIT"
remove.Parent = frame
remove.MouseButton1Click:Connect(function()
	Unequip:FireServer()
end)

OpenShop.OnClientEvent:Connect(function()
	refresh()
	if selected == 0 then
		select(1)
	end
	frame.Visible = true
end)

Result.OnClientEvent:Connect(function(message)
	status.Text = message
	task.delay(4, function()
		if status.Text == message then
			status.Text = ""
		end
	end)
end)
