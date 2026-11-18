--!nonstrict
-- Animates the Golden Wing Boots accessories. The wings are welded to the
-- feet with Motor6Ds (named SantaAvatar_WingMotorL/R), so rotating their
-- Transform each frame makes them flap without fighting the character rig.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function flap()
	local character = player.Character
	if not character then
		return
	end
	local outfit = player:GetAttribute("SantaOutfit")
	if outfit ~= "goldwings" then
		return
	end
	local t = os.clock()
	local angle = math.sin(t * 8) * 0.55
	local angleL = math.sin(t * 8 + math.pi) * 0.55
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") then
			if motor.Name == "SantaAvatar_WingMotorL" then
				motor.Transform = CFrame.Angles(0, 0, angleL)
			elseif motor.Name == "SantaAvatar_WingMotorR" then
				motor.Transform = CFrame.Angles(0, 0, angle)
			end
		end
	end
end

RunService.RenderStepped:Connect(flap)
