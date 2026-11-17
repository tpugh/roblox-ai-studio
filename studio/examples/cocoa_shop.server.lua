--!nonstrict
-- CocoaShop — the hot chocolate stand is the recovery and social hub.
--
-- Cocoa Bucks are earned by scoring (+5 per point) and by hanging around the
-- stand. Drinks grant timed buffs through player attributes; BallService,
-- NBAStreetRules and the defense hooks read those attributes directly. The
-- snowball drink also hands out a tool that stuns defenders it hits.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local stand = Workspace:FindFirstChild("HotChocolateStand")
if not stand then
	warn("[CocoaShop] HotChocolateStand is missing")
	return
end
local counter = stand:FindFirstChild("Counter")
local watchPart = stand:FindFirstChild("WatchSpot")
if not counter or not watchPart then
	warn("[CocoaShop] stand is missing its prompt parts")
	return
end

local remotes = ReplicatedStorage:FindFirstChild("CocoaRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CocoaRemotes"
	remotes.Parent = ReplicatedStorage
end
local function remote(name, className)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = remotes
	return instance
end
local OpenShop = remote("OpenShop", "RemoteEvent")
local Purchase = remote("Purchase", "RemoteEvent")
local Result = remote("Result", "RemoteEvent")
local WatchGame = remote("WatchGame", "RemoteEvent")

local DRINKS = {
	run = { name = "Cocoa Rush", price = 15, seconds = 60, attr = "CocoaRunUntil", blurb = "Run faster for 60s" },
	shoot = { name = "Sharp Shooter Cocoa", price = 20, seconds = 60, attr = "CocoaShootUntil", blurb = "Sharper aim for 60s" },
	dunk = { name = "Slam Cocoa", price = 25, seconds = 60, attr = "CocoaDunkUntil", blurb = "Gamebreaker ready instantly" },
	steal = { name = "Steal Cocoa", price = 15, seconds = 60, attr = "CocoaStealUntil", blurb = "Longer, faster steals" },
	snow = { name = "Snowball Cocoa", price = 25, seconds = 90, attr = "CocoaSnowUntil", blurb = "Snowball gun, stuns defenders" },
}
local START_COINS = 30
local POINTS_TO_COINS = 5
local HANGOUT_COINS = 1
local HANGOUT_RANGE = 16
local DEFAULT_WALK = 16

local lastScore = {}
local lastHangout = {}
local lastSnowball = {}

local function addCoins(player, amount)
	player:SetAttribute("CocoaBucks", math.max(0, (player:GetAttribute("CocoaBucks") or 0) + amount))
end

local function active(player, attr)
	return (player:GetAttribute(attr) or 0) > os.clock()
end

local function snowballTool(player)
	local tool = player.Backpack and player.Backpack:FindFirstChild("Snowball Gun")
	if not tool then
		local character = player.Character
		tool = character and character:FindFirstChild("Snowball Gun")
	end
	return tool
end

local function makeSnowballTool()
	local tool = Instance.new("Tool")
	tool.Name = "Snowball Gun"
	tool.RequiresHandle = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 0.6, 2)
	handle.CanCollide = false
	handle.Transparency = 1
	handle.Parent = tool
	return tool
end

local function stun(model, seconds)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if humanoid:GetAttribute("CocoaStunned") then
		return
	end
	local previous = humanoid.WalkSpeed
	humanoid:SetAttribute("CocoaStunned", true)
	humanoid.WalkSpeed = 0
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.WalkSpeed = previous
			humanoid:SetAttribute("CocoaStunned", nil)
		end
	end)
end

local function fireSnowball(player)
	local now = os.clock()
	if now - (lastSnowball[player] or 0) < 0.7 then
		return
	end
	lastSnowball[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local origin = root.Position + look * 2 + Vector3.new(0, 1.2, 0)

	local ball = Instance.new("Part")
	ball.Name = "Snowball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.1, 1.1, 1.1)
	ball.Color = Color3.new(1, 1, 1)
	ball.Material = Enum.Material.Snow
	ball.CanCollide = false
	ball.CFrame = CFrame.new(origin)
	ball.AssemblyLinearVelocity = look * 95 + Vector3.new(0, 8, 0)
	ball.Parent = Workspace

	ball.Touched:Connect(function(hit)
		local model = hit:IsDescendantOf(Workspace.StreetDefenders) and hit:FindFirstAncestorOfClass("Model")
			or (hit.Parent and hit.Parent:IsA("Model") and hit.Parent:GetAttribute("Team") and hit.Parent)
		if model then
			stun(model, 2.2)
			ball:Destroy()
		end
	end)
	task.delay(3, function()
		if ball.Parent then
			ball:Destroy()
		end
	end)
end

local function watchPlayer(player)
	if player:GetAttribute("CocoaBucks") == nil then
		player:SetAttribute("CocoaBucks", START_COINS)
	end
	lastScore[player] = player:GetAttribute("Score") or 0
	player:GetAttributeChangedSignal("Score"):Connect(function()
		local score = player:GetAttribute("Score") or 0
		local gained = score - (lastScore[player] or 0)
		lastScore[player] = score
		if gained > 0 then
			addCoins(player, gained * POINTS_TO_COINS)
			Result:FireClient(player, "+" .. (gained * POINTS_TO_COINS) .. " Cocoa Bucks for the bucket!")
		end
	end)

	player.CharacterAdded:Connect(function(character)
		if active(player, "CocoaSnowUntil") and not snowballTool(player) then
			makeSnowballTool():Clone().Parent = player.Backpack
		end
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Snowball Gun" then
				child.Activated:Connect(function()
					fireSnowball(player)
				end)
			end
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

Purchase.OnServerEvent:Connect(function(player, id)
	local drink = DRINKS[id]
	if not drink then
		return
	end
	local coins = player:GetAttribute("CocoaBucks") or 0
	if coins < drink.price then
		Result:FireClient(player, "Not enough Cocoa Bucks — score some buckets or hang out!")
		return
	end
	addCoins(player, -drink.price)
	player:SetAttribute(drink.attr, os.clock() + drink.seconds)
	if id == "snow" then
		local tool = snowballTool(player)
		if not tool then
			tool = makeSnowballTool()
			tool.Parent = player.Backpack
		end
		if not tool:GetAttribute("CocoaWired") then
			tool:SetAttribute("CocoaWired", true)
			tool.Activated:Connect(function()
				fireSnowball(player)
			end)
		end
	end
	Result:FireClient(player, drink.name .. " purchased — " .. drink.blurb)
end)

counter.ShopPrompt.Triggered:Connect(function(player)
	OpenShop:FireClient(player, player:GetAttribute("CocoaBucks") or 0)
end)
watchPart.WatchPrompt.Triggered:Connect(function(player)
	WatchGame:FireClient(player)
end)

-- Timed buffs, hangout recovery and passive cocoa earnings.
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = active(player, "CocoaRunUntil") and 28 or DEFAULT_WALK
			end
			if root then
				local distance = (root.Position - counter.Position).Magnitude
				if distance < HANGOUT_RANGE then
					if humanoid and humanoid.Health < humanoid.MaxHealth then
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 3)
					end
					if now - (lastHangout[player] or 0) > 8 then
						lastHangout[player] = now
						addCoins(player, HANGOUT_COINS)
					end
				end
			end
			if not active(player, "CocoaSnowUntil") then
				local tool = snowballTool(player)
				if tool then
					tool:Destroy()
				end
			end
		end
	end
end)
