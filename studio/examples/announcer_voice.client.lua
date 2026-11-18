--!nonstrict
-- Plays the game announcer's voice as 2D audio on each client. Parenting the
-- Sound to PlayerGui (rather than a part in the world) means it is never
-- attenuated by distance, so the callouts are always heard anywhere on court.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BallRemotes", 10)
local announceVoice = remotes and remotes:FindFirstChild("AnnounceVoice", 10)
if not announceVoice then
	return
end

local activeSound
announceVoice.OnClientEvent:Connect(function(assetId)
	if type(assetId) ~= "number" or assetId <= 0 then
		return
	end
	if activeSound then
		activeSound:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnnouncerVoiceLocal"
	sound.SoundId = "rbxassetid://" .. tostring(assetId)
	sound.Volume = 1
	sound.PlaybackSpeed = 1
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()
	activeSound = sound
	task.delay(4, function()
		if activeSound == sound and sound.Parent then
			sound:Destroy()
			activeSound = nil
		end
	end)
end)
