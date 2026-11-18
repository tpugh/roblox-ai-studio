--!nonstrict
-- Street basketball court — deterministic Studio build (no external assets).
--
-- Layout is a scaled-down street court: 84 x 50 studs, painted keys, free-throw
-- circles, 3-point arcs with corner lines, two hoop assemblies with backboards,
-- nets and poles, a chain-link fence with an entrance, floodlights, benches and
-- balls.
--
-- Run through the Studio MCP (execute_luau) or paste into the command bar.
-- It rebuilds from scratch each time and returns a stats blob for review.
--
-- This file builds geometry only: no scripts, no UI, no gameplay. The runtime
-- pieces live beside it and are installed separately:
--   ball_keeper.server.lua   -> ServerScriptService.BallKeeper  (returns strays)
--   ball_service.server.lua  -> ServerScriptService.BallService (grab/throw/score)
--   ball_controller.client.lua -> StarterPlayerScripts.BallController (input/HUD)
-- This builder never touches those services.

local HttpService = game:GetService("HttpService")

local COURT_LENGTH = 84
local COURT_WIDTH = 50
local SURFACE = 1.0 -- top of the court slab
local LINE_Y = SURFACE + 0.03
local HOOP_X = 37.6
local BOARD_X = 38.6
local RIM_Y = SURFACE + 10.9
local BOARD_Y = RIM_Y + 1.8
local FENCE_X = 47.5
local FENCE_Z = 30.0
local FENCE_HEIGHT = 12
local POLE_X = 44.6

local C = {
	plaza = Color3.fromRGB(112, 112, 116),
	asphalt = Color3.fromRGB(40, 40, 45),
	line = Color3.fromRGB(238, 238, 230),
	paint = Color3.fromRGB(26, 62, 82),
	steel = Color3.fromRGB(92, 92, 100),
	board = Color3.fromRGB(236, 240, 244),
	rim = Color3.fromRGB(226, 108, 38),
	net = Color3.fromRGB(232, 232, 232),
	bench = Color3.fromRGB(122, 86, 58),
	ball = Color3.fromRGB(214, 34, 48),
	lamp = Color3.fromRGB(250, 238, 200),
}

local M = {
	asphalt = Enum.Material.Asphalt,
	concrete = Enum.Material.Concrete,
	plastic = Enum.Material.SmoothPlastic,
	metal = Enum.Material.Metal,
	wood = Enum.Material.Wood,
	fabric = Enum.Material.Fabric,
}

local function finish(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makePart(parent, name, size, cframe, color, material, opts)
	opts = opts or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or M.plastic
	part.Anchored = opts.anchored ~= false
	part.CanCollide = opts.canCollide ~= false
	part.CanQuery = opts.canQuery ~= false
	part.CanTouch = opts.canTouch ~= false
	part.CastShadow = opts.castShadow ~= false
	if opts.transparency then
		part.Transparency = opts.transparency
	end
	finish(part)
	part.Parent = parent
	return part
end

local function box(parent, name, size, position, color, material, opts)
	return makePart(parent, name, size, CFrame.new(position), color, material, opts)
end

local function beam(parent, name, from, to, thickness, color, material, opts)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.01 then
		return nil
	end
	local mid = from + delta * 0.5
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt(mid, to),
		color,
		material,
		opts
	)
end

-- Vertical cylinder (Roblox cylinders run along X, so rotate onto Y).
local function pillar(parent, name, height, diameter, position, color, material, opts)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Name = name
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = material or M.metal
	part.Anchored = true
	part.CanCollide = (opts or {}).canCollide ~= false
	part.CastShadow = (opts or {}).castShadow ~= false
	finish(part)
	part.Parent = parent
	return part
end

-- Horizontal cylinder running along a tangent direction.
local function tangentCylinder(parent, name, length, diameter, position, yaw, color, material)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Name = name
	part.Size = Vector3.new(length, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part.Color = color
	part.Material = material or M.metal
	part.Anchored = true
	part.CastShadow = false
	finish(part)
	part.Parent = parent
	return part
end

local function lineX(parent, name, x1, x2, z, width)
	local length = math.abs(x2 - x1)
	return box(
		parent,
		name,
		Vector3.new(length, 0.04, width),
		Vector3.new((x1 + x2) / 2, LINE_Y, z),
		C.line,
		M.plastic,
		{ castShadow = false, canCollide = false }
	)
end

local function lineZ(parent, name, z1, z2, x, width)
	local length = math.abs(z2 - z1)
	return box(
		parent,
		name,
		Vector3.new(width, 0.04, length),
		Vector3.new(x, LINE_Y, (z1 + z2) / 2),
		C.line,
		M.plastic,
		{ castShadow = false, canCollide = false }
	)
end

local function ring(parent, name, cx, cz, radius, width, segments)
	local step = (math.pi * 2) / segments
	local chord = 2 * radius * math.sin(step / 2) + 0.05
	for i = 0, segments - 1 do
		local a = i * step
		local pos = Vector3.new(cx + radius * math.cos(a), LINE_Y, cz + radius * math.sin(a))
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		makePart(
			parent,
			name .. "_" .. i,
			Vector3.new(width, 0.04, chord),
			CFrame.lookAt(pos, pos + tangent),
			C.line,
			M.plastic,
			{ castShadow = false, canCollide = false }
		)
	end
end

local function arc(parent, name, cx, cz, radius, fromAngle, toAngle, width, segments)
	local step = (toAngle - fromAngle) / segments
	local chord = 2 * radius * math.sin(math.abs(step) / 2) + 0.05
	for i = 0, segments - 1 do
		local a = fromAngle + step * (i + 0.5)
		local pos = Vector3.new(cx + radius * math.cos(a), LINE_Y, cz + radius * math.sin(a))
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		makePart(
			parent,
			name .. "_" .. i,
			Vector3.new(width, 0.04, chord),
			CFrame.lookAt(pos, pos + tangent),
			C.line,
			M.plastic,
			{ castShadow = false, canCollide = false }
		)
	end
end

local function buildCourtSurface(model)
	local folder = Instance.new("Folder")
	folder.Name = "Court"
	folder.Parent = model

	box(folder, "Plaza", Vector3.new(140, 0.24, 96), Vector3.new(0, 0.12, 0), C.plaza, M.concrete, { castShadow = false })
	box(
		folder,
		"CourtSlab",
		Vector3.new(COURT_LENGTH, 0.76, COURT_WIDTH),
		Vector3.new(0, SURFACE - 0.38, 0),
		C.asphalt,
		M.asphalt
	)
	-- Entrance threshold: two shallow steps from the plaza up to the court surface.
	box(folder, "EntranceStep", Vector3.new(12, 0.38, 2.4), Vector3.new(0, 0.43, 26.2), C.plaza, M.concrete)

	-- Painted keys.
	for _, sign in ipairs({ 1, -1 }) do
		local x1, x2 = sign * 25, sign * 41.8
		box(
			folder,
			"KeyPaint",
			Vector3.new(math.abs(x2 - x1), 0.04, 14),
			Vector3.new((x1 + x2) / 2, SURFACE + 0.02, 0),
			C.paint,
			M.plastic,
			{ castShadow = false, canCollide = false }
		)
	end

	-- Boundary.
	lineZ(folder, "SidelineA", -24.8, 24.8, -41.8, 0.35)
	lineZ(folder, "SidelineB", -24.8, 24.8, 41.8, 0.35)
	lineX(folder, "BaselineNorth", -41.8, 41.8, -24.8, 0.35)
	lineX(folder, "BaselineSouth", -41.8, 41.8, 24.8, 0.35)
	lineZ(folder, "HalfCourt", -24.8, 24.8, 0, 0.35)

	-- Keys and free-throw circles.
	for _, sign in ipairs({ 1, -1 }) do
		lineX(folder, "KeyLineTop", sign * 25, sign * 41.8, -7, 0.32)
		lineX(folder, "KeyLineBottom", sign * 25, sign * 41.8, 7, 0.32)
		lineZ(folder, "FreeThrowLine", -7, 7, sign * 25, 0.32)
		ring(folder, "FreeThrowCircle", sign * 25, 0, 5.5, 0.3, 20)
	end

	-- Centre circle.
	ring(folder, "CentreCircle", 0, 0, 6, 0.3, 22)

	-- Three-point arcs plus the straight corner segments.
	for _, sign in ipairs({ 1, -1 }) do
		local cx = HOOP_X * sign
		if sign > 0 then
			arc(folder, "ThreePoint", cx, 0, 24, math.rad(113.6), math.rad(246.4), 0.32, 16)
		else
			arc(folder, "ThreePoint", cx, 0, 24, math.rad(-66.4), math.rad(66.4), 0.32, 16)
		end
		lineX(folder, "CornerThreeTop", sign * 28.0, sign * 41.8, -22, 0.32)
		lineX(folder, "CornerThreeBottom", sign * 28.0, sign * 41.8, 22, 0.32)
		-- Restricted-area arc under the basket.
		if sign > 0 then
			arc(folder, "RestrictedArea", cx, 0, 4, math.rad(113.6), math.rad(246.4), 0.26, 8)
		else
			arc(folder, "RestrictedArea", cx, 0, 4, math.rad(-66.4), math.rad(66.4), 0.26, 8)
		end
	end

	return folder
end

local function buildHoop(model, sign)
	local folder = Instance.new("Folder")
	folder.Name = sign > 0 and "HoopEast" or "HoopWest"
	folder.Parent = model:FindFirstChild("Hoops")

	local hx = HOOP_X * sign
	local bx = BOARD_X * sign

	pillar(folder, "Pole", 16, 1.1, Vector3.new(sign * POLE_X, 8, 0), C.steel, M.metal)
	box(folder, "PoleBase", Vector3.new(5, 1.26, 5), Vector3.new(sign * POLE_X, 0.87, 0), C.steel, M.metal)
	-- Padded stanchion in the chase zone, as real courts have (sits on the base plate).
	box(folder, "PolePad", Vector3.new(2.2, 3.2, 2.2), Vector3.new(sign * POLE_X, 3.1, 0), Color3.fromRGB(28, 42, 58), M.fabric)
	box(
		folder,
		"Arm",
		Vector3.new(math.abs(POLE_X - (BOARD_X + 0.2)), 0.5, 0.5),
		Vector3.new(sign * (POLE_X + BOARD_X + 0.2) / 2, BOARD_Y + 1.1, 0),
		C.steel,
		M.metal
	)
	beam(
		folder,
		"Brace",
		Vector3.new(sign * POLE_X, BOARD_Y - 2.2, 0),
		Vector3.new(sign * 39.0, BOARD_Y + 0.9, 0),
		0.32,
		C.steel,
		M.metal
	)

	box(
		folder,
		"Backboard",
		Vector3.new(0.35, 3.6, 6.4),
		Vector3.new(bx, BOARD_Y, 0),
		C.board,
		M.plastic,
		{ transparency = 0.1 }
	)

	-- Target square on the court-facing side of the board.
	local faceX = bx - sign * 0.2
	box(folder, "TargetTop", Vector3.new(0.06, 0.07, 1.4), Vector3.new(faceX, RIM_Y + 1.1, 0), C.rim, M.plastic)
	box(folder, "TargetBottom", Vector3.new(0.06, 0.07, 1.4), Vector3.new(faceX, RIM_Y + 0.2, 0), C.rim, M.plastic)
	box(folder, "TargetLeft", Vector3.new(0.06, 0.9, 0.07), Vector3.new(faceX, RIM_Y + 0.65, -0.7), C.rim, M.plastic)
	box(folder, "TargetRight", Vector3.new(0.06, 0.9, 0.07), Vector3.new(faceX, RIM_Y + 0.65, 0.7), C.rim, M.plastic)

	-- Rim: 16 short cylinders on a 0.85-stud radius.
	local rimRadius = 0.85
	local segments = 16
	local step = (math.pi * 2) / segments
	local chord = 2 * rimRadius * math.sin(step / 2) + 0.08
	for i = 0, segments - 1 do
		local a = i * step
		local pos = Vector3.new(hx + rimRadius * math.cos(a), RIM_Y, rimRadius * math.sin(a))
		tangentCylinder(folder, "Rim_" .. i, chord, 0.18, pos, -(a + math.pi / 2), C.rim, M.metal)
	end

	-- Net: strands from the rim down to a lower ring, plus a mid ring.
	local strands = 10
	local netStep = (math.pi * 2) / strands
	for i = 0, strands - 1 do
		local a = i * netStep
		local top = Vector3.new(hx + 0.82 * math.cos(a), RIM_Y - 0.06, 0.82 * math.sin(a))
		local bottom = Vector3.new(hx + 0.45 * math.cos(a), RIM_Y - 2.4, 0.45 * math.sin(a))
		beam(folder, "NetStrand_" .. i, top, bottom, 0.07, C.net, M.plastic, { canCollide = false, castShadow = false })
	end
	for _, band in ipairs({ { y = RIM_Y - 1.2, r = 0.64 }, { y = RIM_Y - 2.4, r = 0.45 } }) do
		for i = 0, strands - 1 do
			local a = i * netStep
			local b = a + netStep
			local p1 = Vector3.new(hx + band.r * math.cos(a), band.y, band.r * math.sin(a))
			local p2 = Vector3.new(hx + band.r * math.cos(b), band.y, band.r * math.sin(b))
			beam(folder, "NetBand", p1, p2, 0.06, C.net, M.plastic, { canCollide = false, castShadow = false })
		end
	end

	return folder
end

local function buildFence(model)
	local folder = Instance.new("Folder")
	folder.Name = "Fence"
	folder.Parent = model

	local function post(x, z)
		box(folder, "Post", Vector3.new(0.5, FENCE_HEIGHT, 0.5), Vector3.new(x, FENCE_HEIGHT / 2, z), C.steel, M.metal, { castShadow = false })
	end

	local function bay(a, b)
		beam(folder, "Mesh", Vector3.new(a.X, 0.15, a.Z), Vector3.new(b.X, FENCE_HEIGHT - 0.25, b.Z), 0.09, C.steel, M.metal, { castShadow = false })
		beam(folder, "Mesh", Vector3.new(b.X, 0.15, b.Z), Vector3.new(a.X, FENCE_HEIGHT - 0.25, a.Z), 0.09, C.steel, M.metal, { castShadow = false })
	end

	local function run(x1, z1, x2, z2, count)
		local points = {}
		for i = 0, count do
			points[#points + 1] = Vector3.new(x1 + (x2 - x1) * (i / count), 0, z1 + (z2 - z1) * (i / count))
		end
		for i = 1, #points - 1 do
			bay(points[i], points[i + 1])
			post(points[i].X, points[i].Z)
			if i == #points - 1 then
				post(points[i + 1].X, points[i + 1].Z)
			end
		end
		local first, last = points[1], points[#points]
		box(
			folder,
			"TopRail",
			Vector3.new(math.abs(last.X - first.X) + 0.2, 0.18, math.abs(last.Z - first.Z) + 0.2),
			Vector3.new((first.X + last.X) / 2, FENCE_HEIGHT, (first.Z + last.Z) / 2),
			C.steel,
			M.metal,
			{ castShadow = false }
		)
	end

	run(-FENCE_X, -FENCE_Z, FENCE_X, -FENCE_Z, 24)
	run(-FENCE_X, FENCE_Z, -6, FENCE_Z, 10)
	run(6, FENCE_Z, FENCE_X, FENCE_Z, 10)
	run(-FENCE_X, -FENCE_Z, -FENCE_X, FENCE_Z, 14)
	run(FENCE_X, -FENCE_Z, FENCE_X, FENCE_Z, 14)

	-- The lattice is decoration; these panels do the containing so players
	-- cannot slip between posts. One gap is the entrance.
	local function barrier(name, size, position)
		box(folder, name, size, position, C.steel, M.metal, { transparency = 1, castShadow = false })
	end
	barrier("Barrier_South", Vector3.new(FENCE_X * 2, FENCE_HEIGHT, 0.3), Vector3.new(0, FENCE_HEIGHT / 2, -FENCE_Z))
	barrier("Barrier_East", Vector3.new(0.3, FENCE_HEIGHT, FENCE_Z * 2), Vector3.new(FENCE_X, FENCE_HEIGHT / 2, 0))
	barrier("Barrier_West", Vector3.new(0.3, FENCE_HEIGHT, FENCE_Z * 2), Vector3.new(-FENCE_X, FENCE_HEIGHT / 2, 0))
	barrier("Barrier_NorthLeft", Vector3.new(FENCE_X - 6, FENCE_HEIGHT, 0.3), Vector3.new(-(FENCE_X + 6) / 2, FENCE_HEIGHT / 2, FENCE_Z))
	barrier("Barrier_NorthRight", Vector3.new(FENCE_X - 6, FENCE_HEIGHT, 0.3), Vector3.new((FENCE_X + 6) / 2, FENCE_HEIGHT / 2, FENCE_Z))

	-- Make the one opening read as an entrance: accent posts on either side and
	-- a painted threshold crossing the plaza up to the step.
	for _, sign in ipairs({ 1, -1 }) do
		box(
			folder,
			"GatePost",
			Vector3.new(0.7, FENCE_HEIGHT + 0.6, 0.7),
			Vector3.new(sign * 6, (FENCE_HEIGHT + 0.6) / 2, FENCE_Z),
			C.rim,
			M.metal,
			{ castShadow = false }
		)
	end
	for i = 0, 3 do
		box(
			folder,
			"EntranceStripe",
			Vector3.new(9.5, 0.04, 0.55),
			Vector3.new(0, 0.26, 30.9 + i * 1.05),
			C.line,
			M.plastic,
			{ castShadow = false, canCollide = false }
		)
	end

	return folder
end

-- Named, invisible anchors for the Lua handoff: score volumes, ball respawns
-- and the entrance trigger. Geometry + attributes only; no behaviour is scripted here.
local function buildAnchors(model)
	local folder = Instance.new("Folder")
	folder.Name = "Anchors"
	folder.Parent = model

	local function marker(name, position, size, role, team, queryable)
		local part = box(
			folder,
			name,
			size,
			position,
			Color3.fromRGB(255, 140, 0),
			M.plastic,
			{ canCollide = false, transparency = 1, castShadow = false }
		)
		part.CanQuery = queryable == true
		part.CanTouch = true
		part:SetAttribute("Role", role)
		if team then
			part:SetAttribute("Team", team)
		end
		return part
	end

	-- Score volumes sit just *below* the rim plane so a rim bounce that stays
	-- above the ring cannot register; Lua should also require downward velocity.
	marker("RimScore_Home", Vector3.new(HOOP_X, RIM_Y - 0.45, 0), Vector3.new(1.8, 0.9, 1.8), "rim_score", "Home", true)
	marker("RimScore_Away", Vector3.new(-HOOP_X, RIM_Y - 0.45, 0), Vector3.new(1.8, 0.9, 1.8), "rim_score", "Away", true)
	marker("BallSpawn_A", Vector3.new(-6, SURFACE + 0.5, 0), Vector3.new(1, 1, 1), "ball_spawn", nil)
	marker("BallSpawn_B", Vector3.new(6, SURFACE + 0.5, 0), Vector3.new(1, 1, 1), "ball_spawn", nil)
	marker("EntranceGate", Vector3.new(0, 6, FENCE_Z), Vector3.new(12, 12, 0.4), "entrance_gate")
	marker("CourtCentre", Vector3.new(0, SURFACE + 0.5, 0), Vector3.new(1, 1, 1), "court_centre")

	return folder
end

local function buildProps(model)
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = model

	for _, p in ipairs({
		{ x = -32, z = 35, dir = -1 },
		{ x = 32, z = 35, dir = -1 },
		{ x = -32, z = -35, dir = 1 },
		{ x = 32, z = -35, dir = 1 },
	}) do
		local pole = Instance.new("Folder")
		pole.Name = "Floodlight"
		pole.Parent = folder

		pillar(pole, "Pole", 20, 0.9, Vector3.new(p.x, 10, p.z), C.steel, M.metal)
		box(pole, "Footing", Vector3.new(2.6, 0.8, 2.6), Vector3.new(p.x, 0.4, p.z), C.steel, M.metal)
		box(pole, "Arm", Vector3.new(0.4, 0.4, 4), Vector3.new(p.x, 19.6, p.z + p.dir * 2), C.steel, M.metal)
		local head = box(
			pole,
			"Head",
			Vector3.new(2.8, 0.5, 1.4),
			Vector3.new(p.x, 19.6, p.z + p.dir * 4.1),
			C.lamp,
			M.plastic,
			{ castShadow = false }
		)
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 45
		light.Color = Color3.fromRGB(255, 238, 200)
		light.Shadows = false
		light.Parent = head
	end

	for _, b in ipairs({ { x = -26, z = 28.4 }, { x = 26, z = 28.4 } }) do
		local bench = Instance.new("Folder")
		bench.Name = "Bench"
		bench.Parent = folder

		-- Clickable Seat so the bench is real seating, not prop geometry.
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(8, 0.4, 2)
		seat.CFrame = CFrame.new(b.x, 1.5, b.z)
		seat.Color = C.bench
		seat.Material = M.wood
		seat.Anchored = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.Parent = bench

		box(bench, "Backrest", Vector3.new(8, 1.6, 0.3), Vector3.new(b.x, 2.5, b.z + 0.85), C.bench, M.wood)
		box(bench, "LegLeft", Vector3.new(0.4, 1.3, 1.8), Vector3.new(b.x - 3.4, 0.65, b.z), C.steel, M.metal)
		box(bench, "LegRight", Vector3.new(0.4, 1.3, 1.8), Vector3.new(b.x + 3.4, 0.65, b.z), C.steel, M.metal)
	end

	-- Harlem Globetrotters look: a red ball wrapped in three crossed white
	-- bands. The bands are welded, non-colliding and massless, so they follow
	-- the ball's physics without changing how it plays.
	local function addGlobeStripes(ball)
		local white = Color3.fromRGB(250, 250, 246)
		local rotations = {
			CFrame.identity,
			CFrame.Angles(0, math.rad(90), 0),
			CFrame.Angles(0, 0, math.rad(90)),
		}
		for index, rotation in ipairs(rotations) do
			local band = Instance.new("Part")
			band.Name = "GlobeStripe" .. index
			band.Shape = Enum.PartType.Cylinder
			band.Size = Vector3.new(0.06, 0.84, 0.84)
			band.CFrame = ball.CFrame * rotation
			band.Color = white
			band.Material = M.plastic
			band.CanCollide = false
			band.Massless = true
			band.CastShadow = false
			band.Parent = ball
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = ball
			weld.Part1 = band
			weld.Parent = band
		end
	end

	local ballA = makePart(
		folder,
		"Basketball",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(12, SURFACE + 0.45, 6),
		C.ball,
		M.plastic,
		{ anchored = false }
	)
	ballA.Shape = Enum.PartType.Ball
	ballA.CastShadow = true
	ballA.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.75, 1, 1)
	ballA:SetAttribute("HomeCFrame", ballA.CFrame)
	addGlobeStripes(ballA)

	local ballB = makePart(
		folder,
		"Basketball",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(-16, SURFACE + 0.45, 17),
		C.ball,
		M.plastic,
		{ anchored = false }
	)
	ballB.Shape = Enum.PartType.Ball
	ballB.CastShadow = true
	ballB.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.75, 1, 1)
	ballB:SetAttribute("HomeCFrame", ballB.CFrame)
	addGlobeStripes(ballB)

	return folder
end

local function placeSpawn()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Parent = workspace
	end
	-- The default spawn decal would render a star on the court, so drop it.
	for _, child in ipairs(spawn:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
	-- Spawn on the plaza just outside the fence, facing the entrance gap.
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.9, 34.5)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CastShadow = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	return spawn
end

local function build()
	local previous = workspace:FindFirstChild("StreetBasketballCourt")
	if previous then
		previous:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "StreetBasketballCourt"

	local hoops = Instance.new("Folder")
	hoops.Name = "Hoops"
	hoops.Parent = model

	buildCourtSurface(model)
	buildHoop(model, 1)
	buildHoop(model, -1)
	buildFence(model)
	buildProps(model)
	buildAnchors(model)
	model.Parent = workspace

	-- Review metadata travels with the model.
	model:SetAttribute("PlayerCountTarget", 8)
	model:SetAttribute("Streaming", "Whole model fits one streamed region; enable StreamingEnabled with a 512-stud radius if the experience grows past this plaza.")
	model:SetAttribute("Scale", "Court 84 x 50 studs (~0.84 of a 28 x 15 m regulation court); rim kept at regulation 10.9 studs (3.05 m).")
	model:SetAttribute("Lighting", "4 floodlights, brightness 2 / range 45. Lighting.Technology left at place default; time of day untouched.")
	model:SetAttribute("LayoutReviewedBy", "level-world-builder")
	model:SetAttribute("LayoutVerdict", "approved")
	model:SetAttribute("ReviewCorrelationId", "street-court-review-2")
	model:SetAttribute("PropPolicy", "Balls are playable props: E grab, hold M1 throw, Q dribble, R reset (ServerScriptService.BallService). Strays return to their build spot (BallKeeper).")
	model:SetAttribute("OpenFollowUps", "Rim scoring is 2 or 3 by distance from the ring; no match timer, teams or persistent leaderboard.")

	local spawn = placeSpawn()

	local counts = {}
	for _, child in ipairs(model:GetChildren()) do
		counts[child.Name] = #child:GetDescendants()
	end

	local total = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			total += 1
		end
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()

	return {
		model = model:GetFullName(),
		parts = total,
		descendants = #model:GetDescendants(),
		folders = counts,
		bounds = {
			size = tostring(boundsSize),
			centre = tostring(boundsCFrame.Position),
		},
		spawn = tostring(spawn.Position),
		clearances = {
			court = string.format("%d x %d studs", COURT_LENGTH, COURT_WIDTH),
			rim_height = RIM_Y - SURFACE,
			backboard_bottom = (BOARD_Y - 1.8) - SURFACE,
			backboard_top = (BOARD_Y + 1.8) - SURFACE,
			fence_height = FENCE_HEIGHT,
			fence_offset_from_court = FENCE_X - COURT_LENGTH / 2,
			runoff_behind_baseline = FENCE_X - COURT_LENGTH / 2,
			runoff_beside_sideline = FENCE_Z - COURT_WIDTH / 2,
			pole_to_fence = FENCE_X - (POLE_X + 0.55),
			pole_behind_baseline = POLE_X - COURT_LENGTH / 2,
			entrance_width = 12,
			entrance_step_rise = 0.38,
			key_width = 14,
			three_point_apex_from_basket = 24,
			anchor_count = #model.Anchors:GetChildren(),
			rim_score_plane = string.format("%.2f..%.2f (below rim %.2f)", RIM_Y - 0.9, RIM_Y, RIM_Y),
			seat_count = 2,
			loose_balls = 2,
		},
	}
end

return "JSON::" .. HttpService:JSONEncode(build())
