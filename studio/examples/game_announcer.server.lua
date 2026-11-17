--!nonstrict
-- Game announcer: calls out buckets, tricks, Gamebreakers and Santa-court
-- scores on a billboard above the street court. It only reads attributes and
-- scoreboard text, so it never touches game state.

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

local BLARE_ID = "rbxassetid://124140408144336"
local TRICKS = {
	"CROSSOVER",
	"SPIN MOVE",
	"AROUND THE BACK",
	"ANKLE BREAKER",
	"STYLE POINTS",
}

local queue = {}
local running = false

local function blare()
	if not anchor then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnnouncerBlare"
	sound.SoundId = BLARE_ID
	sound.Volume = 0.24
	sound.PlaybackSpeed = 1.35
	sound.Parent = anchor
	sound:Play()
	task.delay(1.6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)

	local home = anchor.Position
	task.spawn(function()
		for _, lift in ipairs({ 0.5, 0.25, 0 }) do
			anchor.Position = home + Vector3.new(0, lift, 0)
			task.wait(0.08)
		end
		anchor.Position = home
	end)
end

local function say(text, priority)
	if priority then
		table.clear(queue) -- a live play by the player cuts in front of filler
	end
	table.insert(queue, text)
	if #queue > 5 then
		table.remove(queue, 1)
	end
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local message = table.remove(queue, 1)
			label.Text = message
			blare()
			task.wait(2.2)
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
			say("THREE POINTER! " .. player.Name .. " IS ON FIRE!", true)
		elseif gained >= 2 then
			say("BUCKET! " .. player.Name .. " SCORES!", true)
		end
	end)

	player:GetAttributeChangedSignal("TrickChain"):Connect(function()
		local chain = player:GetAttribute("TrickChain") or 0
		if chain >= 1 and chain <= #TRICKS then
			say(TRICKS[chain] .. "! NICE HANDLES!", true)
		end
	end)

	player:GetAttributeChangedSignal("GamebreakerActive"):Connect(function()
		if player:GetAttribute("GamebreakerActive") == true then
			say("GAME BREAKER DUNK!", true)
		end
	end)

	player:GetAttributeChangedSignal("StreetScore"):Connect(function()
		local value = player:GetAttribute("StreetScore") or 0
		if value >= 5 then
			say("STREET LEGEND: " .. player.Name .. "!")
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
					say("SANTA COURT: " .. teamA.Text .. "  -  " .. teamB.Text)
				end
			end
		end)
	end
end

task.delay(4, function()
	say("WELCOME TO HOOPSMAS STREETBALL!")
end)
