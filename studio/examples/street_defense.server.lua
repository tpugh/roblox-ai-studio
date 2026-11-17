--!nonstrict
-- StreetDefense — two Hoops Santas guard the player's court. They sag between
-- the ball handler and the rim, contest shots, and can strip a careless
-- dribble. A stolen ball is carried briefly, then passed back into play so the
-- player can use C to steal it back. All ball state changes go through
-- BallService's DefenseCommand, so this never fights the shooter logic.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("BallRemotes", 10)
local command = remotes and remotes:WaitForChild("DefenseCommand", 10)
local roster = Workspace:WaitForChild("StreetDefenders", 10)
local court = Workspace:WaitForChild("StreetBasketballCourt", 10)
if not command or not roster or not court then
	warn("[StreetDefense] remotes, defenders or court missing")
	return
end

local anchors = court:WaitForChild("Anchors")
local rims = {}
for _, part in ipairs(anchors:GetChildren()) do
	if string.sub(part.Name, 1, 8) == "RimScore" then
		table.insert(rims, part)
	end
end
if #rims == 0 then
	warn("[StreetDefense] no rim anchors")
	return
end

local CONTEST_RANGE = 5.5
local CONTEST_SECONDS = 0.5
local STEAL_RANGE = 5.0
local STEAL_CHANCE = 0.28
local GRAB_RANGE = 2.4
local CARRY_SECONDS = 3.2
local GROUND_Y = 0.4

local defenders = {}
for index, model in ipairs(roster:GetChildren()) do
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		humanoid.WalkSpeed = 16
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local function track(id)
			if not animator then
				return nil
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. id
			local t = animator:LoadAnimation(animation)
			t.Looped = true
			return t
		end
		table.insert(defenders, {
			name = model.Name,
			root = root,
			humanoid = humanoid,
			side = index % 2 == 1 and -1 or 1,
			stealReady = os.clock() + 4 + math.random() * 4,
			chasing = 0,
			carryUntil = 0,
			walk = track("507777826"),
			idle = track("507766666"),
			moving = false,
			target = nil,
			movedAt = 0,
		})
	end
end
if #defenders == 0 then
	warn("[StreetDefense] no defenders in StreetDefenders")
	return
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function unit(v)
	local f = flat(v)
	if f.Magnitude < 0.01 then
		return Vector3.new(0, 0, 1)
	end
	return f.Unit
end

local function moveTo(def, point)
	local now = os.clock()
	if def.target and (def.target - point).Magnitude < 2 and now - def.movedAt < 0.6 then
		return
	end
	def.target = point
	def.movedAt = now
	def.humanoid:MoveTo(point)
end

local function nearestRim(position)
	local best, distance
	for _, rim in ipairs(rims) do
		local d = flat(rim.Position - position).Magnitude
		if not distance or d < distance then
			best, distance = rim, d
		end
	end
	return best and best.Position or Vector3.new(39, 0, -4)
end

local function guardSpot(def, carrier, rim)
	local toward = unit(rim - carrier)
	local side = Vector3.new(-toward.Z, 0, toward.X) * def.side
	return Vector3.new(carrier.X, GROUND_Y, carrier.Z) + toward * 1.8 + side * 1.2
end

local function nearestPlayer(position)
	local Players = game:GetService("Players")
	local best, distance
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = flat(root.Position - position).Magnitude
			if not distance or d < distance then
				best, distance = root, d
			end
		end
	end
	return best
end

-- Nobody asked for a frozen crowd: keep the guards' walk/idle tracks in sync.
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, def in ipairs(defenders) do
			local moving = def.humanoid.MoveDirection.Magnitude > 0.1
			if moving ~= def.moving then
				def.moving = moving
				if moving then
					if def.walk then
						def.walk:Play(0.15)
					end
					if def.idle then
						def.idle:Stop(0.25)
					end
				else
					if def.walk then
						def.walk:Stop(0.25)
					end
					if def.idle then
						def.idle:Play(0.25)
					end
				end
			end
		end
	end
end)

local function byName(name)
	for _, def in ipairs(defenders) do
		if def.name == name then
			return def
		end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.15)
		local ball, holder, kind = command:Invoke("carrier")
		if not ball then
			continue
		end
		local now = os.clock()

		if kind == "npc" then
			local carrier = byName(ball:GetAttribute("HeldByNPC"))
			if not carrier then
				continue
			end
			if now < carrier.carryUntil then
				-- Dribble away from the nearest player and keep the ball at hand.
				local target = nearestPlayer(carrier.root.Position)
				local away = target and unit(carrier.root.Position - target.Position) or unit(Vector3.new(1, 0, 0))
				local spot = carrier.root.Position + away * 8
				moveTo(carrier, Vector3.new(spot.X, GROUND_Y, spot.Z))
				local look = unit(carrier.root.CFrame.LookVector)
				ball.CFrame = CFrame.new(carrier.root.Position + look * 1.4 + Vector3.new(0, -0.55, 0))
			else
				local target = nearestPlayer(carrier.root.Position)
				local toward = target and flat(target.Position - carrier.root.Position) or flat(Vector3.new(39, 0, -4) - carrier.root.Position)
				command:Invoke("releaseNPC", ball, toward, 13)
				carrier.carryUntil = 0
			end
			continue
		end

		if kind == "held" or kind == "dribble" then
			local character = holder and holder.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			local rim = nearestRim(root.Position)
			for _, def in ipairs(defenders) do
				moveTo(def, guardSpot(def, root.Position, rim))
				local gap = flat(def.root.Position - root.Position).Magnitude
				if gap < CONTEST_RANGE then
					command:Invoke("contest", ball, CONTEST_SECONDS)
				end
				if gap < STEAL_RANGE and now > def.stealReady and math.random() < STEAL_CHANCE then
					def.stealReady = now + 4 + math.random() * 4
					local knock = flat(def.root.Position - ball.Position)
					if knock.Magnitude > 0.01 then
						command:Invoke("knockLoose", ball, knock, 17)
						def.chasing = now + 3
					end
				end
			end
			continue
		end

		-- Loose ball: whichever guard claimed it goes after it and picks it up.
		local chaser
		for _, def in ipairs(defenders) do
			if def.chasing > now then
				chaser = def
				break
			end
		end
		if chaser then
			moveTo(chaser, ball.Position)
			if flat(chaser.root.Position - ball.Position).Magnitude < GRAB_RANGE and ball.Position.Y < 4.5 then
				if command:Invoke("holdByNPC", ball, chaser.name) then
					chaser.carryUntil = now + CARRY_SECONDS
					chaser.chasing = 0
				end
			end
		else
			local centre = Vector3.new(39, GROUND_Y, -4)
			for _, def in ipairs(defenders) do
				moveTo(def, centre + Vector3.new(def.side * 9, 0, 0))
			end
		end
	end
end)
