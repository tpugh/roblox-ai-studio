--!nonstrict
-- SantaGame — the HoopsMas Claus crew plays 2 v 2 on the second street court.
--
-- Self-contained on purpose: it owns SantaCourt, its ball, its score volumes
-- and its scoreboard, and never touches StreetBasketballCourt. The player's
-- BallService keeps the main court to itself, so the two games cannot fight
-- over a ball.
--
-- The Santas walk with Humanoid:MoveTo and carry the ball kinematically (the
-- ball is anchored and bounced under the lead hand) because these rigs are
-- jointed with BallSocketConstraints, so a welded ball would fight the
-- physics. A shot hands the ball back to physics with the same flight-time arc
-- the player's shots use, so a make is a real ball dropping through a real
-- hoop.
--
-- Install as a Script under ServerScriptService.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local AthleticRig = require(game:GetService("ServerScriptService"):WaitForChild("AthleticRig", 10))

local COURT_NAME = "SantaCourt"
local ROSTER_NAME = "HoopsMas_Santas"

local TEAM_LABELS = { "VARSITY", "STREET" }
local TEAM_COLOURS = {
	Color3.fromRGB(255, 132, 132),
	Color3.fromRGB(168, 208, 255),
}
local TITLE = "HOOPSMAS CLAUS  \u{2022}  2 v 2"

local GROUND_Y = 0.4048 -- top face of the wooden deck
local GRAB_RADIUS = 3.6
local SHOT_COOLDOWN = 1.2 -- seconds on the ball before a shot is allowed
local GATHER_TIME = 0.16 -- ball rises to the hand before it leaves
local THREE_POINT_DISTANCE = 23
local SCORE_COOLDOWN = 0.7
local RESET_Y = -25 -- a ball below this has fallen out of the world
local OUT_X = 34 -- a ball past the deck edge is out of play and comes back
local OUT_Z = 38
local CLAIM_SECONDS = 3 -- the scoring side keeps the ball this long

-- ------------------------------------------------------------------ setup

local court = Workspace:WaitForChild(COURT_NAME, 20)
if not court then
	warn("[SantaGame] SantaCourt is missing, nothing to run")
	return
end

local anchors = court:WaitForChild("Anchors")
local props = court:WaitForChild("Props")
local ball = props:WaitForChild("Basketball")
local boardPart = court:WaitForChild("ScoreboardAnchor")
local board = boardPart:WaitForChild("TeamBoard")
local body = board:WaitForChild("Body")
local title = body:WaitForChild("Title")
local teamALabel = body:WaitForChild("TeamA")
local teamBLabel = body:WaitForChild("TeamB")
title.Text = TITLE

-- Team 1 attacks north, team 2 attacks south; each defends the other end.
local rims = {
	[1] = anchors:WaitForChild("RimScore_North"),
	[2] = anchors:WaitForChild("RimScore_South"),
}
local centre = Vector3.new(
	(rims[1].Position.X + rims[2].Position.X) / 2,
	0,
	(rims[1].Position.Z + rims[2].Position.Z) / 2
)

local roster = Workspace:WaitForChild(ROSTER_NAME, 20)
if not roster then
	warn("[SantaGame] " .. ROSTER_NAME .. " is missing, nothing to run")
	return
end

local players = {}
for _, model in ipairs(roster:GetChildren()) do
	local team = model:GetAttribute("Team")
	if model:IsA("Model") and team then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid and root then
			humanoid.WalkSpeed = 15
			table.insert(players, {
				model = model,
				team = team,
				number = model:GetAttribute("Number") or (#players + 1),
				humanoid = humanoid,
				root = root,
				attack = rims[team],
				defend = rims[3 - team],
				lane = (model:GetAttribute("Number") or 1) % 2 == 1 and -1 or 1,
				spread = 6.5 + ((model:GetAttribute("Number") or 1) % 2) * 2.5,
				moving = nil,
				stealReady = 0,
				rig = AthleticRig and AthleticRig.attach(model),
			})
		end
	end
end
table.sort(players, function(a, b)
	return a.number < b.number
end)
if #players < 2 then
	warn("[SantaGame] need at least two Santas with a Team attribute")
	return
end

-- ------------------------------------------------------------- animation
-- Motion and pose are owned by AthleticRig; it starts the R15 tracks and adds
-- a crouch/run lean so the Santas no longer skate around stiffly.

for _, entry in ipairs(players) do
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(190, 40)
	tag.StudsOffset = Vector3.new(0, 2.4, 0)
	tag.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = TEAM_COLOURS[entry.team]
	label.TextStrokeTransparency = 0.4
	label.Text = TEAM_LABELS[entry.team] .. "  #" .. entry.number
	label.Parent = tag
	tag.Parent = entry.model:FindFirstChild("Head") or entry.root
end

-- ------------------------------------------------------------------ state

local scores = { 0, 0 }
local carrier = nil
local phase = "loose" -- loose | carry | gather | flight
local carryStart = 0
local gatherStart = 0
local flightStart = 0
local shotFrom = nil
local shotTeam = nil
local shotRim = nil
local lastBallY = nil
local streakTeam = nil
local streakCount = 0
local claimTeam = nil
local claimUntil = 0
local lastScore = 0
local spotDistance = 12
local spotLane = 0

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function unit(v)
	local f = flat(v)
	if f.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

local function updateBoard(points, team)
	teamALabel.Text = TEAM_LABELS[1] .. " " .. scores[1]
	teamBLabel.Text = TEAM_LABELS[2] .. " " .. scores[2]
	teamALabel.TextColor3 = TEAM_COLOURS[1]
	teamBLabel.TextColor3 = TEAM_COLOURS[2]
	if points == 3 then
		title.Text = TEAM_LABELS[team] .. "  THREE!"
		task.delay(2.4, function()
			if title.Parent then
				title.Text = TITLE
			end
		end)
	end
end

local function moveTo(entry, position)
	local now = os.clock()
	if entry.target and (entry.target - position).Magnitude < 2 and now - (entry.movedAt or 0) < 0.6 then
		return
	end
	entry.target = position
	entry.movedAt = now
	entry.humanoid:MoveTo(position)
end

-- A shooting spot `distance` studs out from the rim the player attacks, offset
-- sideways by `lane` so two teammates do not stack on the same spot.
local function spotFor(entry, distance, lane)
	local rim = entry.attack.Position
	local toward = unit(centre - rim)
	local side = Vector3.new(-toward.Z, 0, toward.X)
	local spot = rim + toward * distance + side * lane
	return Vector3.new(spot.X, GROUND_Y, spot.Z)
end

local function setCarry(entry)
	carrier = entry
	phase = "carry"
	carryStart = os.clock()
	spotDistance = (math.random() < 0.28) and (21 + math.random() * 4) or (9 + math.random() * 5)
	spotLane = entry.lane * (3.5 + math.random() * 4)
	ball.Anchored = true
	ball.CanCollide = false
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
end

local function release(entry)
	local rim = entry.attack.Position
	local launch = ball.Position
	local delta = rim + Vector3.new(0, 0.35, 0) - launch
	local horizontal = flat(delta)
	local distance = math.max(horizontal.Magnitude, 1)
	local gravity = Workspace.Gravity
	local seconds = 0.42 + distance * 0.016
	local vertical = (delta.Y + 0.5 * gravity * seconds * seconds) / seconds
	local speed = distance / seconds
	-- A defender in the shooter's face muddies the release.
	local spread = entry.spread
	for _, other in ipairs(players) do
		if other.team ~= entry.team and (flat(other.root.Position) - flat(entry.root.Position)).Magnitude < 5.5 then
			spread = spread * 1.8
			break
		end
	end
	local bend = math.rad((math.random() * 2 - 1) * spread)
	local aim = CFrame.fromAxisAngle(Vector3.yAxis, bend) * horizontal.Unit

	ball.Anchored = false
	ball.CanCollide = true
	ball.CFrame = CFrame.new(launch)
	ball.AssemblyLinearVelocity = aim * speed + Vector3.new(0, vertical, 0)
	ball.AssemblyAngularVelocity = Vector3.new(8, 5, 0)

	shotFrom = launch
	shotTeam = entry.team
	shotRim = entry.attack
	lastBallY = launch.Y
	flightStart = os.clock()
	phase = "flight"
end

-- ------------------------------------------------------------------ score

-- A shot arrives at 60-70 studs/s, so a 0.9-stud score volume is barely one
-- physics step tall and a Touched check drops makes. The crossing is tested
-- directly instead: the ball must pass the ring plane going down, inside the
-- ring.
local function award(team, from, rim)
	local now = os.clock()
	if now - lastScore < SCORE_COOLDOWN then
		return
	end
	lastScore = now
	local points = 2
	if from then
		local reached = Vector2.new(from.X - rim.Position.X, from.Z - rim.Position.Z).Magnitude
		if reached > THREE_POINT_DISTANCE then
			points = 3
		end
	end
	scores[team] = scores[team] + points
	updateBoard(points, team)
	if streakTeam == team then
		streakCount = streakCount + 1
	else
		streakTeam, streakCount = team, 1
	end
	-- Street rules: the side that scored takes the ball back, but no side runs
	-- more than two in a row or the game stops being a game.
	claimTeam = (streakCount >= 2) and (3 - team) or team
	claimUntil = now + CLAIM_SECONDS
end

local RING_PLANE_OFFSET = 0.3 -- the ring sits a little above its anchor
local RING_RADIUS = 1.15 -- a ball inside this of the ring axis counts

-- Checked every frame while a shot is in the air. The ball crosses the ring
-- plane at 60-70 studs/s, which is faster than the 0.9-stud score volume is
-- tall, so an overlap test drops makes. A swept crossing cannot.
RunService.Heartbeat:Connect(function()
	if phase ~= "flight" or not shotRim then
		lastBallY = nil
		return
	end
	local position = ball.Position
	local plane = shotRim.Position.Y + RING_PLANE_OFFSET
	local previous = lastBallY
	lastBallY = position.Y
	if not previous or previous <= plane or position.Y > plane then
		return
	end
	local gap = Vector2.new(position.X - shotRim.Position.X, position.Z - shotRim.Position.Z).Magnitude
	if gap <= RING_RADIUS then
		award(shotTeam, shotFrom, shotRim)
	end
end)

updateBoard(0, 1)

-- ------------------------------------------------------------------- play

local function nearest(teams)
	local best, bestDistance
	for _, entry in ipairs(players) do
		if not teams or teams[entry.team] then
			local d = (flat(entry.root.Position) - flat(ball.Position)).Magnitude
			if not bestDistance or d < bestDistance then
				best, bestDistance = entry, d
			end
		end
	end
	return best, bestDistance
end

local function resetBall()
	local home = ball:GetAttribute("HomeCFrame")
	ball.Anchored = true
	ball.CFrame = typeof(home) == "CFrame" and home or CFrame.new(centre.X, 1, centre.Z)
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	task.wait(0.12)
	ball.Anchored = false
	carrier = nil
	phase = "loose"
	shotFrom = nil
	shotRim = nil
end

task.spawn(function()
	while true do
		task.wait(0.1)
		if not ball.Parent then
			break
		end

		local position = ball.Position
		if
			position.Y < RESET_Y
			or math.abs(position.X - centre.X) > OUT_X
			or math.abs(position.Z - centre.Z) > OUT_Z
		then
			resetBall()
			continue
		end

		if phase == "loose" then
			local wanted = nil
			if claimTeam and os.clock() < claimUntil then
				wanted = { [claimTeam] = true }
			end
			local entry, distance = nearest(wanted)
			if not entry then
				entry, distance = nearest(nil)
			end
			if entry then
				moveTo(entry, Vector3.new(ball.Position.X, GROUND_Y, ball.Position.Z))
				if distance and distance < GRAB_RADIUS and ball.AssemblyLinearVelocity.Magnitude < 16 then
					setCarry(entry)
				end
			end
		elseif phase == "carry" then
			local entry = carrier
			if not entry or not entry.root.Parent then
				carrier = nil
				phase = "loose"
				continue
			end
			-- A defender camping on the handler can strip the ball. The
			-- cooldown keeps it from turning into a steal train.
			local stolen = false
			for _, other in ipairs(players) do
				if other.team ~= entry.team
					and (flat(other.root.Position) - flat(entry.root.Position)).Magnitude < 2.8
					and os.clock() > (other.stealReady or 0)
					and math.random() < 0.16 then
					other.stealReady = os.clock() + 6
					if AthleticRig then
						AthleticRig.swipe(other.rig, flat(entry.root.Position - other.root.Position))
					end
					other.lungeUntil = os.clock() + 0.4
					other.humanoid:MoveTo(entry.root.Position)
					setCarry(other)
					stolen = true
					break
				end
			end
			if stolen then
				continue
			end
			local spot = spotFor(entry, spotDistance, spotLane)
			moveTo(entry, spot)
			local gap = (flat(entry.root.Position) - flat(spot)).Magnitude
			local waited = os.clock() - carryStart
			if (gap < 2.2 and waited > SHOT_COOLDOWN) or waited > 10 then
				phase = "gather"
				gatherStart = os.clock()
			end
		elseif phase == "gather" then
			if os.clock() - gatherStart > GATHER_TIME then
				release(carrier)
			end
		elseif phase == "flight" then
			local landed = ball.Position.Y < GROUND_Y + 0.8
			if (landed and os.clock() - flightStart > 0.5) or os.clock() - flightStart > 6 then
				carrier = nil
				shotFrom = nil
				shotRim = nil
				phase = "loose"
			end
		end
	end
end)

-- Off-ball movement: the teammate spaces out, the defender sags between the
-- ball handler and the hoop they are protecting.
task.spawn(function()
	while true do
		task.wait(0.35)
		if phase ~= "carry" or not carrier then
			continue
		end
		for _, entry in ipairs(players) do
			if entry ~= carrier and entry.root.Parent then
				if (entry.lungeUntil or 0) > os.clock() then
					continue -- this defender is in the middle of a swipe
				end
				if entry.team == carrier.team then
					moveTo(entry, spotFor(entry, spotDistance + 3, -spotLane))
				else
					local target = flat(carrier.root.Position) + unit(entry.defend.Position - carrier.root.Position) * 4.5
					moveTo(entry, Vector3.new(target.X, GROUND_Y, target.Z))
				end
			end
		end
	end
end)

-- The dribble: the ball is anchored and bounced under the lead hand, then
-- lifted to the hand during the gather.
RunService.Heartbeat:Connect(function()
	if not carrier or (phase ~= "carry" and phase ~= "gather") then
		return
	end
	local root = carrier.root
	if not root.Parent then
		return
	end
	local look = unit(root.CFrame.LookVector)
	local side = Vector3.new(-look.Z, 0, look.X)
	local base = root.Position + look * 1.35 + side * 0.75
	local low = Vector3.new(base.X, GROUND_Y + 0.45, base.Z)

	if phase == "gather" then
		local t = math.clamp((os.clock() - gatherStart) / GATHER_TIME, 0, 1)
		local hand = root.Position + look * 0.9 + Vector3.new(0, 0.55, 0)
		ball.CFrame = CFrame.new(low:Lerp(hand, t))
		return
	end

	local cycle = (os.clock() * 1.85) % 1
	local top = root.Position.Y - 0.55
	local y = low.Y + (top - low.Y) * math.abs(math.cos(cycle * math.pi))
	ball.CFrame = CFrame.new(Vector3.new(base.X, y, base.Z))
end)
