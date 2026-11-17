--!nonstrict
-- Run once in Edit mode, after winter_perimeter.lua. Adds a groomed ski run
-- beyond the north fence with carved track lines, slalom gates and a lift line,
-- plus a cluster of lit log cabins in the aspen grove.

local Workspace = game:GetService("Workspace")
local root = Workspace:FindFirstChild("WinterPerimeter")
if not root then
	warn("[SkiLines] run winter_perimeter.lua first")
	return
end

local SNOW = Color3.fromRGB(238, 244, 250)
local TRACK = Color3.fromRGB(120, 156, 188)

-- Cabin spots are shared by the clearing pass and the build pass below.
local CABIN_SPOTS = {
	{ "Elf Lodge", Vector3.new(-145, 0, -35), "ELF LODGE" },
	{ "Snow Cabin", Vector3.new(-140, 0, 52), "SNOW CABIN" },
	{ "Cocoa Lodge", Vector3.new(175, 0, -30), "COCOA LODGE" },
	{ "Pine Rest", Vector3.new(170, 0, 55), "PINE REST" },
	{ "North Star Cabin", Vector3.new(25, 0, -135), "NORTH STAR CABIN" },
}

-- Clear aspens out of the ski run and each cabin clearing so the new features
-- are not buried in the grove.
local grove = root:FindFirstChild("AspenGrove")
if grove then
	for _, part in ipairs(grove:GetChildren()) do
		local p = part.Position
		local inRun = p.X > -26 and p.X < 78 and p.Z > -222 and p.Z < -78
		local inClearing = false
		for _, spot in ipairs(CABIN_SPOTS) do
			local dx, dz = p.X - spot[2].X, p.Z - spot[2].Z
			if dx * dx + dz * dz < 24 * 24 then
				inClearing = true
				break
			end
		end
		if inRun or inClearing then
			part:Destroy()
		end
	end
end
local LOG = Color3.fromRGB(116, 72, 46)
local WARM = Color3.fromRGB(255, 214, 138)
local CHIMNEY = Color3.fromRGB(76, 62, 58)
local RED = Color3.fromRGB(198, 52, 54)
local BLUE = Color3.fromRGB(52, 104, 178)
local PINE = Color3.fromRGB(30, 74, 58)

local function block(name, size, position, colour, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = colour or Color3.new(1, 1, 1)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Groomed ski run ------------------------------------------------------------
local run = root:FindFirstChild("SkiRun")
if run then
	run:Destroy()
end
run = Instance.new("Model")
run.Name = "SkiRun"
run.Parent = root

local slope = block("Slope", Vector3.new(90, 4, 130), Vector3.new(25, 10, -150), SNOW, Enum.Material.Snow, run)
slope.CFrame = CFrame.new(25, 10, -150) * CFrame.Angles(0.15, 0, 0)
run.PrimaryPart = slope

local function put(name, size, offset, colour, material, rotation)
	local part = block(name, size, Vector3.new(0, 0, 0), colour, material, run)
	part.CFrame = slope.CFrame * CFrame.new(table.unpack(offset)) * (rotation or CFrame.new())
	return part
end

-- Four parallel carved lines: two lanes, two skis each.
for _, lane in ipairs({ -8, 6 }) do
	for _, ski in ipairs({ -1.4, 1.4 }) do
		local track = put("SkiLine", Vector3.new(1.1, 0.14, 118), { lane + ski, 2.2, 0 }, TRACK, Enum.Material.SmoothPlastic)
		track.Transparency = 0.1
	end
end

-- Raised snow berms along both edges frame the groomed run.
for _, side in ipairs({ -1, 1 }) do
	put("RunBerm", Vector3.new(1.6, 1.2, 128), { side * 32, 2.6, 0 }, SNOW, Enum.Material.Snow)
end

-- Slalom gates alternating along the run.
for index, z in ipairs({ -42, -23, -4, 15, 34 }) do
	local side = index % 2 == 0 and 1 or -1
	local colour = side == 1 and RED or BLUE
	put("GatePole", Vector3.new(0.4, 4, 0.4), { side * 18, 4, z }, colour)
	put("GateFlag", Vector3.new(2.6, 1.4, 0.18), { side * 19.3, 5.4, z }, colour)
end

local function banner(name, z, text)
	for _, side in ipairs({ -1, 1 }) do
		put("BannerPost", Vector3.new(0.6, 8, 0.6), { side * 26, 4, z }, LOG, Enum.Material.Wood)
	end
	local beam = put("BannerBeam", Vector3.new(53, 1.8, 0.7), { 0, 8, z }, LOG, Enum.Material.Wood)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RunSign"
	gui.Size = UDim2.fromOffset(420, 80)
	gui.MaxDistance = 240
	gui.Parent = beam
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = WARM
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
end
banner("StartBanner", -58, "SKI RUN  ·  START")
banner("FinishBanner", 58, "FINISH  ·  HOOPS LODGE")

-- Lift line: cable, towers and hanging chairs.
put("LiftCable", Vector3.new(0.25, 0.25, 132), { 36, 14, 0 }, Color3.fromRGB(48, 54, 62), Enum.Material.Neon)
for _, z in ipairs({ -50, -25, 0, 25, 50 }) do
	put("LiftTower", Vector3.new(0.8, 14, 0.8), { 36, 7, z }, Color3.fromRGB(64, 70, 78), Enum.Material.SmoothPlastic)
	put("TowerArm", Vector3.new(5, 0.5, 0.5), { 36, 14, z }, Color3.fromRGB(64, 70, 78))
end
for _, z in ipairs({ -38, -13, 12, 37 }) do
	put("LiftChair", Vector3.new(3, 0.5, 1.4), { 36, 10, z }, LOG, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		put("ChairHanger", Vector3.new(0.14, 3.5, 0.14), { 36 + side * 1.2, 12, z }, Color3.fromRGB(64, 70, 78))
	end
end

-- Pines down both edges of the run.
for index, z in ipairs({ -50, -20, 10, 40 }) do
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (38 + (index % 2) * 4)
		for tier = 0, 2 do
			put("RunPine", Vector3.new(6 - tier * 1.5, 7, 6 - tier * 1.5),
				{ x, 2 + tier * 5, z }, PINE)
		end
		put("RunPineSnow", Vector3.new(2, 1, 2), { x, 13, z }, SNOW, Enum.Material.Snow)
	end
end

-- Cabins in the grove --------------------------------------------------------
local cabins = root:FindFirstChild("Cabins")
if cabins then
	cabins:Destroy()
end
cabins = Instance.new("Folder")
cabins.Name = "Cabins"
cabins.Parent = root

local function cabin(name, position, text)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = cabins
	local rootPart = block("CabinRoot", Vector3.new(1, 1, 1), position, SNOW, nil, model)
	rootPart.Transparency = 1
	model.PrimaryPart = rootPart
	local function putCabin(partName, size, offset, colour, material)
		local part = block(partName, size, Vector3.new(0, 0, 0), colour, material, model)
		part.CFrame = rootPart.CFrame * CFrame.new(table.unpack(offset))
		return part
	end

	putCabin("Foundation", Vector3.new(15, 0.6, 12), { 0, 0.3, 0 }, SNOW, Enum.Material.Snow)
	putCabin("Logs", Vector3.new(12, 6, 9), { 0, 3.2, 0 }, LOG, Enum.Material.Wood)
	putCabin("Door", Vector3.new(2.4, 3.6, 0.4), { 0, 1.8, 4.6 }, Color3.fromRGB(72, 44, 34), Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		putCabin("Window", Vector3.new(2.4, 2, 0.3), { side * 3.4, 3.4, 4.6 }, WARM, Enum.Material.Neon)
		putCabin("WindowFrame", Vector3.new(2.8, 0.3, 0.4), { side * 3.4, 4.5, 4.62 }, SNOW)
		putCabin("PorchPost", Vector3.new(0.5, 3, 0.5), { side * 6, 1.5, 5.4 }, LOG, Enum.Material.Wood)
		local roof = block("Roof", Vector3.new(8, 0.8, 11), Vector3.new(0, 0, 0), SNOW, Enum.Material.Snow, model)
		roof.CFrame = rootPart.CFrame * CFrame.new(side * 3.4, 7.3, 0) * CFrame.Angles(0, 0, side * 0.55)
	end
	putCabin("PorchRoof", Vector3.new(13, 0.4, 2.6), { 0, 3.8, 5.6 }, SNOW, Enum.Material.Snow)

	local stack = putCabin("Chimney", Vector3.new(1.4, 3.4, 1.4), { 4, 8.2, -2 }, CHIMNEY)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Rate = 5
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	smoke.Parent = stack

	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Brightness = 1.4
	light.Range = 22
	light.Parent = putCabin("PorchLight", Vector3.new(0.5, 0.5, 0.5), { 0, 3.6, 5.2 }, WARM, Enum.Material.Neon)

	local signAnchor = putCabin("SignAnchor", Vector3.new(0.3, 0.3, 0.3), { 0, 6.2, 4.8 }, SNOW)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CabinSign"
	gui.Size = UDim2.fromOffset(320, 70)
	gui.MaxDistance = 200
	gui.Parent = signAnchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = WARM
	label.TextScaled = true
	label.Parent = gui
end

for _, spot in ipairs(CABIN_SPOTS) do
	cabin(spot[1], spot[2], spot[3])
end

return "built ski lines, gates, lift and five cabins"
