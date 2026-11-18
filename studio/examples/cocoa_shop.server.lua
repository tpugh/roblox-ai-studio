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
local TweenService = game:GetService("TweenService")

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
-- Keyboard (B) and on-screen touch button fire through here; left-click still
-- fires through the Tool.Activated connection below.
local FireSnowball = remote("FireSnowball", "RemoteEvent")

local DRINKS = {
	run = { name = "Cocoa Rush", price = 15, seconds = 60, attr = "CocoaRunUntil", blurb = "Run faster for 60s" },
	shoot = { name = "Sharp Shooter Cocoa", price = 20, seconds = 60, attr = "CocoaShootUntil", blurb = "Sharper aim for 60s" },
	dunk = { name = "Slam Cocoa", price = 25, seconds = 60, attr = "CocoaDunkUntil", blurb = "Gamebreaker ready instantly" },
	steal = { name = "Steal Cocoa", price = 15, seconds = 60, attr = "CocoaStealUntil", blurb = "Longer, faster steals" },
	snow = { name = "Snowball Cocoa", price = 25, seconds = 90, attr = "CocoaSnowUntil", blurb = "Snowball gun, 30 rounds, knocks them down" },
}
local START_COINS = 30
local POINTS_TO_COINS = 5
local HANGOUT_COINS = 1
local HANGOUT_RANGE = 16
local DEFAULT_WALK = 16

local lastScore = {}
local lastHangout = {}
local lastSnowball = {}
local snowRounds = {} -- [player] = rounds left in the current gun (30 per purchase)
local SNOW_ROUNDS = 30

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

-- A chunky cyan snowball launcher with a steel barrel, pale muzzle and a
-- pink snowball in the cradle, styled after a bright cartoon blaster.
local function makeSnowballTool()
	local tool = Instance.new("Tool")
	tool.Name = "Snowball Gun"
	tool.RequiresHandle = false

	local CYAN = Color3.fromRGB(84, 214, 236)
	local CYAN_DARK = Color3.fromRGB(42, 148, 190)
	local INK = Color3.fromRGB(24, 28, 38)
	local STEEL = Color3.fromRGB(150, 158, 174)
	local WHITE = Color3.fromRGB(234, 242, 252)
	local PINK = Color3.fromRGB(255, 206, 218)

	local function put(name, shape, size, pos, colour, rot)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Position = pos
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		if rot then
			p.CFrame = CFrame.new(pos) * rot
		end
		p.Parent = tool
		return p
	end

	local handle = put("Handle", Enum.PartType.Block, Vector3.new(0.9, 0.72, 2.2), Vector3.new(0, 0, 0), CYAN)
	put("EdgeLeft", Enum.PartType.Block, Vector3.new(0.1, 0.82, 2.25), Vector3.new(-0.48, -0.02, 0), INK)
	put("EdgeRight", Enum.PartType.Block, Vector3.new(0.1, 0.82, 2.25), Vector3.new(0.48, -0.02, 0), INK)
	put("EdgeBottom", Enum.PartType.Block, Vector3.new(0.96, 0.1, 2.25), Vector3.new(0, -0.4, 0), INK)
	put("Shoulder", Enum.PartType.Block, Vector3.new(1.05, 0.24, 1.1), Vector3.new(0, 0.44, -0.55), CYAN_DARK,
		CFrame.Angles(0, 0, math.rad(-8)))
	put("Barrel", Enum.PartType.Cylinder, Vector3.new(0.5, 2.1, 0.5), Vector3.new(0, 0.42, 0.7), STEEL,
		CFrame.Angles(math.rad(90), 0, 0))
	put("Muzzle", Enum.PartType.Block, Vector3.new(1.02, 1.02, 0.6), Vector3.new(0, 0.42, 1.85), WHITE,
		CFrame.Angles(0, 0, math.rad(45)))
	put("MuzzleFace", Enum.PartType.Block, Vector3.new(0.62, 0.62, 0.12), Vector3.new(0, 0.42, 2.18), WHITE)
	put("SnowCradle", Enum.PartType.Cylinder, Vector3.new(0.86, 0.18, 0.86), Vector3.new(0, 0.78, 0.42), CYAN_DARK)
	put("LoadedSnowball", Enum.PartType.Ball, Vector3.new(0.74, 0.74, 0.74), Vector3.new(0, 1.06, 0.42), PINK)
	put("Grip", Enum.PartType.Block, Vector3.new(0.42, 0.86, 0.54), Vector3.new(0, -0.7, -0.62), CYAN,
		CFrame.Angles(math.rad(-18), 0, 0))
	put("GripTrim", Enum.PartType.Block, Vector3.new(0.5, 0.14, 0.6), Vector3.new(0, -1.08, -0.62), INK)

	for _, part in ipairs(tool:GetChildren()) do
		if part ~= handle and part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return tool
end

local function snowBurst(position)
	local holder = Instance.new("Part")
	holder.Name = "SnowBurst"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Anchored = true
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace

	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	puff.Lifetime = NumberRange.new(0.4, 0.8)
	puff.Speed = NumberRange.new(8, 18)
	puff.SpreadAngle = Vector2.new(180, 180)
	puff.Rate = 0
	puff.Parent = holder
	puff:Emit(28)
	task.delay(1.2, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- A snowball hit tips the target right off their feet. The root is anchored
-- and the Humanoid put in PlatformStand for the short cinematic, then fully
-- restored. This works on both player avatars and the BallSocket-constraint
-- Santas because only the root is posed, never the individual limbs.
local function knockDown(model, seconds, direction)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	if humanoid:GetAttribute("CocoaStunned") then
		return
	end

	local previousWalk = humanoid.WalkSpeed
	local previousStand = humanoid.PlatformStand
	local previousRotate = humanoid.AutoRotate
	local wasAnchored = root.Anchored
	local base = root.CFrame

	local away = typeof(direction) == "Vector3" and Vector3.new(direction.X, 0, direction.Z) or Vector3.new(0, 0, -1)
	if away.Magnitude < 0.01 then
		away = Vector3.new(0, 0, -1)
	end
	away = away.Unit

	humanoid:SetAttribute("CocoaStunned", true)
	humanoid.WalkSpeed = 0
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	root.Anchored = true

	local fallen = CFrame.new(base.Position - away * 1.3 + Vector3.new(0, -1.05, 0))
		* base.Rotation
		* CFrame.Angles(math.rad(78), 0, math.rad(16))

	task.spawn(function()
		snowBurst(base.Position + Vector3.new(0, -1.3, 0))
		local hitTween = TweenService:Create(root,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = fallen })
		hitTween:Play()
		hitTween.Completed:Wait()
		task.wait(math.max(0.55, seconds - 0.85))
		if not root.Parent then
			return
		end
		local rise = TweenService:Create(root,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = base })
		rise:Play()
		rise.Completed:Wait()
		if root.Parent then
			root.Anchored = wasAnchored
			humanoid.WalkSpeed = previousWalk
			humanoid.PlatformStand = previousStand
			humanoid.AutoRotate = previousRotate
			humanoid:SetAttribute("CocoaStunned", nil)
		end
	end)
end

local THUMP_ID = "rbxassetid://377958030" -- softball "thump", slowed down

local function thump(character)
	if not character then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "SnowGunThump"
	sound.SoundId = THUMP_ID
	sound.Volume = 0.65
	sound.PlaybackSpeed = 0.62
	local host = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
	if host then
		sound.Parent = host
		sound:Play()
		task.delay(1, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
end

-- A visible scatter of little white snowballs that fly out with each shot.
-- Only the main projectile can hit anyone; these are decoration.
local function snowScatter(origin, look)
	for i = 1, 6 do
		local pellet = Instance.new("Part")
		pellet.Name = "SnowPellet"
		pellet.Shape = Enum.PartType.Ball
		pellet.Size = Vector3.new(0.35 + math.random() * 0.2, 0.35 + math.random() * 0.2, 0.35 + math.random() * 0.2)
		pellet.Color = Color3.new(1, 1, 1)
		pellet.Material = Enum.Material.Snow
		pellet.CanCollide = false
		pellet.CanTouch = false
		pellet.CanQuery = false
		pellet.CFrame = CFrame.new(origin + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.8)
		pellet.AssemblyLinearVelocity = look * (62 + math.random() * 30)
			+ Vector3.new((math.random() - 0.5) * 12, 6 + math.random() * 6, (math.random() - 0.5) * 12)
		pellet.Parent = Workspace
		task.delay(1.1, function()
			if pellet.Parent then
				pellet:Destroy()
			end
		end)
	end
end

local function fireSnowball(player)
	local rounds = snowRounds[player] or 0
	if rounds <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastSnowball[player] or 0) < 0.7 then
		return
	end
	lastSnowball[player] = now

	rounds -= 1
	snowRounds[player] = rounds
	player:SetAttribute("SnowRounds", rounds)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	thump(character)

	local look = root.CFrame.LookVector
	local origin = root.Position + look * 2 + Vector3.new(0, 1.2, 0)
	snowScatter(origin, look)

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
		local model
		if hit:IsDescendantOf(Workspace.StreetDefenders) then
			model = hit:FindFirstAncestorOfClass("Model")
		elseif hit.Parent and hit.Parent:IsA("Model") and hit.Parent:GetAttribute("Team") then
			model = hit.Parent -- Santa-court Santas carry a Team attribute
		elseif hit.Parent and hit.Parent:IsA("Model") then
			local character = hit.Parent
			if Players:GetPlayerFromCharacter(character) and character ~= player.Character then
				model = character -- an opposing basketball player
			end
		end
		if model then
			knockDown(model, 2.2, ball.AssemblyLinearVelocity)
			ball:Destroy()
		end
	end)
	task.delay(3, function()
		if ball.Parent then
			ball:Destroy()
		end
	end)

	if rounds <= 0 then
		local tool = snowballTool(player)
		if tool then
			tool:Destroy()
		end
		Result:FireClient(player, "OUT OF SNOWBALLS! Buy Snowball Cocoa to reload.")
	end
end

-- Non-mouse firing: B key and the touch button both come through here. The
-- same purchase/ cooldown gates apply because fireSnowball owns the cooldown.
FireSnowball.OnServerEvent:Connect(function(player)
	if not active(player, "CocoaSnowUntil") then
		return
	end
	if not snowballTool(player) then
		return
	end
	fireSnowball(player)
end)

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
			if not snowRounds[player] then
				snowRounds[player] = SNOW_ROUNDS
			end
			player:SetAttribute("SnowRounds", snowRounds[player])
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
		snowRounds[player] = SNOW_ROUNDS
		player:SetAttribute("SnowRounds", SNOW_ROUNDS)
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
			if humanoid and not humanoid:GetAttribute("CocoaStunned") then
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
