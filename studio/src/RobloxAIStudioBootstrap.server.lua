--!nonstrict
-- Boots the Roblox AI Studio runtime in a running server.
-- The runtime itself lives in ReplicatedStorage.RobloxAIStudio (ModuleScript).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local runtime = require(ReplicatedStorage:WaitForChild("RobloxAIStudio"))

_G.RobloxAIStudio = runtime
workspace:SetAttribute("RobloxAIStudioReady", true)
workspace:SetAttribute("RobloxAIStudioVersion", runtime.Version)

print(string.format(
	"[RobloxAIStudio] runtime %s ready — %d implemented agents, %d pipelines",
	runtime.Version,
	#runtime.IMPLEMENTED_AGENTS,
	(function()
		local count = 0
		for _ in pairs(runtime.Pipelines) do
			count += 1
		end
		return count
	end)()
))

-- Set workspace.RobloxAIStudioAutoDemo = true before a playtest to run the
-- gamepass pipeline once and print the gate results.
workspace:GetAttributeChangedSignal("RobloxAIStudioAutoDemo"):Connect(function()
	if workspace:GetAttribute("RobloxAIStudioAutoDemo") ~= true then
		return
	end
	workspace:SetAttribute("RobloxAIStudioAutoDemo", false)
	local report = runtime.runGamepass(runtime.DEMO_OPPORTUNITY)
	print("[RobloxAIStudio] demo decision: " .. tostring(report.decision))
	print("[RobloxAIStudio] correlation: " .. tostring(report.correlation_id))
	local gateResults = runtime.demonstrateGate()
	for name, result in pairs(gateResults) do
		if type(result) == "table" and result.pass ~= nil then
			print(string.format("[RobloxAIStudio] gate %s: %s", name, tostring(result.pass)))
		end
	end
end)
