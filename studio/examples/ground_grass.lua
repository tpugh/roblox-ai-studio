--!nonstrict
-- Run once in Edit mode. The plaza, courts and stands sit on the stock grey
-- baseplate; this lays a thin walkable meadow over the bare ground everywhere
-- else. The surface stops at y=0.15, below every court floor and snow path,
-- so nothing that already exists gets covered up. A few low snow drifts break
-- up the green and tie it into the falling snow.

local Workspace = game:GetService("Workspace")

local ground = Workspace:FindFirstChild("GrassGround")
if ground then
	ground:Destroy()
end
ground = Instance.new("Model")
ground.Name = "GrassGround"
ground.Parent = Workspace

local meadow = Instance.new("Part")
meadow.Name = "Meadow"
meadow.Size = Vector3.new(900, 0.3, 900)
meadow.Position = Vector3.new(20, 0, 0)
meadow.Anchored = true
meadow.CanCollide = true
meadow.CanTouch = false
meadow.CanQuery = false
meadow.Material = Enum.Material.Grass
meadow.Color = Color3.fromRGB(122, 148, 88)
meadow.Parent = ground

math.randomseed(26012)
local drifts = 0
for _ = 1, 28 do
	local x = math.random(-150, 190)
	local z = math.random(-120, 120)
	-- keep the two courts and the plaza clear
	if not (x > -50 and x < 130 and z > -60 and z < 55) then
		local width = 6 + math.random() * 12
		local drift = Instance.new("Part")
		drift.Name = "SnowDrift"
		drift.Shape = Enum.PartType.Ball
		drift.Size = Vector3.new(width, 0.7, width * (0.6 + math.random() * 0.5))
		drift.Position = Vector3.new(x, 0.22, z)
		drift.Anchored = true
		drift.CanCollide = false
		drift.CanTouch = false
		drift.CanQuery = false
		drift.Material = Enum.Material.Snow
		drift.Color = Color3.fromRGB(240, 244, 250)
		drift.Parent = ground
		drifts = drifts + 1
	end
end

return string.format("laid meadow top=0.15 with %d snow drifts", drifts)
