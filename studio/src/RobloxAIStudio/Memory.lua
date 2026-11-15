--!nonstrict
-- Memory: append-only agent logs with ownership and PII guards.
-- Mirrors PROTOCOL_RULES.md section 7 (Memory Protocol).

local Memory = {}
Memory.__index = Memory

local PII_FIELDS = {
	username = true,
	userid = true,
	displayname = true,
	email = true,
	phone = true,
	address = true,
	playerid = true,
}

local MAX_ENTRIES_PER_AGENT = 500

local function normaliseValue(value)
	if type(value) == "table" then
		return "[table]"
	end
	local text = tostring(value)
	if #text > 200 then
		text = string.sub(text, 1, 197) .. "..."
	end
	return text
end

function Memory.new(registry)
	local self = setmetatable({}, Memory)
	self.registry = registry or {}
	self.store = {}
	self.order = {}
	self.violations = {}
	self.appends = 0
	return self
end

function Memory:ownerCategory(agent)
	local record = self.registry[agent]
	return record and record.category or nil
end

function Memory:isKnown(agent)
	return self.registry[agent] ~= nil
end

function Memory:assertNoPII(fields)
	for key in pairs(fields) do
		if PII_FIELDS[string.lower(key)] then
			return false, key
		end
	end
	return true, nil
end

function Memory:append(agent, fields, sourceAgent)
	if not self:isKnown(agent) then
		return nil, "unknown agent: " .. tostring(agent)
	end

	-- No agent may write another agent's log.
	local writer = sourceAgent or agent
	if writer ~= agent then
		table.insert(self.violations, {
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			writer = writer,
			target = agent,
			kind = "cross_agent_write",
		})
		return nil, "agent '" .. tostring(writer) .. "' may not write to '" .. tostring(agent) .. "' memory"
	end

	local clean, offender = self:assertNoPII(fields)
	if not clean then
		table.insert(self.violations, {
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			writer = writer,
			target = agent,
			kind = "pii_rejected",
			field = offender,
		})
		return nil, "PII field rejected: " .. tostring(offender)
	end

	local keys = {}
	for key in pairs(fields) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local parts = { "[" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "]" }
	for _, key in ipairs(keys) do
		table.insert(parts, tostring(key) .. ": " .. normaliseValue(fields[key]))
	end
	local line = table.concat(parts, " | ")

	local entries = self.store[agent]
	if not entries then
		entries = {}
		self.store[agent] = entries
		table.insert(self.order, agent)
	end
	table.insert(entries, { line = line, fields = fields, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") })
	while #entries > MAX_ENTRIES_PER_AGENT do
		table.remove(entries, 1)
	end
	self.appends += 1
	return line
end

function Memory:read(agent, requester)
	if not self:isKnown(agent) then
		return nil, "unknown agent: " .. tostring(agent)
	end
	if requester ~= agent and requester ~= "analytics-agent" and requester ~= "orchestrator-runtime-agent" then
		local requesterCategory = self:ownerCategory(requester)
		local targetCategory = self:ownerCategory(agent)
		if requesterCategory == nil or requesterCategory ~= targetCategory then
			return nil, "agent '" .. tostring(requester) .. "' may not read '" .. tostring(agent) .. "' memory"
		end
	end
	return self.store[agent] or {}
end

function Memory:count(agent)
	if agent then
		return #(self.store[agent] or {})
	end
	return self.appends
end

function Memory:dump()
	local lines = {}
	for _, agent in ipairs(self.order) do
		table.insert(lines, "== " .. agent .. " ==")
		for _, entry in ipairs(self.store[agent]) do
			table.insert(lines, entry.line)
		end
	end
	return table.concat(lines, "\n")
end

return Memory
