--!nonstrict
-- Athletic rig motion for the Hoops Santas. Their generated rigs are held
-- together by BallSocketConstraints, so directly rotating a limb is undone by
-- physics on the next step. What does work is the Animator's tracks plus a
-- small whole-model pose applied through PivotTo every frame.
--
-- attach(model) returns a small state object; swipe(state, direction) makes
-- that character lunge at the ball. Call attach once per Santa from any server
-- script -- StreetDefense and SantaGame both use it.

local RunService = game:GetService("RunService")

local module = {}
module.__index = module

local WALK_ID = "507777826"
local IDLE_ID = "507766666"

local function loadTrack(animator, id)
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		return track
	end
	return nil
end

function module.attach(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		-- The repurposed stray Santa shipped without one; the R15 tracks still
		-- drive its constraint rig once an Animator is present.
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local state = setmetatable({
		model = model,
		root = root,
		walk = loadTrack(animator, WALK_ID),
		idle = loadTrack(animator, IDLE_ID),
		moving = false,
		baseHip = humanoid.HipHeight,
		lastPosition = root.Position,
		lastOffset = CFrame.identity,
		swipeUntil = 0,
		swipeDir = Vector3.new(0, 0, 1),
	}, module)

	-- Both tracks are started once and cross-faded by weight; repeatedly
	-- calling Play/Stop on these constraint rigs leaves stale duplicate tracks.
	-- MoveDirection is unreliable here, so movement uses actual displacement.
	if state.idle then
		state.idle:Play()
	end
	if state.walk then
		state.walk:Play()
		state.walk:AdjustWeight(0, 0)
	end

	local tick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < tick then
			return
		end
		tick = now + 1 / 30

		local position = state.root.Position
		local speed = (Vector3.new(position.X, 0, position.Z) - Vector3.new(state.lastPosition.X, 0, state.lastPosition.Z)).Magnitude / 0.033
		state.lastPosition = position
		local moving = speed > 2.5
		if moving ~= state.moving then
			state.moving = moving
			if state.walk then
				state.walk:AdjustWeight(moving and 1 or 0, 0.15)
			end
			if state.idle then
				state.idle:AdjustWeight(moving and 0 or 1, 0.15)
			end
		end

		-- Strip off last frame's pose so the Humanoid's own movement isn't
		-- overwritten, then apply a fresh crouch / run lean / lunge.
		local current = state.model:GetPivot()
		local natural = current * state.lastOffset:Inverse()
		local crouch = moving and 0.25 or 0.5
		-- HipHeight actually compresses the leg rig, unlike rotating a limb,
		-- which the BallSocketConstraints undo on the next physics step.
		humanoid.HipHeight = state.baseHip - crouch
		local lean = moving and 13 or 8
		local bob = math.sin(now * (moving and 11 or 2.4)) * (moving and 0.16 or 0.06)
		local forward = 0
		local yaw = 0

		if now < state.swipeUntil then
			local progress = 1 - (state.swipeUntil - now) / 0.45
			forward = math.sin(progress * math.pi) * 1.7
			lean = lean + 16
			local dir = state.swipeDir
			if dir.Magnitude > 0.01 then
				yaw = math.deg(math.atan2(dir.X, -dir.Z))
			end
		end

		local offset = CFrame.new(0, bob - crouch, -forward)
			* CFrame.Angles(math.rad(-lean), math.rad(yaw), 0)
		state.model:PivotTo(natural * offset)
		state.lastOffset = offset
	end)

	return state
end

function module.swipe(state, direction)
	if not state then
		return
	end
	state.swipeUntil = os.clock() + 0.45
	local dir = direction and Vector3.new(direction.X, 0, direction.Z) or state.root.CFrame.LookVector
	if dir.Magnitude < 0.01 then
		dir = state.root.CFrame.LookVector
	end
	dir = dir.Unit
	state.swipeDir = dir

	-- A brief pale arc from the lead hand reads as the swipe even though the
	-- constraint rig can't hold a manually posed arm.
	local hand = state.model:FindFirstChild("RightHand")
	if not hand then
		return
	end
	local start = hand.Position
	local arc = Instance.new("Part")
	arc.Name = "SwipeArc"
	arc.Shape = Enum.PartType.Ball
	arc.Size = Vector3.new(1.6, 0.5, 2.6)
	arc.Color = Color3.new(1, 1, 1)
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.4
	arc.CanCollide = false
	arc.CanTouch = false
	arc.CanQuery = false
	arc.CFrame = CFrame.new(start + dir * 0.6, start + dir * 3)
	arc.Parent = workspace
	task.spawn(function()
		for i = 1, 6 do
			task.wait(0.045)
			if not arc.Parent then
				return
			end
			local t = i / 6
			arc.CFrame = CFrame.new(start + dir * (0.6 + t * 2.6), start + dir * (3 + t * 2.6))
			arc.Transparency = 0.4 + t * 0.6
		end
		arc:Destroy()
	end)
end

return module
