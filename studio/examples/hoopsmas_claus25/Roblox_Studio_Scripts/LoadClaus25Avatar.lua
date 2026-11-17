-- HoopsMas Claus #25 Avatar Builder Script for Roblox Studio
-- Place this script inside ServerScriptService or run it in the Studio Command Bar!
-- Replace the Asset IDs below once you upload the included PNGs and OBJs to Creator Hub.

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local AVATAR_CONFIG = {
    SkinColor = Color3.fromRGB(108, 68, 45), -- Warm Medium-Dark Brown matching reference
    ShirtAssetId = "rbxassetid://000000000", -- Upload 2D_Classic_Clothing/Claus25_Shirt_585x559.png
    PantsAssetId = "rbxassetid://000000000", -- Upload 2D_Classic_Clothing/Claus25_Pants_585x559.png
    Accessories = {
        {Name = "HoopsMas_SantaHat",   AssetId = 000000000}, -- HatAttachment
        {Name = "HoopsMas_Shades",     AssetId = 000000000}, -- FaceFrontAttachment
        {Name = "HoopsMas_Beard",      AssetId = 000000000}, -- FaceFrontAttachment
        {Name = "HoopsMas_Basketball", AssetId = 000000000}, -- RightGripAttachment
        {Name = "HoopsMas_WingLeft",   AssetId = 000000000}, -- LeftFootAttachment
        {Name = "HoopsMas_WingRight",  AssetId = 000000000}, -- RightFootAttachment
    }
}

local function applyClaus25Look(character)
    local humanoid = character:WaitForChild("Humanoid")
    local desc = humanoid:GetAppliedDescription()

    -- Apply R6/R15 Blocky Proportions
    desc.Head = 0
    desc.Torso = 0
    desc.LeftArm = 0
    desc.RightArm = 0
    desc.LeftLeg = 0
    desc.RightLeg = 0

    -- Apply Skin Tone across all body parts
    desc.HeadColor = AVATAR_CONFIG.SkinColor
    desc.TorsoColor = AVATAR_CONFIG.SkinColor
    desc.LeftArmColor = AVATAR_CONFIG.SkinColor
    desc.RightArmColor = AVATAR_CONFIG.SkinColor
    desc.LeftLegColor = AVATAR_CONFIG.SkinColor
    desc.RightLegColor = AVATAR_CONFIG.SkinColor

    -- Apply Classic 2D Clothing
    if AVATAR_CONFIG.ShirtAssetId ~= "rbxassetid://000000000" then
        desc.Shirt = tonumber(AVATAR_CONFIG.ShirtAssetId:match("%d+"))
    end
    if AVATAR_CONFIG.PantsAssetId ~= "rbxassetid://000000000" then
        desc.Pants = tonumber(AVATAR_CONFIG.PantsAssetId:match("%d+"))
    end

    humanoid:ApplyDescription(desc)
end

-- Spawn a preview Dummy in Workspace immediately if run from Command Bar
local function spawnStudioPreviewDummy()
    local dummy = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
    dummy.Name = "HoopsMas_Claus25_Rig"
    dummy.Parent = workspace
    dummy:PivotTo(CFrame.new(0, 5, 0))
    applyClaus25Look(dummy)
    print("[HoopsMas] Spawned Claus #25 R15 Avatar Rig in Workspace!")
end

spawnStudioPreviewDummy()
