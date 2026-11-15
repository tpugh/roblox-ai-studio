--!nonstrict
-- Publish: the non-negotiable TOS gate in front of every publish action.
-- Mirrors PROTOCOL_RULES.md section 6 (The Publish Gate).

local Protocol = require(script.Parent.Protocol)

local Publish = {}
Publish.__index = Publish

function Publish.new(config)
	local self = setmetatable({}, Publish)
	self.gates = config.gates
	self.memory = config.memory
	self.published = {}
	self.order = {}
	self.blocked = {}
	self.rollbacks = {}
	-- Replaceable sink so a real publish (Open Cloud / MarketplaceService) can be wired later.
	self.sink = config.sink
	return self
end

function Publish:check(asset)
	local approval = self.gates:approvalFor(asset)
	if not approval then
		return false, Protocol.error(
			"TOS_VIOLATION",
			"asset '" .. tostring(asset) .. "' has no TOS compliance approval",
			"build-release-agent"
		)
	end
	if approval.decision ~= "approved" then
		return false, Protocol.error(
			"TOS_VIOLATION",
			"asset '" .. tostring(asset) .. "' decision is '" .. tostring(approval.decision) .. "'",
			"build-release-agent"
		)
	end
	return true, approval
end

function Publish:request(request)
	assert(type(request) == "table" and request.asset, "publish request requires an asset id")
	local ok, approvalOrError = self:check(request.asset)
	if not ok then
		local error = approvalOrError
		error.error.correlation_id = request.correlation_id or ""
		table.insert(self.blocked, {
			asset = request.asset,
			at = Protocol.isoNow(),
			code = error.error.code,
			reason = error.error.message,
			correlation_id = request.correlation_id,
		})
		return error
	end

	local approval = approvalOrError
	local receipt = {
		asset = request.asset,
		asset_type = request.asset_type or approval.asset_type,
		published_at = Protocol.isoNow(),
		correlation_id = request.correlation_id or approval.correlation_id,
		approved_by = approval.owner,
		gate_id = approval.gate_id,
		target = request.target or {},
		artifacts = request.artifacts or {},
		status = "published",
	}

	if self.sink then
		local sinkOk, sinkResult = pcall(self.sink, receipt)
		if not sinkOk then
			return Protocol.error("UPSTREAM_UNAVAILABLE", "publish sink failed: " .. tostring(sinkResult), "build-release-agent", receipt.correlation_id)
		end
		receipt.sink = sinkResult
	end

	table.insert(self.order, receipt.asset)
	self.published[receipt.asset] = receipt
	return receipt
end

function Publish:rollback(asset, reason, actor)
	local receipt = self.published[asset]
	if not receipt then
		return Protocol.error("SCHEMA_INVALID", "asset '" .. tostring(asset) .. "' is not published", actor or "build-release-agent")
	end
	receipt.status = "rolled_back"
	receipt.rolled_back_at = Protocol.isoNow()
	receipt.rollback_reason = reason or "publish gate violation"
	table.insert(self.rollbacks, {
		asset = asset,
		at = receipt.rolled_back_at,
		reason = receipt.rollback_reason,
		actor = actor or "build-release-agent",
	})
	return receipt
end

function Publish:stats()
	local byType = {}
	for _, asset in ipairs(self.order) do
		local receipt = self.published[asset]
		byType[receipt.asset_type] = (byType[receipt.asset_type] or 0) + 1
	end
	return {
		published = #self.order,
		blocked = #self.blocked,
		rollbacks = #self.rollbacks,
		by_type = byType,
	}
end

return Publish
