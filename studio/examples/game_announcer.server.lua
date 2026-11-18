--!nonstrict
-- Game announcer: a voiced TV-style broadcaster calling buckets, tricks,
-- Gamebreakers and Santa-court scores, with the bubble text to match. It only
-- reads attributes and scoreboard text, so it never touches game state.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local model = Workspace:WaitForChild("GameAnnouncer", 10)
if not model then
	return
end
local anchor = model:FindFirstChild("BubbleAnchor")
local gui = anchor and anchor:FindFirstChild("Bubble")
local label = gui and gui:FindFirstChild("Text")
if not label then
	return
end

local VOICE = {
	welcome = 113763813805926,
	bucket = 136152530915050,
	three = 135686510272453,
	crossover = 72215520692870,
	spin = 115975635383452,
	behindback = 72197064642027,
	ankle = 78781674330805,
	style = 117478930036237,
	gamebreaker = 83311040427554,
	santascore = 117390797062289,
}
local BLARE_ID = "rbxassetid://124140408144336"
local TRICK_NAMES = { "CROSSOVER", "SPIN MOVE", "AROUND THE BACK", "ANKLE BREAKER", "STYLE POINTS" }
local TRICK_VOICE = { "crossover", "spin", "behindback", "ankle", "style" }

local queue = {}
local running = false

local function speak(key)
	if not anchor then
		return
	end
	local id = key and VOICE[key]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnnouncerVoice"
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = 1
	sound.PlaybackSpeed = 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 0 -- heard anywhere on the court
	sound.Parent = anchor
	sound:Play()
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function blare()
	if not anchor then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnnouncerBlare"
	sound.SoundId = BLARE_ID
	sound.Volume = 0.18
	sound.PlaybackSpeed = 1.35
	sound.Parent = anchor
	sound:Play()
	task.delay(1.6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function say(text, voiceKey, priority)
	if priority then
		table.clear(queue) -- a live play cuts in front of filler
	end
	table.insert(queue, { text = text, voice = voiceKey })
	if #queue > 5 then
		table.remove(queue, 1)
	end
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local call = table.remove(queue, 1)
			label.Text = call.text
			if call.voice then
				speak(call.voice)
			else
				blare()
			end
			task.wait(call.voice and 2.6 or 2.2)

			local home = anchor.Position
			task.spawn(function()
				for _, lift in ipairs({ 0.5, 0.25, 0 }) do
					anchor.Position = home + Vector3.new(0, lift, 0)
					task.wait(0.08)
				end
				anchor.Position = home
			end)
		end
		label.Text = "HOOPSMAS STREETBALL"
		running = false
	end)
end

local function watchPlayer(player)
	local lastScore = player:GetAttribute("Score") or 0
	player:GetAttributeChangedSignal("Score"):Connect(function()
		local value = player:GetAttribute("Score") or 0
		local gained = value - lastScore
		lastScore = value
		if gained >= 3 then
			say("THREE POINTER! " .. player.Name .. " IS ON FIRE!", "three", true)
		elseif gained >= 2 then
			say("BUCKET! " .. player.Name .. " SCORES!", "bucket", true)
		end
	end)

	player:GetAttributeChangedSignal("TrickChain"):Connect(function()
		local chain = player:GetAttribute("TrickChain") or 0
		if chain >= 1 and chain <= #TRICK_NAMES then
			say(TRICK_NAMES[chain] .. "! NICE HANDLES!", TRICK_VOICE[chain], true)
		end
	end)

	player:GetAttributeChangedSignal("GamebreakerActive"):Connect(function()
		if player:GetAttribute("GamebreakerActive") == true then
			say("GAME BREAKER DUNK!", "gamebreaker", true)
		end
	end)

	player:GetAttributeChangedSignal("StreetScore"):Connect(function()
		local value = player:GetAttribute("StreetScore") or 0
		if value >= 5 then
			say("STREET LEGEND: " .. player.Name .. "!", "style")
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- The Santa 2v2 score lives in scoreboard labels rather than an attribute.
local santa = Workspace:FindFirstChild("SantaCourt")
local body = santa and santa:FindFirstChild("ScoreboardAnchor")
body = body and body:FindFirstChild("TeamBoard")
body = body and body:FindFirstChild("Body")
if body then
	local teamA = body:FindFirstChild("TeamA")
	local teamB = body:FindFirstChild("TeamB")
	if teamA and teamB then
		local lastA, lastB = teamA.Text, teamB.Text
		local lastSantaCall = 0
		task.spawn(function()
			while teamA.Parent and teamB.Parent do
				task.wait(0.3)
				local changed = false
				if teamA.Text ~= lastA then
					lastA = teamA.Text
					changed = true
				end
				if teamB.Text ~= lastB then
					lastB = teamB.Text
					changed = true
				end
				if changed and os.clock() - lastSantaCall > 8 then
					lastSantaCall = os.clock()
					say("SANTA COURT: " .. teamA.Text .. "  -  " .. teamB.Text, "santascore")
				end
			end
		end)
	end
end

task.delay(4, function()
	say("WELCOME TO HOOPSMAS STREETBALL!", "welcome")
end)
