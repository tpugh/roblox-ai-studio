--!nonstrict
-- Touch controls for phones and tablets. Circular action buttons cluster on
-- the right side (opposite the movement joystick), styled after the reference:
-- one large SHOOT button ringed by smaller move buttons. All buttons fire the
-- same server remotes as the keyboard keys, so validation stays server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local ball = ReplicatedStorage:WaitForChild("BallRemotes", 10)
local function remote(name)
	return ball and ball:FindFirstChild(name) or nil
end
local Throw = remote("Throw")
local ResetBalls = remote("ResetBalls")
local Defend = remote("Defend")
local Grab = remote("Grab")
local Dunk = remote("Dunk")
local Trick = remote("Trick")
local Gamebreaker = remote("Gamebreaker")
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

-- Roblox's default touch JUMP button sits in the same bottom-right corner as
-- SHOOT. On real touch devices remove it so the two never overlap; our DUNK
-- button already covers the jump/dunk action.
if UserInputService.TouchEnabled then
	pcall(function()
		game:GetService("ContextActionService"):UnbindAction("jumpAction")
	end)
end

local CREAM = Color3.fromRGB(240, 240, 246)
local INK = Color3.fromRGB(38, 38, 48)
local GLASS = Color3.fromRGB(66, 58, 50)

-- Landscape phones have a short viewport height, so scale every button and
-- its offset from the reference height (720). Clamped so tablets stay usable.
local buttons = {}
local function uiScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(viewport.Y / 720, 0.6, 1.15)
end

-- Circular button: a dark/coloured ring with a slightly smaller face inside.
local function circleButton(name, text, size, centre, big, onTap, onHold)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	table.insert(buttons, { holder = holder, baseSize = size, baseCentre = centre, big = big })

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundColor3 = big and INK or CREAM
	ring.BorderSizePixel = 0
	ring.Parent = holder
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring

	local face = Instance.new("TextButton")
	face.Name = "Tap"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.new(1, -7, 1, -7)
	face.BackgroundColor3 = big and CREAM or GLASS
	face.BackgroundTransparency = big and 0 or 0.15
	face.BorderSizePixel = 0
	face.Font = Enum.Font.GothamBlack
	face.Text = text
	face.TextColor3 = big and INK or CREAM
	face.TextScaled = true
	face.Parent = holder
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0.5, 0)
	faceCorner.Parent = face

	if onTap then
		face.MouseButton1Click:Connect(onTap)
	end
	if onHold then
		face.MouseButton1Down:Connect(function()
			onHold(true)
		end)
		face.MouseButton1Up:Connect(function()
			onHold(false)
		end)
		face.MouseLeave:Connect(function()
			onHold(false)
		end)
	end
	return holder
end

-- Hold SHOOT to charge, release to fire (mirrors the F key).
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

-- Right-side circular cluster: SHOOT is the anchor, moves ring around it.
local function at(right, bottom)
	return UDim2.new(1, -right, 1, -bottom)
end

-- SHOOT is the hub; the four action buttons sit in an arc wrapped around its
-- top and left (the right/bottom edges are screen boundaries).
-- The cluster sits well left of the corner: Roblox's default touch JUMP button
-- lives at the bottom-right and used to overlap SHOOT.
circleButton("MobileShoot", "SHOOT", UDim2.fromOffset(136, 136), at(255, 120), true, nil, setCharging)
circleButton("MobileDunk", "DUNK", UDim2.fromOffset(78, 78), at(255, 250), false, function()
	if Dunk then Dunk:FireServer() end
end)
circleButton("MobileTrick", "TRICK", UDim2.fromOffset(78, 78), at(345, 215), false, function()
	if Trick then Trick:FireServer() end
end)
circleButton("MobileSteal", "STEAL", UDim2.fromOffset(78, 78), at(385, 135), false, function()
	if Defend then Defend:FireServer() end
end)
circleButton("MobileBreaker", "BREAKER", UDim2.fromOffset(78, 78), at(345, 50), false, function()
	if Gamebreaker then Gamebreaker:FireServer() end
end)

-- Support circles form a smaller arc above the hub (no MUSIC button on mobile).
circleButton("MobileTurbo", "TURBO", UDim2.fromOffset(68, 68), at(185, 335), false, nil, setTurbo)
circleButton("MobileGrab", "GRAB", UDim2.fromOffset(68, 68), at(270, 360), false, grabNearest)
circleButton("MobileReset", "RESET", UDim2.fromOffset(64, 64), at(355, 335), false, function()
	if ResetBalls then ResetBalls:FireServer() end
end)

local function applyScale()
	local scale = uiScale()
	for _, entry in ipairs(buttons) do
		local s = entry.baseSize
		local c = entry.baseCentre
		entry.holder.Size = UDim2.fromOffset(s.X.Offset * scale, s.Y.Offset * scale)
		entry.holder.Position = UDim2.new(1, c.X.Offset * scale, 1, c.Y.Offset * scale)
	end
end
applyScale()
local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
end

-- Shrink the Score and Cocoa Bucks bubbles on phones and make them see-through
-- so they stop covering the court. Keep the numbers readable with a dark stroke.
local hudSlimmed = false
local function slimHUD()
	if hudSlimmed then
		return
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local specs = {
		{ gui = "BallHUD", name = "WalletBubble", w = 360, h = 60, font = 19, scale = 0.6 },
		{ gui = "BallHUD", name = "ScoreBubble", w = 320, h = 76, font = 30, scale = 0.6 },
		{ gui = "StreetHUD", name = "ScoreboardBubble", w = 480, h = 104, font = 16, scale = 0.5 },
		-- Transient score / trick pop-ups: see-through so they don't blanket the court.
		{ gui = "BallHUD", name = "FlashBubble", w = 840, h = 112, font = 30, scale = 0.55 },
		{ gui = "StreetHUD", name = "FlashBubble", w = 940, h = 128, font = 32, scale = 0.55 },
		{ gui = "StreetHUD", name = "ChainBubble", w = 760, h = 88, font = 26, scale = 0.55 },
	}
	for _, spec in ipairs(specs) do
		local hud = playerGui:FindFirstChild(spec.gui)
		if not hud or not hud:FindFirstChild(spec.name) then
			return -- HUD not built yet; try again next tick
		end
	end
	-- CocoaShopUI keeps its own always-on gold wallet with a dark translucent
	-- backing. It stacks on top of BallHUD's wallet on phones, producing the
	-- dark bar over the gold text. BallHUD already shows the count, so hide it.
	local cocoaShop = playerGui:FindFirstChild("CocoaShopUI")
	local shopWallet = cocoaShop and cocoaShop:FindFirstChild("Wallet")
	if shopWallet then
		shopWallet.Visible = false
	end
	hudSlimmed = true
	for _, spec in ipairs(specs) do
		local hud = playerGui:FindFirstChild(spec.gui)
		local rim = hud and hud:FindFirstChild(spec.name)
		local shadow = hud and hud:FindFirstChild(spec.name .. "Shadow")
		if rim then
			rim.Size = UDim2.fromOffset(math.floor(spec.w * spec.scale), math.floor(spec.h * spec.scale))
			rim.BackgroundTransparency = 1
			local inner = rim:FindFirstChild("Inner")
			if inner then
				inner.BackgroundTransparency = 1
				for _, child in ipairs(inner:GetChildren()) do
					if child:IsA("Frame") then
						child.Visible = false -- candy stripes
					end
				end
				for _, label in ipairs(inner:GetDescendants()) do
					if label:IsA("TextLabel") then
						-- Scale to the shrunken bubble: showFlash() resets TextSize
						-- on every pop-up, so a fixed mobile font would not stick.
						label.TextScaled = true
						label.TextSize = spec.font
						label.TextStrokeColor3 = Color3.new(1, 1, 1)
						label.TextStrokeTransparency = 0.45
					end
				end
			end
		end
		if shadow then
			shadow.Visible = false
		end
	end
end

-- Phones have less room: hide keyboard hints and shrink the world sign boards.
local function slimSigns()
	slimHUD()
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local ballHud = playerGui:FindFirstChild("BallHUD")
		local streetHud = playerGui:FindFirstChild("StreetHUD")
		for _, pair in ipairs({
			{ ballHud, "HintBubble" }, { ballHud, "HintBubbleShadow" },
			{ streetHud, "ControlsBubble" }, { streetHud, "ControlsBubbleShadow" },
		}) do
			local panel = pair[1] and pair[1]:FindFirstChild(pair[2])
			if panel then
				panel.Visible = false
			end
		end
		-- Holiday Piano's tag ends in "M mute" — a keyboard hint with no phone
		-- equivalent. Hide the whole tag; music mute stays on through other UI.
		local piano = playerGui:FindFirstChild("HolidayPianoUI")
		local musicTag = piano and piano:FindFirstChild("MusicTag")
		if musicTag then
			musicTag.Visible = false
		end
	end
	-- The big in-world HOOPSMAS title board eats phone screen space. The voice
	-- announcer still delivers every callout, so hide the visual board entirely.
	local announcer = Workspace:FindFirstChild("GameAnnouncer")
	local anchor = announcer and announcer:FindFirstChild("BubbleAnchor")
	local titleBoard = anchor and anchor:FindFirstChild("Bubble")
	if titleBoard and titleBoard:IsA("BillboardGui") then
		titleBoard.Enabled = false
	end
	-- The spectator sign's second line is a keyboard hint ("press E to watch").
	-- Keep the useful label but drop the key instruction on touch devices.
	local stand = Workspace:FindFirstChild("HotChocolateStand")
	local watchAnchor = stand and stand:FindFirstChild("WatchSignAnchor")
	local watchSign = watchAnchor and watchAnchor:FindFirstChild("WatchSign")
	local watchLabel = watchSign and watchSign:FindFirstChild("TextLabel")
	if watchLabel then
		watchLabel.Text = "SPECTATOR DECK"
	end
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("BillboardGui") and not object:GetAttribute("MobileScaled") then
			local s = object.Size
			if s.X.Offset > 0 and s.Y.Offset > 0 then
				object:SetAttribute("MobileScaled", true)
				object.Size = UDim2.fromOffset(s.X.Offset * 0.65, s.Y.Offset * 0.65)
				object.MaxDistance = object.MaxDistance * 0.75
			end
		end
	end
end
slimSigns()
-- Keep retrying even if the mobile GUI was disabled when the script first ran
-- (ForceMobileControls can be set a moment later). slimHUD guards its own work.
task.spawn(function()
	while true do
		task.wait(2)
		slimSigns()
	end
end)
