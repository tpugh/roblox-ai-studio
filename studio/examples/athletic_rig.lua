--!nonstrict
-- Athletic rig motion for the Hoops Santas. Their generated rigs are held
-- together by BallSocketConstraints, so trying to pose a limb or nudge the
-- whole model every frame fights the Humanoid and makes them hop in place.
-- What works reliably is the Animator's own tracks, cross-faded by real
-- movement, plus a short visual arc when a defender goes for a steal.
--
-- attach(model) returns a small state object; swipe(state, direction) makes
-- that character flash a swipe arc. Both StreetDefense and SantaGame use it.

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
		lastPosition = root.Position,
	}, module)

	-- Both tracks are started once and cross-faded by weight. MoveDirection is
	-- unreliable on these rigs, so movement uses actual displacement.
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
		tick = now + 0.15

		local position = state.root.Position
		local moved = Vector3.new(position.X - state.lastPosition.X, 0, position.Z - state.lastPosition.Z).Magnitude
		state.lastPosition = position
		local moving = moved > 0.2
		if moving ~= state.moving then
			state.moving = moving
			if state.walk then
				state.walk:AdjustWeight(moving and 1 or 0, 0.18)
			end
			if state.idle then
				state.idle:AdjustWeight(moving and 0 or 1, 0.18)
			end
		end
	end)

	return state
end

function module.swipe(state, direction)
	if not state then
		return
	end
	local dir = direction and Vector3.new(direction.X, 0, direction.Z) or state.root.CFrame.LookVector
	if dir.Magnitude < 0.01 then
		dir = state.root.CFrame.LookVector
	end
	dir = dir.Unit

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
