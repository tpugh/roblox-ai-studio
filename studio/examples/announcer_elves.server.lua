--!nonstrict
-- Announcer Elves — two megaphone-toting criers who call out what the cocoa
-- stand and the Santa avatar boutique are selling. They rotate ad messages on
-- a timer and cut in with a special shout whenever someone actually buys.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local station = Workspace:FindFirstChild("AnnouncerElves")
if not station then
	warn("[Announcers] AnnouncerElves station is missing")
	return
end

local BLARE_ID = "rbxassetid://124140408144336"
local DRINKS = {
	{ key = "CocoaRunUntil", duration = 60, name = "COCOA RUSH" },
	{ key = "CocoaShootUntil", duration = 60, name = "SHARP SHOOTER" },
	{ key = "CocoaDunkUntil", duration = 60, name = "SLAM COCOA" },
	{ key = "CocoaStealUntil", duration = 60, name = "STEAL COCOA" },
	{ key = "CocoaSnowUntil", duration = 90, name = "SNOWBALL COCOA" },
}
local OUTFITS = {
	santa = "CLASSIC SANTA",
	mrs = "MRS CLAUS",
	elf = "WORKSHOP ELF",
	reindeer = "REINDEER",
	snowman = "SNOWMAN",
}
local ADS = {
	Cocoa = {
		"HOT CHOCOLATE! COCOA RUSH 15 BUCKS!",
		"SHARP SHOOTER 20 BUCKS - GREEN AIM!",
		"SLAM COCOA 25 - DUNK ON DEMAND!",
		"STEAL COCOA 15 - LOCK DOWN THE BALL!",
		"SNOWBALL COCOA 25 - FREEZE DEFENDERS!",
		"SCORE BUCKETS TO EARN COCOA BUCKS!",
	},
	Avatar = {
		"SANTA AVATARS AT THE WORKSHOP!",
		"CLASSIC SANTA 60 BUCKS - HO HO HO!",
		"MRS CLAUS 50 - FESTIVE AND FIERCE!",
		"WORKSHOP ELF 40 - GREEN MACHINE!",
		"REINDEER 55 - ANTLERS AND ALL!",
		"SNOWMAN 50 - COOL UNDER PRESSURE!",
	},
}

local criers = {}
for _, model in ipairs(station:GetChildren()) do
	local id = model:GetAttribute("Announcer")
	if id and ADS[id] then
		local bubble = model:FindFirstChild("BubbleAnchor")
		local gui = bubble and bubble:FindFirstChild("Bubble")
		local label = gui and gui:FindFirstChild("Text")
		table.insert(criers, {
			id = id,
			model = model,
			home = model:GetPivot(),
			label = label,
			index = 0,
			busy = false,
		})
	end
end
if #criers == 0 then
	warn("[Announcers] no criers found")
	return
end

local function blare(crier, pitch)
	local root = crier.model.PrimaryPart
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "MegaphoneBlare"
	sound.SoundId = BLARE_ID
	sound.Volume = 0.25
	sound.PlaybackSpeed = pitch or 1.5
	sound.Parent = root
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(1.2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function hop(crier)
	if crier.busy then
		return
	end
	crier.busy = true
	local base = crier.home.Position
	for _ = 1, 3 do
		crier.model:PivotTo(CFrame.new(base + Vector3.new(0, 0.8, 0)))
		task.wait(0.09)
		crier.model:PivotTo(crier.home)
		task.wait(0.09)
	end
	crier.busy = false
end

local function announce(crier, text)
	if crier.label then
		crier.label.Text = text
	end
	blare(crier, 1.5)
	task.spawn(function()
		hop(crier)
	end)
end

local function byId(id)
	for _, crier in ipairs(criers) do
		if crier.id == id then
			return crier
		end
	end
	return nil
end

-- Rotate the ads. Each crier is offset so they never shout over each other.
task.spawn(function()
	while true do
		for _, crier in ipairs(criers) do
			crier.index = (crier.index % #ADS[crier.id]) + 1
			announce(crier, ADS[crier.id][crier.index])
			task.wait(2.6)
		end
		task.wait(2.2)
	end
end)

local function identifyDrink(player)
	local now = os.clock()
	for _, drink in ipairs(DRINKS) do
		local untilTime = player:GetAttribute(drink.key)
		if type(untilTime) == "number" and untilTime > now and untilTime - now > drink.duration - 4 then
			return drink.name
		end
	end
	return nil
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal("CocoaBucks"):Connect(function()
		local drink = identifyDrink(player)
		if drink then
			local cocoa = byId("Cocoa")
			if cocoa then
				announce(cocoa, "NICE BUY! " .. drink .. " IS ACTIVE - GET AFTER IT!")
			end
		end
	end)
	player:GetAttributeChangedSignal("SantaOutfit"):Connect(function()
		local outfit = player:GetAttribute("SantaOutfit")
		if outfit and OUTFITS[outfit] then
			local avatar = byId("Avatar")
			if avatar then
				announce(avatar, "LOOKING SHARP! " .. OUTFITS[outfit] .. " AVATAR EQUIPPED!")
			end
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(function(player)
	watchPlayer(player)
	task.delay(3, function()
		local avatar = byId("Avatar")
		if avatar then
			announce(avatar, "WELCOME! SANTA AVATARS AT THE WORKSHOP!")
		end
	end)
end)
