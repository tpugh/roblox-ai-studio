--!nonstrict
-- BallController — input and HUD for grab / shoot / dribble / reset.
--
-- The client sends intent only; BallService (ServerScriptService) validates and
-- owns every ball. Keys:
--   E        pick up (ProximityPrompt on the ball)
--   F        hold to charge, release to shoot
--   Q        dribble toggle (walking dribbles automatically; Q catches)
--   R        reset both balls to their build spot
--
-- Install as a LocalScript under StarterPlayer/StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BallRemotes")
local ThrowRemote = remotes:WaitForChild("Throw")
local DribbleRemote = remotes:WaitForChild("Dribble")
local ResetRemote = remotes:WaitForChild("ResetBalls")
local Feedback = remotes:WaitForChild("Feedback")

local CHARGE_SECONDS = 1.1

-- -------------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "BallHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Name = "Hints"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -18)
hint.Size = UDim2.new(0, 720, 0, 24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 15
hint.TextColor3 = Color3.fromRGB(235, 235, 240)
hint.TextStrokeTransparency = 0.6
hint.Text = "E  pick up   ·   walk to dribble   ·   Q  dribble/catch   ·   hold F  shoot   ·   R  reset"
hint.Parent = gui

local score = Instance.new("TextLabel")
score.Name = "Score"
score.AnchorPoint = Vector2.new(0.5, 0)
score.Position = UDim2.new(0.5, 0, 0, 14)
score.Size = UDim2.new(0, 220, 0, 30)
score.BackgroundTransparency = 1
score.Font = Enum.Font.GothamBold
score.TextSize = 22
score.TextColor3 = Color3.fromRGB(255, 255, 255)
score.TextStrokeTransparency = 0.5
score.Text = "0 pts"
score.Parent = gui

local flash = Instance.new("TextLabel")
flash.Name = "Flash"
flash.AnchorPoint = Vector2.new(0.5, 0.5)
flash.Position = UDim2.new(0.5, 0, 0.35, 0)
flash.Size = UDim2.new(0, 320, 0, 56)
flash.BackgroundTransparency = 1
flash.Font = Enum.Font.GothamBlack
flash.TextSize = 44
flash.TextColor3 = Color3.fromRGB(255, 196, 64)
flash.TextStrokeTransparency = 0.4
flash.TextTransparency = 1
flash.Text = ""
flash.Parent = gui

local chargeBack = Instance.new("Frame")
chargeBack.Name = "ChargeTrack"
chargeBack.AnchorPoint = Vector2.new(0.5, 1)
chargeBack.Position = UDim2.new(0.5, 0, 1, -48)
chargeBack.Size = UDim2.new(0, 200, 0, 7)
chargeBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
chargeBack.BackgroundTransparency = 0.35
chargeBack.BorderSizePixel = 0
chargeBack.Visible = false
chargeBack.Parent = gui

local chargeFill = Instance.new("Frame")
chargeFill.Name = "Fill"
chargeFill.Size = UDim2.new(0, 0, 1, 0)
chargeFill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
chargeFill.BorderSizePixel = 0
chargeFill.Parent = chargeBack

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = chargeBack

-- ------------------------------------------------------------------ state

local holding = false
local charging = false
local charge = 0

local function refreshHolding()
	holding = player:GetAttribute("HoldingBall") == true
	local dribbling = player:GetAttribute("Dribbling") == true
	if dribbling then
		hint.Text = "hold F  shoot   ·   walk to keep dribbling   ·   Q  catch   ·   R  reset"
	elseif holding then
		hint.Text = "walk to dribble   ·   hold F  shoot   ·   Q  dribble   ·   R  reset"
	else
		hint.Text = "E  pick up   ·   walk to dribble   ·   Q  dribble/catch   ·   hold F  shoot   ·   R  reset"
	end
end

local function refreshScore()
	score.Text = string.format("%d pts", player:GetAttribute("Score") or 0)
end

player:GetAttributeChangedSignal("HoldingBall"):Connect(function()
	refreshHolding()
	if not holding then
		charging = false
		charge = 0
		chargeBack.Visible = false
		chargeFill.Size = UDim2.new(0, 0, 1, 0)
		player:SetAttribute("Charging", false)
	end
end)
player:GetAttributeChangedSignal("Score"):Connect(refreshScore)
player:GetAttributeChangedSignal("Dribbling"):Connect(refreshHolding)
refreshHolding()
refreshScore()

-- ------------------------------------------------------------------ input

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		ResetRemote:FireServer()
		return
	end
	if not holding then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		charging = true
		charge = 0
		chargeBack.Visible = true
		player:SetAttribute("Charging", true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		DribbleRemote:FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F and charging then
		charging = false
		chargeBack.Visible = false
		player:SetAttribute("Charging", false)
		local camera = Workspace.CurrentCamera
		local direction = camera and (camera.CFrame.LookVector + Vector3.new(0, 0.15, 0)) or Vector3.new(0, 0.2, -1)
		ThrowRemote:FireServer(direction, math.clamp(charge, 0, 1))
		charge = 0
		chargeFill.Size = UDim2.new(0, 0, 1, 0)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not charging then
		return
	end
	charge = math.min(1, charge + dt / CHARGE_SECONDS)
	chargeFill.Size = UDim2.new(charge, 0, 1, 0)
end)

-- --------------------------------------------------------------- feedback

local flashToken = 0
local function showFlash(text, color)
	flashToken += 1
	local token = flashToken
	flash.Text = text
	flash.TextColor3 = color
	flash.TextTransparency = 0
	flash.Position = UDim2.new(0.5, 0, 0.35, 0)
	task.spawn(function()
		for step = 1, 30 do
			if token ~= flashToken then
				return
			end
			local alpha = step / 30
			flash.TextTransparency = alpha
			flash.Position = UDim2.new(0.5, 0, 0.35 - 0.06 * alpha, 0)
			task.wait(0.03)
		end
	end)
end

Feedback.OnClientEvent:Connect(function(scorer, points)
	local who = scorer and scorer.Name or "Someone"
	local mine = scorer == player
	local label = string.format("%s%d", points == 3 and "3PT! +" or "SWISH +", points)
	showFlash(mine and label or (who .. "  +" .. points), mine and Color3.fromRGB(255, 196, 64) or Color3.fromRGB(180, 200, 220))
end)
