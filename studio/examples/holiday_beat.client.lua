--!nonstrict
-- Holiday Beat — an original, procedently sequenced hip-hop Christmas loop.
-- External music assets are restricted in this experience, so the track is
-- built from the free one-shot SFX already licensed into the place: a pitched
---down ball bounce for kick and bass, a rim clank for snare and sleigh bells,
-- and a shot sound for hats. Runs per-client so each player can mute it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local BPM = 92
local STEP = 60 / BPM / 4 -- sixteenth note
local STEPS_PER_BAR = 16
local BARS = 4

local SFX = {
	kick = "rbxassetid://377958030",
	snare = "rbxassetid://81912260477958",
	hat = "rbxassetid://124140408144336",
	bass = "rbxassetid://377958030",
	bell = "rbxassetid://81912260477958",
	piano = "rbxassetid://584691395",
}

local function makeSound(name, id, volume)
	local sound = Instance.new("Sound")
	sound.Name = "HolidayBeat_" .. name
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local muted = false

local voices = {
	kick = makeSound("Kick", SFX.kick, 0.3),
	snare = makeSound("Snare", SFX.snare, 0.16),
	hat = makeSound("Hat", SFX.hat, 0.06),
	bass = makeSound("Bass", SFX.bass, 0.2),
	bell = makeSound("Bell", SFX.bell, 0.09),
	pianoA = makeSound("PianoA", SFX.piano, 0.09),
	pianoB = makeSound("PianoB", SFX.piano, 0.09),
	pianoC = makeSound("PianoC", SFX.piano, 0.09),
}

local function hit(name, speed)
	local sound = voices[name]
	if not sound or muted then
		return
	end
	sound.PlaybackSpeed = speed or 1
	sound:Play()
end

-- A simple Jingle Bells-style motif transcribed as playback speeds on the bell.
local NOTES = { C = 2.05, D = 2.25, E = 2.45, G = 2.8 }
local MELODY = {
	{ "E", "E", "E", "E" },
	{ "E", "E", "E", "E" },
	{ "E", "G", "C", "D" },
	{ "E", "E", "E", "D" },
}

-- Real piano notes: playback speed shifts the sample up or down the scale.
local PIANO = { C = 1.0, D = 1.12, E = 1.26, F = 1.34, G = 1.5, A = 1.68, B = 1.89 }
local CHORDS = {
	{ "C", "E", "G" }, -- C major
	{ "A", "C", "E" }, -- A minor
	{ "F", "A", "C" }, -- F major
	{ "G", "B", "D" }, -- G dominant
}
local ARP = { "E", "G", "C", "E", "E", "G", "C", "D" }

local gui = Instance.new("ScreenGui")
gui.Name = "HolidayBeatUI"
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
label.Text = "♪  HOHO HIP-HOP  ·  M mute"
label.Parent = gui

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.M then
		return
	end
	muted = not muted
	if muted then
		for _, sound in pairs(voices) do
			sound:Stop()
		end
		label.Text = "♪  MUSIC MUTED  ·  M play"
	else
		label.Text = "♪  HOHO HIP-HOP  ·  M mute"
	end
end)

-- Boom-bap drums with a swung hat and a sleigh-bell hook on top.
local step = 0
local total = STEPS_PER_BAR * BARS
while true do
	local inBar = step % STEPS_PER_BAR
	local bar = math.floor(step / STEPS_PER_BAR) % BARS + 1

	-- Kick: downbeat, the "and" of 2, and a syncopated pickup.
	if inBar == 0 or inBar == 6 or inBar == 11 then
		hit("kick", 0.42)
		hit("bass", 0.3)
	elseif inBar == 14 then
		hit("bass", 0.36)
	end
	-- Snare on 2 and 4.
	if inBar == 4 or inBar == 12 then
		hit("snare", 1.45)
	end
	-- Hats on every eighth note, with an occasional ghost note.
	if inBar % 2 == 0 then
		hit("hat", inBar % 4 == 2 and 3.4 or 3.0)
	elseif inBar == 7 or inBar == 15 then
		hit("hat", 3.8)
	end
	-- Sleigh-bell motif on the quarter notes.
	if inBar % 4 == 0 then
		local note = MELODY[bar][inBar / 4 + 1]
		if note then
			hit("bell", NOTES[note] or NOTES.E)
		end
	end
	-- Piano: a warm chord on each downbeat plus a rolling arpeggio.
	if inBar == 0 then
		local chord = CHORDS[bar]
		hit("pianoA", PIANO[chord[1]])
		hit("pianoB", PIANO[chord[2]])
		hit("pianoC", PIANO[chord[3]])
	end
	if inBar % 2 == 0 then
		local note = ARP[inBar / 2 + 1]
		if note then
			hit("pianoC", PIANO[note])
		end
	end
	-- Extra shimmer at the end of each two-bar phrase.
	if inBar == 15 and (bar == 2 or bar == 4) then
		hit("bell", 3.6)
	end

	step = (step + 1) % total
	task.wait(STEP)
end
