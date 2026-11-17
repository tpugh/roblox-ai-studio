--!nonstrict
-- Client side of the hot chocolate stand: shop menu, Cocoa Bucks HUD,
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

local DRINKS = {
	{ id = "run", name = "Cocoa Rush", price = 15, blurb = "Run much faster for 60s" },
	{ id = "shoot", name = "Sharp Shooter", price = 20, blurb = "Sharper aim for 60s" },
	{ id = "dunk", name = "Slam Cocoa", price = 25, blurb = "Gamebreaker dunk ready now" },
	{ id = "steal", name = "Steal Cocoa", price = 15, blurb = "Longer reach on steals" },
	{ id = "snow", name = "Snowball Cocoa", price = 25, blurb = "Snowball gun that stuns defenders" },
}

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
wallet.TextColor3 = Color3.fromRGB(255, 226, 160)
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
frame.Size = UDim2.fromOffset(560, 480)
frame.BackgroundColor3 = Color3.fromRGB(32, 24, 28)
frame.BackgroundTransparency = 0.08
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 70)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 34
title.Text = "HOT CHOCOLATE"
title.TextColor3 = Color3.fromRGB(255, 222, 160)
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(0, 56)
subtitle.Size = UDim2.new(1, 0, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 17
subtitle.Text = "Pick your boost · score buckets or relax by the fire to earn Cocoa Bucks"
subtitle.TextColor3 = Color3.fromRGB(225, 216, 210)
subtitle.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(0, 88)
status.Size = UDim2.new(1, 0, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 17
status.Text = ""
status.TextColor3 = Color3.fromRGB(180, 240, 190)
status.Parent = frame

for index, drink in ipairs(DRINKS) do
	local button = Instance.new("TextButton")
	button.Name = drink.id
	button.Position = UDim2.fromOffset(24, 128 + (index - 1) * 58)
	button.Size = UDim2.fromOffset(512, 50)
	button.BackgroundColor3 = Color3.fromRGB(86, 48, 38)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(255, 245, 230)
	button.Text = string.format("%-22s %3d buck%s   ·   %s", drink.name, drink.price,
		drink.price == 1 and "" or "s", drink.blurb)
	button.Parent = frame
	button.MouseButton1Click:Connect(function()
		Purchase:FireServer(drink.id)
	end)
end

local close = Instance.new("TextButton")
close.Position = UDim2.fromOffset(452, 20)
close.Size = UDim2.fromOffset(84, 40)
close.BackgroundColor3 = Color3.fromRGB(150, 44, 52)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 20
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Parent = frame
local robuxFrame -- declared early so the close button can hide it too
close.MouseButton1Click:Connect(function()
	frame.Visible = false
	if robuxFrame then
		robuxFrame.Visible = false
	end
end)

-- Robux bundles ---------------------------------------------------------------
-- Product IDs and prices come from the shared config; the server opens the
-- actual MarketplaceService prompt and credits the Cocoa Bucks after payment.
local BuyBucks = remotes:WaitForChild("BuyBucks", 10)
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
robuxTitle.TextColor3 = Color3.fromRGB(255, 226, 160)
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
robuxButton.Position = UDim2.fromOffset(24, 414)
robuxButton.Size = UDim2.fromOffset(512, 46)
robuxButton.BackgroundColor3 = Color3.fromRGB(38, 96, 66)
robuxButton.BorderSizePixel = 0
robuxButton.Font = Enum.Font.GothamBold
robuxButton.TextSize = 18
robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
robuxButton.Text = "BUY COCOA BUCKS WITH ROBUX"
robuxButton.Parent = frame
robuxButton.MouseButton1Click:Connect(function()
	robuxFrame.Visible = true
end)

OpenShop.OnClientEvent:Connect(function(bucks)
	refreshWallet()
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
