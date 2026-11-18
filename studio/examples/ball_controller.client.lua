--!nonstrict
-- BallController — input and HUD for grab / shoot / dribble / reset.
--
-- The client sends intent only; BallService (ServerScriptService) validates and
-- owns every ball. Keys:
--   E        pick up (ProximityPrompt on the ball, or walk over it)
--   F        hold to charge, release to shoot
--   V        dunk
--   Q        dribble toggle (walking dribbles automatically; Q catches)
--   R        reset both balls to their build spot
--   C        block / steal
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
local DefendRemote = remotes:WaitForChild("Defend")
local Feedback = remotes:WaitForChild("Feedback")
local cocoaRemotes = ReplicatedStorage:WaitForChild("CocoaRemotes", 10)
local WatchGame = cocoaRemotes and cocoaRemotes:FindFirstChild("WatchGame")
local FireSnowball = cocoaRemotes and cocoaRemotes:FindFirstChild("FireSnowball", 10)
local DunkRemote = remotes:WaitForChild("Dunk", 10)
local DunkFeedback = remotes:WaitForChild("DunkFeedback", 10)
local Candy = require(ReplicatedStorage:WaitForChild("CandyUI", 10))

local CHARGE_SECONDS = 1.1

-- -------------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "BallHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local walletPanel = Candy.bubble(gui, "WalletBubble", UDim2.fromOffset(360, 60),
	UDim2.new(1, -16, 0, 14), Vector2.new(1, 0), Candy.RED)
local wallet = Candy.text(walletPanel, "Wallet", "COCOA BUCKS  0", UDim2.fromScale(0.92, 0.78), 28, Candy.DARK)

local scorePanel = Candy.bubble(gui, "ScoreBubble", UDim2.fromOffset(320, 76),
	UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0), Candy.PINK)
local score = Candy.text(scorePanel, "Score", "0 pts", UDim2.fromScale(0.92, 0.8), 52, Candy.RED)

local hintPanel = Candy.bubble(gui, "HintBubble", UDim2.fromOffset(1120, 62),
	UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1), Candy.MINT)
local hint = Candy.text(hintPanel, "Hints",
	"E  pick up   ·   F  shoot   ·   V  dunk   ·   Q  dribble   ·   C  block/steal   ·   R  reset",
	UDim2.fromScale(0.96, 0.78), 26, Candy.DARK)

local flashPanel = Candy.bubble(gui, "FlashBubble", UDim2.fromOffset(840, 112),
	UDim2.new(0.5, 0, 0.34, 0), Vector2.new(0.5, 0.5), Candy.GOLD)
local flash = Candy.text(flashPanel, "Flash", "", UDim2.fromScale(0.94, 0.78), 64, Candy.RED)
flash.TextTransparency = 1
Candy.show(flashPanel, false)

local chargePanel = Candy.bubble(gui, "ChargeBubble", UDim2.fromOffset(340, 30),
	UDim2.new(0.5, 0, 1, -86), Vector2.new(0.5, 1), Candy.RED)
local chargeBack = Instance.new("Frame")
chargeBack.Name = "ChargeTrack"
chargeBack.AnchorPoint = Vector2.new(0.5, 0.5)
chargeBack.Position = UDim2.fromScale(0.5, 0.5)
chargeBack.Size = UDim2.new(1, -8, 1, -8)
chargeBack.BackgroundColor3 = Color3.fromRGB(70, 30, 42)
chargeBack.BackgroundTransparency = 0.35
chargeBack.BorderSizePixel = 0
chargeBack.Visible = false
chargeBack.Parent = chargePanel
Candy.corner(chargeBack, 8)

local chargeFill = Instance.new("Frame")
chargeFill.Name = "Fill"
chargeFill.Size = UDim2.fromScale(0, 1)
chargeFill.BackgroundColor3 = Candy.RED
chargeFill.BorderSizePixel = 0
chargeFill.Parent = chargeBack
Candy.corner(chargeFill, 8)

-- Touch / on-screen fire button. Appears whenever the Snowball Gun is owned,
-- so players without a mouse can fire with a tap.
local snowPanel = Candy.bubble(gui, "SnowButtonBubble", UDim2.fromOffset(230, 82),
	UDim2.new(1, -18, 1, -104), Vector2.new(1, 1), Candy.MINT)
local snowButton = Instance.new("TextButton")
snowButton.Name = "SnowballFire"
snowButton.AnchorPoint = Vector2.new(0.5, 0.5)
snowButton.Position = UDim2.fromScale(0.5, 0.44)
snowButton.Size = UDim2.fromScale(0.94, 0.76)
snowButton.BackgroundTransparency = 1
snowButton.Font = Candy.FONT
snowButton.TextSize = 32
snowButton.Text = "❄ FIRE"
snowButton.TextColor3 = Candy.RED
snowButton.TextStrokeTransparency = 0.9
snowButton.Parent = snowPanel
Candy.show(snowPanel, false)
if FireSnowball then
	snowButton.MouseButton1Click:Connect(function()
		FireSnowball:FireServer()
	end)
end

local function hasSnowGun()
	local backpack = player:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild("Snowball Gun") then
		return true
	end
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Snowball Gun") ~= nil
end

local function refreshSnowButton()
	Candy.show(snowPanel, hasSnowGun())
end

local function watchSnowGun()
	refreshSnowButton()
	local function watchContainer(container)
		if not container then
			return
		end
		container.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Snowball Gun" then
				refreshSnowButton()
			end
		end)
		container.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Snowball Gun" then
				refreshSnowButton()
			end
		end)
	end
	watchContainer(player:FindFirstChild("Backpack"))
	watchContainer(player.Character)
end
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	watchSnowGun()
end)
watchSnowGun()

-- ------------------------------------------------------------------ state

local holding = false
local charging = false
local charge = 0

local function refreshHolding()
	holding = player:GetAttribute("HoldingBall") == true
	local dribbling = player:GetAttribute("Dribbling") == true
	if dribbling then
		hint.Text = "F  shoot   ·   V  dunk   ·   Q  catch   ·   C  block/steal   ·   R  reset"
	elseif holding then
		hint.Text = "walk to dribble   ·   F  shoot   ·   V  dunk   ·   Q  catch   ·   C  block/steal   ·   R  reset"
	else
		hint.Text = "E  pick up   ·   F  shoot   ·   V  dunk   ·   Q  dribble   ·   C  block/steal   ·   R  reset"
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
		chargeFill.Size = UDim2.fromScale(0, 1)
		player:SetAttribute("Charging", false)
	end
end)
player:GetAttributeChangedSignal("Score"):Connect(refreshScore)
player:GetAttributeChangedSignal("Dribbling"):Connect(refreshHolding)
refreshHolding()
refreshScore()

local function refreshWallet()
	wallet.Text = "COCOA BUCKS  " .. tostring(player:GetAttribute("CocoaBucks") or 0)
end
refreshWallet()
player:GetAttributeChangedSignal("CocoaBucks"):Connect(refreshWallet)

-- ------------------------------------------------------------------ input

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		ResetRemote:FireServer()
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		DefendRemote:FireServer()
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		-- Dunk works from a held ball or a live dribble; the server validates.
		if DunkRemote then
			DunkRemote:FireServer()
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		-- Keyboard alternative to left-click for firing the snowball gun.
		if FireSnowball then
			FireSnowball:FireServer()
		end
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
		chargeFill.Size = UDim2.fromScale(0, 1)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not charging then
		return
	end
	charge = math.min(1, charge + dt / CHARGE_SECONDS)
	chargeFill.Size = UDim2.fromScale(charge, 1)
end)

-- --------------------------------------------------------------- feedback

local flashToken = 0
local function showFlash(text, color)
	flashToken += 1
	local token = flashToken
	flash.Text = text
	flash.TextColor3 = color
	flash.TextTransparency = 0
	Candy.show(flashPanel, true)
	task.spawn(function()
		for step = 1, 30 do
			if token ~= flashToken then
				Candy.show(flashPanel, false)
				return
			end
			local alpha = step / 30
			flash.TextTransparency = alpha
			task.wait(0.03)
		end
		Candy.show(flashPanel, false)
	end)
end

Feedback.OnClientEvent:Connect(function(scorer, points)
	local who = scorer and scorer.Name or "Someone"
	local mine = scorer == player
	local label = string.format("%s%d", points == 3 and "3PT! +" or "SWISH +", points)
	showFlash(mine and label or (who .. "  +" .. points), mine and Candy.GOLD or Color3.fromRGB(180, 200, 220))
end)

if DunkFeedback then
	DunkFeedback.OnClientEvent:Connect(function(message)
		showFlash(message, Candy.GOLD)
	end)
end

-- Spectator deck: hold a scriptable view of the street court for a while.
local watching = false
if WatchGame then
WatchGame.OnClientEvent:Connect(function()
	if watching then
		return
	end
	watching = true
	local camera = Workspace.CurrentCamera
	if not camera then
		watching = false
		return
	end
	local previousType = camera.CameraType
	local previousCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(92, 34, 62) * CFrame.Angles(math.rad(-24), math.rad(0), 0)
	task.delay(12, function()
		camera.CameraType = previousType
		camera.CFrame = previousCFrame
		watching = false
	end)
end)
end
