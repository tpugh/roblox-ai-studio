--!nonstrict
-- Santa Workshop boutique UI: browse Santa outfits, buy them with Cocoa Bucks,
-- see purchase feedback and take the outfit off again.

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

local AVATARS = {
	{ id = "santa", name = "Classic Santa", price = 60, blurb = "Red suit, hat, beard and belt" },
	{ id = "mrs", name = "Mrs Claus", price = 50, blurb = "Red dress, white hair and boots" },
	{ id = "elf", name = "Workshop Elf", price = 40, blurb = "Green suit, hat and pointy ears" },
	{ id = "reindeer", name = "Reindeer", price = 55, blurb = "Brown coat, antlers and red nose" },
	{ id = "snowman", name = "Snowman", price = 50, blurb = "White suit, top hat and carrot nose" },
}

local gui = Instance.new("ScreenGui")
gui.Name = "SantaWorkshopUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Menu"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(560, 520)
frame.BackgroundColor3 = Color3.fromRGB(32, 24, 28)
frame.BackgroundTransparency = 0.08
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 70)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 30
title.Text = "SANTA WORKSHOP BOUTIQUE"
title.TextColor3 = Color3.fromRGB(255, 226, 160)
title.Parent = frame

local wallet = Instance.new("TextLabel")
wallet.Position = UDim2.fromOffset(0, 64)
wallet.Size = UDim2.new(1, 0, 0, 26)
wallet.BackgroundTransparency = 1
wallet.Font = Enum.Font.GothamBold
wallet.TextSize = 18
wallet.TextColor3 = Color3.fromRGB(230, 220, 210)
wallet.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(0, 94)
status.Size = UDim2.new(1, 0, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 17
status.TextColor3 = Color3.fromRGB(180, 240, 190)
status.Parent = frame

local function refresh(text)
	wallet.Text = "COCOA BUCKS  " .. tostring(player:GetAttribute("CocoaBucks") or 0)
		.. "      WEARING  " .. tostring(player:GetAttribute("SantaOutfit") or "none")
end
refresh()
player:GetAttributeChangedSignal("CocoaBucks"):Connect(refresh)
player:GetAttributeChangedSignal("SantaOutfit"):Connect(refresh)

for index, avatar in ipairs(AVATARS) do
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(24, 134 + (index - 1) * 56)
	button.Size = UDim2.fromOffset(512, 48)
	button.BackgroundColor3 = Color3.fromRGB(92, 46, 44)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(255, 245, 230)
	button.Text = string.format("%-18s %3d bucks  ·  %s", avatar.name, avatar.price, avatar.blurb)
	button.Parent = frame
	button.MouseButton1Click:Connect(function()
		Purchase:FireServer(avatar.id)
	end)
end

local remove = Instance.new("TextButton")
remove.Position = UDim2.fromOffset(24, 422)
remove.Size = UDim2.fromOffset(512, 44)
remove.BackgroundColor3 = Color3.fromRGB(60, 70, 80)
remove.BorderSizePixel = 0
remove.Font = Enum.Font.GothamBold
remove.TextSize = 17
remove.TextColor3 = Color3.fromRGB(255, 255, 255)
remove.Text = "REMOVE OUTFIT"
remove.Parent = frame
remove.MouseButton1Click:Connect(function()
	Unequip:FireServer()
end)

local close = Instance.new("TextButton")
close.Position = UDim2.fromOffset(452, 16)
close.Size = UDim2.fromOffset(84, 40)
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

OpenShop.OnClientEvent:Connect(function()
	refresh()
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
