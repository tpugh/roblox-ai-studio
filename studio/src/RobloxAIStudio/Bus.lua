--!nonstrict
-- Bus: PUSH/EVENT delivery, PULL providers, and the analytics event-hub rule.
-- Mirrors PROTOCOL_RULES.md sections 1, 4 and 8.

local Protocol = require(script.Parent.Protocol)

local Bus = {}
Bus.__index = Bus

function Bus.new(config)
	local self = setmetatable({}, Bus)
	self.events = config.events or {}
	self.registry = config.registry or {}
	self.handlers = {}
	self.providers = {}
	self.inboxes = {}
	self.history = {}
	self.maxHistory = config.maxHistory or 500
	self.forwardedToHub = 0
	return self
end

function Bus:register(agent, handler)
	assert(self.registry[agent], "cannot register unknown agent: " .. tostring(agent))
	self.handlers[agent] = handler
end

function Bus:registerProvider(name, provider)
	self.providers[name] = provider
end

function Bus:categoryOf(agent)
	local record = self.registry[agent]
	return record and record.category or "unknown"
end

-- Cross-pipeline means subscribers span more than one category.
function Bus:isCrossPipeline(subscribers)
	local categories = {}
	for _, agent in ipairs(subscribers or {}) do
		categories[self:categoryOf(agent)] = true
	end
	local count = 0
	for _ in pairs(categories) do
		count += 1
	end
	return count > 1
end

function Bus:record(entry)
	table.insert(self.history, entry)
	while #self.history > self.maxHistory do
		table.remove(self.history, 1)
	end
end

function Bus:deliver(protocol, from, to, payloadType, data, opts)
	opts = opts or {}
	local message = Protocol.envelope({
		protocol = protocol,
		from_agent = from,
		to_agent = to,
		payload_type = payloadType,
		data = data,
		priority = opts.priority,
		correlation_id = opts.correlation_id,
	})

	local handler = self.handlers[to]
	if handler then
		local ok, result = pcall(handler, message)
		if not ok then
			self:record({
				timestamp = message.envelope.timestamp,
				protocol = protocol,
				from = from,
				to = to,
				payload_type = payloadType,
				correlation_id = message.envelope.correlation_id,
				status = "failed",
				error = tostring(result),
			})
			return Protocol.error("SCHEMA_INVALID", "handler failed: " .. tostring(result), to, message.envelope.correlation_id), message
		end
		self:record({
			timestamp = message.envelope.timestamp,
			protocol = protocol,
			from = from,
			to = to,
			payload_type = payloadType,
			correlation_id = message.envelope.correlation_id,
			status = "delivered",
		})
		return result, message
	end

	-- PUSH does not wait: offline agents get an inbox entry and keep moving.
	local inbox = self.inboxes[to]
	if not inbox then
		inbox = {}
		self.inboxes[to] = inbox
	end
	table.insert(inbox, message)
	self:record({
		timestamp = message.envelope.timestamp,
		protocol = protocol,
		from = from,
		to = to,
		payload_type = payloadType,
		correlation_id = message.envelope.correlation_id,
		status = "queued",
	})
	return nil, message
end

function Bus:push(from, to, payloadType, data, opts)
	return self:deliver("push", from, to, payloadType, data, opts)
end

function Bus:pull(pullingAgent, dataSource, query)
	local provider = self.providers[dataSource]
	if not provider then
		return Protocol.error("UPSTREAM_UNAVAILABLE", "no provider for '" .. tostring(dataSource) .. "'", pullingAgent)
	end
	local ok, data = pcall(provider, query or {})
	if not ok then
		return Protocol.error("UPSTREAM_UNAVAILABLE", tostring(data), pullingAgent)
	end
	self:record({
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		protocol = "pull",
		from = dataSource,
		to = pullingAgent,
		payload_type = "pull_result",
		correlation_id = (query and query.correlation_id) or "",
		status = "delivered",
	})
	return data
end

function Bus:emit(eventName, sourceAgent, data, opts)
	opts = opts or {}
	local spec = self.events[eventName]
	if not spec then
		return Protocol.error("SCHEMA_INVALID", "unregistered event '" .. tostring(eventName) .. "'", sourceAgent, opts.correlation_id)
	end

	local ok, missing, mismatched = Protocol.validateFields(spec.fields, data or {})
	local invalid = {}
	if not ok then
		for _, field in ipairs(missing) do
			table.insert(invalid, field)
		end
	end

	local subscribers = {}
	for _, agent in ipairs(spec.subscribers or {}) do
		if self.registry[agent] then
			table.insert(subscribers, agent)
		end
	end

	local crossPipeline = self:isCrossPipeline(subscribers)
	local routedViaAnalytics = crossPipeline and sourceAgent ~= "analytics-agent"
	if routedViaAnalytics then
		self.forwardedToHub += 1
	end

	local deliveries = {}
	local envelopes = {}
	for _, agent in ipairs(subscribers) do
		local result, message = self:deliver("event", sourceAgent, agent, eventName, data, {
			priority = opts.priority or spec.priority,
			correlation_id = opts.correlation_id,
		})
		table.insert(deliveries, { agent = agent, result = result, status = message and "sent" or "queued" })
		table.insert(envelopes, message)
	end

	-- The analytics agent observes every cross-pipeline event as the hub.
	if routedViaAnalytics and self.handlers["analytics-agent"] then
		self:deliver("event", sourceAgent, "analytics-agent", eventName, data, {
			priority = opts.priority or spec.priority,
			correlation_id = opts.correlation_id,
		})
	end

	return {
		event = eventName,
		source = sourceAgent,
		subscribers = subscribers,
		deliveries = deliveries,
		envelopes = envelopes,
		routed_via_analytics = routedViaAnalytics,
		missing_fields = invalid,
		mismatched_fields = mismatched,
	}
end

function Bus:drain(agent)
	local inbox = self.inboxes[agent]
	if not inbox or #inbox == 0 then
		return {}
	end
	self.inboxes[agent] = nil
	return inbox
end

function Bus:stats()
	local counts = { delivered = 0, queued = 0, failed = 0 }
	for _, entry in ipairs(self.history) do
		if counts[entry.status] then
			counts[entry.status] += 1
		end
	end
	counts.total = #self.history
	counts.routed_via_analytics = self.forwardedToHub
	return counts
end

return Bus
