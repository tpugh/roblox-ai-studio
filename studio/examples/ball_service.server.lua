--!nonstrict
-- BallService — grab / throw / dribble / score / reset for the street court.
--
-- Server-authoritative. The client only sends intent: a throw direction and a
-- charge fraction, both clamped here. Nothing the client says moves a ball
-- without passing a distance and state check first.
--
-- Layout assumed (see street_basketball_court.lua):
--   Workspace.StreetBasketballCourt.Props.Basketball  (x2, unanchored)
--   Workspace.StreetBasketballCourt.Anchors.RimScore_Home / RimScore_Away
--   each ball carries a `HomeCFrame` attribute
--
-- Install as a Script under ServerScriptService. The court builder does not
-- create this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local COURT_MODEL = "StreetBasketballCourt"
local COURT_SURFACE = 1.0
local GRAB_DISTANCE = 9
local THROW_SPEED_MIN, THROW_SPEED_MAX = 50, 105
local GRAB_LOCKOUT = 0.35 -- can't instantly re-grab a ball you just let go
local THROW_COLLIDE_DELAY = 0.3
local SCORE_COOLDOWN = 0.8
local SCORE_MAX_RISE = 0 -- a descending ball in the ring scores; a rising one clanks
local THREE_POINT_DISTANCE = 23
local CLANK_COOLDOWN = 0.22 -- a rim rattle touches several times; sound it once
local BOUNCE_MIN_SPEED = 8 -- studs/s downward before a floor hit is worth a thud
local BOUNCE_COOLDOWN = 0.14 -- a settling ball touches repeatedly

-- Dribble: kinematic bounce loop. It starts on its own as soon as you walk with
-- the ball, and Q toggles it while standing still. Kinematic (anchored) instead
-- of loose physics so the rhythm never turns into the ball squirting away.
local DRIBBLE_RHYTHM = 3.4 -- phase units/sec; ~1.7 bounces/sec
local DRIBBLE_IDLE_CATCH = 0.3 -- stand still this long -> ball is caught back into the hand
local DRIBBLE_FORWARD = 1.4 -- studs in front of the root
local DRIBBLE_SWAY = 0.35 -- side-to-side studs, so the bounce has some life
local DRIBBLE_TOP_OFFSET = 1.1 -- hand height below the root
local DRIBBLE_FLOOR_OFFSET = 2.9 -- fallback ground distance below the root
local DRIBBLE_BALL_RADIUS = 0.45 -- half of the 0.8 ball, plus a hair

-- Gamebreaker dunk: a scripted finish, not a physics shot. The ball is taken
-- off the player, flown above the rim and slammed down through it, so the
-- finish is guaranteed. The NBA Street layer owns the points; the normal rim
-- score is suppressed for a window so the dunk cannot pay twice.
local DUNK_GATHER_TIME = 0.34
local DUNK_SLAM_TIME = 0.16
local DUNK_DROP_TIME = 0.1
local DUNK_NO_SCORE_WINDOW = 1.5
local DUNK_DROP_SPEED = 68

-- ------------------------------------------------------------------- sound

-- Free Creator Store one-shots: the ball on the floor, the shot leaving the
-- hand, and a hard rim/board clank. Each hit clones a short-lived Sound onto
-- the ball, so it is positional and cleans itself up.
local SFX = {
	bounce = { id = "rbxassetid://377958030", volume = 0.42 },
	shot = { id = "rbxassetid://124140408144336", volume = 0.5 },
	rim = { id = "rbxassetid://81912260477958", volume = 0.55 },
}

local function playSound(part, kind, pitchScale)
	local spec = SFX[kind]
	if not (spec and part and part.Parent) then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. kind
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.PlaybackSpeed = pitchScale or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 9
	sound.RollOffMaxDistance = 140
	sound.Parent = part
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	-- Belt and braces: Ended never fires if the emitter is destroyed first.
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------- remotes

local remotesFolder = ReplicatedStorage:FindFirstChild("BallRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "BallRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function remote(name, className)
	local existing = remotesFolder:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = remotesFolder
	return instance
end

local ThrowRemote = remote("Throw", "RemoteEvent")
local DribbleRemote = remote("Dribble", "RemoteEvent")
local GrabRemote = remote("Grab", "RemoteEvent")
local ResetRemote = remote("ResetBalls", "RemoteEvent")
local Feedback = remote("Feedback", "RemoteEvent")
-- Server-to-server: the NBA Street layer invokes this to run a Gamebreaker
-- dunk. It is a BindableFunction so the caller learns whether the dunk started.
local DunkCommand = remote("DunkCommand", "BindableFunction")
-- Player-facing dunk request (V key) and a small text-feedback channel.
local DunkRemote = remote("Dunk", "RemoteEvent")
local DunkFeedback = remote("DunkFeedback", "RemoteEvent")
-- NBAStreetRules invokes this when X lands so the dribbled ball follows the
-- same move the avatar is performing.
local TrickBallCommand = remote("TrickBallCommand", "BindableFunction")
-- Defense hooks: StreetDefense and the player's C input ask this script to
-- move the ball around instead of touching the state tables themselves.
local DefendRemote = remote("Defend", "RemoteEvent")
local DefenseCommand = remote("DefenseCommand", "BindableFunction")

-- ----------------------------------------------------------------- state

local held = {} -- [ball] = { player = Player, weld = WeldConstraint }
local dribbling = {} -- [ball] = { player, phase, manual, idle }
local trickBall = {} -- [ball] = { move = 1..5, start, duration }
local mode = {} -- [ball] = "free" | "held" | "dribble"
local lockout = {} -- [ball] = os.clock() until which grabbing is refused
local lastScore = {} -- [ball] = os.clock()
local lastClank = {} -- [ball] = os.clock(), rim hits that did not drop
local lastBounce = {} -- [ball] = os.clock(), floor hits of a loose ball
local bounceHook = {} -- [ball] = true, floor-bounce listener installed
local shotOrigin = {} -- [ball] = Vector3, where the current shot was released
local dunkBusy = {} -- [ball] = true while the scripted dunk owns it
local dunkNoScore = {} -- [ball] = os.clock() until which the rim score is muted
local thrower = setmetatable({}, { __mode = "k" })
local watchedRims = {}

-- --------------------------------------------------------------- helpers

local function balls()
	local list = {}
	local model = Workspace:FindFirstChild(COURT_MODEL)
	local props = model and model:FindFirstChild("Props")
	if not props then
		return list
	end
	for _, child in ipairs(props:GetChildren()) do
		if child.Name == "Basketball" and child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function handOf(character)
	return character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
end

local function heldBallOf(player)
	for ball, data in pairs(held) do
		if data.player == player then
			return ball
		end
	end
	return nil
end

local function setPromptEnabled(ball, enabled)
	local prompt = ball:FindFirstChild("GrabBall")
	if prompt then
		prompt.Enabled = enabled
	end
end

local function release(ball, canCollide)
	if dribbling[ball] then
		local entry = dribbling[ball]
		dribbling[ball] = nil
		if ball.Parent then
			ball.Anchored = false
		end
		if entry.player and entry.player.Parent then
			entry.player:SetAttribute("Dribbling", false)
			entry.player:SetAttribute("HoldingBall", false)
		end
	end
	local data = held[ball]
	if data then
		if data.weld then
			data.weld:Destroy()
		end
		held[ball] = nil
		if data.player and data.player.Parent then
			data.player:SetAttribute("HoldingBall", false)
			data.player:SetAttribute("Dribbling", false)
		end
	end
	ball:SetAttribute("HeldBy", nil)
	ball.Massless = false
	ball.CanCollide = canCollide ~= false
	setPromptEnabled(ball, true)
	mode[ball] = "free"
	lockout[ball] = os.clock() + GRAB_LOCKOUT
end

-- ------------------------------------------------------------------ grab

local function grab(player, ball)
	if not ball or not ball.Parent or not ball:IsA("BasePart") then
		return false
	end
	if (mode[ball] or "free") ~= "free" then
		return false
	end
	if (lockout[ball] or 0) > os.clock() then
		return false
	end
	if heldBallOf(player) then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hand = handOf(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and hand and humanoid) or humanoid.Health <= 0 then
		return false
	end
	if (ball.Position - root.Position).Magnitude > GRAB_DISTANCE then
		return false
	end

	ball.Anchored = false
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CanCollide = false
	ball.Massless = true
	ball.CFrame = hand.CFrame * CFrame.new(0, -1.1, -1.3)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "HeldWeld"
	weld.Part0 = hand
	weld.Part1 = ball
	weld.Parent = ball

	held[ball] = { player = player, weld = weld }
	mode[ball] = "held"
	player:SetAttribute("HoldingBall", true)
	ball:SetAttribute("HeldBy", player.UserId)
	setPromptEnabled(ball, false)
	return true
end

-- --------------------------------------------------------------- dribble

local function dribbledBallOf(player)
	for ball, data in pairs(dribbling) do
		if data.player == player then
			return ball
		end
	end
	return nil
end

-- Hand the ball over to the kinematic bounce loop. `manual` means the player
-- pressed Q while standing still; otherwise walking started it.
local function beginDribble(player, ball, manual)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not ball or not ball.Parent or not root then
		return false
	end
	release(ball, false)
	lockout[ball] = 0 -- a dribbled ball can be caught again immediately
	ball.Anchored = true
	ball.CanCollide = false
	ball.Massless = false
	mode[ball] = "dribble"
	dribbling[ball] = { player = player, phase = 0, manual = manual == true, idle = 0 }
	setPromptEnabled(ball, false)
	player:SetAttribute("HoldingBall", true)
	player:SetAttribute("Dribbling", true)
	return true
end

local function endDribble(ball, recatch)
	local data = dribbling[ball]
	if not data then
		return
	end
	dribbling[ball] = nil
	mode[ball] = "free"
	lockout[ball] = 0
	ball.Anchored = false
	ball.CanCollide = true
	ball.Massless = false
	setPromptEnabled(ball, true)
	local player = data.player
	if player and player.Parent then
		player:SetAttribute("Dribbling", false)
		player:SetAttribute("HoldingBall", false)
	end
	if recatch and player and player.Parent then
		grab(player, ball)
	end
end

local bounceRayParams = RaycastParams.new()
bounceRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function planarSpeed(root)
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- The server never sees Humanoid.MoveDirection from a client-driven character
-- (it reads the replicated velocity instead), so movement is judged from the
-- root part's own horizontal speed.
local function isWalking(root)
	return planarSpeed(root) > 2
end

local function updateDribble(ball, data, dt)
	local player = data.player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (ball.Parent and root and humanoid) or humanoid.Health <= 0 then
		if ball.Parent then
			ball.Anchored = false
			ball.CanCollide = true
			setPromptEnabled(ball, true)
		end
		dribbling[ball] = nil
		mode[ball] = "free"
		if player.Parent then
			player:SetAttribute("Dribbling", false)
			player:SetAttribute("HoldingBall", false)
		end
		return
	end

	local moving = planarSpeed(root) > 1 and player:GetAttribute("Charging") ~= true
	if data.manual and moving then
		data.manual = false -- walking takes over from the in-place toggle
	end
	if not data.manual then
		if moving then
			data.idle = 0
		else
			data.idle = data.idle + dt
			if data.idle >= DRIBBLE_IDLE_CATCH then
				endDribble(ball, true)
				return
			end
		end
	end

	data.phase = (data.phase + dt * DRIBBLE_RHYTHM) % 1
	if data.previousPhase and data.previousPhase < 0.5 and data.phase >= 0.5 then
		-- Phase 0.5 is the floor contact of the bounce.
		playSound(ball, "bounce", 0.94 + math.random() * 0.12)
	end
	data.previousPhase = data.phase

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local right = flat:Cross(Vector3.yAxis)
	local center = root.Position
		+ flat * DRIBBLE_FORWARD
		+ right * (math.sin(data.phase * math.pi * 2) * DRIBBLE_SWAY)

	bounceRayParams.FilterDescendantsInstances = { ball, character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), bounceRayParams)
	local floorY = hit and hit.Position.Y or (root.Position.Y - DRIBBLE_FLOOR_OFFSET)
	local bottomY = floorY + DRIBBLE_BALL_RADIUS
	local topY = root.Position.Y - DRIBBLE_TOP_OFFSET
	if topY < bottomY + 1 then
		topY = bottomY + 1
	end

	-- |cos| keeps the ball hanging at the hand longer and snapping through the
	-- floor contact, which reads as a real bounce instead of a sine slide.
	-- During a trick the ball follows the same move the avatar is doing, so a
	-- crossover really crosses the body and a spin really orbits the player.
	local trickLift = 0
	if trickBall[ball] then
		local trick = trickBall[ball]
		local elapsed = os.clock() - trick.start
		if elapsed >= trick.duration then
			trickBall[ball] = nil
		else
			local t = elapsed / trick.duration
			local swirl = t * math.pi * 2
			local arc = math.sin(t * math.pi)
			if trick.move == 1 then
				center = root.Position + flat * DRIBBLE_FORWARD + right * (math.sin(swirl) * 2.6)
			elseif trick.move == 2 then
				center = root.Position + (flat * math.cos(swirl) + right * math.sin(swirl)) * 2.1
				topY = root.Position.Y + 1.0 + arc * 1.5
				trickLift = 0.82
			elseif trick.move == 3 then
				center = root.Position - flat * 1.8 + right * (math.sin(t * math.pi) * 1.5)
				topY = root.Position.Y + 0.8 + arc * 0.9
				trickLift = 0.82
			elseif trick.move == 4 then
				center = root.Position + flat * 0.5 + right * (math.sin(swirl) * 2.0)
				topY = root.Position.Y - 0.6
			else
				center = root.Position + right * (math.sin(swirl) * 0.8)
				topY = root.Position.Y + 1.6 + arc * 1.2
				trickLift = 0.88
			end
		end
	end

	local bounce = math.abs(math.cos(data.phase * math.pi))
	if trickLift > 0 then
		bounce = math.max(bounce, trickLift)
	end
	local y = bottomY + (topY - bottomY) * bounce
	ball.CFrame = CFrame.new(Vector3.new(center.X, y, center.Z)) * CFrame.Angles(data.phase * math.pi * 2, 0, 0)
end

local function updateDribbles(dt)
	for ball, data in pairs(dribbling) do
		updateDribble(ball, data, dt)
	end
	-- Automatic dribble: the moment a ball holder walks, the ball goes to the
	-- floor under its own rhythm. Standing still catches it back into the hand.
	for ball, data in pairs(held) do
		local player = data.player
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			root
			and humanoid
			and humanoid.Health > 0
			and isWalking(root)
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and player:GetAttribute("Charging") ~= true
		then
			beginDribble(player, ball, false)
		end
	end
end

RunService.Heartbeat:Connect(updateDribbles)

-- --------------------------------------------------------------- ballistics

local AIM_RANGE = 62 -- rims further than this are thrown at, not aimed
local AIM_LIFT = 0.25 -- aim above the ring so the ball drops through the volume
local AIM_SPREAD_MAX = math.rad(30)
local ASSIST_NEAR, ASSIST_FAR = 0.92, 0.55

-- A launch velocity that lands `from` on `to` on the way down. The flight time
-- is chosen from the range, so short shots arc and long shots flatten, and a
-- charged shot arrives with more pace. Solving for speed at the minimum-energy
-- angle instead put the apex on the rim, so the ball was still climbing when it
-- got there and sailed over the backboard.
local function ballistic(from, to, charge)
	local delta = to - from
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local d = flat.Magnitude
	if d < 0.5 then
		return nil
	end
	local g = Workspace.Gravity
	local seconds = (0.35 + d * 0.012) * (1.06 - 0.18 * charge)
	local vy = (delta.Y + 0.5 * g * seconds * seconds) / seconds
	local vh = d / seconds
	return flat.Unit * vh + Vector3.new(0, vy, 0)
end

-- Same arc, bent off target by the player's own aim. Charge raises the assist,
-- so a hard shot forgives more than a quick flick.
local function assistedVelocity(origin, aimOrigin, rimPosition, aim, charge)
	local solved = ballistic(origin, rimPosition + Vector3.new(0, AIM_LIFT, 0), charge)
	if not solved then
		return nil
	end
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	if flatAim.Magnitude < 0.05 then
		return solved
	end
	flatAim = flatAim.Unit
	-- Measure the aim from the character, not the hand: a player looking at the
	-- hoop is then exactly on target instead of a few degrees wide.
	local toRim = Vector3.new(rimPosition.X - aimOrigin.X, 0, rimPosition.Z - aimOrigin.Z)
	if toRim.Magnitude < 0.05 then
		return solved
	end
	toRim = toRim.Unit
	-- Signed horizontal angle between the rim and where the player is aiming.
	local error = math.atan2(toRim:Cross(flatAim).Y, toRim:Dot(flatAim))
	local assist = ASSIST_FAR + (ASSIST_NEAR - ASSIST_FAR) * charge
	local bend = math.clamp(error * (1 - assist), -AIM_SPREAD_MAX, AIM_SPREAD_MAX)
	return CFrame.fromAxisAngle(Vector3.yAxis, bend) * solved
end

-- ----------------------------------------------------------------- throw

local function throwBall(player, direction, charge)
	local ball = heldBallOf(player)
	if not ball then
		-- Shooting out of a dribble: catch the ball back into the hand first.
		local dribbled = dribbledBallOf(player)
		if dribbled then
			endDribble(dribbled, true)
			ball = heldBallOf(player)
		end
	end
	if not ball then
		return
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		return
	end

	-- The player's aim is a direction only; the arc is solved here so a shot
	-- always reaches the rim. Without this a mostly-horizontal aim launched the
	-- ball flat and it could never climb to the 9-stud ring.
	local unit = direction.Unit
	unit = Vector3.new(unit.X, math.clamp(unit.Y, -0.25, 0.95), unit.Z).Unit
	if unit.Magnitude < 0.1 then
		return
	end
	charge = math.clamp(tonumber(charge) or 0, 0, 1)
	-- Sharp Shooter cocoa buys a little extra charge and aim assist.
	if (player:GetAttribute("CocoaShootUntil") or 0) > os.clock() then
		charge = math.min(1, charge + 0.35)
	end

	local character = player.Character
	local hand = handOf(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local launch = (hand and hand.CFrame or ball.CFrame) * CFrame.new(0, 0, -1.2)

	-- Aim assist: solve the arc to the nearest rim and let the player's aim bend
	-- it slightly off target. Charge raises both the pace and the assist.
	local model = Workspace:FindFirstChild(COURT_MODEL)
	local anchors = model and model:FindFirstChild("Anchors")
	local velocity
	if anchors then
		local best, bestDist
		for _, a in ipairs(anchors:GetChildren()) do
			if string.sub(a.Name, 1, 8) == "RimScore" then
				local d = (a.Position - launch.Position).Magnitude
				if d < AIM_RANGE and (not bestDist or d < bestDist) then
					best, bestDist = a, d
				end
			end
		end
		if best then
			velocity = assistedVelocity(launch.Position, root and root.Position or launch.Position, best.Position, unit, charge)
		end
	end
	if not velocity then
		velocity = unit * (THROW_SPEED_MIN + (THROW_SPEED_MAX - THROW_SPEED_MIN) * charge)
	end

	-- A defender in the shooter's air space contests the release: the arc is
	-- nudged off line and loses a little pace, so a tight contest can force a
	-- miss even when the player's aim and charge were perfect.
	local contested = (ball:GetAttribute("ContestedUntil") or 0) > os.clock()
	if contested then
		ball:SetAttribute("ContestedUntil", nil)
		local nudge = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
		if nudge.Magnitude > 0.01 then
			nudge = nudge.Unit * (5 + math.random() * 5)
		end
		velocity = velocity * 0.92 + nudge
	end

	release(ball, false) -- no collide for a moment so it clears the thrower
	ball.CFrame = launch
	-- Set velocity directly: reading AssemblyMass in the same tick that Massless
	-- flips can return a stale (near-zero) mass, which silently killed the launch.
	ball.AssemblyLinearVelocity = velocity
	playSound(ball, "shot", 0.94 + charge * 0.12)
	ball.AssemblyAngularVelocity = Vector3.new(math.random() * 5 - 2.5, math.random() * 5 - 2.5, math.random() * 5 - 2.5)
	thrower[ball] = player
	shotOrigin[ball] = launch.Position
	ball:SetAttribute("LastThrownBy", player.UserId)

	task.delay(THROW_COLLIDE_DELAY, function()
		if ball.Parent then
			ball.CanCollide = true
		end
	end)
end

-- --------------------------------------------------------------- dribble

-- Q toggles the bounce. Start dribbling from the hand, or catch a dribble that
-- is already running. Walking also starts it (see updateDribbles).
local function dribble(player)
	local ball = heldBallOf(player)
	if ball then
		beginDribble(player, ball, true)
		return
	end
	local dribbled = dribbledBallOf(player)
	if dribbled then
		endDribble(dribbled, true)
	end
end

-- ----------------------------------------------------------------- dunk

local function rimAnchors()
	local list = {}
	-- Both the street court and the Santa court host score volumes; a dunk
	-- should target whichever hoop the player is actually standing near.
	for _, modelName in ipairs({ COURT_MODEL, "SantaCourt" }) do
		local model = Workspace:FindFirstChild(modelName)
		local anchors = model and model:FindFirstChild("Anchors")
		if anchors then
			for _, part in ipairs(anchors:GetChildren()) do
				if string.sub(part.Name, 1, 8) == "RimScore" then
					table.insert(list, part)
				end
			end
		end
	end
	return list
end

local function nearestRim(position)
	local best, bestDist
	for _, anchor in ipairs(rimAnchors()) do
		local distance = (anchor.Position - position).Magnitude
		if not bestDist or distance < bestDist then
			best, bestDist = anchor, distance
		end
	end
	return best
end

-- The score volumes sit just under the ring, so the ring centre is 0.45 above.
local function rimCenter(scoreVolume)
	return scoreVolume.Position + Vector3.new(0, 0.45, 0)
end

local function dunkBurst(position, gamebreaker)
	local holder = Instance.new("Part")
	holder.Name = gamebreaker and "GamebreakerDunkFX" or "DunkFX"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Anchored = true
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace

	local tint = gamebreaker and Color3.fromRGB(255, 214, 92) or Color3.fromRGB(232, 244, 255)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(tint)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, gamebreaker and 1.8 or 1.0),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkle.Lifetime = NumberRange.new(0.4, 0.9)
	sparkle.Speed = NumberRange.new(10, gamebreaker and 26 or 16)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 0
	sparkle.LightEmission = 1
	sparkle.Parent = holder

	local flash = Instance.new("PointLight")
	flash.Brightness = gamebreaker and 9 or 3
	flash.Range = gamebreaker and 26 or 14
	flash.Color = tint
	flash.Parent = holder

	sparkle:Emit(gamebreaker and 70 or 24)
	task.delay(1.4, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- A dunk rattles the ring. Rim and net parts are found by name around the
-- hoop, so this works for the metal street rims and the generated ones too.
local shakingRims = setmetatable({}, { __mode = "k" })

local function rimVisualsNear(position)
	local found = {}
	local hits = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(5, 2.5, 5))
	for _, part in ipairs(hits) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, 8) ~= "RimScore" then
			local name = string.lower(part.Name)
			if string.find(name, "rim", 1, true)
				or string.find(name, "segment", 1, true)
				or string.find(name, "net", 1, true) then
				table.insert(found, part)
			end
		end
	end
	return found
end

local function shakeRim(position, strength)
	for _, part in ipairs(rimVisualsNear(position)) do
		if not shakingRims[part] then
			shakingRims[part] = true
			local isNet = string.find(string.lower(part.Name), "net", 1, true) ~= nil
			local amplitude = (isNet and 0.09 or 0.16) * strength
			local base = part.CFrame
			task.spawn(function()
				local steps = strength > 1 and 9 or 6
				for step = 1, steps do
					if not part.Parent then
						break
					end
					local decay = 1 - (step - 1) / steps
					local a = amplitude * decay
					part.CFrame = base
						* CFrame.new((math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a)
						* CFrame.Angles((math.random() * 2 - 1) * a * 0.6, 0, (math.random() * 2 - 1) * a * 0.6)
					task.wait(0.04)
				end
				if part.Parent then
					part.CFrame = base
				end
				shakingRims[part] = nil
			end)
		end
	end
end

local function tweenPart(part, goal, seconds, style, direction)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(part, info, { CFrame = goal })
	tween:Play()
	tween.Completed:Wait()
end

local function dunkBall(player, scoreVolume, gamebreaker)
	gamebreaker = gamebreaker == true
	if not (player and player.Parent) then
		return false
	end
	local ball = heldBallOf(player) or dribbledBallOf(player)
	if not ball or dunkBusy[ball] then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and scoreVolume and scoreVolume.Parent) then
		return false
	end

	-- Free the ball from whichever state it is in, without catching it back.
	if dribbling[ball] then
		endDribble(ball, false)
	elseif held[ball] then
		release(ball, false)
	end

	dunkBusy[ball] = true
	dunkNoScore[ball] = os.clock() + DUNK_NO_SCORE_WINDOW
	mode[ball] = "dunk"
	ball.Anchored = true
	ball.CanCollide = false
	ball.Massless = false
	setPromptEnabled(ball, false)
	ball:SetAttribute("HeldBy", nil)
	player:SetAttribute("HoldingBall", false)
	player:SetAttribute("Dribbling", false)

	local startCFrame = ball.CFrame
	local rim = rimCenter(scoreVolume)
	local inward = Vector3.new(root.Position.X - rim.X, 0, root.Position.Z - rim.Z)
	if inward.Magnitude < 1 then
		inward = Vector3.new(0, 0, 1)
	else
		inward = inward.Unit
	end

	-- The player leaps up to the ring with the ball, so a dunk really does
	-- touch the rim instead of only flying the ball through the hoop.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local apexPos = rim + inward * 2.2 + Vector3.new(0, -0.7, 0)
	local apexRoot = CFrame.lookAt(apexPos, rim)

	-- Cocked above the front of the rim, then straight down through the ring.
	local gather = CFrame.new(rim + inward * 2.6 + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(90), 0, 0)
	local through = CFrame.new(rim + Vector3.new(0, -0.2, 0)) * CFrame.Angles(math.rad(180), 0, 0)
	local drop = CFrame.new(rim + Vector3.new(0, -3.2, 0)) * CFrame.Angles(math.rad(180), 0, 0)

	task.spawn(function()
		-- Lift the character in parallel with the ball's gather, hold at the
		-- rim through the slam, then ease back down to the floor.
		local baseRoot = root.CFrame
		local wasAnchored = root.Anchored
		if humanoid then
			humanoid.PlatformStand = true
		end
		root.Anchored = true
		task.spawn(function()
			tweenPart(root, apexRoot, DUNK_GATHER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(DUNK_SLAM_TIME + DUNK_DROP_TIME + 0.12)
			if root.Parent then
				tweenPart(root, baseRoot, 0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				root.Anchored = wasAnchored
				if humanoid then
					humanoid.PlatformStand = false
				end
			end
		end)

		ball.CFrame = startCFrame
		tweenPart(ball, gather, DUNK_GATHER_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if not ball.Parent then
			return
		end
		tweenPart(ball, through, DUNK_SLAM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		dunkBurst(rim, gamebreaker)
		shakeRim(rim, gamebreaker and 1.9 or 0.6)
		playSound(ball, "rim", 0.86)
		if not gamebreaker and player.Parent then
			-- Gamebreaker pays its own points in the NBA Street layer; a normal
			-- dunk scores here like any other made basket.
			player:SetAttribute("Score", (player:GetAttribute("Score") or 0) + 2)
			Feedback:FireAllClients(player, 2)
		end
		if not ball.Parent then
			return
		end
		tweenPart(ball, drop, DUNK_DROP_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		if not ball.Parent then
			return
		end

		-- Hand the ball back to physics below the net.
		ball.Anchored = false
		ball.CanCollide = true
		ball.Massless = false
		ball.AssemblyLinearVelocity = Vector3.new(0, -DUNK_DROP_SPEED, 0)
		ball.AssemblyAngularVelocity = Vector3.new(6, 3, 0)
		mode[ball] = "free"
		lockout[ball] = os.clock() + GRAB_LOCKOUT
		setPromptEnabled(ball, true)
		dunkBusy[ball] = nil
		ball:SetAttribute("LastDunkedBy", player.UserId)
	end)

	return true
end

-- A loose ball that lands should sound like a ball, not a rock: misses, passes
-- and rebounds all bounce. Dribbling is skipped because its own loop already
-- accents the floor contact.
local function watchBounce(ball)
	if bounceHook[ball] then
		return
	end
	bounceHook[ball] = true
	ball.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		if mode[ball] == "held" or mode[ball] == "dribble" then
			return
		end
		if ball.AssemblyLinearVelocity.Y > -BOUNCE_MIN_SPEED then
			return -- too slow to be a bounce worth hearing
		end
		-- Contact near the ball's own height is a rim, board or player; a floor
		-- contact sits roughly a ball radius below it.
		if hit.Position.Y > ball.Position.Y - 0.35 then
			return
		end
		local now = os.clock()
		if lastBounce[ball] and now - lastBounce[ball] < BOUNCE_COOLDOWN then
			return
		end
		lastBounce[ball] = now
		playSound(ball, "bounce", 0.9 + math.random() * 0.14)
	end)
end

-- ----------------------------------------------------------------- score

local function watchRim(scoreVolume)
	scoreVolume.Touched:Connect(function(hit)
		if not (hit and hit.Name == "Basketball" and hit:IsA("BasePart")) then
			return
		end
		if mode[hit] == "held" or mode[hit] == "dribble" then
			return
		end
		local now = os.clock()
		if lastScore[hit] and now - lastScore[hit] < SCORE_COOLDOWN then
			return
		end
		local skipUntil = dunkNoScore[hit]
		if skipUntil and now < skipUntil then
			return -- the Gamebreaker dunk pays through the NBA Street layer
		end
		-- A ball that reaches the ring but is not dropping through it is a clank.
		local velocity = hit.AssemblyLinearVelocity
		if velocity.Y > SCORE_MAX_RISE then
			if not lastClank[hit] or now - lastClank[hit] > CLANK_COOLDOWN then
				lastClank[hit] = now
				playSound(hit, "rim", 0.96 + math.random() * 0.08)
			end
			return
		end
		lastScore[hit] = now
		playSound(hit, "rim", 0.9 + math.random() * 0.06)

		-- Three-pointers are judged from where the shot left the hand, not from
		-- the ring: at the ring every ball is at distance zero.
		local origin = shotOrigin[hit]
		local flat
		if origin then
			flat = Vector3.new(origin.X - scoreVolume.Position.X, 0, origin.Z - scoreVolume.Position.Z).Magnitude
		else
			flat = Vector3.new(hit.Position.X - scoreVolume.Position.X, 0, hit.Position.Z - scoreVolume.Position.Z).Magnitude
		end
		local points = flat > THREE_POINT_DISTANCE and 3 or 2
		local scorer = thrower[hit]
		if scorer and scorer.Parent then
			scorer:SetAttribute("Score", (scorer:GetAttribute("Score") or 0) + points)
			Feedback:FireAllClients(scorer, points)
		else
			Feedback:FireAllClients(nil, points)
		end
	end)
end

-- ----------------------------------------------------------------- reset

local function resetBalls()
	for _, ball in ipairs(balls()) do
		release(ball, true)
		mode[ball] = "free"
		local home = ball:GetAttribute("HomeCFrame")
		if typeof(home) ~= "CFrame" then
			continue
		end
		ball.Anchored = true
		ball.CFrame = home
		ball.AssemblyLinearVelocity = Vector3.zero
		ball.AssemblyAngularVelocity = Vector3.zero
		task.delay(0.1, function()
			if ball.Parent then
				ball.Anchored = false
			end
		end)
	end
end

-- --------------------------------------------------------------- prompts

local function ensurePrompt(ball)
	if ball:FindFirstChild("GrabBall") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabBall"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Basketball"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GRAB_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = ball
	prompt.Triggered:Connect(function(player)
		grab(player, ball)
	end)
end

-- ------------------------------------------------------------- lifecycle

local function watchPlayer(player)
	player:SetAttribute("HoldingBall", false)
	player:SetAttribute("Dribbling", false)
	player:SetAttribute("Charging", false)
	if not player:GetAttribute("Score") then
		player:SetAttribute("Score", 0)
	end

	local function drop()
		for ball, data in pairs(held) do
			if data.player == player then
				release(ball, true)
			end
		end
		player:SetAttribute("HoldingBall", false)
	end

	player.CharacterRemoving:Connect(drop)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("HoldingBall", false)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	for ball, data in pairs(held) do
		if data.player == player then
			release(ball, true)
		end
	end
end)

-- ---------------------------------------------------------------- defense
-- Ball state still belongs to this script. StreetDefense (AI opponents) and
-- the player's Defend input only ask for these operations by name.

local npcHold = {} -- [ball] = name of the NPC currently carrying it

local function carrierInfo()
	for ball, data in pairs(held) do
		return ball, data.player, "held"
	end
	for ball, data in pairs(dribbling) do
		return ball, data.player, "dribble"
	end
	for ball, name in pairs(npcHold) do
		return ball, name, "npc"
	end
	-- A loose ball still needs to be visible to the defense so the guards can
	-- chase it; only the holder changes.
	local model = Workspace:FindFirstChild(COURT_MODEL)
	local props = model and model:FindFirstChild("Props")
	local loose = props and props:FindFirstChild("Basketball")
	return loose, nil, "free"
end

DefenseCommand.OnInvoke = function(action, ball, extra, speed)
	if action == "carrier" then
		return carrierInfo()
	end
	if not ball or not ball.Parent or not ball:IsA("BasePart") then
		return false
	end
	if action == "contest" then
		ball:SetAttribute("ContestedUntil", os.clock() + (tonumber(extra) or 0.5))
		return true
	end
	if action == "knockLoose" then
		if dunkBusy[ball] then
			return false
		end
		release(ball, false)
		local dir = typeof(extra) == "Vector3" and extra or Vector3.new(0, 0, 1)
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(0, 0, 1)
		end
		ball.AssemblyLinearVelocity = dir.Unit * (tonumber(speed) or 16) + Vector3.new(0, 6, 0)
		ball.AssemblyAngularVelocity = Vector3.new(6, 3, 0)
		lockout[ball] = os.clock() + 0.35
		return true
	end
	if action == "holdByNPC" then
		if dunkBusy[ball] then
			return false
		end
		release(ball, false)
		npcHold[ball] = tostring(extra)
		mode[ball] = "npc"
		ball.Anchored = true
		ball.CanCollide = false
		ball:SetAttribute("HeldByNPC", tostring(extra))
		lockout[ball] = os.clock() + 600
		return true
	end
	if action == "releaseNPC" then
		if not npcHold[ball] then
			return false
		end
		npcHold[ball] = nil
		ball:SetAttribute("HeldByNPC", nil)
		ball.Anchored = false
		ball.CanCollide = true
		mode[ball] = "free"
		local dir = typeof(extra) == "Vector3" and extra or Vector3.new(0, 0, 1)
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(0, 0, 1)
		end
		ball.AssemblyLinearVelocity = dir.Unit * (tonumber(speed) or 14) + Vector3.new(0, 5, 0)
		lockout[ball] = os.clock() + 0.6
		return true
	end
	if action == "shootTo" then
		if dunkBusy[ball] or typeof(extra) ~= "Vector3" then
			return false
		end
		release(ball, false)
		local from = ball.Position
		local delta = extra - from
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		local distance = math.max(horizontal.Magnitude, 1)
		local seconds = 0.5 + distance * 0.018
		local vertical = (delta.Y + 0.5 * Workspace.Gravity * seconds * seconds) / seconds
		local spread = tonumber(speed) or 3
		local bend = math.rad((math.random() * 2 - 1) * spread)
		local aim = CFrame.fromAxisAngle(Vector3.yAxis, bend) * horizontal.Unit
		ball.CFrame = CFrame.new(from)
		ball.CanCollide = false
		ball.AssemblyLinearVelocity = aim * (distance / seconds) + Vector3.new(0, vertical, 0)
		ball.AssemblyAngularVelocity = Vector3.new(6, 3, 0)
		lockout[ball] = os.clock() + 0.3
		shotOrigin[ball] = from
		thrower[ball] = nil
		task.delay(THROW_COLLIDE_DELAY, function()
			if ball.Parent then
				ball.CanCollide = true
			end
		end)
		return true
	end
	if action == "dunkTo" then
		if dunkBusy[ball] or typeof(extra) ~= "Vector3" then
			return false
		end
		release(ball, false)
		dunkBusy[ball] = true
		mode[ball] = "npc"
		ball.Anchored = true
		ball.CanCollide = false
		task.spawn(function()
			local gather = CFrame.new(extra + Vector3.new(0, 3.2, 0))
			local through = CFrame.new(extra - Vector3.new(0, 0.4, 0))
			tweenPart(ball, gather, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			if not ball.Parent then
				dunkBusy[ball] = nil
				return
			end
			tweenPart(ball, through, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			if not ball.Parent then
				dunkBusy[ball] = nil
				return
			end
			ball.Anchored = false
			ball.CanCollide = true
			mode[ball] = "free"
			ball.AssemblyLinearVelocity = Vector3.new(0, -16, 0)
			lockout[ball] = os.clock() + 0.5
			dunkBusy[ball] = nil
		end)
		return true
	end
	if action == "stealToPlayer" then
		local thief = extra
		if not (thief and thief:IsA("Player")) then
			return false
		end
		if heldBallOf(thief) or dribbledBallOf(thief) then
			return false
		end
		if npcHold[ball] then
			npcHold[ball] = nil
			ball:SetAttribute("HeldByNPC", nil)
		end
		release(ball, false)
		lockout[ball] = 0
		return grab(thief, ball)
	end
	if action == "deflect" then
		if dunkBusy[ball] or mode[ball] ~= "free" or typeof(extra) ~= "Vector3" then
			return false
		end
		local away = ball.Position - extra
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.01 then
			away = Vector3.new(0, 0, 1)
		end
		ball.AssemblyLinearVelocity = away.Unit * 18 + Vector3.new(0, 10, 0)
		thrower[ball] = nil
		ball:SetAttribute("LastThrownBy", nil)
		return true
	end
	return false
end

DefendRemote.OnServerEvent:Connect(function(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Steal from a defender that is carrying the ball. Steal cocoa extends the
	-- reach so the buff is felt on both halves of the floor.
	local stealRange = (player:GetAttribute("CocoaStealUntil") or 0) > os.clock() and 13 or 7
	for ball in pairs(npcHold) do
		if (ball.Position - root.Position).Magnitude < stealRange then
			if DefenseCommand:Invoke("stealToPlayer", ball, player) then
				return
			end
		end
	end
	-- Block a shot that is in the air close by.
	for ball, who in pairs(thrower) do
		if who ~= player and ball.Parent and (ball.Position - root.Position).Magnitude < 10 then
			if DefenseCommand:Invoke("deflect", ball, root.Position) then
				return
			end
		end
	end
	-- Otherwise shake off a tight contest while holding the ball.
	local ball, holder = carrierInfo()
	if ball and holder == player then
		ball:SetAttribute("ContestedUntil", nil)
		player:SetAttribute("DefendPulse", os.clock())
	end
end)

GrabRemote.OnServerEvent:Connect(grab)
ThrowRemote.OnServerEvent:Connect(throwBall)
DribbleRemote.OnServerEvent:Connect(dribble)
ResetRemote.OnServerEvent:Connect(resetBalls)

-- The NBA Street layer calls this for a Gamebreaker. A missing ball returns
-- false instead of throwing, so the caller can prompt the player.
DunkCommand.OnInvoke = function(player, scoreVolume, gamebreaker)
	if not (player and player:IsA("Player")) then
		return false
	end
	if scoreVolume and not scoreVolume:IsA("BasePart") then
		scoreVolume = nil
	end
	if not scoreVolume then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		scoreVolume = root and nearestRim(root.Position) or nil
	end
	return dunkBall(player, scoreVolume, gamebreaker == true)
end

-- Regular dunk: the V key asks for the same scripted slam, scored as a normal
-- two-point basket. The caller supplies no hoop, so the nearest one is used.
DunkRemote.OnServerEvent:Connect(function(player)
	if not (player and player.Parent) then
		return
	end
	if player:GetAttribute("HoldingBall") ~= true and player:GetAttribute("Dribbling") ~= true then
		DunkFeedback:FireClient(player, "Grab the ball first!")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local scoreVolume = nearestRim(root.Position)
	if not scoreVolume then
		DunkFeedback:FireClient(player, "No hoop in range")
		return
	end
	if (scoreVolume.Position - root.Position).Magnitude > 55 then
		DunkFeedback:FireClient(player, "Get closer to the hoop to dunk!")
		return
	end
	if not dunkBall(player, scoreVolume, false) then
		DunkFeedback:FireClient(player, "Can't dunk right now")
	end
end)

-- Start the matching ball path for an X trick. The avatar animation is driven
-- on the clients by TrickAnim; this is only the ball's route through the move.
TrickBallCommand.OnInvoke = function(player, move)
	if not (player and player:IsA("Player")) then
		return false
	end
	local ball = dribbledBallOf(player)
	if not ball then
		return false
	end
	trickBall[ball] = {
		move = math.clamp(tonumber(move) or 1, 1, 5),
		start = os.clock(),
		duration = 0.65,
	}
	return true
end

-- Keep prompts and rim hooks alive across rebuilds, and tidy dead balls.
task.spawn(function()
	while true do
		for _, ball in ipairs(balls()) do
			ensurePrompt(ball)
			watchBounce(ball)
			if held[ball] then
				setPromptEnabled(ball, false)
			end
		end
		local model = Workspace:FindFirstChild(COURT_MODEL)
		local anchors = model and model:FindFirstChild("Anchors")
		if anchors then
			for _, part in ipairs(anchors:GetChildren()) do
				if string.sub(part.Name, 1, 8) == "RimScore" and not watchedRims[part] then
					watchedRims[part] = true
					watchRim(part)
				end
			end
			for part in pairs(watchedRims) do
				if not part.Parent then
					watchedRims[part] = nil
				end
			end
		end
		for ball in pairs(mode) do
			if not ball.Parent then
				mode[ball] = nil
				lockout[ball] = nil
				lastScore[ball] = nil
				lastClank[ball] = nil
				lastBounce[ball] = nil
				bounceHook[ball] = nil
				dribbling[ball] = nil
			end
		end
		local now = os.clock()
		for ball, untilTime in pairs(dunkNoScore) do
			if not ball.Parent or now > untilTime then
				dunkNoScore[ball] = nil
			end
		end
		for ball in pairs(dunkBusy) do
			if not ball.Parent then
				dunkBusy[ball] = nil
			end
		end
		for ball in pairs(trickBall) do
			if not ball.Parent then
				trickBall[ball] = nil
			end
		end
		task.wait(1)
	end
end)
