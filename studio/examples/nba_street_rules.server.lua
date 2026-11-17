--!nonstrict
-- NBAStreetRules — Gamebreaker meter, trick chains, and street scoring.
--
-- Layered on top of BallService. It never moves a ball: it reads the score
-- BallService already awards and puts the NBA Street layer on top of it.
--
-- Rule set (NBA Street / Vol. 2):
--   * games to 21, win by 2
--   * 1 point inside the arc, 2 beyond it
--   * tricks chain into style points that fill the Gamebreaker meter
--   * a full meter unleashes a Gamebreaker: +2 for you, -1 off the leader
--
-- BallService scores 2 for an inside basket and 3 beyond the arc, so the
-- mapping is: 3 -> 2 street points, 2 -> 1 street point.
--
-- Install as a Script under ServerScriptService, next to BallService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WIN_SCORE = 21
local WIN_MARGIN = 2

local METER_MAX = 100
local METER_PER_TRICK = 7
local METER_PER_MAKE = 18

local CHAIN_WINDOW = 2.5
local CHAIN_MAX = 5
local TRICK_COOLDOWN = 0.4

local GAMEBREAKER_POINTS = 2
local GAMEBREAKER_DRAIN = 1
local GAMEBREAKER_LOCKOUT = 1.2

-- BallService creates BallRemotes; wait so load order does not matter.
local remotes = ReplicatedStorage:WaitForChild("BallRemotes")

local function remote(name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new("RemoteEvent")
	instance.Name = name
	instance.Parent = remotes
	return instance
end

local TrickRemote = remote("Trick")
local GamebreakerRemote = remote("Gamebreaker")
local StreetEvent = remote("StreetEvent")
-- Carries the trick move to every client so each avatar performs it.
local TrickAnim = remote("TrickAnim")
-- BallService exposes the scripted dunk and trick dribble through bindables.
local DunkCommand = remotes:WaitForChild("DunkCommand")
local TrickBallCommand = remotes:WaitForChild("TrickBallCommand", 10)

local streetScore = {}
local meter = {}
local chain = {}
local lastAwarded = {}
local lastBreaker = {}
local matchOver = false

-- ---------------------------------------------------------------- helpers

local function addMeter(player, amount)
	meter[player] = math.clamp((meter[player] or 0) + amount, 0, METER_MAX)
	player:SetAttribute("Gamebreaker", math.floor(meter[player] + 0.5))
end

local function leaderExcept(player)
	local bestPlayer, bestScore = nil, -1
	for other, score in pairs(streetScore) do
		if other ~= player and score > bestScore then
			bestPlayer, bestScore = other, score
		end
	end
	return bestPlayer
end

local function broadcastScores()
	local payload = {}
	for player, score in pairs(streetScore) do
		table.insert(payload, { name = player.Name, score = score })
	end
	StreetEvent:FireAllClients("scores", payload)
end

local function resetMatch()
	for player in pairs(streetScore) do
		streetScore[player] = 0
		meter[player] = 0
		chain[player] = { count = 0, at = 0 }
		player:SetAttribute("StreetScore", 0)
		player:SetAttribute("Gamebreaker", 0)
		player:SetAttribute("TrickChain", 0)
	end
	matchOver = false
	broadcastScores()
end

local function award(player, points, reason)
	if matchOver then
		return
	end
	streetScore[player] = (streetScore[player] or 0) + points
	player:SetAttribute("StreetScore", streetScore[player])
	StreetEvent:FireAllClients("award", player, points, reason)
	broadcastScores()

	local rivalPlayer = leaderExcept(player)
	local rivalScore = rivalPlayer and (streetScore[rivalPlayer] or 0) or 0
	local mine = streetScore[player]
	if mine >= WIN_SCORE and (mine - rivalScore) >= WIN_MARGIN then
		matchOver = true
		StreetEvent:FireAllClients("matchover", player, mine, rivalScore)
		task.delay(5, resetMatch)
	end
end

-- ------------------------------------------------------------------ join

local function initPlayer(player)
	streetScore[player] = 0
	meter[player] = 0
	chain[player] = { count = 0, at = 0 }
	lastAwarded[player] = player:GetAttribute("Score") or 0

	player:SetAttribute("StreetScore", 0)
	player:SetAttribute("Gamebreaker", 0)
	player:SetAttribute("TrickChain", 0)
	player:SetAttribute("GamebreakerActive", false)

	-- BallService owns the Score attribute; we convert its increments.
	player:GetAttributeChangedSignal("Score"):Connect(function()
		local current = player:GetAttribute("Score") or 0
		local delta = current - (lastAwarded[player] or 0)
		lastAwarded[player] = current
		if delta <= 0 then
			return
		end

		local streetPoints = delta >= 3 and 2 or 1
		chain[player] = { count = 0, at = 0 }
		player:SetAttribute("TrickChain", 0)
		addMeter(player, METER_PER_MAKE)
		award(player, streetPoints, "basket")
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	initPlayer(player)
end
Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player)
	streetScore[player] = nil
	meter[player] = nil
	chain[player] = nil
	lastAwarded[player] = nil
	lastBreaker[player] = nil
end)

-- ---------------------------------------------------------------- tricks

TrickRemote.OnServerEvent:Connect(function(player)
	local state = chain[player]
	if not state then
		return
	end
	if player:GetAttribute("Dribbling") ~= true then
		return
	end

	local now = os.clock()
	if now - (state.last or 0) < TRICK_COOLDOWN then
		return
	end
	if now - state.at > CHAIN_WINDOW then
		state.count = 0
	end

	state.last = now
	state.at = now
	state.count = math.min(CHAIN_MAX, state.count + 1)
	player:SetAttribute("TrickChain", state.count)
	addMeter(player, METER_PER_TRICK * state.count)
	StreetEvent:FireClient(player, "trick", state.count)

	-- Play it, don't just announce it: every client poses this character and
	-- BallService steers the dribbled ball through the same move.
	TrickAnim:FireAllClients(player, state.count)
	if TrickBallCommand then
		pcall(function()
			TrickBallCommand:Invoke(player, state.count)
		end)
	end
end)

-- ----------------------------------------------------------- gamebreaker

GamebreakerRemote.OnServerEvent:Connect(function(player)
	if matchOver then
		return
	end
	-- Slam cocoa grants a ready Gamebreaker without filling the meter.
	if (meter[player] or 0) < METER_MAX and (player:GetAttribute("CocoaDunkUntil") or 0) <= os.clock() then
		return
	end
	if player:GetAttribute("HoldingBall") ~= true and player:GetAttribute("Dribbling") ~= true then
		return
	end

	local now = os.clock()
	if now - (lastBreaker[player] or 0) < GAMEBREAKER_LOCKOUT then
		return
	end

	-- A Gamebreaker is a dunk, so it needs the ball. BallService flies the ball
	-- through the rim and returns false when the player has nothing to dunk.
	local invoked, started = pcall(function()
		return DunkCommand:Invoke(player, nil, true)
	end)
	if not invoked or started ~= true then
		StreetEvent:FireClient(player, "needball")
		return
	end
	lastBreaker[player] = now

	if (player:GetAttribute("CocoaDunkUntil") or 0) > os.clock() then
		player:SetAttribute("CocoaDunkUntil", 0)
	else
		meter[player] = 0
	end
	player:SetAttribute("Gamebreaker", 0)
	player:SetAttribute("GamebreakerActive", true)

	award(player, GAMEBREAKER_POINTS, "gamebreaker")

	local victim = leaderExcept(player)
	if victim and (streetScore[victim] or 0) > 0 then
		streetScore[victim] = math.max(0, streetScore[victim] - GAMEBREAKER_DRAIN)
		victim:SetAttribute("StreetScore", streetScore[victim])
		StreetEvent:FireClient(victim, "robbed", player, GAMEBREAKER_DRAIN)
	end

	broadcastScores()
	StreetEvent:FireAllClients("gamebreaker", player)

	task.delay(GAMEBREAKER_LOCKOUT, function()
		if player.Parent then
			player:SetAttribute("GamebreakerActive", false)
		end
	end)
end)
