--!nonstrict
-- NBAStreetHUD — Gamebreaker meter, trick chains, street scoreboard, turbo.
--
-- Companion to nba_street_rules.server.lua. Keys:
--   X          trick (only works while dribbling; chains raise the multiplier)
--   G          unleash the Gamebreaker when the meter is full
--   LeftShift  turbo sprint
--
-- Install as a LocalScript under StarterPlayer/StarterPlayerScripts, next to
-- BallController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BallRemotes")
local TrickRemote = remotes:WaitForChild("Trick")
local GamebreakerRemote = remotes:WaitForChild("Gamebreaker")
local StreetEvent = remotes:WaitForChild("StreetEvent")
local Candy = require(ReplicatedStorage:WaitForChild("CandyUI", 10))

local BASE_SPEED = 16
local TURBO_SPEED = 26
local WIN_SCORE = 21

-- -------------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "StreetHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local boardPanel = Candy.bubble(gui, "ScoreboardBubble", UDim2.fromOffset(480, 104),
	UDim2.new(0, 18, 0, 16), Vector2.new(0, 0), Candy.RED)
local board = Candy.text(boardPanel, "Scoreboard", "STREET · TO 21\nYOU 0   ·   0 RIVAL",
	UDim2.fromScale(0.92, 0.82), 32, Candy.DARK, Enum.TextXAlignment.Center)

local meterPanel = Candy.bubble(gui, "BreakerBubble", UDim2.fromOffset(400, 46),
	UDim2.new(0, 18, 1, -22), Vector2.new(0, 1), Candy.MINT)
local meterBack = Instance.new("Frame")
meterBack.Name = "BreakerTrack"
meterBack.AnchorPoint = Vector2.new(0.5, 0.5)
meterBack.Position = UDim2.fromScale(0.5, 0.5)
meterBack.Size = UDim2.new(1, -10, 0, 18)
meterBack.BackgroundColor3 = Color3.fromRGB(70, 30, 42)
meterBack.BackgroundTransparency = 0.3
meterBack.BorderSizePixel = 0
meterBack.Parent = meterPanel
Candy.corner(meterBack, 9)

local meterFill = Instance.new("Frame")
meterFill.Name = "Fill"
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
meterFill.BorderSizePixel = 0
meterFill.Parent = meterBack
Candy.corner(meterFill, 9)

local controlPanel = Candy.bubble(gui, "ControlsBubble", UDim2.fromOffset(860, 50),
	UDim2.new(0, 18, 1, -76), Vector2.new(0, 1), Candy.PINK)
local meterLabel = Candy.text(controlPanel, "Label", "X  trick   ·   G  Gamebreaker   ·   Shift  turbo   ·   V  dunk",
	UDim2.fromScale(0.94, 0.8), 22, Candy.DARK)

local chainPanel = Candy.bubble(gui, "ChainBubble", UDim2.fromOffset(760, 88),
	UDim2.new(0.5, 0, 0.62, 0), Vector2.new(0.5, 0.5), Candy.MINT)
local chainLabel = Candy.text(chainPanel, "Chain", "", UDim2.fromScale(0.94, 0.8), 50, Candy.RED)
chainLabel.TextTransparency = 1
Candy.show(chainPanel, false)

local flashPanel = Candy.bubble(gui, "FlashBubble", UDim2.fromOffset(940, 128),
	UDim2.new(0.5, 0, 0.32, 0), Vector2.new(0.5, 0.5), Candy.GOLD)
local flash = Candy.text(flashPanel, "BreakFlash", "", UDim2.fromScale(0.94, 0.8), 72, Candy.RED)
flash.TextTransparency = 1
Candy.show(flashPanel, false)

-- ------------------------------------------------------------------ state

local scores = {}
local turboOn = false

local function refreshBoard()
	local mine = scores[player.Name] or 0
	local rivalName, rivalScore = nil, 0
	for name, score in pairs(scores) do
		if name ~= player.Name and score > rivalScore then
			rivalName, rivalScore = name, score
		end
	end
	local rivalText = rivalName and ("RIVAL " .. rivalScore) or "NO RIVAL"
	board.Text = string.format("STREET · TO %d\nYOU %d   ·   %s", WIN_SCORE, mine, rivalText)
end

local flashToken = 0
local function showFlash(text, color, size)
	flashToken += 1
	local token = flashToken
	flash.Text = text
	flash.TextColor3 = color
	flash.TextSize = size or 54
	flash.TextTransparency = 0
	Candy.show(flashPanel, true)
	task.spawn(function()
		for step = 1, 36 do
			if token ~= flashToken then
				Candy.show(flashPanel, false)
				return
			end
			flash.TextTransparency = step / 36
			task.wait(0.03)
		end
		Candy.show(flashPanel, false)
	end)
end

local chainToken = 0
local function showChain(count)
	chainToken += 1
	local token = chainToken
	local names = { "CROSSOVER", "SPIN", "BEHIND THE BACK", "ANKLE BREAKER", "STYLE!" }
	chainLabel.Text = string.format("x%d  %s", count, names[math.min(count, #names)])
	chainLabel.TextTransparency = 0
	Candy.show(chainPanel, true)
	chainLabel.Position = UDim2.fromScale(0.5, 0.55)
	task.spawn(function()
		for step = 1, 40 do
			if token ~= chainToken then
				Candy.show(chainPanel, false)
				return
			end
			chainLabel.TextTransparency = step / 40
			chainLabel.Position = UDim2.fromScale(0.5, 0.55 - 0.12 * (step / 40))
			task.wait(0.03)
		end
		Candy.show(chainPanel, false)
	end)
end

local function refreshMeter()
	local value = player:GetAttribute("Gamebreaker") or 0
	meterFill.Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1)
	if value >= 100 then
		meterFill.BackgroundColor3 = Candy.GOLD
		meterLabel.Text = "GAMEBREAKER READY!  ·  press G to dunk"
		meterLabel.TextColor3 = Candy.RED
	else
		meterFill.BackgroundColor3 = Candy.MINT
		meterLabel.Text = string.format("GAMEBREAKER  %d%%  ·  X  trick   G  dunk   Shift  turbo   V  dunk", math.floor(value + 0.5))
		meterLabel.TextColor3 = Candy.DARK
	end
end

player:GetAttributeChangedSignal("Gamebreaker"):Connect(refreshMeter)
player:GetAttributeChangedSignal("StreetScore"):Connect(function()
	local mine = player:GetAttribute("StreetScore") or 0
	scores[player.Name] = mine
	refreshBoard()
end)

refreshMeter()
refreshBoard()

-- ---------------------------------------------------------------- network

StreetEvent.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "scores" then
		scores = {}
		for _, entry in ipairs(a) do
			scores[entry.name] = entry.score
		end
		refreshBoard()
	elseif kind == "trick" then
		showChain(a)
	elseif kind == "gamebreaker" then
		showFlash(a == player and "GAME BREAKER DUNK!" or (a.Name .. " GAME BREAKER!"), Candy.GOLD, 72)
	elseif kind == "needball" then
		showFlash("GAME BREAKER NEEDS THE BALL", Candy.PINK, 46)
	elseif kind == "robbed" then
		showFlash(string.format("-%d  ROBBED BY %s", b, a.Name), Candy.RED, 54)
	elseif kind == "award" then
		local who = a
		if who == player then
			showFlash("+" .. b .. " STREET", Candy.MINT, 66)
		end
	elseif kind == "matchover" then
		showFlash(a == player and "MATCH WON!" or (a.Name .. " WINS"), Candy.MINT, 74)
	end
end)

-- ------------------------------------------------------------------ input

local function setTurbo(enabled)
	turboOn = enabled
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and TURBO_SPEED or BASE_SPEED
	end
end

player.CharacterAdded:Connect(function()
	if turboOn then
		task.wait(0.25)
		setTurbo(true)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	-- Gamepad: R2 trick, D-pad right Gamebreaker, L1 turbo (A stays jump and
	-- X stays the pick-up ProximityPrompt button).
	if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonR2 then
		TrickRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.DPadRight then
		GamebreakerRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL1 then
		setTurbo(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL1 then
		setTurbo(false)
	end
end)
