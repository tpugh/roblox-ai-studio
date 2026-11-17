--!nonstrict
-- Run once in Edit mode. Builds the Santa avatar boutique just outside the
-- Workshop cabin: a counter with a shop prompt, a sign and a pair of mannequins
-- showing off the outfits. The shop logic lives in santa_workshop.server.lua.

local Workspace = game:GetService("Workspace")

local stand = Workspace:FindFirstChild("SantaWorkshopStand")
if stand then
	stand:Destroy()
end
stand = Instance.new("Model")
stand.Name = "SantaWorkshopStand"
stand.Parent = Workspace

local WOOD = Color3.fromRGB(122, 74, 44)
local RED = Color3.fromRGB(158, 42, 48)
local GREEN = Color3.fromRGB(32, 104, 64)
local SNOW = Color3.fromRGB(240, 244, 250)
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
	part.Parent = parent or stand
	return part
end

block("Deck", Vector3.new(14, 0.4, 12), Vector3.new(-32, 0.2, -8), WOOD, Enum.Material.Wood)
block("BackWall", Vector3.new(14, 6, 0.6), Vector3.new(-32, 3.2, -13.5), GREEN, Enum.Material.Wood)
block("Roof", Vector3.new(15, 0.7, 13), Vector3.new(-32, 6.4, -8), RED)
block("RoofSnow", Vector3.new(15.3, 0.2, 13.3), Vector3.new(-32, 6.85, -8), SNOW, Enum.Material.Snow)

local counter = block("Counter", Vector3.new(11, 2, 2.4), Vector3.new(-32, 1.3, -6), WOOD, Enum.Material.Wood)
counter.CanTouch = true
counter.CanQuery = true
block("CounterTop", Vector3.new(12, 0.3, 2.8), Vector3.new(-32, 2.45, -6), SNOW, Enum.Material.Snow)

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "AvatarPrompt"
prompt.ActionText = "Browse Santa avatars"
prompt.ObjectText = "Santa Workshop Boutique"
prompt.MaxActivationDistance = 12
prompt.Parent = counter

local signAnchor = block("SignAnchor", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-32, 5, -5.5), GOLD)
local gui = Instance.new("BillboardGui")
gui.Name = "ShopSign"
gui.Size = UDim2.fromOffset(520, 100)
gui.MaxDistance = 160
gui.LightInfluence = 0
gui.Parent = signAnchor
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
label.BackgroundTransparency = 0.2
label.Font = Enum.Font.GothamBold
label.Text = "SANTA WORKSHOP  ·  AVATAR BOUTIQUE"
label.TextColor3 = GOLD
label.TextScaled = true
label.Parent = gui

-- Two mannequins in Santa colours, purely decorative.
for index, x in ipairs({ -36, -28 }) do
	local colour = index == 1 and RED or GREEN
	block("MannequinTorso", Vector3.new(2, 2.6, 1.2), Vector3.new(x, 2, -11.5), colour)
	block("MannequinHead", Vector3.new(1.4, 1.4, 1.4), Vector3.new(x, 4, -11.5), Color3.fromRGB(232, 194, 158))
	block("MannequinHat", Vector3.new(1.2, 1.4, 1.2), Vector3.new(x, 5, -11.5), colour)
	block("MannequinBeard", Vector3.new(1.2, 0.9, 0.7), Vector3.new(x, 3.6, -10.9), SNOW)
end

local lamp = Instance.new("PointLight")
lamp.Color = Color3.fromRGB(255, 226, 180)
lamp.Brightness = 1.8
lamp.Range = 34
lamp.Parent = block("Lamp", Vector3.new(1, 1, 1), Vector3.new(-32, 5.5, -7), GOLD)

return "built Santa Workshop avatar boutique with shop prompt"
