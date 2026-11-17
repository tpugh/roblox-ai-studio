--!nonstrict
-- Shared candy-cane HUD theme. Big rounded "bubble" panels, a soft shadow and
-- red/white stripes, with FredokaOne for a rounded, storybook look.
-- Install as a ModuleScript under ReplicatedStorage.CandyUI.

local Candy = {}

Candy.FONT = Enum.Font.FredokaOne
Candy.RED = Color3.fromRGB(224, 48, 72)
Candy.CREAM = Color3.fromRGB(255, 250, 242)
Candy.PINK = Color3.fromRGB(255, 122, 152)
Candy.MINT = Color3.fromRGB(104, 212, 176)
Candy.GOLD = Color3.fromRGB(255, 208, 84)
Candy.DARK = Color3.fromRGB(66, 26, 40)

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 18)
	c.Parent = inst
	return c
end
Candy.corner = corner

-- Returns the inner panel; parent text and bars to it.
function Candy.bubble(parent, name, size, position, anchor, accent)
	anchor = anchor or Vector2.new(0, 0)
	accent = accent or Candy.RED

	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.AnchorPoint = anchor
	shadow.Position = position + UDim2.fromOffset(5, 6)
	shadow.Size = size
	shadow.BackgroundColor3 = Color3.fromRGB(20, 8, 14)
	shadow.BackgroundTransparency = 0.5
	shadow.BorderSizePixel = 0
	shadow.Parent = parent
	corner(shadow, 22)

	local rim = Instance.new("Frame")
	rim.Name = name
	rim.AnchorPoint = anchor
	rim.Position = position
	rim.Size = size
	rim.BackgroundColor3 = accent
	rim.BorderSizePixel = 0
	rim.Parent = parent
	corner(rim, 22)

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundColor3 = Candy.CREAM
	inner.BackgroundTransparency = 0.03
	inner.BorderSizePixel = 0
	inner.ClipsDescendants = true
	inner.Parent = rim
	corner(inner, 17)

	-- A little candy-cane stripe trim along the bottom edge of every bubble.
	local width = size.X.Offset > 0 and size.X.Offset or 200
	local count = math.ceil(width / 18) + 2
	for i = 1, count do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.fromOffset(18, 11)
		stripe.Position = UDim2.fromOffset((i - 2) * 18, 0)
		stripe.AnchorPoint = Vector2.new(0, 1)
		stripe.Rotation = 28
		stripe.BackgroundColor3 = (i % 2 == 0) and Candy.RED or Candy.CREAM
		stripe.BorderSizePixel = 0
		stripe.Parent = inner
	end

	return inner
end

function Candy.text(parent, name, text, size, textSize, colour, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.46)
	label.Size = size or UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Candy.FONT
	label.TextSize = textSize or 24
	label.Text = text
	label.TextColor3 = colour or Candy.DARK
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.9
	label.Parent = parent
	return label
end

-- Hides or shows a bubble, including the drop shadow that sits beside its rim.
function Candy.show(inner, visible)
	local rim = inner and inner.Parent
	if not rim then
		return
	end
	rim.Visible = visible
	local shadow = rim.Parent and rim.Parent:FindFirstChild(rim.Name .. "Shadow")
	if shadow then
		shadow.Visible = visible
	end
end

return Candy
