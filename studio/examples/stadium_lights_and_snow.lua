--!nonstrict
-- Run once in Edit mode. Adds four floodlight masts around each court and
-- fills the existing (empty) falling-snow canopy with drifting snowfall.
-- Lights are shadowless spotlights aimed at mid-court so eight of them stay
-- cheap, and the snow is plain ParticleEmitters on invisible high-altitude
-- parts, so no per-frame script is needed.

local Workspace = game:GetService("Workspace")

local METAL = Color3.fromRGB(52, 58, 66)
local WARM = Color3.fromRGB(255, 238, 200)

-- ------------------------------------------------------------------ lights

local lights = Workspace:FindFirstChild("CourtLights")
if lights then
	lights:Destroy()
end
lights = Instance.new("Model")
lights.Name = "CourtLights"
lights.Parent = Workspace

local function mast(courtName, x, z, targetX, targetZ)
	local pole = Instance.new("Model")
	pole.Name = courtName .. "_Mast"
	pole.Parent = lights

	local function piece(name, size, position, colour, material)
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
		part.Parent = pole
		return part
	end

	local base = piece("Base", Vector3.new(2.6, 1.4, 2.6), Vector3.new(x, 0.7, z), METAL)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, 0, math.pi / 2)

	local shaft = piece("Shaft", Vector3.new(1.1, 32, 1.1), Vector3.new(x, 16.5, z), METAL)
	shaft.Shape = Enum.PartType.Cylinder
	shaft.CFrame = CFrame.new(shaft.Position) * CFrame.Angles(0, 0, math.pi / 2)

	local lamp = piece("LampBank", Vector3.new(6, 1.8, 4.5), Vector3.new(x, 33, z), METAL)
	lamp.CFrame = CFrame.lookAt(lamp.Position, Vector3.new(targetX, 1, targetZ))

	local lens = piece("Lens", Vector3.new(5.4, 0.2, 4), Vector3.zero, WARM, Enum.Material.Neon)
	lens.CFrame = lamp.CFrame * CFrame.new(0, 0, -2.35)

	local beam = Instance.new("SpotLight")
	beam.Name = "Floodlight"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 62
	beam.Range = 115
	beam.Brightness = 1.6
	beam.Color = WARM
	beam.Shadows = false
	beam.Parent = lamp
end

for _, court in ipairs({ { name = "main", x = 39 }, { name = "santa", x = 91 } }) do
	for _, side in ipairs({ -1, 1 }) do
		for _, endZ in ipairs({ -16, 16 }) do
			mast(court.name, court.x + side * 24, endZ, court.x, -4)
		end
	end
end

-- ------------------------------------------------------------------- snow

local canopy = Workspace["Christmas Wonderland"]:FindFirstChild("falling-snow")
if not canopy then
	canopy = Instance.new("Model")
	canopy.Name = "falling-snow"
	canopy.Parent = Workspace["Christmas Wonderland"]
end
local snow = canopy:FindFirstChild("Snowfall")
if snow then
	snow:Destroy()
end
snow = Instance.new("Model")
snow.Name = "Snowfall"
snow.Parent = canopy

local size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.45),
	NumberSequenceKeypoint.new(0.5, 0.65),
	NumberSequenceKeypoint.new(1, 0.45),
})
local fade = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.8, 0.35),
	NumberSequenceKeypoint.new(1, 0.55),
})
local white = ColorSequence.new(Color3.new(1, 1, 1))

local count = 0
for _, x in ipairs({ -45, -10, 25, 60, 95, 120 }) do
	for _, z in ipairs({ -45, -5, 35 }) do
		local source = Instance.new("Part")
		source.Name = "SnowField"
		source.Size = Vector3.new(18, 1, 18)
		source.Position = Vector3.new(x, 48, z)
		source.Anchored = true
		source.CanCollide = false
		source.CanTouch = false
		source.CanQuery = false
		source.Transparency = 1
		source.Parent = snow

		local flakes = Instance.new("ParticleEmitter")
		flakes.Name = "Flakes"
		flakes.Texture = "rbxasset://textures/particles/smoke_main.dds"
		flakes.EmissionDirection = Enum.NormalId.Bottom
		flakes.SpreadAngle = Vector2.new(38, 38)
		flakes.Rate = 22
		flakes.Lifetime = NumberRange.new(16, 20)
		flakes.Speed = NumberRange.new(3.5)
		flakes.Acceleration = Vector3.new(0, -0.25, 0)
		flakes.Drag = 0.15
		flakes.Size = size
		flakes.Color = white
		flakes.Transparency = fade
		flakes.LightEmission = 1
		flakes.Brightness = 1
		flakes.Parent = source
		count = count + 1
	end
end

return string.format("built 8 floodlights and %d snow fields", count)
