--!nonstrict
-- Gates: blocking SYNC gates, decisions, timeout escalation, publish approvals.
-- Mirrors PROTOCOL_RULES.md sections 1.4, 5 and 6.

local Protocol = require(script.Parent.Protocol)

local Gates = {}
Gates.__index = Gates

Gates.DEFAULT_TIMEOUT_SECONDS = 1800 -- 30 minutes, then human escalation.

function Gates.new(config)
	local self = setmetatable({}, Gates)
	self.registry = config.registry or {}
	self.gates = {}
	self.order = {}
	self.approvals = {}
	self.decisions = {}
	self.escalations = {}
	self.timeout = config.timeout or Gates.DEFAULT_TIMEOUT_SECONDS
	return self
end

function Gates:open(request)
	assert(type(request) == "table", "gate request required")
	local owner = request.owner or request.gate_owner
	assert(owner and self.registry[owner], "unknown gate owner: " .. tostring(owner))
	assert(request.requester and self.registry[request.requester], "unknown requester: " .. tostring(request.requester))
	assert(request.asset, "gate requires an asset identifier")

	local gate = {
		id = request.id or Protocol.uuid(),
		protocol = "sync",
		requester = request.requester,
		owner = owner,
		asset = request.asset,
		asset_type = request.asset_type or "asset",
		reason = request.reason or "",
		correlation_id = request.correlation_id or Protocol.uuid(),
		state = "waiting",
		decision = nil,
		opened_at = os.time(),
		deadline = os.time() + (request.timeout or self.timeout),
		resolved_at = nil,
		history = {},
	}
	table.insert(gate.history, { at = os.time(), event = "opened" })
	self.gates[gate.id] = gate
	table.insert(self.order, gate.id)
	return gate
end

function Gates:respond(gateId, agent, decision, reason)
	local gate = self.gates[gateId]
	if not gate then
		return Protocol.error("SCHEMA_INVALID", "unknown gate '" .. tostring(gateId) .. "'", agent)
	end
	if gate.owner ~= agent then
		return Protocol.error("SCHEMA_INVALID", "only '" .. gate.owner .. "' may answer this gate", agent)
	end
	if gate.state ~= "waiting" then
		return Protocol.error("SCHEMA_INVALID", "gate already " .. gate.state, agent)
	end
	if not Protocol.DECISIONS[decision] then
		return Protocol.error("SCHEMA_INVALID", "invalid decision '" .. tostring(decision) .. "'", agent)
	end
	if decision ~= "approved" and (reason == nil or reason == "") then
		return Protocol.error("SCHEMA_INVALID", "a rejection requires a reason", agent)
	end

	gate.state = "resolved"
	gate.decision = decision
	gate.reason = reason or ""
	gate.resolved_at = os.time()
	table.insert(gate.history, { at = gate.resolved_at, event = "resolved", decision = decision, reason = gate.reason })

	local record = {
		gate_id = gate.id,
		asset = gate.asset,
		asset_type = gate.asset_type,
		owner = gate.owner,
		requester = gate.requester,
		decision = decision,
		reason = gate.reason,
		correlation_id = gate.correlation_id,
		decided_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		reviewed_by = gate.owner,
	}
	self.decisions[gate.id] = record
	if decision == "approved" then
		local history = self.approvals[gate.asset] or {}
		table.insert(history, record)
		self.approvals[gate.asset] = history
	end
	return gate
end

-- Returns the latest approved record for an asset, if any.
function Gates:approvalFor(asset)
	local history = self.approvals[asset]
	if not history or #history == 0 then
		return nil
	end
	return history[#history]
end

function Gates:isApproved(asset)
	return self:approvalFor(asset) ~= nil
end

function Gates:pending()
	local list = {}
	for _, id in ipairs(self.order) do
		local gate = self.gates[id]
		if gate.state == "waiting" then
			table.insert(list, gate)
		end
	end
	return list
end

function Gates:sweep(now)
	now = now or os.time()
	local escalated = {}
	for _, id in ipairs(self.order) do
		local gate = self.gates[id]
		if gate.state == "waiting" and now >= gate.deadline then
			gate.state = "escalated"
			table.insert(gate.history, { at = now, event = "escalated", reason = "TIMEOUT" })
			table.insert(self.escalations, {
				gate_id = gate.id,
				asset = gate.asset,
				owner = gate.owner,
				correlation_id = gate.correlation_id,
				at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				code = "TIMEOUT",
			})
			table.insert(escalated, gate)
		end
	end
	return escalated
end

function Gates:historyFor(asset)
	local history = self.approvals[asset]
	if not history then
		return {}
	end
	return history
end

function Gates:stats()
	local waiting, resolved, escalated = 0, 0, 0
	for _, id in ipairs(self.order) do
		local state = self.gates[id].state
		if state == "waiting" then
			waiting += 1
		elseif state == "resolved" then
			resolved += 1
		elseif state == "escalated" then
			escalated += 1
		end
	end
	local approved = 0
	for _ in pairs(self.approvals) do
		approved += 1
	end
	return { total = #self.order, waiting = waiting, resolved = resolved, escalated = escalated, approved_assets = approved }
end

return Gates
