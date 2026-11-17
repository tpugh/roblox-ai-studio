--!nonstrict
-- Run once in Edit mode. Builds the Hot Chocolate stand on the open grass just
-- north of the street court: a counter with a shop prompt, a menu board,
-- stools, spectator benches facing the court, a fire pit and warm lighting.
-- The shop logic lives in cocoa_shop.server.lua / cocoa_shop.client.lua.

local Workspace = game:GetService("Workspace")

local stand = Workspace:FindFirstChild("HotChocolateStand")
if stand then
	stand:Destroy()
end
stand = Instance.new("Model")
stand.Name = "HotChocolateStand"
stand.Parent = Workspace

local WOOD = Color3.fromRGB(122, 74, 44)
local DARK = Color3.fromRGB(64, 36, 28)
local GREEN = Color3.fromRGB(34, 106, 62)
local RED = Color3.fromRGB(158, 44, 52)
local SNOW = Color3.fromRGB(240, 244, 250)

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
	part.Parent = parent or stand
	return part
end

-- Deck and hut ---------------------------------------------------------------
block("Deck", Vector3.new(22, 0.5, 16), Vector3.new(5, 0.25, -48), WOOD, Enum.Material.Wood)
block("BackWall", Vector3.new(22, 8, 0.8), Vector3.new(5, 4.2, -55.5), DARK, Enum.Material.Wood)
block("WallL", Vector3.new(0.8, 8, 15), Vector3.new(-6, 4.2, -48), DARK, Enum.Material.Wood)
block("WallR", Vector3.new(0.8, 8, 15), Vector3.new(16, 4.2, -48), DARK, Enum.Material.Wood)
block("Roof", Vector3.new(24, 0.9, 17), Vector3.new(5, 8.8, -48), GREEN, Enum.Material.Wood)
block("RoofSnow", Vector3.new(24.4, 0.25, 17.4), Vector3.new(5, 9.35, -48), SNOW, Enum.Material.Snow)
for _, x in ipairs({ -5, 5, 15 }) do
	block("Stripe", Vector3.new(2.4, 0.25, 17.5), Vector3.new(x, 9.5, -48), RED)
end

-- Counter and stools ---------------------------------------------------------
local counter = block("Counter", Vector3.new(16, 2, 2.6), Vector3.new(5, 1.3, -45), WOOD, Enum.Material.Wood)
counter.CanTouch = true
counter.CanQuery = true
block("CounterTop", Vector3.new(17, 0.35, 3), Vector3.new(5, 2.45, -45), SNOW, Enum.Material.Snow)

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "ShopPrompt"
prompt.ActionText = "Browse Hot Chocolate"
prompt.ObjectText = "Cocoa Stand"
prompt.MaxActivationDistance = 12
prompt.Parent = counter

for _, x in ipairs({ 0, 5, 10 }) do
	local stool = block("Stool", Vector3.new(1.4, 1.2, 1.4), Vector3.new(x, 0.8, -42.2), RED)
	stool.Shape = Enum.PartType.Cylinder
	stool.CFrame = CFrame.new(stool.Position) * CFrame.Angles(0, 0, math.pi / 2)
end

-- Signs ---------------------------------------------------------------------
local function sign(name, text, position, size, color, parent)
	local anchor = block(name .. "Anchor", Vector3.new(0.3, 0.3, 0.3), position, color, nil, parent)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	return gui
end

sign("ShopSign", "HOT CHOCOLATE  ☕  COCOA SHOP", Vector3.new(5, 6.5, -44.5), UDim2.fromOffset(560, 90), Color3.fromRGB(255, 222, 160))
sign("MenuBoard",
	"Cocoa Rush 15  ·  Sharp Shooter 20\nSlam Cocoa 25  ·  Steal Cocoa 15\nSnowball Cocoa 25  ·  60s each",
	Vector3.new(5, 3.8, -44.5), UDim2.fromOffset(520, 170), Color3.fromRGB(245, 236, 220))

-- Hangout and spectating ----------------------------------------------------
for _, x in ipairs({ -2, 12 }) do
	block("Bench", Vector3.new(8, 0.6, 2.4), Vector3.new(x, 0.6, -39), WOOD, Enum.Material.Wood)
	block("BenchBack", Vector3.new(8, 1.4, 0.4), Vector3.new(x, 1.4, -40), GREEN)
end
local watchPart = block("WatchSpot", Vector3.new(3, 0.3, 3), Vector3.new(5, 0.3, -37), SNOW, Enum.Material.Snow)
watchPart.CanTouch = true
watchPart.CanQuery = true
local watchPrompt = Instance.new("ProximityPrompt")
watchPrompt.Name = "WatchPrompt"
watchPrompt.ActionText = "Watch the game"
watchPrompt.ObjectText = "Spectator deck"
watchPrompt.MaxActivationDistance = 12
watchPrompt.Parent = watchPart
sign("WatchSign", "SPECTATOR DECK\npress E to watch", Vector3.new(5, 4.5, -37), UDim2.fromOffset(320, 110), Color3.fromRGB(200, 225, 255))

-- Fire pit ------------------------------------------------------------------
block("FirePit", Vector3.new(3.2, 0.8, 3.2), Vector3.new(13, 0.5, -51), DARK, Enum.Material.Slate)
local fire = block("Fire", Vector3.new(1.8, 1.4, 1.8), Vector3.new(13, 1.4, -51), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
fire.CanTouch = false
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 170, 90)
glow.Brightness = 2.2
glow.Range = 28
glow.Parent = fire

local lamp = Instance.new("PointLight")
lamp.Color = Color3.fromRGB(255, 226, 180)
lamp.Brightness = 1.6
lamp.Range = 40
lamp.Parent = block("Lamp", Vector3.new(1, 1, 1), Vector3.new(5, 7, -46), SNOW)

return "built hot chocolate stand with shop, stools, benches and fire pit"
