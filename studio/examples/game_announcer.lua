--!nonstrict
-- Run once in Edit mode. Builds the score/move announcer's bubble above the
-- street court. The box is filled in by game_announcer.server.lua at runtime.

local Workspace = game:GetService("Workspace")

local RED = Color3.fromRGB(224, 48, 72)
local CREAM = Color3.fromRGB(255, 250, 242)
local DARK = Color3.fromRGB(66, 26, 40)

local old = Workspace:FindFirstChild("GameAnnouncer")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "GameAnnouncer"
model.Parent = Workspace

local anchor = Instance.new("Part")
anchor.Name = "BubbleAnchor"
anchor.Size = Vector3.new(1, 1, 1)
anchor.Position = Vector3.new(26, 21, -30)
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanTouch = false
anchor.CanQuery = false
anchor.Transparency = 1
anchor.Parent = model
model.PrimaryPart = anchor

local gui = Instance.new("BillboardGui")
gui.Name = "Bubble"
gui.Size = UDim2.fromOffset(720, 132)
gui.MaxDistance = 300
gui.LightInfluence = 0
gui.Parent = anchor

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local shadow = Instance.new("Frame")
shadow.Size = UDim2.fromScale(1, 1)
shadow.Position = UDim2.fromOffset(6, 8)
shadow.BackgroundColor3 = Color3.fromRGB(20, 8, 14)
shadow.BackgroundTransparency = 0.45
shadow.BorderSizePixel = 0
shadow.Parent = gui
round(shadow, 34)

local rim = Instance.new("Frame")
rim.Size = UDim2.fromScale(1, 1)
rim.BackgroundColor3 = RED
rim.BorderSizePixel = 0
rim.Parent = gui
round(rim, 34)

-- Candy-cane trim along the bottom of the bubble.
rim.ClipsDescendants = true
for i = 1, 56 do
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(0, 1)
	stripe.Size = UDim2.fromOffset(20, 16)
	stripe.Position = UDim2.fromOffset((i - 2) * 20, 0)
	stripe.Rotation = 28
	stripe.BackgroundColor3 = (i % 2 == 0) and RED or CREAM
	stripe.BorderSizePixel = 0
	stripe.Parent = rim
end

local label = Instance.new("TextLabel")
label.Name = "Text"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.45)
label.Size = UDim2.new(1, -14, 1, -30)
label.BackgroundColor3 = CREAM
label.BackgroundTransparency = 0.02
label.Font = Enum.Font.FredokaOne
label.Text = "HOOPSMAS STREETBALL"
label.TextColor3 = DARK
label.TextSize = 42
label.TextScaled = false
label.TextStrokeColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.9
label.Parent = gui
round(label, 26)

return "built GameAnnouncer"
