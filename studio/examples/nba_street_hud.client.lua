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

local BASE_SPEED = 16
local TURBO_SPEED = 26
local WIN_SCORE = 21

-- -------------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "StreetHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local board = Instance.new("TextLabel")
board.Name = "Scoreboard"
board.AnchorPoint = Vector2.new(0, 0)
board.Position = UDim2.new(0, 22, 0, 18)
board.Size = UDim2.new(0, 300, 0, 46)
board.BackgroundTransparency = 1
board.Font = Enum.Font.GothamBlack
board.TextSize = 20
board.TextXAlignment = Enum.TextXAlignment.Left
board.TextColor3 = Color3.fromRGB(255, 255, 255)
board.TextStrokeTransparency = 0.5
board.Text = "STREET · TO 21\nYOU 0   ·   0 RIVAL"
board.Parent = gui

local meterBack = Instance.new("Frame")
meterBack.Name = "BreakerTrack"
meterBack.AnchorPoint = Vector2.new(0, 1)
meterBack.Position = UDim2.new(0, 22, 1, -54)
meterBack.Size = UDim2.new(0, 240, 0, 12)
meterBack.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
meterBack.BackgroundTransparency = 0.3
meterBack.BorderSizePixel = 0
meterBack.Parent = gui

local meterFill = Instance.new("Frame")
meterFill.Name = "Fill"
meterFill.Size = UDim2.new(0, 0, 1, 0)
meterFill.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
meterFill.BorderSizePixel = 0
meterFill.Parent = meterBack

local meterCorner = Instance.new("UICorner")
meterCorner.CornerRadius = UDim.new(1, 0)
meterCorner.Parent = meterBack

local meterLabel = Instance.new("TextLabel")
meterLabel.Name = "Label"
meterLabel.AnchorPoint = Vector2.new(0, 1)
meterLabel.Position = UDim2.new(0, 22, 1, -70)
meterLabel.Size = UDim2.new(0, 320, 0, 18)
meterLabel.BackgroundTransparency = 1
meterLabel.Font = Enum.Font.GothamBold
meterLabel.TextSize = 13
meterLabel.TextXAlignment = Enum.TextXAlignment.Left
meterLabel.TextColor3 = Color3.fromRGB(170, 200, 220)
meterLabel.TextStrokeTransparency = 0.7
meterLabel.Text = "GAMEBREAKER  ·  X trick   G dunk   Shift turbo"
meterLabel.Parent = gui

local chainLabel = Instance.new("TextLabel")
chainLabel.Name = "Chain"
chainLabel.AnchorPoint = Vector2.new(0.5, 0.5)
chainLabel.Position = UDim2.new(0.5, 0, 0.6, 0)
chainLabel.Size = UDim2.new(0, 420, 0, 40)
chainLabel.BackgroundTransparency = 1
chainLabel.Font = Enum.Font.GothamBlack
chainLabel.TextSize = 30
chainLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
chainLabel.TextStrokeTransparency = 0.4
chainLabel.TextTransparency = 1
chainLabel.Text = ""
chainLabel.Parent = gui

local flash = Instance.new("TextLabel")
flash.Name = "BreakFlash"
flash.AnchorPoint = Vector2.new(0.5, 0.5)
flash.Position = UDim2.new(0.5, 0, 0.32, 0)
flash.Size = UDim2.new(0, 760, 0, 90)
flash.BackgroundTransparency = 1
flash.Font = Enum.Font.GothamBlack
flash.TextSize = 54
flash.TextColor3 = Color3.fromRGB(255, 220, 90)
flash.TextStrokeTransparency = 0.35
flash.TextTransparency = 1
flash.Text = ""
flash.Parent = gui

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
	task.spawn(function()
		for step = 1, 36 do
			if token ~= flashToken then
				return
			end
			flash.TextTransparency = step / 36
			task.wait(0.03)
		end
	end)
end

local chainToken = 0
local function showChain(count)
	chainToken += 1
	local token = chainToken
	local names = { "CROSSOVER", "SPIN", "BEHIND THE BACK", "ANKLE BREAKER", "STYLE!" }
	chainLabel.Text = string.format("x%d  %s", count, names[math.min(count, #names)])
	chainLabel.TextTransparency = 0
	chainLabel.Position = UDim2.new(0.5, 0, 0.6, 0)
	task.spawn(function()
		for step = 1, 40 do
			if token ~= chainToken then
				return
			end
			chainLabel.TextTransparency = step / 40
			chainLabel.Position = UDim2.new(0.5, 0, 0.6 - 0.05 * (step / 40), 0)
			task.wait(0.03)
		end
	end)
end

local function refreshMeter()
	local value = player:GetAttribute("Gamebreaker") or 0
	meterFill.Size = UDim2.new(math.clamp(value / 100, 0, 1), 0, 1, 0)
	if value >= 100 then
		meterFill.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
		meterLabel.Text = "GAMEBREAKER READY  ·  press G to dunk"
		meterLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	else
		meterFill.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
		meterLabel.Text = string.format("GAMEBREAKER  %d%%  ·  X trick", math.floor(value + 0.5))
		meterLabel.TextColor3 = Color3.fromRGB(170, 200, 220)
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
		showFlash(a == player and "GAME BREAKER DUNK!" or (a.Name .. " GAME BREAKER!"), Color3.fromRGB(255, 220, 90), 58)
	elseif kind == "needball" then
		showFlash("GAME BREAKER NEEDS THE BALL", Color3.fromRGB(255, 150, 90), 30)
	elseif kind == "robbed" then
		showFlash(string.format("-%d  ROBBED BY %s", b, a.Name), Color3.fromRGB(255, 90, 90), 34)
	elseif kind == "award" then
		local who = a
		if who == player then
			showFlash("+" .. b .. " STREET", Color3.fromRGB(120, 255, 170), 44)
		end
	elseif kind == "matchover" then
		showFlash(a == player and "MATCH WON!" or (a.Name .. " WINS"), Color3.fromRGB(120, 220, 255), 60)
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
	if input.KeyCode == Enum.KeyCode.X then
		TrickRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		GamebreakerRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setTurbo(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setTurbo(false)
	end
end)
