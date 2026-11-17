--!nonstrict
-- Elf Ball Crew — keeps the street court stocked with basketballs.
--
-- The rack holds spares and three tiny referee elves ferry balls onto the
-- court whenever the player count calls for more. Target is one ball per two
-- players (at least two, at most six), so the court always keeps a 50%+ ball
-- ratio. Elves whistle on delivery, retire idle extras back to the rack, and
-- hop in celebration when someone scores.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local station = Workspace:FindFirstChild("ElfBallCrew")
local court = Workspace:FindFirstChild("StreetBasketballCourt")
if not station or not court then
	warn("[ElfCrew] crew station or court is missing")
	return
end
local props = court:FindFirstChild("Props")
local sign = station:FindFirstChild("SignAnchor")
local status = sign and sign:FindFirstChild("CrewSign")
status = status and status:FindFirstChild("Status")
if not props then
	warn("[ElfCrew] court props are missing")
	return
end

local RACK = Vector3.new(12, 0, 10)
local DROPS = {
	Vector3.new(29, 0.82, -8),
	Vector3.new(49, 0.82, 8),
	Vector3.new(39, 0.82, 14),
	Vector3.new(24, 0.82, 16),
	Vector3.new(54, 0.82, -14),
	Vector3.new(39, 0.82, -16),
}
local MIN_BALLS = 2
local MAX_BALLS = 6
local WHISTLE_ID = "rbxassetid://124140408144336" -- borrowed one-shot, pitched up

local elves = {}
for _, model in ipairs(station:GetChildren()) do
	if model:GetAttribute("Elf") then
		table.insert(elves, {
			model = model,
			home = model:GetPivot(),
			busy = false,
		})
	end
end
if #elves == 0 then
	warn("[ElfCrew] no elves at the station")
	return
end

local function ballCount()
	local n = 0
	for _, child in ipairs(props:GetChildren()) do
		if child.Name == "Basketball" and child:IsA("BasePart") then
			n = n + 1
		end
	end
	return n
end

local function targetCount()
	local players = #Players:GetPlayers()
	return math.clamp(math.max(MIN_BALLS, math.ceil(players / 2)), MIN_BALLS, MAX_BALLS)
end

local function updateSign()
	if status then
		status.Text = string.format("ELF BALL CREW  ·  BALLS ON COURT %d / %d", ballCount(), targetCount())
	end
end

local function chirp(elf, pitch)
	if not elf then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "ElfWhistle"
	sound.SoundId = WHISTLE_ID
	sound.Volume = 0.38
	sound.PlaybackSpeed = pitch or 2.4
	sound.Parent = elf.model
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(1.5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function moveElf(elf, goal, seconds)
	local model = elf.model
	local from = model:GetPivot().Position
	local started = os.clock()
	local duration = math.max(0.1, seconds)
	while true do
		local t = (os.clock() - started) / duration
		if t >= 1 then
			break
		end
		local pos = from:Lerp(goal, t)
		local dir = goal - from
		local yaw = math.atan2(dir.X, dir.Z)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
		task.wait(1 / 30)
	end
	model:PivotTo(CFrame.new(goal))
end

local function freeElf()
	for _, elf in ipairs(elves) do
		if not elf.busy then
			return elf
		end
	end
	return nil
end

local function makeBall(position)
	local ball = Instance.new("Part")
	ball.Name = "Basketball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.Color = Color3.fromRGB(212, 108, 44)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.5, 0.2, 1, 1)
	ball.CFrame = CFrame.new(position)
	ball:SetAttribute("HomeCFrame", CFrame.new(position))
	ball.Parent = props
	return ball
end

local function deliver(elf)
	elf.busy = true
	local index = ballCount() + 1
	local spot = DROPS[((index - 1) % #DROPS) + 1]
	local ball = makeBall(RACK + Vector3.new(0, 2, 0))
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false

	chirp(elf, 2.6)
	moveElf(elf, RACK + Vector3.new(0, 0, 3.5), 0.5)
	moveElf(elf, spot - Vector3.new(0, 0, 3), 1.8)
	-- Carry the spare at the elf's shoulder during the run.
	local carrying = task.spawn(function()
		while ball.Parent and ball.Anchored do
			ball.CFrame = elf.model:GetPivot() * CFrame.new(0, 2.1, 1)
			task.wait(1 / 30)
		end
	end)

	ball.CFrame = CFrame.new(spot)
	ball.Anchored = false
	ball.CanCollide = true
	ball.CanTouch = true
	ball.AssemblyLinearVelocity = Vector3.new(0, 3, 0)
	ball:SetAttribute("HomeCFrame", CFrame.new(spot))
	task.cancel(carrying)
	chirp(elf, 2.1)
	moveElf(elf, elf.home.Position, 1.2)
	elf.model:PivotTo(elf.home)
	elf.busy = false
	updateSign()
end

local function retire(elf, ball)
	elf.busy = true
	ball:SetAttribute("Retiring", true)
	ball.Anchored = true
	ball.CanCollide = false
	moveElf(elf, ball.Position + Vector3.new(0, 0, -2), 1.2)
	moveElf(elf, RACK + Vector3.new(0, 0, 3.5), 1.4)
	ball:Destroy()
	elf.model:PivotTo(elf.home)
	elf.busy = false
	updateSign()
end

local idleSince = {} -- [ball] = os.clock() when it stopped moving

local function manage()
	local target = targetCount()
	local count = ballCount()
	if count < target then
		local elf = freeElf()
		if elf then
			task.spawn(function()
				deliver(elf)
			end)
		end
	elseif count > target then
		local spare
		for _, ball in ipairs(props:GetChildren()) do
			if ball.Name == "Basketball" and ball:IsA("BasePart") and not ball:GetAttribute("Retiring")
				and not ball:GetAttribute("HeldBy") and not ball.Anchored then
				local since = idleSince[ball] or os.clock()
				if ball.AssemblyLinearVelocity.Magnitude < 1.5 then
					if os.clock() - since > 12 then
						spare = ball
						break
					end
				else
					idleSince[ball] = os.clock()
				end
			end
		end
		if spare then
			local elf = freeElf()
			if elf then
				task.spawn(function()
					retire(elf, spare)
				end)
			end
		end
	end
	updateSign()
end

task.spawn(function()
	while true do
		task.wait(2)
		manage()
	end
end)

-- Celebrate buckets with a tiny ref hop and a whistle chirp.
for _, player in ipairs(Players:GetPlayers()) do
	player:GetAttributeChangedSignal("Score"):Connect(function()
		local elf = freeElf()
		if not elf then
			return
		end
		chirp(elf, 3.1)
		local base = elf.home.Position
		task.spawn(function()
			for _ = 1, 3 do
				moveElf(elf, base + Vector3.new(0, 1.1, 0), 0.12)
				moveElf(elf, base, 0.12)
			end
		end)
	end)
end
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("Score"):Connect(function()
		local elf = freeElf()
		if not elf then
			return
		end
		chirp(elf, 3.1)
		local base = elf.home.Position
		task.spawn(function()
			for _ = 1, 3 do
				moveElf(elf, base + Vector3.new(0, 1.1, 0), 0.12)
				moveElf(elf, base, 0.12)
			end
		end)
	end)
end)

updateSign()
