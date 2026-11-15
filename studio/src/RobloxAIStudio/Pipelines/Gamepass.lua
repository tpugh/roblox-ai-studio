--!nonstrict
-- Gamepass pipeline: analytics -> design -> balance (SYNC) -> copy -> price
-- (gamepass_ready) -> implement (SYNC) -> TOS publish gate -> publish.
-- Stage list comes from shared/schemas/pipelines.json.

local Protocol = require(script.Parent.Parent.Protocol)

local GamepassPipeline = {}
GamepassPipeline.__index = GamepassPipeline

function GamepassPipeline.new(config)
	local self = setmetatable({}, GamepassPipeline)
	self.pipelines = config.pipelines
	self.events = config.events
	self.bus = config.bus
	self.orchestrator = config.orchestrator
	self.publish = config.publish
	self.gates = config.gates
	return self
end

function GamepassPipeline:stageMap()
	local pipeline = self.pipelines.gamepass
	assert(pipeline, "gamepass pipeline definition missing")
	local map = {}
	for _, stage in ipairs(pipeline.stages) do
		map[stage.id] = stage
	end
	return map, pipeline
end

local function assetIdFor(conceptName)
	return "gamepass/" .. (string.gsub(string.lower(tostring(conceptName)), "[^%w]+", "-"))
end

-- opportunity: the analytics_opportunity payload
-- opts.competitor_data: required by pricing-analyst; supply a real pull in production.
function GamepassPipeline:run(opportunity, opts)
	opts = opts or {}
	local correlationId = opts.correlation_id or Protocol.uuid()
	local stages, entryPipeline = self:stageMap()
	self.orchestrator:workflow(correlationId, "gamepass")

	local report = {
		correlation_id = correlationId,
		stage_results = {},
		decisions = {},
	}

	-- 0. Validate the entry event against the registry schema.
	local opportunityEvent = self.events.analytics_opportunity
	local valid, missingFields = Protocol.validateFields(opportunityEvent.fields, opportunity or {})
	if not valid then
		local error = Protocol.error(
			"SCHEMA_INVALID",
			"analytics_opportunity payload missing: " .. table.concat(missingFields, ", "),
			"analytics-agent",
			correlationId
		)
		report.decision = "blocked"
		report.error = error
		return report
	end

	-- 1. Analytics fires the opportunity event; the designer is a subscriber.
	local designerResult = self.orchestrator:runStage(stages.design, opportunity, {
		correlation_id = correlationId,
		pipeline = "gamepass",
		from = "analytics-agent",
	})
	if Protocol.isError(designerResult) then
		report.decision = "blocked"
		report.error = designerResult
		return report
	end
	report.stage_results.design = designerResult.data
	report.concepts = designerResult.data.concepts

	-- 2. Balance is a blocking SYNC gate (BALANCE_FAIL stops the pipeline).
	local balanceReview = self.orchestrator:syncReview({
		requester = "gamepass-designer",
		owner = stages.balance.agent,
		asset = assetIdFor(designerResult.data.concepts[1].name) .. "/balance",
		asset_type = "perk_spec",
		payload_type = stages.balance.produces,
		step = stages.balance.id,
		correlation_id = correlationId,
		data = designerResult.data,
	})
	report.decisions.balance = balanceReview.decision
	report.stage_results.balance = balanceReview.result and balanceReview.result.data or nil
	if balanceReview.decision ~= "approved" then
		report.decision = "blocked"
		report.error = balanceReview.error
			or Protocol.error("BALANCE_FAIL", "perk balance gate rejected the concepts", "perk-balancer", correlationId)
		report.blocked_at = "balance"
		return report
	end

	local concept = balanceReview.result.data.selected_concept
	report.concept = concept
	local assetId = assetIdFor(concept.name)

	-- 3. Copy is a fire-and-forget PUSH.
	local copyResult = self.orchestrator:runStage(stages.copy, {
		selected_concept = concept,
		approved_perks = balanceReview.result.data.approved_perks,
	}, {
		correlation_id = correlationId,
		pipeline = "gamepass",
		from = "perk-balancer",
	})
	if Protocol.isError(copyResult) then
		report.decision = "blocked"
		report.error = copyResult
		return report
	end
	report.stage_results.copy = copyResult.data

	-- 4. Pricing PULLs competitor data, then the pipeline fires gamepass_ready.
	local competitorData = opts.competitor_data
		or self.bus:pull("pricing-analyst", "competitor-intel-agent", { genre = opportunity.top_activity, correlation_id = correlationId })

	local pricingResult = self.orchestrator:runStage(stages.price, {
		copy = copyResult.data,
		selected_concept = concept,
		genre = opportunity.top_activity,
		competitor_data = competitorData,
	}, {
		correlation_id = correlationId,
		pipeline = "gamepass",
		from = "conversion-copywriter",
	})
	if Protocol.isError(pricingResult) then
		report.decision = "blocked"
		report.error = pricingResult
		report.blocked_at = "pricing"
		return report
	end
	report.stage_results.pricing = pricingResult.data

	local package = {
		perk_spec = {
			name = concept.name,
			perks = concept.perks,
			target_player = concept.target_player,
			risk_level = concept.risk_level,
		},
		copy = copyResult.data,
		pricing = {
			price_robux = pricingResult.data.recommended_price,
			product_id = nil,
		},
		correlation_id = correlationId,
		experience_context = {
			place_id = tostring(game.PlaceId),
			existing_systems = { "MarketplaceService", "PlayerAttributes" },
		},
	}

	-- 5. gamepass_ready triggers the lua-script-writer, which is itself a SYNC gate.
	local implementResult = self.orchestrator:runStage(stages.implement, package, {
		correlation_id = correlationId,
		pipeline = "gamepass",
		from = "pricing-analyst",
		payload_type = "gamepass_ready",
	})
	if Protocol.isError(implementResult) then
		report.decision = "blocked"
		report.error = implementResult
		report.blocked_at = "implementation"
		return report
	end
	report.stage_results.implementation = implementResult.data
	report.decisions.implementation = implementResult.data.decision
	if implementResult.data.decision ~= "approved" then
		report.decision = "blocked"
		report.blocked_at = "implementation"
		return report
	end

	-- 6. TOS compliance is a blocking publish gate. No approval, no publish.
	local artifact = {
		copy = copyResult.data,
		scripts = implementResult.data.implementation.scripts,
		data_notes = "stores non-identifying gameplay attributes only",
		price_robux = pricingResult.data.recommended_price,
	}
	report.artifact = artifact

	local tosReview = self.orchestrator:syncReview({
		requester = "lua-script-writer",
		owner = stages.publish_gate.agent,
		asset = assetId,
		asset_type = "game_update",
		payload_type = "publish_review",
		step = stages.publish_gate.id,
		correlation_id = correlationId,
		data = {
			asset_id = assetId,
			asset_type = "game_update",
			artifact = artifact,
		},
	})
	report.decisions.tos = tosReview.decision
	report.stage_results.tos = tosReview.result and tosReview.result.data or nil
	if tosReview.decision ~= "approved" then
		report.decision = "blocked"
		report.blocked_at = "tos"
		report.error = tosReview.error
		report.blocked_publish = self.publish:request({ asset = assetId, correlation_id = correlationId })
		return report
	end

	-- 7. Publish (guarded: re-reads the approval record, does not trust the caller).
	report.publish = self.publish:request({
		asset = assetId,
		asset_type = "game_update",
		correlation_id = correlationId,
		target = { place_id = tostring(game.PlaceId), channel = "studio" },
		artifacts = implementResult.data.implementation.scripts,
	})
	if Protocol.isError(report.publish) then
		report.decision = "blocked"
		report.error = report.publish
		report.blocked_at = "publish"
		return report
	end
	report.decision = "published"
	self.orchestrator:advance(correlationId, "publish", "build-release-agent", "completed", assetId)
	return report
end

return GamepassPipeline
