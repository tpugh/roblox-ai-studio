--!nonstrict
-- Roblox AI Studio runtime entry point.
-- Wires the generated registry (agents, events, pipelines) to the protocol
-- layer and exposes a single API for Studio scripts and MCP calls.

local Generated = script:WaitForChild("Config"):WaitForChild("Generated")

local Registry = require(Generated.Agents)
local Events = require(Generated.Events)
local Pipelines = require(Generated.Pipelines)

local Protocol = require(script.Protocol)
local Memory = require(script.Memory)
local Bus = require(script.Bus)
local Gates = require(script.Gates)
local Publish = require(script.Publish)
local Orchestrator = require(script.Orchestrator)
local GamepassAgents = require(script.Agents.Gamepass)
local CrossCuttingAgents = require(script.Agents.CrossCutting)
local GamepassPipeline = require(script.Pipelines.Gamepass)

local Runtime = {}

local memory = Memory.new(Registry)
local bus = Bus.new({ registry = Registry, events = Events })
local gates = Gates.new({ registry = Registry })
local publish = Publish.new({ gates = gates, memory = memory })
local orchestrator = Orchestrator.new({
	registry = Registry,
	events = Events,
	memory = memory,
	bus = bus,
	gates = gates,
	publish = publish,
})

-- Cross-pipeline signals are observed by the analytics agent.
bus:register("analytics-agent", function(message)
	memory:append("analytics-agent", {
		correlation_id = message.envelope.correlation_id,
		event = message.payload.type,
		source = message.envelope.from_agent,
	})
	return { ok = true, data = { received = true, event = message.payload.type } }
end)

-- Fixture provider: stand-in for competitor-intel-agent until a live pull is wired.
local COMPETITOR_FIXTURES = {
	["dungeon runs"] = { min = 150, max = 800, avg = 425, sample_size = 7 },
	["tower defense"] = { min = 100, max = 600, avg = 320, sample_size = 6 },
	default = { min = 100, max = 700, avg = 375, sample_size = 5 },
}
bus:registerProvider("competitor-intel-agent", function(query)
	local key = tostring(query.genre or ""):lower()
	local fixture = COMPETITOR_FIXTURES[key] or COMPETITOR_FIXTURES.default
	local out = table.clone(fixture)
	out.source = "competitor-intel-agent (fixture)"
	out.genre = query.genre
	return out
end)

bus:registerProvider("analytics-agent", function()
	return {
		segments = { "new", "mid-game", "endgame" },
		last_updated = Protocol.isoNow(),
		source = "analytics-agent (fixture)",
	}
end)

orchestrator:register(GamepassAgents.build({ protocol = Protocol, bus = bus }))
orchestrator:register(CrossCuttingAgents.build({ protocol = Protocol, bus = bus, memory = memory }))

local gamepass = GamepassPipeline.new({
	pipelines = Pipelines,
	events = Events,
	bus = bus,
	orchestrator = orchestrator,
	publish = publish,
	gates = gates,
})

Runtime.Version = "1.0.0"
Runtime.Registry = Registry
Runtime.Events = Events
Runtime.Pipelines = Pipelines
Runtime.protocol = Protocol
Runtime.memory = memory
Runtime.bus = bus
Runtime.gates = gates
Runtime.publish = publish
Runtime.orchestrator = orchestrator
Runtime.gamepass = gamepass

Runtime.IMPLEMENTED_AGENTS = {
	"analytics-agent",
	"gamepass-designer",
	"perk-balancer",
	"conversion-copywriter",
	"pricing-analyst",
	"lua-script-writer",
	"tos-compliance-agent",
}

function Runtime.runGamepass(opportunity, opts)
	return gamepass:run(opportunity, opts)
end

Runtime.DEMO_OPPORTUNITY = {
	segment = "mid-game grinders",
	avg_session_minutes = 18,
	top_activity = "dungeon runs",
	drop_off_point = "upgrade timer wall",
	player_count = 1240,
}

function Runtime.runDemo()
	local report = Runtime.runGamepass(Runtime.DEMO_OPPORTUNITY)
	local summary = {
		correlation_id = report.correlation_id,
		decision = report.decision,
		concept = report.concept and report.concept.name,
		price = report.stage_results.pricing and report.stage_results.pricing.recommended_price,
		decisions = report.decisions,
		publish = report.publish,
		blocked_at = report.blocked_at,
		error = report.error,
	}
	print("[RobloxAIStudio] demo " .. tostring(summary.decision) .. " — " .. tostring(summary.concept))
	return summary
end

-- Proves the gate: an unreviewed asset cannot publish, scam copy is rejected,
-- and compliant copy publishes only after approval.
function Runtime.demonstrateGate()
	local outcomes = {}

	local blocked = publish:request({ asset = "gamepass/unreviewed-demo", correlation_id = Protocol.uuid() })
	outcomes.unreviewed_publish_blocked = {
		pass = Protocol.errorCode(blocked) == "TOS_VIOLATION",
		code = Protocol.errorCode(blocked),
	}

	local scamArtifact = {
		asset_id = "marketing/scam-demo",
		asset_type = "marketing",
		artifact = {
			copy = {
				title = "Free Robux Generator",
				short_description = "Ends tonight!",
				full_description = "Claim free robux now, only today.",
			},
		},
	}
	local scamReview = orchestrator:syncReview({
		requester = "community-manager",
		owner = "tos-compliance-agent",
		asset = "marketing/scam-demo",
		asset_type = "marketing",
		payload_type = "publish_review",
		correlation_id = Protocol.uuid(),
		data = scamArtifact,
	})
	outcomes.scam_copy_rejected = {
		pass = scamReview.decision == "rejected",
		decision = scamReview.decision,
		violations = scamReview.result and scamReview.result.data.violations,
	}
	local blockedScam = publish:request({ asset = "marketing/scam-demo" })
	outcomes.scam_publish_blocked = { pass = Protocol.errorCode(blockedScam) == "TOS_VIOLATION" }

	local cleanArtifact = {
		asset_id = "marketing/clean-demo",
		asset_type = "marketing",
		artifact = {
			copy = {
				title = "New Dungeon Update",
				short_description = "Three new rooms and a boss.",
				full_description = "Three new rooms, a new boss, and rebalanced loot. Live this Friday.",
			},
		},
	}
	local cleanReview = orchestrator:syncReview({
		requester = "community-manager",
		owner = "tos-compliance-agent",
		asset = "marketing/clean-demo",
		asset_type = "marketing",
		payload_type = "publish_review",
		correlation_id = Protocol.uuid(),
		data = cleanArtifact,
	})
	outcomes.clean_copy_approved = { pass = cleanReview.decision == "approved", decision = cleanReview.decision }
	local publishedClean = publish:request({ asset = "marketing/clean-demo", asset_type = "marketing" })
	outcomes.clean_publish_allowed = { pass = publishedClean.status == "published" }

	local passed = 0
	local total = 0
	for _, outcome in pairs(outcomes) do
		total += 1
		if outcome.pass then
			passed += 1
		end
	end
	outcomes.summary = { passed = passed, total = total, ok = passed == total }
	return outcomes
end

function Runtime.snapshot()
	return {
		version = Runtime.Version,
		registry = {
			agents = (function()
				local count = 0
				for _ in pairs(Registry) do
					count += 1
				end
				return count
			end)(),
			events = (function()
				local count = 0
				for _ in pairs(Events) do
					count += 1
				end
				return count
			end)(),
			pipelines = (function()
				local count = 0
				for _ in pairs(Pipelines) do
					count += 1
				end
				return count
			end)(),
			implemented = Runtime.IMPLEMENTED_AGENTS,
		},
		bus = bus:stats(),
		gates = gates:stats(),
		publish = publish:stats(),
		orchestrator = orchestrator.metrics,
		memory_entries = memory:count(),
	}
end

function Runtime.trace(correlationId)
	return orchestrator.workflows[correlationId]
end

function Runtime.memoryDump()
	return memory:dump()
end

return Runtime
