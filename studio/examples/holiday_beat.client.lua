--!nonstrict
-- Holiday Piano — a slow, smooth solo-piano version of the seasonal loop.
-- One licensed piano note sample is pitched into chords and arpeggios, with
-- gentle volume fades so notes bloom instead of hitting like percussion.
-- Runs per-client; press M to mute.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local BPM = 72
local STEP = 60 / BPM / 4
local STEPS_PER_BAR = 16
local BARS = 4
local PIANO_ID = "rbxassetid://584691395"

local muted = false

local function makeVoice(name)
	local sound = Instance.new("Sound")
	sound.Name = "HolidayPiano_" .. name
	sound.SoundId = PIANO_ID
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

local voices = {
	A = makeVoice("A"),
	B = makeVoice("B"),
	C = makeVoice("C"),
	ARP = makeVoice("ARP"),
	ECHO = makeVoice("ECHO"),
}

-- Playback speed shifts the sample up or down the scale.
local NOTE = { C = 1.0, D = 1.12, E = 1.26, F = 1.34, G = 1.5, A = 1.68, B = 1.89 }
local CHORDS = {
	{ "C", "E", "G" }, -- C major
	{ "A", "C", "E" }, -- A minor
	{ "F", "A", "C" }, -- F major
	{ "G", "B", "D" }, -- G dominant
}
local ARP = { "E", "C", "G", "E", "E", "C", "A", "D" }

local function note(voice, pitch, level, attack, release)
	if muted then
		return
	end
	local sound = voices[voice]
	sound.PlaybackSpeed = pitch
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(attack), { Volume = level }):Play()
	task.delay(attack + 0.25, function()
		if sound.Parent and sound.IsPlaying then
			TweenService:Create(sound, TweenInfo.new(release), { Volume = 0 }):Play()
		end
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "HolidayPianoUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "MusicTag"
label.AnchorPoint = Vector2.new(0, 1)
label.Position = UDim2.new(0, 16, 1, -16)
label.Size = UDim2.fromOffset(320, 26)
label.BackgroundColor3 = Color3.fromRGB(28, 22, 26)
label.BackgroundTransparency = 0.45
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextColor3 = Color3.fromRGB(255, 226, 160)
label.TextStrokeTransparency = 0.6
label.Text = "♪  HOLIDAY PIANO  ·  M mute"
label.Parent = gui

local function toggleMute()
	muted = not muted
	if muted then
		for _, sound in pairs(voices) do
			sound:Stop()
		end
		label.Text = "♪  MUSIC MUTED  ·  M play"
	else
		label.Text = "♪  HOLIDAY PIANO  ·  M mute"
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.M then
		return
	end
	toggleMute()
end)

-- Mobile MUSIC button uses this rather than a keyboard key.
local muteToggle = ReplicatedStorage:FindFirstChild("MusicMuteToggle")
if not muteToggle then
	muteToggle = Instance.new("BindableEvent")
	muteToggle.Name = "MusicMuteToggle"
	muteToggle.Parent = ReplicatedStorage
end
muteToggle.Event:Connect(toggleMute)

local step = 0
local total = STEPS_PER_BAR * BARS
while true do
	local inBar = step % STEPS_PER_BAR
	local bar = math.floor(step / STEPS_PER_BAR) % BARS + 1

	-- A soft chord blooms at the start of every bar.
	if inBar == 0 then
		local chord = CHORDS[bar]
		note("A", NOTE[chord[1]], 0.1, 0.22, 1.6)
		note("B", NOTE[chord[2]], 0.085, 0.3, 1.7)
		note("C", NOTE[chord[3]], 0.08, 0.38, 1.8)
	end

	-- Three gentle arpeggio notes with a quiet echo behind each one.
	if inBar == 4 or inBar == 8 or inBar == 12 then
		local pitch = NOTE[ARP[math.floor(inBar / 4) + (bar - 1) * 2] or "E"] or NOTE.E
		note("ARP", pitch, 0.11, 0.1, 0.9)
		task.delay(0.16, function()
			note("ECHO", pitch, 0.035, 0.12, 0.8)
		end)
	end

	step = (step + 1) % total
	task.wait(STEP)
end
