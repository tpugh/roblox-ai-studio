--!nonstrict
-- Makes the X tricks visible. NBAStreetRules fires TrickAnim with the player
-- and the chain step. This drives the character's root through the move and
-- trails a swipe arc with it. Root motion is used deliberately: player avatars
-- use AnimationConstraint joints that cannot be posed from Luau, but the root
-- part is a plain Part, so the whole body can be spun, dipped and cut reliably.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("BallRemotes")
local TrickAnim = remotes:WaitForChild("TrickAnim", 10)

local DURATIONS = { 0.65, 0.75, 0.7, 0.6, 0.82 }

local active = {}

local function pulse(t)
	return math.sin(t * math.pi)
end

local function sparkleAt(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "TrickSparkle"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(root.Position + Vector3.new(0, 1.2, 0))
	holder.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.Parent = holder
	emitter:Emit(24)
	task.delay(1, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- A short neon streak swept through character-local space. It reads as the
-- hand/path of the move even on rigs whose limbs cannot be posed directly.
local function sweep(character, from, to, thickness)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local base = root.CFrame
	local arc = Instance.new("Part")
	arc.Name = "TrickArc"
	arc.Shape = Enum.PartType.Ball
	arc.Size = Vector3.new(thickness, thickness * 0.35, thickness * 1.9)
	arc.Color = Color3.fromRGB(255, 222, 140)
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.4
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.Parent = workspace
	task.spawn(function()
		for i = 1, 12 do
			task.wait(0.035)
			if not arc.Parent then
				return
			end
			local t = i / 12
			local point = base:PointToWorldSpace(from:Lerp(to, t))
			arc.CFrame = CFrame.new(point, base:PointToWorldSpace(to))
			arc.Transparency = 0.4 + t * 0.55
		end
		arc:Destroy()
	end)
end

local function playSweep(character, move)
	if move == 1 then
		sweep(character, Vector3.new(1.3, 1.1, -0.4), Vector3.new(-1.3, 1.1, -0.4), 1.1)
	elseif move == 2 then
		sweep(character, Vector3.new(1.5, 1.1, 0), Vector3.new(-1.5, 1.1, 0), 1.3)
		task.delay(0.12, function()
			sweep(character, Vector3.new(-1.5, 1.1, 0), Vector3.new(1.5, 1.1, 0), 1.3)
		end)
	elseif move == 3 then
		sweep(character, Vector3.new(1.3, 1.1, -0.3), Vector3.new(-1.1, 0.85, 1.1), 1.2)
	elseif move == 4 then
		sweep(character, Vector3.new(1.2, 0.45, -0.3), Vector3.new(-1.2, 0.45, -0.3), 1.0)
	else
		sweep(character, Vector3.new(0.9, 1.1, 0), Vector3.new(0.9, 2.5, 0), 1.2)
	end
end

local function perform(character, move)
	if not character or active[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	local token = {}
	active[character] = token
	sparkleAt(character)
	playSweep(character, move)

	local wasAutoRotate = humanoid.AutoRotate
	local wasAnchored = root.Anchored
	local baseRoot = root.CFrame
	root.Anchored = true
	humanoid.AutoRotate = false

	local duration = DURATIONS[move] or 0.65
	local startedAt = os.clock()
	local connection

	local function restore()
		if root.Parent then
			root.CFrame = baseRoot
			root.Anchored = wasAnchored
		end
		humanoid.AutoRotate = wasAutoRotate
		active[character] = nil
		if connection then
			connection:Disconnect()
		end
	end

	connection = RunService.RenderStepped:Connect(function()
		if active[character] ~= token or not root.Parent then
			restore()
			return
		end
		local t = (os.clock() - startedAt) / duration
		if t >= 1 then
			restore()
			return
		end

		local p = pulse(t)
		local spin = t * math.pi * 2
		local yaw, offset

		if move == 1 then
			-- Crossover: sharp side-to-side cut with the shoulders following.
			yaw = math.sin(spin) * 0.55 * p
			offset = Vector3.new(math.sin(spin) * 0.9 * p, 0.06 * p, 0)
		elseif move == 2 then
			-- Spin: a full 360 with arms/ball tucked around the body.
			yaw = spin
			offset = Vector3.new(0, 0.1 * p, 0)
		elseif move == 3 then
			-- Around the back: torso opens, body leans back into the wrap.
			yaw = -0.8 * p
			offset = Vector3.new(0.45 * p, 0.05 * p, 0.25 * p)
		elseif move == 4 then
			-- Ankle breaker: low dip and a hard lateral cut.
			yaw = math.sin(spin) * 0.45 * p
			offset = Vector3.new(math.sin(spin) * 1.2 * p, -0.45 * p, 0)
		else
			-- Style: a showy hop with a quick shoulder shake.
			yaw = math.sin(t * math.pi * 6) * 0.4 * p
			offset = Vector3.new(0, 0.4 * p, 0)
		end

		root.CFrame = baseRoot * CFrame.Angles(0, yaw, 0) * CFrame.new(offset)
	end)
end

if TrickAnim then
	TrickAnim.OnClientEvent:Connect(function(who, move)
		if not who then
			return
		end
		perform(who.Character or who.character, math.clamp(tonumber(move) or 1, 1, #DURATIONS))
	end)
end
