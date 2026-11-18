--!nonstrict
-- Santa Workshop avatar boutique. Players spend Cocoa Bucks on Santa-themed
-- outfits that are applied to their own character, so they keep all their
-- normal movement and basketball abilities. Outfits are cosmetic only.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local stand = Workspace:FindFirstChild("SantaWorkshopStand")
if not stand then
	warn("[SantaWorkshop] boutique stand is missing")
	return
end
local counter = stand:FindFirstChild("Counter")
if not counter then
	warn("[SantaWorkshop] boutique counter is missing")
	return
end

local remotes = ReplicatedStorage:FindFirstChild("SantaWorkshopRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "SantaWorkshopRemotes"
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
local Unequip = remote("Unequip", "RemoteEvent")
local Result = remote("Result", "RemoteEvent")

local RED = Color3.fromRGB(190, 38, 46)
local DARK_RED = Color3.fromRGB(138, 28, 36)
local GREEN = Color3.fromRGB(32, 116, 70)
local WHITE = Color3.fromRGB(245, 245, 240)
local BLACK = Color3.fromRGB(32, 28, 30)
local BROWN = Color3.fromRGB(129, 84, 52)
local SKIN = Color3.fromRGB(232, 194, 158)
local GOLD = Color3.fromRGB(255, 214, 120)

local AVATARS = {
	santa = {
		name = "Classic Santa", price = 60, coat = RED, pants = RED,
		hat = RED, beard = true, belt = true, boots = BLACK,
	},
	mrs = {
		name = "Mrs Claus", price = 50, coat = RED, pants = DARK_RED,
		hat = RED, hair = true, boots = BLACK, apron = true,
	},
	elf = {
		name = "Workshop Elf", price = 40, coat = GREEN, pants = GREEN,
		hat = GREEN, ears = true, boots = BLACK,
	},
	reindeer = {
		name = "Reindeer", price = 55, coat = BROWN, pants = BROWN, headColor = BROWN,
		antlers = true, nose = true, boots = BROWN,
	},
	snowman = {
		name = "Snowman", price = 50, coat = WHITE, pants = WHITE, headColor = WHITE,
		hat = BLACK, carrot = true, boots = BLACK,
	},
	goldwings = {
		name = "Golden Wing Boots", price = 70, coat = Color3.fromRGB(120, 80, 30),
		pants = Color3.fromRGB(90, 60, 20), hat = GOLD, head = SKIN,
		boots = GOLD, wings = true, hair = false,
	},
}

local originalColors = {} -- [player] = { [part] = Color3 }

local outfitParts = {
	"Head",
	"UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local function rememberColors(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player or originalColors[player] then
		return
	end
	local saved = {}
	for _, name in ipairs(outfitParts) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			saved[part] = part.Color
		end
	end
	originalColors[player] = saved
end

local function clearOutfit(character)
	for _, child in ipairs(character:GetChildren()) do
		if string.sub(child.Name, 1, 12) == "SantaAvatar_" then
			child:Destroy()
		end
	end
end

local function accessory(name, shape, size, color, anchor, offset, rotation)
	local part = Instance.new("Part")
	part.Name = "SantaAvatar_" .. name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = anchor.CFrame * (offset or CFrame.new()) * (rotation or CFrame.new())
	part.Parent = anchor.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyOutfit(player, id)
	local def = AVATARS[id]
	local character = player.Character
	if not def or not character then
		return
	end
	rememberColors(character)
	clearOutfit(character)

	for part, colour in pairs(originalColors[player] or {}) do
		if part.Parent then
			part.Color = colour
		end
	end
	for part, colour in pairs(originalColors[player] or {}) do
		if part.Parent then
			local name = part.Name
			local isBoot = name == "LeftFoot" or name == "RightFoot"
			if isBoot and def.boots then
				part.Color = def.boots
			elseif name == "Head" then
				if def.headColor then
					part.Color = def.headColor
				end
			elseif string.find(name, "Arm") or string.find(name, "Leg") or string.find(name, "Torso") or name == "Torso" then
				part.Color = string.find(name, "Leg") and def.pants or def.coat
			end
		end
	end

	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if head and head:IsA("BasePart") then
		if def.hat then
			accessory("HatBrim", Enum.PartType.Cylinder, Vector3.new(1.7, 0.22, 1.7), def.hat, head,
				CFrame.new(0, 0.95, 0), CFrame.Angles(0, 0, math.pi / 2))
			accessory("HatBody", Enum.PartType.Cylinder, Vector3.new(1.35, 1.5, 1.35), def.hat, head,
				CFrame.new(0, 1.65, 0), CFrame.Angles(0, 0, math.pi / 2))
			accessory("HatTip", Enum.PartType.Ball, Vector3.new(0.85, 0.85, 0.85), def.hat, head,
				CFrame.new(0, 2.6, -0.35))
			accessory("Pom", Enum.PartType.Ball, Vector3.new(0.75, 0.75, 0.75), WHITE, head,
				CFrame.new(0, 2.95, -0.5))
			accessory("HatCuff", Enum.PartType.Cylinder, Vector3.new(1.5, 0.3, 1.5), WHITE, head,
				CFrame.new(0, 1.0, 0), CFrame.Angles(0, 0, math.pi / 2))
		end
		if def.beard then
			-- Layered balls form a fuller, rounded beard instead of a single flat disc.
			accessory("BeardTop", Enum.PartType.Ball, Vector3.new(1.55, 0.95, 1.05), WHITE, head,
				CFrame.new(0, -0.65, -1.05))
			accessory("BeardMid", Enum.PartType.Ball, Vector3.new(1.75, 1.05, 1.15), WHITE, head,
				CFrame.new(0, -1.0, -1.1))
			accessory("BeardLower", Enum.PartType.Ball, Vector3.new(1.45, 0.85, 1.0), WHITE, head,
				CFrame.new(0, -1.35, -0.9))
			accessory("BeardBottom", Enum.PartType.Ball, Vector3.new(1.15, 0.7, 0.85), WHITE, head,
				CFrame.new(0, -1.6, -0.7))
			accessory("MoustacheL", Enum.PartType.Ball, Vector3.new(0.55, 0.22, 0.35), WHITE, head,
				CFrame.new(-0.3, 2.42, -0.5))
			accessory("MoustacheR", Enum.PartType.Ball, Vector3.new(0.55, 0.22, 0.35), WHITE, head,
				CFrame.new(0.3, 2.42, -0.5))
		end
		if def.hair then
			accessory("Hair", Enum.PartType.Ball, Vector3.new(1.8, 1.1, 1.6), WHITE, head,
				CFrame.new(0, 1.1, -0.1))
		end
		if def.antlers then
			for side = -1, 1, 2 do
				accessory("Antler", Enum.PartType.Cylinder, Vector3.new(0.2, 1.6, 0.2), BROWN, head,
					CFrame.new(side * 0.45, 1.6, 0), CFrame.Angles(0, 0, side * 0.45))
				accessory("AntlerBranch1", Enum.PartType.Cylinder, Vector3.new(0.14, 1.0, 0.14), BROWN, head,
					CFrame.new(side * 0.9, 2.05, 0.3), CFrame.Angles(0, 0, side * 0.75))
				accessory("AntlerBranch2", Enum.PartType.Cylinder, Vector3.new(0.14, 0.8, 0.14), BROWN, head,
					CFrame.new(side * 0.95, 1.85, -0.25), CFrame.Angles(0, 0, side * -0.3))
				accessory("AntlerTip", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), BROWN, head,
					CFrame.new(side * 1.25, 2.35, 0.35))
			end
		end
		if def.nose then
			accessory("Nose", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), RED, head,
				CFrame.new(0, -0.2, 1.3))
		end
		if def.antlers then
			accessory("Tail", Enum.PartType.Ball, Vector3.new(0.7, 0.6, 0.7), BROWN, torso,
				CFrame.new(0, -0.4, -0.9))
		end
		if def.carrot then
			accessory("Carrot", Enum.PartType.Cylinder, Vector3.new(0.3, 1.1, 0.3), Color3.fromRGB(240, 140, 40), head,
				CFrame.new(0, -0.2, 1.5), CFrame.Angles(math.pi / 2, 0, 0))
		end
		if def.topHat then
			accessory("TopHatBand", Enum.PartType.Cylinder, Vector3.new(1.25, 0.25, 1.25), Color3.fromRGB(190, 38, 46), head,
				CFrame.new(0, 2.78, 0), CFrame.Angles(0, 0, math.pi / 2))
			for i = 0, 2 do
				accessory("CoalButton" .. i, Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28), BLACK, torso,
					CFrame.new(0, 1.3 - i * 0.4, 0.6))
			end
			accessory("Scarf", Enum.PartType.Block, Vector3.new(2.0, 0.35, 1.7), Color3.fromRGB(190, 38, 46), torso,
				CFrame.new(0, 0.35, 0.6))
		end
		if def.ears then
			for side = -1, 1, 2 do
				accessory("Ear", Enum.PartType.Ball, Vector3.new(0.5, 0.9, 0.4), SKIN, head,
					CFrame.new(side * 1.05, 0, 0))
			end
			accessory("JingleBell", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), GOLD, head,
				CFrame.new(0, 3.35, 0))
		end
	end
	if def.belt and torso and torso:IsA("BasePart") then
		accessory("Belt", Enum.PartType.Block, Vector3.new(2.6, 0.45, 1.6), BLACK, torso,
			CFrame.new(0, -0.6, 0.55))
	end
	if def.apron and torso and torso:IsA("BasePart") then
		accessory("Apron", Enum.PartType.Block, Vector3.new(2.4, 1.9, 0.22), WHITE, torso,
			CFrame.new(0, 0.2, 0.85))
		accessory("ApronBow", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.4), WHITE, torso,
			CFrame.new(0, 1.25, 0.9))
	end
	if def.wings and torso and torso:IsA("BasePart") then
		accessory("Cape", Enum.PartType.Block, Vector3.new(2.2, 2.4, 0.18), Color3.fromRGB(120, 80, 30), torso,
			CFrame.new(0, 0.4, -0.9))
		accessory("CapeTrim", Enum.PartType.Block, Vector3.new(2.25, 0.18, 0.22), GOLD, torso,
			CFrame.new(0, 1.6, -0.9))
	end
	-- Golden Wing Boots: a pair of flapping wings welded to each foot with a
	-- Motor6D so the client can animate them without fighting the rig.
	if def.wings then
		for _, side in ipairs({ -1, 1 }) do
			local foot = character:FindFirstChild(side == -1 and "LeftFoot" or "RightFoot")
			if foot and foot:IsA("BasePart") then
				local wing = Instance.new("Part")
				wing.Name = side == -1 and "SantaAvatar_WingL" or "SantaAvatar_WingR"
				wing.Shape = Enum.PartType.Block
				wing.Size = Vector3.new(1.7, 0.14, 1.05)
				wing.Color = GOLD
				wing.Material = Enum.Material.SmoothPlastic
				wing.CanCollide = false
				wing.CanTouch = false
				wing.CanQuery = false
				wing.CFrame = foot.CFrame * CFrame.new(side * 0.35, 0.45, -0.25)
					* CFrame.Angles(math.rad(-30), side * math.rad(22), side * math.rad(35))
				wing.Parent = foot.Parent

				local motor = Instance.new("Motor6D")
				motor.Name = side == -1 and "SantaAvatar_WingMotorL" or "SantaAvatar_WingMotorR"
				motor.Part0 = foot
				motor.Part1 = wing
				motor.C0 = CFrame.new(side * 0.35, 0.45, -0.25) * CFrame.Angles(math.rad(-30), side * math.rad(22), side * math.rad(35))
				motor.C1 = CFrame.new(0, 0, 0)
				motor.Parent = wing
			end
		end
	end
	player:SetAttribute("SantaOutfit", id)
end

for _, player in ipairs(Players:GetPlayers()) do
	local function watch()
		player.CharacterAdded:Connect(function()
			local id = player:GetAttribute("SantaOutfit")
			if id and AVATARS[id] then
				task.wait(0.2)
				applyOutfit(player, id)
			end
		end)
	end
	watch()
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local id = player:GetAttribute("SantaOutfit")
		if id and AVATARS[id] then
			task.wait(0.2)
			applyOutfit(player, id)
		end
	end)
end)

counter.AvatarPrompt.Triggered:Connect(function(player)
	OpenShop:FireClient(player, player:GetAttribute("CocoaBucks") or 0, player:GetAttribute("SantaOutfit"))
end)

Purchase.OnServerEvent:Connect(function(player, id)
	local def = AVATARS[id]
	if not def then
		return
	end
	local coins = player:GetAttribute("CocoaBucks") or 0
	if coins < def.price then
		Result:FireClient(player, "Not enough Cocoa Bucks — score some hoops!")
		return
	end
	player:SetAttribute("CocoaBucks", coins - def.price)
	applyOutfit(player, id)
	Result:FireClient(player, def.name .. " is yours! Wear it with pride.")
end)

Unequip.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then
		return
	end
	clearOutfit(character)
	for part, colour in pairs(originalColors[player] or {}) do
		if part.Parent then
			part.Color = colour
		end
	end
	player:SetAttribute("SantaOutfit", nil)
	Result:FireClient(player, "Back to your usual look.")
end)
