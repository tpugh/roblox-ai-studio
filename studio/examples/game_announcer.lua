--!nonstrict
-- Run once in Edit mode. Builds the score/move announcer's sign above the
-- street court. The box is filled in by game_announcer.server.lua at runtime.

local Workspace = game:GetService("Workspace")

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
anchor.Position = Vector3.new(0, 17, -24)
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanTouch = false
anchor.CanQuery = false
anchor.Transparency = 1
anchor.Parent = model
model.PrimaryPart = anchor

local gui = Instance.new("BillboardGui")
gui.Name = "Bubble"
gui.Size = UDim2.fromOffset(640, 120)
gui.MaxDistance = 260
gui.LightInfluence = 0
gui.Parent = anchor

local label = Instance.new("TextLabel")
label.Name = "Text"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(24, 18, 24)
label.BackgroundTransparency = 0.25
label.Font = Enum.Font.GothamBlack
label.Text = "HOOPSMAS STREETBALL"
label.TextColor3 = Color3.fromRGB(255, 226, 160)
label.TextStrokeTransparency = 0.45
label.TextScaled = true
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.16, 0)
corner.Parent = label

return "built GameAnnouncer"
