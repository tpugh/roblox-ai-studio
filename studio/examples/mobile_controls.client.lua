--!nonstrict
-- Touch controls for phones and tablets. Mirrors the keyboard bindings through
-- the exact same remotes, so the server still validates every action. Shown on
-- touch devices (or when the player has the ForceMobileControls attribute).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Candy = require(ReplicatedStorage:WaitForChild("CandyUI", 10))

local ball = ReplicatedStorage:WaitForChild("BallRemotes", 10)
local cocoa = ReplicatedStorage:FindFirstChild("CocoaRemotes")

local function remote(folder, name)
	return folder and folder:FindFirstChild(name) or nil
end

local Throw = remote(ball, "Throw")
local Dribble = remote(ball, "Dribble")
local ResetBalls = remote(ball, "ResetBalls")
local Defend = remote(ball, "Defend")
local Grab = remote(ball, "Grab")
local Dunk = remote(ball, "Dunk")
local Trick = remote(ball, "Trick")
local Gamebreaker = remote(ball, "Gamebreaker")
local MusicMute = ReplicatedStorage:FindFirstChild("MusicMuteToggle", true)
if not MusicMute then
	MusicMute = Instance.new("BindableEvent")
	MusicMute.Name = "MusicMuteToggle"
	MusicMute.Parent = ReplicatedStorage
end

local gui = Instance.new("ScreenGui")
gui.Name = "MobileControls"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = UserInputService.TouchEnabled or player:GetAttribute("ForceMobileControls") == true
gui.Parent = player:WaitForChild("PlayerGui")

player:GetAttributeChangedSignal("ForceMobileControls"):Connect(function()
	gui.Enabled = UserInputService.TouchEnabled or player:GetAttribute("ForceMobileControls") == true
end)

local function button(name, text, size, position, anchor, accent, onTap, onHold)
	local panel = Candy.bubble(gui, name, size, position, anchor, accent)
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.AnchorPoint = Vector2.new(0.5, 0.5)
	tap.Position = UDim2.fromScale(0.5, 0.44)
	tap.Size = UDim2.fromScale(0.94, 0.8)
	tap.BackgroundTransparency = 1
	tap.Font = Candy.FONT
	tap.Text = text
	tap.TextSize = size.Y.Offset > 90 and 30 or 21
	tap.TextColor3 = Candy.DARK
	tap.TextStrokeTransparency = 0.9
	tap.Parent = panel

	tap.MouseButton1Click:Connect(function()
		if onTap then
			onTap()
		end
	end)
	if onHold then
		tap.MouseButton1Down:Connect(function()
			onHold(true)
		end)
		tap.MouseButton1Up:Connect(function()
			onHold(false)
		end)
		tap.MouseLeave:Connect(function()
			onHold(false)
		end)
	end
	return panel
end

-- Shooting: hold to charge, release to fire, exactly like the F key.
local charging = false
local charge = 0
local CHARGE_SECONDS = 1.1

local function setCharging(on)
	if on == charging then
		return
	end
	charging = on
	player:SetAttribute("Charging", on)
	if not on then
		local camera = Workspace.CurrentCamera
		local direction = camera and (camera.CFrame.LookVector + Vector3.new(0, 0.15, 0)) or Vector3.new(0, 0.2, -1)
		if Throw then
			Throw:FireServer(direction, math.clamp(charge, 0, 1))
		end
		charge = 0
	end
end

RunService.RenderStepped:Connect(function(dt)
	if charging then
		charge = math.min(1, charge + dt / CHARGE_SECONDS)
	end
end)

player:GetAttributeChangedSignal("HoldingBall"):Connect(function()
	if player:GetAttribute("HoldingBall") ~= true then
		charging = false
		charge = 0
		player:SetAttribute("Charging", false)
	end
end)

local turboOn = false
local function setTurbo(on)
	turboOn = on
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = on and 26 or 16
	end
end
player.CharacterAdded:Connect(function()
	if turboOn then
		task.wait(0.25)
		setTurbo(true)
	end
end)

local function grabNearest()
	local props = Workspace:FindFirstChild("StreetBasketballCourt")
	props = props and props:FindFirstChild("Props")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (Grab and props and root) then
		return
	end
	local best, bestDistance
	for _, part in ipairs(props:GetChildren()) do
		if part:IsA("BasePart") and part.Name == "Basketball" then
			local distance = (part.Position - root.Position).Magnitude
			if not bestDistance or distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	if best and bestDistance <= 9 then
		Grab:FireServer(best)
	end
end

-- Right thumb cluster: the main actions.
button("MobileShoot", "SHOOT", UDim2.fromOffset(148, 112), UDim2.new(1, -18, 1, -200), Vector2.new(1, 1),
	Candy.PINK, nil, setCharging)
button("MobileDunk", "DUNK", UDim2.fromOffset(132, 56), UDim2.new(1, -18, 1, -322), Vector2.new(1, 1),
	Candy.RED, function()
		if Dunk then Dunk:FireServer() end
	end)
button("MobileTrick", "TRICK", UDim2.fromOffset(132, 56), UDim2.new(1, -18, 1, -384), Vector2.new(1, 1),
	Candy.MINT, function()
		if Trick then Trick:FireServer() end
	end)
button("MobileSteal", "STEAL", UDim2.fromOffset(132, 56), UDim2.new(1, -18, 1, -446), Vector2.new(1, 1),
	Candy.GOLD, function()
		if Defend then Defend:FireServer() end
	end)

-- Left thumb cluster: movement / support actions.
button("MobileBreaker", "GAME BREAKER", UDim2.fromOffset(168, 54), UDim2.new(0, 18, 1, -206), Vector2.new(0, 1),
	Candy.GOLD, function()
		if Gamebreaker then Gamebreaker:FireServer() end
	end)
button("MobileTurbo", "TURBO", UDim2.fromOffset(128, 52), UDim2.new(0, 18, 1, -266), Vector2.new(0, 1),
	Candy.MINT, nil, setTurbo)
button("MobileDribble", "DRIBBLE", UDim2.fromOffset(128, 52), UDim2.new(0, 18, 1, -324), Vector2.new(0, 1),
	Candy.PINK, function()
		if Dribble then Dribble:FireServer() end
	end)
button("MobileGrab", "PICK UP", UDim2.fromOffset(128, 52), UDim2.new(0, 18, 1, -382), Vector2.new(0, 1),
	Candy.RED, grabNearest)
button("MobileReset", "RESET", UDim2.fromOffset(128, 52), UDim2.new(0, 18, 1, -440), Vector2.new(0, 1),
	Candy.MINT, function()
		if ResetBalls then ResetBalls:FireServer() end
	end)
button("MobileMute", "MUSIC", UDim2.fromOffset(96, 44), UDim2.new(0, 18, 1, -498), Vector2.new(0, 1),
	Candy.GOLD, function()
		if MusicMute then
			MusicMute:Fire()
		end
	end)
