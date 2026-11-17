--!nonstrict
-- CrowdCheer — brings the holiday bleachers to life.
--
-- Every fan is a Model tagged `Fan` under Workspace.CourtStands. Idle fans
-- sway gently; a bucket on either court sets the whole place bouncing and
-- plays a short crowd pop at the scoring end (the other end joins in softly).
-- A low applause loop runs under it all.
--
-- Score hooks avoid touching game logic: the street court is watched through
-- the players' Score attribute (set by BallService for shots and dunks) and
-- the Santa court through its scoreboard labels.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local stands = Workspace:WaitForChild("CourtStands", 10)
if not stands then
	warn("[CrowdCheer] CourtStands is missing, no crowd to cheer")
	return
end

local courts = { main = { fans = {} }, santa = { fans = {} } }
local allFans = {}

for _, stand in ipairs(stands:GetChildren()) do
	if stand:IsA("Model") then
		local name = stand:GetAttribute("Court")
		local group = name and courts[name]
		if group then
			local anchor = stand:FindFirstChild("SoundAnchor")
			group.burst = anchor and anchor:FindFirstChild("CheerBurst") or nil
			group.ambience = anchor and anchor:FindFirstChild("CrowdAmbience") or nil
			if group.ambience and not group.ambience.IsPlaying then
				local length = group.ambience.TimeLength
				group.ambience.TimePosition = length > 1 and math.random() * (length - 1) or 0
				group.ambience:Play()
			end
			for _, fan in ipairs(stand:GetDescendants()) do
				if fan:IsA("Model") and fan:GetAttribute("Fan") then
					local entry = {
						model = fan,
						base = fan:GetPivot(),
						phase = math.random() * math.pi * 2,
						lift = fan:GetAttribute("Fan") == "reindeer" and 0.75 or 0.45,
					}
					table.insert(group.fans, entry)
					table.insert(allFans, entry)
				end
			end
		end
	end
end

local cheerUntil = 0
local lastCheer = { main = 0, santa = 0 }

local function cheer(court)
	local now = os.clock()
	if now - (lastCheer[court] or 0) < 1.2 then
		return
	end
	lastCheer[court] = now
	cheerUntil = now + 3.4

	local group = courts[court]
	if group and group.burst then
		group.burst.Volume = 0.85
		group.burst:Play()
	end
	local other = courts[court == "main" and "santa" or "main"]
	if other and other.burst then
		other.burst.Volume = 0.28
		other.burst:Play()
	end
end

-- A rim touch is the earliest sign of a bucket, so use it for a quick pop.
local function watchRims(anchorContainer, court)
	if not anchorContainer then
		return
	end
	for _, rim in ipairs(anchorContainer:GetChildren()) do
		if string.sub(rim.Name, 1, 8) == "RimScore" and rim:IsA("BasePart") then
			rim.Touched:Connect(function(hit)
				if hit.Name ~= "Basketball" or hit.AssemblyLinearVelocity.Y > 0 then
					return
				end
				cheer(court)
			end)
		end
	end
end

local street = Workspace:FindFirstChild("StreetBasketballCourt")
local santa = Workspace:FindFirstChild("SantaCourt")
watchRims(street and street:FindFirstChild("Anchors"), "main")
watchRims(santa and santa:FindFirstChild("Anchors"), "santa")

-- BallService gives every player a Score attribute on join, and updates it for
-- shots and Gamebreaker dunks alike.
local function watchPlayer(player)
	player:GetAttributeChangedSignal("Score"):Connect(function()
		cheer("main")
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- SantaGame writes its tally to a BillboardGui rather than an attribute.
local santaBoard = santa and santa:FindFirstChild("ScoreboardAnchor")
local body = santaBoard and santaBoard:FindFirstChild("TeamBoard")
body = body and body:FindFirstChild("Body")
if body then
	local a, b = body:FindFirstChild("TeamA"), body:FindFirstChild("TeamB")
	if a and b then
		local lastA, lastB = a.Text, b.Text
		task.spawn(function()
			while a.Parent and b.Parent do
				task.wait(0.3)
				if a.Text ~= lastA or b.Text ~= lastB then
					lastA, lastB = a.Text, b.Text
					cheer("santa")
				end
			end
		end)
	end
end

-- One shared heartbeat drives the sway/celebration; the fans are anchored
-- props, so a single PivotTo per fan moves the whole little character.
local nextTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextTick then
		return
	end
	nextTick = now + 0.06
	local excited = now < cheerUntil
	local beat = now * 9
	for _, fan in ipairs(allFans) do
		local lift
		if excited then
			lift = math.abs(math.sin(beat + fan.phase)) * fan.lift
		else
			lift = math.sin(now * 1.6 + fan.phase) * 0.05
		end
		fan.model:PivotTo(fan.base + Vector3.new(0, lift, 0))
	end
end)
