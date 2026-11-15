--!nonstrict
-- Protocol: envelope construction/validation, priorities, error objects.
-- Mirrors protocols/PROTOCOL_RULES.md (v1.0.0).

local HttpService = game:GetService("HttpService")

local Protocol = {}

Protocol.VERSION = "1.0.0"
Protocol.PROTOCOLS = { "push", "pull", "event", "sync" }
Protocol.DECISIONS = { approved = true, rejected = true, needs_revision = true }

Protocol.SLA_SECONDS = {
	P0 = 0,
	P1 = 3600,
	P2 = 86400,
	P3 = 604800,
}

Protocol.ERRORS = {
	SCHEMA_INVALID = { recoverable = true, retry_after = nil },
	MISSING_DATA = { recoverable = true, retry_after = nil },
	BALANCE_FAIL = { recoverable = true, retry_after = 3600 },
	TOS_VIOLATION = { recoverable = false, retry_after = nil },
	TIMEOUT = { recoverable = false, retry_after = nil },
	RATE_LIMITED = { recoverable = true, retry_after = 60 },
	UPSTREAM_UNAVAILABLE = { recoverable = true, retry_after = 900 },
}

local function isoNow()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

Protocol.isoNow = isoNow

function Protocol.uuid()
	return HttpService:GenerateGUID(false)
end

function Protocol.isPriority(priority)
	return Protocol.SLA_SECONDS[priority] ~= nil
end

function Protocol.isProtocol(name)
	for _, value in ipairs(Protocol.PROTOCOLS) do
		if value == name then
			return true
		end
	end
	return false
end

function Protocol.envelope(opts)
	assert(type(opts) == "table", "Protocol.envelope requires an options table")
	assert(Protocol.isProtocol(opts.protocol), "invalid protocol: " .. tostring(opts.protocol))
	assert(opts.from_agent, "from_agent is required")
	assert(opts.to_agent, "to_agent is required")

	local priority = opts.priority or "P2"
	assert(Protocol.isPriority(priority), "invalid priority: " .. tostring(priority))

	return {
		envelope = {
			message_id = opts.message_id or Protocol.uuid(),
			protocol = opts.protocol,
			from_agent = opts.from_agent,
			to_agent = opts.to_agent,
			timestamp = opts.timestamp or isoNow(),
			version = Protocol.VERSION,
			priority = priority,
			correlation_id = opts.correlation_id or Protocol.uuid(),
		},
		payload = {
			type = opts.payload_type or "untyped",
			data = opts.data or {},
		},
	}
end

function Protocol.validate(message)
	if type(message) ~= "table" then
		return false, "message is not a table"
	end
	local env = message.envelope
	if type(env) ~= "table" then
		return false, "missing envelope"
	end
	for _, field in ipairs({ "message_id", "protocol", "from_agent", "to_agent", "timestamp", "version", "priority" }) do
		if env[field] == nil or env[field] == "" then
			return false, "missing envelope field: " .. field
		end
	end
	if not Protocol.isProtocol(env.protocol) then
		return false, "invalid protocol: " .. tostring(env.protocol)
	end
	if not Protocol.isPriority(env.priority) then
		return false, "invalid priority: " .. tostring(env.priority)
	end
	if type(message.payload) ~= "table" or message.payload.type == nil then
		return false, "missing payload.type"
	end
	return true
end

function Protocol.error(code, message, agent, correlation_id)
	local spec = Protocol.ERRORS[code]
	if not spec then
		code = "SCHEMA_INVALID"
		spec = Protocol.ERRORS[code]
	end
	return {
		error = {
			code = code,
			message = message or code,
			agent = agent or "unknown",
			recoverable = spec.recoverable,
			retry_after_seconds = spec.retry_after,
			correlation_id = correlation_id or "",
			timestamp = isoNow(),
		},
	}
end

function Protocol.isError(value)
	return type(value) == "table" and value.error ~= nil
end

function Protocol.errorCode(value)
	if Protocol.isError(value) then
		return value.error.code
	end
	return nil
end

-- Checks the declared fields in shared/schemas/events.json against a payload.
-- Returns ok, missing[] and mismatched[] (type mismatches only).
function Protocol.validateFields(fields, data)
	local missing, mismatched = {}, {}
	for name, spec in pairs(fields or {}) do
		local value = data[name]
		if value == nil then
			table.insert(missing, name)
		else
			local wanted = spec.type
			local ok = true
			if wanted == "string" then
				ok = type(value) == "string"
			elseif wanted == "number" then
				ok = type(value) == "number"
			elseif wanted == "boolean" then
				ok = type(value) == "boolean"
			elseif wanted == "object" then
				ok = type(value) == "table"
			elseif wanted == "array" then
				ok = type(value) == "table"
			end
			if not ok then
				table.insert(mismatched, { field = name, wanted = wanted, got = type(value) })
			end
		end
	end
	table.sort(missing)
	return #missing == 0, missing, mismatched
end

return Protocol
