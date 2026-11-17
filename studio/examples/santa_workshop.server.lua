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

local AVATARS = {
	santa = {
		name = "Classic Santa", price = 60, coat = RED, pants = RED,
		hat = RED, beard = true, belt = true, boots = BLACK,
	},
	mrs = {
		name = "Mrs Claus", price = 50, coat = RED, pants = DARK_RED,
		hat = RED, hair = true, boots = BLACK,
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
			accessory("Hat", Enum.PartType.Cylinder, Vector3.new(1.5, 1.1, 1.5), def.hat, head,
				CFrame.new(0, 1.4, 0), CFrame.Angles(0, 0, math.pi / 2))
			accessory("HatCuff", Enum.PartType.Cylinder, Vector3.new(1.6, 0.35, 1.6), WHITE, head,
				CFrame.new(0, 1, 0), CFrame.Angles(0, 0, math.pi / 2))
			accessory("Pom", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), WHITE, head,
				CFrame.new(0, 2.1, -0.2))
		end
		if def.beard then
			accessory("Beard", Enum.PartType.Ball, Vector3.new(1.7, 1.5, 0.9), WHITE, head,
				CFrame.new(0, -0.9, 1.1))
		end
		if def.hair then
			accessory("Hair", Enum.PartType.Ball, Vector3.new(1.8, 1.1, 1.6), WHITE, head,
				CFrame.new(0, 1.1, -0.1))
		end
		if def.antlers then
			for side = -1, 1, 2 do
				accessory("Antler", Enum.PartType.Cylinder, Vector3.new(0.2, 1.6, 0.2), BROWN, head,
					CFrame.new(side * 0.45, 1.6, 0), CFrame.Angles(0, 0, side * 0.45))
			end
		end
		if def.nose then
			accessory("Nose", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), RED, head,
				CFrame.new(0, -0.2, 1.3))
		end
		if def.carrot then
			accessory("Carrot", Enum.PartType.Cylinder, Vector3.new(0.3, 1.1, 0.3), Color3.fromRGB(240, 140, 40), head,
				CFrame.new(0, -0.2, 1.5), CFrame.Angles(math.pi / 2, 0, 0))
		end
		if def.ears then
			for side = -1, 1, 2 do
				accessory("Ear", Enum.PartType.Ball, Vector3.new(0.5, 0.9, 0.4), SKIN, head,
					CFrame.new(side * 1.05, 0, 0))
			end
		end
	end
	if def.belt and torso and torso:IsA("BasePart") then
		accessory("Belt", Enum.PartType.Block, Vector3.new(2.6, 0.45, 1.6), BLACK, torso,
			CFrame.new(0, -0.6, 0.55))
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
