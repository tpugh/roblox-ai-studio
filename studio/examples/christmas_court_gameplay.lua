--!nonstrict
-- Christmas court gameplay rig — second hoop, rim anchors and balls.
--
-- The generated Christmas scene ships one "Holiday Basketball Hoop" at the
-- north end of the wooden court. This script turns that into a playable full
-- court:
--   * clones and mirrors the generated hoop to the south end
--   * writes Workspace.StreetBasketballCourt.Anchors.RimScore_North / _South
--   * adds two playable Basketball props with HomeCFrame
--
-- BallService / BallKeeper / BallController and the NBA Street layer look for
-- a model named StreetBasketballCourt, so the anchors and balls live there
-- while the visible geometry stays part of the generated Christmas scene.
--
-- Run with execute_luau. Safe to re-run: it replaces the gameplay rig and the
-- south hoop clone, and leaves the rest of the scene untouched.

local HttpService = game:GetService("HttpService")

local COURT_NAME = "StreetBasketballCourt"
local SCENE = "Christmas Wonderland"
local COURT_SCENE = "basketball-court"
local NORTH_HOOP = "Holiday Basketball Hoop"
local SOUTH_HOOP = "Holiday Basketball Hoop South"

-- Rim geometry, measured from the generated holiday hoop.
local RIM_DROP = 1.9 -- rim plane sits this far under the backboard centre
local RIM_OFFSET = 1.5 -- and this far in front of the board face
local RIM_VOLUME = Vector3.new(2.2, 0.9, 2.2)
local BALL_SIZE = 0.8

local scene = workspace:FindFirstChild(SCENE)
local courtScene = scene and scene:FindFirstChild(COURT_SCENE)
local generated = courtScene and courtScene:FindFirstChild("Generated")
local northHoop = generated and generated:FindFirstChild(NORTH_HOOP)
local markings = generated and generated:FindFirstChild("Basketball Court Markings")

if not (northHoop and markings) then
	return "JSON::"
		.. HttpService:JSONEncode({
			ok = false,
			error = "generated holiday court not found",
			scene = scene ~= nil,
			courtScene = courtScene ~= nil,
			generated = generated ~= nil,
			northHoop = northHoop ~= nil,
			markings = markings ~= nil,
		})
end

local function backboardOf(model)
	for _, part in ipairs(model:GetDescendants()) do
		if
			part:IsA("BasePart")
			and part.Size.X > 7
			and part.Size.Y > 4
			and part.Size.Y < 6
			and part.Size.Z < 1
		then
			return part
		end
	end
	return nil
end

-- `facing` is +1 when the rim points along +Z, -1 when it points along -Z.
local function rimOf(model, facing)
	local board = backboardOf(model)
	if not board then
		return nil
	end
	return board.Position + Vector3.new(0, -RIM_DROP, RIM_OFFSET * facing)
end

local northRim = rimOf(northHoop, 1)

-- Mirror the north hoop across the court's centre axis to make the south one.
local floorCFrame, floorSize = markings:GetBoundingBox()
local axis = floorCFrame.Position
local mirrorCFrame
if axis.Magnitude > 0 then
	mirrorCFrame = CFrame.new(axis.X, 0, axis.Z) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-axis.X, 0, -axis.Z)
end

local previousSouth = generated:FindFirstChild(SOUTH_HOOP)
if previousSouth then
	previousSouth:Destroy()
end

local southHoop = northHoop:Clone()
southHoop.Name = SOUTH_HOOP
southHoop:PivotTo(mirrorCFrame * northHoop:GetPivot())
southHoop.Parent = generated

local southRim = rimOf(southHoop, -1)

-- The generated rim is a ring of thin Segment_ parts with a hanging net. At this
-- scale a real ball cannot squeeze through the ring, so the rim and net are made
-- non-solid and the score volume under the ring decides the basket. The
-- backboard and pole stay solid so shots still rebound off them.
local function softenRim(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local name = string.lower(part.Name)
			if
				string.find(name, "segment", 1, true)
				or string.find(name, "net", 1, true)
				or string.find(name, "rim", 1, true)
			then
				part.CanCollide = false
			end
		end
	end
end

softenRim(northHoop)
softenRim(southHoop)

-- Ground height at the centre circle, so the balls rest on the wooden court.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { northHoop, southHoop }
local groundHit = workspace:Raycast(Vector3.new(axis.X, 200, axis.Z), Vector3.new(0, -400, 0), rayParams)
local groundY = groundHit and groundHit.Position.Y or 0.3

-- Replace the gameplay rig (anchors + balls) every run.
local previousRig = workspace:FindFirstChild(COURT_NAME)
if previousRig then
	previousRig:Destroy()
end

local rig = Instance.new("Model")
rig.Name = COURT_NAME

local anchors = Instance.new("Folder")
anchors.Name = "Anchors"
anchors.Parent = rig

local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = rig

local function scoreVolume(name, rim, team)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = RIM_VOLUME
	part.CFrame = CFrame.new(rim - Vector3.new(0, 0.45, 0))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = true
	part.Transparency = 1
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Role", "rim_score")
	part:SetAttribute("Team", team)
	part.Parent = anchors
	return part
end

scoreVolume("RimScore_North", northRim, "North")
scoreVolume("RimScore_South", southRim, "South")

local function basketball(position)
	local part = Instance.new("Part")
	part.Name = "Basketball"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE)
	part.CFrame = CFrame.new(position)
	part.Color = Color3.fromRGB(212, 108, 44)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.75, 1, 1)
	part:SetAttribute("HomeCFrame", CFrame.new(position))
	part.Parent = props
	return part
end

local restingY = groundY + BALL_SIZE / 2 + 0.02
local ballA = basketball(Vector3.new(axis.X - 5, restingY, axis.Z + 8))
local ballB = basketball(Vector3.new(axis.X + 5, restingY, axis.Z - 8))

rig.Parent = workspace

rig:SetAttribute("RimHeight", string.format("%.2f", (northRim.Y - groundY)))
rig:SetAttribute("CourtLength", string.format("%.1f", floorSize.Z))
rig:SetAttribute("CourtWidth", string.format("%.1f", floorSize.X))
rig:SetAttribute("PropPolicy", "E grab, hold F shoot, X trick, G Gamebreaker dunk, Q dribble, Shift turbo, R reset.")
rig:SetAttribute("SecondHoop", "Holiday Basketball Hoop South (mirror of the generated north hoop).")
rig:SetAttribute("RigParts", "Anchors + Props only; visible hoop geometry stays under Christmas Wonderland.basketball-court.")

return "JSON::"
	.. HttpService:JSONEncode({
		ok = true,
		groundY = groundY,
		axis = string.format("%.1f,%.1f", axis.X, axis.Z),
		northRim = tostring(northRim),
		southRim = tostring(southRim),
		rimHeight = (northRim.Y - groundY),
		mirrorGap = (southRim - northRim).Magnitude,
		southHoopParts = #southHoop:GetDescendants(),
		balls = { tostring(ballA.Position), tostring(ballB.Position) },
		anchors = { "RimScore_North", "RimScore_South" },
	})
