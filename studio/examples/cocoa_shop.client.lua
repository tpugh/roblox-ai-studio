--!nonstrict
-- Client side of the hot chocolate stand. Shows a gallery of drink cards with
-- live 3D previews, a detail panel for the selected item, the Cocoa Bucks HUD,
-- purchase feedback and the spectator-deck camera view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("CocoaRemotes", 10)
if not remotes then
	return
end
local OpenShop = remotes:WaitForChild("OpenShop")
local Purchase = remotes:WaitForChild("Purchase")
local Result = remotes:WaitForChild("Result")
local WatchGame = remotes:WaitForChild("WatchGame")
local BuyBucks = remotes:WaitForChild("BuyBucks", 10)

local DRINKS = {
	{ id = "run", name = "Cocoa Rush", price = 15, blurb = "Run much faster for 60s",
		effect = "Speed boost · 60 seconds", mug = Color3.fromRGB(62, 168, 98), accent = Color3.fromRGB(255, 214, 78), kind = "bolt" },
	{ id = "shoot", name = "Sharp Shooter", price = 20, blurb = "Sharper aim for 60s",
		effect = "Precision aim · 60 seconds", mug = Color3.fromRGB(66, 132, 212), accent = Color3.fromRGB(238, 142, 44), kind = "ball" },
	{ id = "dunk", name = "Slam Cocoa", price = 25, blurb = "Gamebreaker dunk ready now",
		effect = "Gamebreaker charged · instant", mug = Color3.fromRGB(206, 60, 64), accent = Color3.fromRGB(238, 142, 44), kind = "ball" },
	{ id = "steal", name = "Steal Cocoa", price = 15, blurb = "Longer reach on steals",
		effect = "Long steal reach · 60 seconds", mug = Color3.fromRGB(142, 90, 180), accent = Color3.fromRGB(226, 228, 238), kind = "spark" },
	{ id = "snow", name = "Snowball Cocoa", price = 25, blurb = "Snowball gun · 30 rounds · knocks them down",
		effect = "Snowball gun · 90 seconds", mug = Color3.fromRGB(228, 238, 248), accent = Color3.fromRGB(255, 255, 255), kind = "snow" },
}

local COCOA = Color3.fromRGB(94, 54, 36)
local CREAM = Color3.fromRGB(255, 250, 238)
local DARK = Color3.fromRGB(38, 28, 32)
local GOLD = Color3.fromRGB(255, 222, 160)

-- Builds a small, self-contained 3D preview of a drink inside a ViewportFrame.
local function makeDrinkPreview(drink, parent, size)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = size
	viewport.BackgroundColor3 = Color3.fromRGB(58, 40, 46)
	viewport.BorderSizePixel = 2
	viewport.BorderColor3 = DARK
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.9, 3.6), Vector3.new(0, 1.15, 0))
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	local lightHost = Instance.new("Part")
	lightHost.Size = Vector3.new(1, 1, 1)
	lightHost.Position = Vector3.new(2, 4, 4)
	lightHost.Transparency = 1
	lightHost.Parent = world
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 220)
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

	put("Saucer", Enum.PartType.Cylinder, Vector3.new(0.14, 1.7, 1.7), Vector3.new(0, 0.12, 0),
		Color3.fromRGB(236, 232, 224))
	put("Mug", Enum.PartType.Cylinder, Vector3.new(1.12, 1.3, 1.12), Vector3.new(0, 0.88, 0), drink.mug)
	put("Sleeve", Enum.PartType.Cylinder, Vector3.new(1.16, 0.26, 1.16), Vector3.new(0, 0.98, 0), drink.accent)
	put("Cocoa", Enum.PartType.Cylinder, Vector3.new(0.98, 0.12, 0.98), Vector3.new(0, 1.55, 0), COCOA)
	put("Cream", Enum.PartType.Ball, Vector3.new(0.72, 0.42, 0.72), Vector3.new(0, 1.72, 0), CREAM)
	put("Straw", Enum.PartType.Cylinder, Vector3.new(0.09, 1.05, 0.09), Vector3.new(0.34, 1.75, 0),
		Color3.fromRGB(240, 244, 248)).CFrame = CFrame.new(0.34, 1.75, 0) * CFrame.Angles(0, 0, math.rad(-18))

	if drink.kind == "ball" then
		put("Basketball", Enum.PartType.Ball, Vector3.new(0.52, 0.52, 0.52), Vector3.new(0, 2.12, 0),
			Color3.fromRGB(238, 142, 44))
	elseif drink.kind == "snow" then
		put("Snowball", Enum.PartType.Ball, Vector3.new(0.46, 0.46, 0.46), Vector3.new(0, 2.08, 0), CREAM)
		put("SnowSpark", Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16), Vector3.new(0.34, 2.3, 0.1),
			Color3.fromRGB(170, 214, 248))
	elseif drink.kind == "bolt" then
		put("Bolt", Enum.PartType.Block, Vector3.new(0.14, 0.6, 0.14), Vector3.new(0, 2.15, 0), drink.accent).CFrame =
			CFrame.new(0, 2.15, 0) * CFrame.Angles(0, 0, math.rad(24))
	else
		put("Spark", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 2.1, 0), drink.accent)
	end

	return viewport
end

local gui = Instance.new("ScreenGui")
gui.Name = "CocoaShopUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local wallet = Instance.new("TextLabel")
wallet.Name = "Wallet"
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -16, 0, 16)
wallet.Size = UDim2.fromOffset(260, 34)
wallet.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
wallet.BackgroundTransparency = 0.35
wallet.Font = Enum.Font.GothamBold
wallet.TextSize = 18
wallet.TextColor3 = GOLD
wallet.TextStrokeTransparency = 0.6
wallet.Parent = gui

local function refreshWallet()
	wallet.Text = "COCOA BUCKS  " .. tostring(player:GetAttribute("CocoaBucks") or 0)
end
refreshWallet()
player:GetAttributeChangedSignal("CocoaBucks"):Connect(refreshWallet)

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
title.Size = UDim2.new(1, 0, 0, 56)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 32
title.Text = "HOT CHOCOLATE GALLERY"
title.TextColor3 = GOLD
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(0, 54)
subtitle.Size = UDim2.new(1, 0, 0, 26)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 16
subtitle.Text = "Pick a drink to see it up close · score buckets or relax by the fire to earn Cocoa Bucks"
subtitle.TextColor3 = Color3.fromRGB(225, 216, 210)
subtitle.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(0, 82)
status.Size = UDim2.new(1, 0, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 17
status.Text = ""
status.TextColor3 = Color3.fromRGB(180, 240, 190)
status.Parent = frame

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
local robuxFrame
close.MouseButton1Click:Connect(function()
	frame.Visible = false
	if robuxFrame then
		robuxFrame.Visible = false
	end
end)

-- Gallery of drink cards -----------------------------------------------------
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

local detailEffect = Instance.new("TextLabel")
detailEffect.Position = UDim2.fromOffset(176, 84)
detailEffect.Size = UDim2.fromOffset(494, 26)
detailEffect.BackgroundTransparency = 1
detailEffect.Font = Enum.Font.GothamBold
detailEffect.TextSize = 16
detailEffect.TextColor3 = Color3.fromRGB(170, 214, 248)
detailEffect.Parent = detail

buyButton = Instance.new("TextButton")
buyButton.Position = UDim2.fromOffset(176, 120)
buyButton.Size = UDim2.fromOffset(300, 46)
buyButton.BackgroundColor3 = Color3.fromRGB(48, 122, 78)
buyButton.BorderSizePixel = 0
buyButton.Font = Enum.Font.GothamBold
buyButton.TextSize = 19
buyButton.TextColor3 = Color3.new(1, 1, 1)
buyButton.Parent = detail

local function select(index)
	selected = index
	local drink = DRINKS[index]
	detailName.Text = drink.name
	detailBlurb.Text = drink.blurb
	detailEffect.Text = drink.effect
	buyButton.Text = string.format("BUY  ·  %d COCOA BUCKS", drink.price)
	if detailPreview then
		detailPreview:Destroy()
	end
	detailPreview = makeDrinkPreview(drink, detail, UDim2.fromOffset(160, 160))
	detailPreview.Position = UDim2.fromOffset(6, 10)
end

for index, drink in ipairs(DRINKS) do
	local card = Instance.new("TextButton")
	card.Name = drink.id
	card.Position = UDim2.fromOffset(18 + (index - 1) * 134, 120)
	card.Size = UDim2.fromOffset(126, 158)
	card.BackgroundColor3 = Color3.fromRGB(58, 40, 46)
	card.BorderSizePixel = 2
	card.BorderColor3 = Color3.fromRGB(104, 78, 66)
	card.Text = ""
	card.Parent = frame

	local preview = makeDrinkPreview(drink, card, UDim2.fromOffset(122, 100))
	preview.Position = UDim2.fromOffset(2, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(2, 104)
	nameLabel.Size = UDim2.fromOffset(122, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(255, 245, 230)
	nameLabel.Text = drink.name
	nameLabel.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Position = UDim2.fromOffset(2, 128)
	priceLabel.Size = UDim2.fromOffset(122, 24)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 15
	priceLabel.TextColor3 = GOLD
	priceLabel.Text = drink.price .. " BUCKS"
	priceLabel.Parent = card

	card.MouseButton1Click:Connect(function()
		select(index)
	end)
end
buyButton.MouseButton1Click:Connect(function()
	if selected > 0 then
		Purchase:FireServer(DRINKS[selected].id)
	end
end)

-- Robux bundles ---------------------------------------------------------------
-- Product IDs and prices come from the shared config; the server opens the
-- actual MarketplaceService prompt and credits the Cocoa Bucks after payment.
robuxFrame = Instance.new("Frame")
robuxFrame.Name = "RobuxMenu"
robuxFrame.AnchorPoint = Vector2.new(0.5, 0.5)
robuxFrame.Position = UDim2.fromScale(0.5, 0.5)
robuxFrame.Size = UDim2.fromOffset(420, 260)
robuxFrame.BackgroundColor3 = Color3.fromRGB(40, 28, 32)
robuxFrame.Visible = false
robuxFrame.Parent = gui

local robuxTitle = Instance.new("TextLabel")
robuxTitle.Size = UDim2.new(1, 0, 0, 50)
robuxTitle.BackgroundTransparency = 1
robuxTitle.Font = Enum.Font.GothamBlack
robuxTitle.TextSize = 24
robuxTitle.Text = "COCOA BUCKS WITH ROBUX"
robuxTitle.TextColor3 = GOLD
robuxTitle.Parent = robuxFrame

local robuxClose = Instance.new("TextButton")
robuxClose.Position = UDim2.fromOffset(360, 10)
robuxClose.Size = UDim2.fromOffset(44, 36)
robuxClose.BackgroundColor3 = Color3.fromRGB(150, 44, 52)
robuxClose.BorderSizePixel = 0
robuxClose.Font = Enum.Font.GothamBold
robuxClose.TextSize = 18
robuxClose.Text = "X"
robuxClose.TextColor3 = Color3.new(1, 1, 1)
robuxClose.Parent = robuxFrame
robuxClose.MouseButton1Click:Connect(function()
	robuxFrame.Visible = false
end)

local configModule = ReplicatedStorage:FindFirstChild("CocoaMonetizationConfig")
if BuyBucks and configModule then
	local ok, config = pcall(function()
		return require(configModule)
	end)
	if ok and config and config.Products then
		for index, product in ipairs(config.Products) do
			local button = Instance.new("TextButton")
			button.Position = UDim2.fromOffset(24, 58 + (index - 1) * 56)
			button.Size = UDim2.fromOffset(372, 46)
			button.BackgroundColor3 = Color3.fromRGB(88, 52, 42)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = 18
			button.TextColor3 = Color3.fromRGB(255, 245, 230)
			button.Text = string.format("%s  ·  %d Robux", product.name, product.robux)
			button.Parent = robuxFrame
			button.MouseButton1Click:Connect(function()
				if BuyBucks then
					BuyBucks:FireServer(product.id)
				end
			end)
		end
	end
end

local robuxButton = Instance.new("TextButton")
robuxButton.Position = UDim2.fromOffset(18, 486)
robuxButton.Size = UDim2.fromOffset(684, 46)
robuxButton.BackgroundColor3 = Color3.fromRGB(38, 96, 66)
robuxButton.BorderSizePixel = 0
robuxButton.Font = Enum.Font.GothamBold
robuxButton.TextSize = 18
robuxButton.TextColor3 = Color3.new(1, 1, 1)
robuxButton.Text = "BUY COCOA BUCKS WITH ROBUX"
robuxButton.Parent = frame
robuxButton.MouseButton1Click:Connect(function()
	robuxFrame.Visible = true
end)

OpenShop.OnClientEvent:Connect(function(bucks)
	refreshWallet()
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

-- Spectator deck: hold a scriptable view of the street court for a while.
local watching = false
WatchGame.OnClientEvent:Connect(function()
	if watching then
		return
	end
	watching = true
	local camera = Workspace.CurrentCamera
	if not camera then
		watching = false
		return
	end
	local previousType = camera.CameraType
	local previousCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(92, 34, 62) * CFrame.Angles(math.rad(-24), math.rad(0), 0)
	task.delay(12, function()
		camera.CameraType = previousType
		camera.CFrame = previousCFrame
		watching = false
	end)
end)
