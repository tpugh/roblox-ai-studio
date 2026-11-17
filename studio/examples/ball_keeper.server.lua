--!nonstrict
-- BallKeeper — keeps the loose basketball props inside the fenced court.
--
-- This is NOT gameplay. There is no pickup, no scoring and no UI: the court is
-- a pure level and the balls are plain physics props. The only job here is to
-- put a ball that has left the enclosure back where it was built, because a
-- stray ball is otherwise unrecoverable by hand.
--
-- Each ball carries a `HomeCFrame` attribute written by the court builder, so
-- this never has to guess where "home" is and a ball that starts out stray is
-- still recoverable. Balls without the attribute fall back to wherever they
-- were first seen inside the fence.
--
-- Install as a Script under ServerScriptService. The court builder
-- (street_basketball_court.lua) does not create this; see its header.

local Workspace = game:GetService("Workspace")

local CONFIG = {
	modelName = "StreetBasketballCourt",
	pollSeconds = 0.25,
	fenceX = 47.5, -- fence line; a ball beyond it is out
	fenceZ = 30.0,
	floorY = 0.3, -- below the plaza top (0.24): it fell off the edge
	resetCooldown = 2,
	resetHoldSeconds = 0.1,
}

local captured = {} -- [BasePart] = first CFrame seen inside the fence
local lastReset = {}

-- The court model may widen the keep-in box: the Christmas holiday court is
-- 38 x 52 studs with hoops 3 studs past each baseline, which is wider than the
-- street court's fence. Attributes let one keeper serve both layouts.
local function boundsOf(model)
	return model:GetAttribute("KeepInBoundsX") or CONFIG.fenceX,
		model:GetAttribute("KeepInBoundsZ") or CONFIG.fenceZ,
		model:GetAttribute("KeepAboveY") or CONFIG.floorY
end

local function isStray(position, boundX, boundZ, floorY)
	return math.abs(position.X) > boundX
		or math.abs(position.Z) > boundZ
		or position.Y < floorY
end

local function homeOf(ball)
	local home = ball:GetAttribute("HomeCFrame")
	if typeof(home) == "CFrame" then
		return home
	end
	return captured[ball]
end

local function resetBall(ball)
	local target = homeOf(ball)
	if not target then
		return
	end
	local now = os.clock()
	if lastReset[ball] and now - lastReset[ball] < CONFIG.resetCooldown then
		return
	end
	lastReset[ball] = now
	-- Anchor for a frame so the teleport sticks instead of being interpolated.
	ball.Anchored = true
	ball.CanCollide = true -- a reset during a throw's no-collide window must not leave it hollow
	ball.CFrame = target
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	task.delay(CONFIG.resetHoldSeconds, function()
		if ball.Parent then
			ball.Anchored = false
		end
	end)
end

local function sweep()
	local model = Workspace:FindFirstChild(CONFIG.modelName)
	if not model then
		return
	end
	local props = model:FindFirstChild("Props")
	if not props then
		return
	end
	local boundX, boundZ, floorY = boundsOf(model)
	for _, object in ipairs(props:GetChildren()) do
		if object.Name == "Basketball" and object:IsA("BasePart") then
			if not homeOf(object) and not isStray(object.Position, boundX, boundZ, floorY) then
				captured[object] = object.CFrame
			end
			if isStray(object.Position, boundX, boundZ, floorY) and homeOf(object) then
				resetBall(object)
			end
		end
	end
	-- Forget balls that were destroyed by a rebuild.
	for ball in pairs(captured) do
		if not ball.Parent then
			captured[ball] = nil
			lastReset[ball] = nil
		end
	end
end

while true do
	task.wait(CONFIG.pollSeconds)
	sweep()
end
