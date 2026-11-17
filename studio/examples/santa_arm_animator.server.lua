--!nonstrict
-- Keeps every Hoops Santa's arms and legs alive. The generated rigs use
-- AnimationConstraints, so limbs cannot be posed from Luau; they need real
-- animation tracks on the Animator. If a track is missing or gets stopped, the
-- Santa freezes in a stiff pose, so this script owns the walk/idle tracks for
-- both the street defenders and the Santa-court roster and re-attaches to any
-- model that appears later.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WALK_ID = "rbxassetid://507777826"
local IDLE_ID = "rbxassetid://507766666"

local RIGS = { "StreetDefenders", "HoopsMas_Santas" }
local states = {} -- [model] = { walk, idle, root, moving, last }

local function load(animator, id)
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		return track
	end
	return nil
end

local function attach(model)
	if states[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Take ownership cleanly: a stray stopped track would leave the rig stiff.
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	local idle = load(animator, IDLE_ID)
	local walk = load(animator, WALK_ID)
	if idle then
		idle:Play(0.1)
		idle:AdjustWeight(1, 0)
	end
	if walk then
		walk:Play(0.1)
		walk:AdjustWeight(0, 0)
	end
	if not idle and not walk then
		return
	end

	states[model] = {
		idle = idle,
		walk = walk,
		root = root,
		moving = false,
		last = root.Position,
	}
end

local function scan()
	for _, folderName in ipairs(RIGS) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					attach(model)
				end
			end
		end
	end
end

-- A freshly spawned generated rig is still settling during its first couple
-- of seconds; tracks loaded then can silently refuse to play. Wait before the
-- first attach, and keep retrying any rig whose Animator ends up with none.
local function ensure()
	scan()
	for model, state in pairs(states) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator and #animator:GetPlayingAnimationTracks() == 0 then
			states[model] = nil
			attach(model)
		end
	end
end

task.delay(2, function()
	ensure()
	while true do
		task.wait(1)
		ensure()
	end
end)

local tick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < tick then
		return
	end
	tick = now + 0.15
	for model, state in pairs(states) do
		local root = state.root
		if not (root and root.Parent) then
			states[model] = nil
			continue
		end
		local position = root.Position
		local dx = position.X - state.last.X
		local dz = position.Z - state.last.Z
		state.last = position
		local moving = (dx * dx + dz * dz) > 0.04
		if moving ~= state.moving then
			state.moving = moving
			if state.walk then
				state.walk:AdjustWeight(moving and 1 or 0, 0.18)
			end
			if state.idle then
				state.idle:AdjustWeight(moving and 0 or 1, 0.18)
			end
		end
	end
end)
