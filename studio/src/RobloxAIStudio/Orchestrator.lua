--!nonstrict
-- Orchestrator: routes protocol traffic, tracks workflow state, logs memory,
-- and runs SYNC reviews end to end.
-- Mirrors agents/cross-cutting/orchestrator-runtime-agent.md.

local Protocol = require(script.Parent.Protocol)

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator.new(config)
	local self = setmetatable({}, Orchestrator)
	self.registry = config.registry or {}
	self.events = config.events or {}
	self.memory = config.memory
	self.bus = config.bus
	self.gates = config.gates
	self.publish = config.publish
	self.workflows = {}
	self.metrics = {
		stages = 0,
		errors = 0,
		retries = 0,
		sync_reviews = 0,
		escalations = 0,
	}
	self.trace = {}
	return self
end

function Orchestrator:register(agentHandlers)
	for slug, handler in pairs(agentHandlers) do
		self.bus:register(slug, handler)
	end
end

function Orchestrator:workflow(correlationId, pipelineName)
	local state = self.workflows[correlationId]
	if not state then
		state = {
			correlation_id = correlationId,
			pipeline = pipelineName,
			step = "created",
			waiting_on = nil,
			started_at = Protocol.isoNow(),
			history = {},
		}
		self.workflows[correlationId] = state
		table.insert(self.trace, { correlation_id = correlationId, at = state.started_at, event = "workflow_created", pipeline = pipelineName })
	end
	return state
end

function Orchestrator:advance(correlationId, step, agent, status, detail)
	local state = self.workflows[correlationId]
	if not state then
		return
	end
	state.step = step
	state.waiting_on = (status == "waiting") and agent or nil
	table.insert(state.history, {
		step = step,
		agent = agent,
		status = status,
		detail = detail,
		at = Protocol.isoNow(),
	})
	table.insert(self.trace, {
		correlation_id = correlationId,
		at = Protocol.isoNow(),
		event = step,
		agent = agent,
		status = status,
	})
end

function Orchestrator:log(agent, fields)
	if not self.memory then
		return nil
	end
	return self.memory:append(agent, fields)
end

function Orchestrator:invoke(agent, data, opts)
	opts = opts or {}
	assert(self.registry[agent], "unknown agent: " .. tostring(agent))
	local from = opts.from or "orchestrator-runtime-agent"
	local protocol = opts.protocol or "push"
	local payloadType = opts.payload_type or "work"

	local result, message
	if protocol == "event" then
		if self.events[payloadType] then
			result = self.bus:emit(payloadType, from, data, {
				priority = opts.priority,
				correlation_id = opts.correlation_id,
			})
			-- emit returns a broadcast summary; the target's own result is the first delivery
			for _, delivery in ipairs(result.deliveries or {}) do
				if delivery.agent == agent then
					result = delivery.result
				end
			end
		else
			result, message = self.bus:deliver("event", from, agent, payloadType, data, {
				priority = opts.priority,
				correlation_id = opts.correlation_id,
			})
		end
	elseif protocol == "sync" then
		result, message = self.bus:deliver("sync", from, agent, payloadType, data, {
			priority = opts.priority or "P2",
			correlation_id = opts.correlation_id,
		})
	elseif protocol == "pull" then
		result = self.bus:pull(from, agent, data)
	else
		result, message = self.bus:push(from, agent, payloadType, data, {
			priority = opts.priority,
			correlation_id = opts.correlation_id,
		})
	end

	self.metrics.stages += 1
	if Protocol.isError(result) then
		self.metrics.errors += 1
	end
	return result, message
end

-- Runs one pipeline stage with retry-on-recoverable and memory logging.
function Orchestrator:runStage(stage, data, opts)
	opts = opts or {}
	local correlationId = opts.correlation_id or Protocol.uuid()
	local from = opts.from or "orchestrator-runtime-agent"
	local state = self:workflow(correlationId, opts.pipeline)
	self:advance(correlationId, stage.id, stage.agent, "running")

	local attempts = 0
	local maxAttempts = 2
	local result
	repeat
		attempts += 1
		result = self:invoke(stage.agent, data, {
			from = from,
			protocol = stage.in_protocol,
			payload_type = stage.produces or "work",
			correlation_id = correlationId,
			priority = opts.priority,
		})
		if Protocol.isError(result) and attempts < maxAttempts then
			local code = Protocol.errorCode(result)
			if code == "RATE_LIMITED" or code == "UPSTREAM_UNAVAILABLE" then
				self.metrics.retries += 1
				self:advance(correlationId, stage.id, stage.agent, "retrying", code)
			else
				break
			end
		else
			break
		end
	until false

	if Protocol.isError(result) then
		local code = Protocol.errorCode(result)
		self:advance(correlationId, stage.id, stage.agent, "failed", code .. ": " .. tostring(result.error.message))
		self:log(stage.agent, {
			correlation_id = correlationId,
			stage = stage.id,
			decision = "error",
			code = code,
		})
		return result
	end

	local decision = type(result) == "table" and result.data and result.data.decision or "ok"
	self:advance(correlationId, stage.id, stage.agent, "completed", decision)
	self:log(stage.agent, {
		correlation_id = correlationId,
		stage = stage.id,
		decision = decision,
		outputs = stage.produces,
	})
	return result
end

-- Opens a SYNC gate, asks the gate owner for a decision, records the answer.
function Orchestrator:syncReview(opts)
	assert(opts.owner and self.registry[opts.owner], "unknown gate owner")
	local gate = self.gates:open({
		requester = opts.requester,
		owner = opts.owner,
		asset = opts.asset,
		asset_type = opts.asset_type,
		reason = opts.reason,
		correlation_id = opts.correlation_id,
	})
	self.metrics.sync_reviews += 1
	self:advance(opts.correlation_id, opts.step or "sync_review", opts.owner, "waiting")

	local result = self:invoke(opts.owner, opts.data, {
		from = opts.requester,
		protocol = "sync",
		payload_type = opts.payload_type or "sync_review",
		correlation_id = opts.correlation_id,
	})

	if result == nil then
		return { gate = gate, decision = "pending", error = Protocol.error("TIMEOUT", "gate owner queued (offline)", opts.owner, opts.correlation_id) }
	end

	if Protocol.isError(result) then
		local code = Protocol.errorCode(result)
		local decision = (code == "MISSING_DATA") and "needs_revision" or "rejected"
		local resolved = self.gates:respond(gate.id, opts.owner, decision, result.error.message)
		self:advance(opts.correlation_id, opts.step or "sync_review", opts.owner, "resolved", decision)
		return { gate = gate, decision = decision, error = result, record = type(resolved) == "table" and resolved or nil }
	end

	local decision = (type(result) == "table" and result.data and result.data.decision) or "rejected"
	if decision ~= "approved" and decision ~= "rejected" and decision ~= "needs_revision" then
		decision = "rejected"
	end
	local reason = nil
	if type(result) == "table" and result.data then
		reason = result.data.recommendation or result.data.reason
		if type(reason) ~= "string" then
			reason = result.data.summary and ("blockers=" .. tostring(result.data.summary.blockers)) or nil
		end
	end
	if decision ~= "approved" and (reason == nil or reason == "") then
		reason = "gate returned " .. decision
	end

	local record = self.gates:respond(gate.id, opts.owner, decision, reason)
	self:advance(opts.correlation_id, opts.step or "sync_review", opts.owner, "resolved", decision)
	self:log(opts.owner, {
		correlation_id = opts.correlation_id,
		asset = opts.asset,
		decision = decision,
	})
	return { gate = gate, decision = decision, result = result, record = record }
end

function Orchestrator:sweepGates()
	local escalated = self.gates:sweep()
	if #escalated > 0 then
		self.metrics.escalations += #escalated
	end
	return escalated
end

function Orchestrator:snapshot()
	return {
		workflows = self.workflows,
		trace = self.trace,
		metrics = self.metrics,
	}
end

return Orchestrator
