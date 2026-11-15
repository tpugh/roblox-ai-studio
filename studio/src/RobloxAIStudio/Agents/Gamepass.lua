--!nonstrict
-- Deterministic implementations of the gamepass pipeline agents.
-- Each handler follows the agent spec in agents/gamepass/*.md and returns either
-- { ok = true, data = <schema-conforming output> } or a Protocol error object.

local Protocol = require(script.Parent.Parent.Protocol)

local Gamepass = {}

local function lower(text)
	return string.lower(tostring(text or ""))
end

local function contains(text, needle)
	return string.find(lower(text), needle, 1, true) ~= nil
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function copyList(list)
	local out = {}
	for _, value in ipairs(list or {}) do
		table.insert(out, value)
	end
	return out
end

local function missing(fields)
	return Protocol.error("MISSING_DATA", "missing required fields: " .. table.concat(fields, ", "), nil)
end

local function isCurrencyPerk(perk)
	for _, token in ipairs({ "currency", "coins", "gold", "cash", "robux", "gems" }) do
		if contains(perk, token) then
			return true
		end
	end
	return false
end

local function isQualityOfLifePerk(perk)
	for _, token in ipairs({ "inventory", "convenience", "quality of life", "save slot", "queue", "auto-collect", "timer", "respawn" }) do
		if contains(perk, token) then
			return true
		end
	end
	return false
end

function Gamepass.build(deps)
	local agents = {}

	------------------------------------------------------------------
	-- gamepass-designer (PUSH out)
	------------------------------------------------------------------
	agents["gamepass-designer"] = function(message)
		local data = message.payload.data or {}
		local required = { "segment", "avg_session_minutes", "top_activity", "drop_off_point" }
		local missingFields = {}
		for _, field in ipairs(required) do
			if data[field] == nil then
				table.insert(missingFields, field)
			end
		end
		if #missingFields > 0 then
			return missing(missingFields)
		end

		local stress = (data.drop_off_point or "progression")
		local activity = data.top_activity or "core loop"

		local concepts = {
			{
				name = "Momentum Pass",
				tagline = "Keep the run going when the grind bites.",
				perks = {
					"Skip one upgrade timer every session",
					"Extra inventory row",
					"+25% progression speed for 10 minutes daily",
				},
				target_player = "Returning players who stall at " .. stress,
				risk_level = "low",
			},
			{
				name = "Vault Key",
				tagline = "Unlock the side of " .. activity .. " most players never see.",
				perks = {
					"Exclusive vault cosmetic trail",
					"One extra save slot",
					"Priority queue on full servers",
				},
				target_player = "Status-driven collectors",
				risk_level = "low",
			},
			{
				name = "Fortune's Favor",
				tagline = "Turn a good run into a great one.",
				perks = {
					"Auto-collect nearby drops",
					"Instant respawn at the last checkpoint",
					"Double reward streak for your first 5 minutes",
				},
				target_player = "High-session players grinding " .. activity,
				risk_level = "med",
			},
		}

		-- Any concept that hands out currency is automatically high risk (spec rule).
		for _, concept in ipairs(concepts) do
			for _, perk in ipairs(concept.perks) do
				if isCurrencyPerk(perk) then
					concept.risk_level = "high"
				end
			end
			-- Every concept must carry exactly one quality-of-life perk.
			local hasQoL = false
			for _, perk in ipairs(concept.perks) do
				if isQualityOfLifePerk(perk) then
					hasQoL = true
				end
			end
			if not hasQoL then
				concept.perks[2] = "Extra inventory row"
			end
		end

		return {
			ok = true,
			data = {
				concepts = concepts,
				source_segment = data.segment,
				created_at = Protocol.isoNow(),
			},
		}
	end

	------------------------------------------------------------------
	-- perk-balancer (SYNC gate)
	------------------------------------------------------------------
	local function scorePerk(perk)
		local power = 5
		local economy = 1
		local exclusivity = 5

		if contains(perk, "double") or contains(perk, "+25%") or contains(perk, "+50%") then
			power += 2
		end
		if contains(perk, "instant") or contains(perk, "skip") then
			power += 1
		end
		if contains(perk, "auto") then
			power += 1
		end
		if contains(perk, "infinite") or contains(perk, "unlimited") then
			power += 6
		end
		if contains(perk, "cosmetic") or contains(perk, "trail") then
			power -= 2
			exclusivity += 3
		end
		if isQualityOfLifePerk(perk) then
			power -= 1
			exclusivity -= 1
		end
		if isCurrencyPerk(perk) then
			economy += 3
		elseif contains(perk, "reward") or contains(perk, "xp") or contains(perk, "progression") then
			economy += 2
		end
		if contains(perk, "exclusive") or contains(perk, "vault") then
			exclusivity += 2
		end

		return {
			power_delta = clamp(power, 1, 10),
			economy_impact = clamp(economy, 1, 10),
			exclusivity = clamp(exclusivity, 1, 10),
		}
	end

	agents["perk-balancer"] = function(message)
		local data = message.payload.data or {}
		if type(data.concepts) ~= "table" or #data.concepts == 0 then
			return missing({ "concepts" })
		end

		local approvedPerks = {}
		local flaggedPerks = {}
		local rejectedPerks = {}
		local approvedConcepts = {}

		for _, concept in ipairs(data.concepts) do
			local conceptOk = true
			for _, perk in ipairs(concept.perks or {}) do
				if contains(perk, "infinite") or contains(perk, "unlimited") then
					conceptOk = false
					table.insert(rejectedPerks, { perk = perk, reason = "Grants unbounded resources — auto-reject per spec" })
				else
					local score = scorePerk(perk)
					local entry = { perk = perk, concept = concept.name, score = score }
					if score.power_delta > 7 then
						conceptOk = false
						table.insert(flaggedPerks, {
							perk = perk,
							concept = concept.name,
							reason = "Power delta " .. score.power_delta .. " exceeds 7 — manual review required",
							score = score,
						})
					elseif score.exclusivity < 5 then
						table.insert(flaggedPerks, {
							perk = perk,
							concept = concept.name,
							reason = "Exclusivity " .. score.exclusivity .. " below 5 — add perceived rarity",
							score = score,
						})
					else
						table.insert(approvedPerks, entry)
					end
					if score.economy_impact > 6 then
						table.insert(flaggedPerks, {
							perk = perk,
							concept = concept.name,
							reason = "Economy impact " .. score.economy_impact .. " — escalate to economy-architect",
							score = score,
						})
					end
				end
			end
			if conceptOk and #(concept.perks or {}) == 3 then
				table.insert(approvedConcepts, concept)
			end
		end

		local selected = approvedConcepts[1]
		local recommendation
		if not selected then
			recommendation = "No concept is safe to ship as-is. Revise flagged perks and resubmit."
		else
			recommendation = string.format(
				"Ship '%s' (%s risk). %d approved perks, %d flagged, %d rejected.",
				selected.name,
				tostring(selected.risk_level),
				#approvedPerks,
				#flaggedPerks,
				#rejectedPerks
			)
		end

		if not selected then
			local error = Protocol.error("BALANCE_FAIL", recommendation, "perk-balancer", message.envelope.correlation_id)
			error.details = {
				approved_perks = approvedPerks,
				flagged_perks = flaggedPerks,
				rejected_perks = rejectedPerks,
			}
			return error
		end

		return {
			ok = true,
			data = {
				approved_perks = approvedPerks,
				flagged_perks = flaggedPerks,
				rejected_perks = rejectedPerks,
				approved_concepts = approvedConcepts,
				selected_concept = selected,
				recommendation = recommendation,
				decision = "approved",
				correlation_id = message.envelope.correlation_id,
			},
		}
	end

	------------------------------------------------------------------
	-- conversion-copywriter (PUSH out)
	------------------------------------------------------------------
	agents["conversion-copywriter"] = function(message)
		local data = message.payload.data or {}
		local concept = data.selected_concept
		if type(concept) ~= "table" or type(concept.perks) ~= "table" then
			return missing({ "selected_concept" })
		end

		local function trim(text, limit)
			if #text <= limit then
				return text
			end
			return string.sub(text, 1, limit)
		end

		local topPerks = { concept.perks[1], concept.perks[2] }
		local title = trim("VIP: " .. concept.name, 50)
		local short = trim(concept.tagline .. " " .. topPerks[1] .. ".", 100)
		local full = table.concat({
			concept.tagline,
			"",
			"Become known for " .. lower(concept.name) .. " on every server you join.",
			"",
			"What you unlock:",
			"- " .. topPerks[1],
			"- " .. topPerks[2],
			"- " .. concept.perks[3],
			"",
			"Built for " .. lower(concept.target_player) .. ". One purchase, permanent access on your account.",
		}, "\n")

		return {
			ok = true,
			data = {
				title = title,
				short_description = short,
				full_description = trim(full, 1000),
				ui_button_text = trim("Get " .. concept.name, 20),
				a_b_variant = {
					title = trim(concept.name .. " Pass", 50),
					short_description = trim("Unlock " .. topPerks[1], 100),
				},
				concept_name = concept.name,
				correlation_id = message.envelope.correlation_id,
			},
		}
	end

	------------------------------------------------------------------
	-- pricing-analyst (EVENT out: gamepass_ready)
	------------------------------------------------------------------
	agents["pricing-analyst"] = function(message)
		local data = message.payload.data or {}
		if type(data.copy) ~= "table" or type(data.selected_concept) ~= "table" then
			return missing({ "copy", "selected_concept" })
		end

		local competitor = data.competitor_data
		if type(competitor) ~= "table" then
			competitor = deps.bus:pull("pricing-analyst", "competitor-intel-agent", {
				genre = data.genre,
				correlation_id = message.envelope.correlation_id,
			})
			if type(competitor) ~= "table" or Protocol.isError(competitor) then
				return Protocol.error(
					"MISSING_DATA",
					"competitor pricing data is required before recommending a price",
					"pricing-analyst",
					message.envelope.correlation_id
				)
			end
		end

		local maxPower = 0
		for _, perk in ipairs(data.selected_concept.perks or {}) do
			local score = scorePerk(perk)
			maxPower = math.max(maxPower, score.power_delta)
		end

		local tier, price
		if maxPower <= 5 then
			tier, price = "entry", 150
		elseif maxPower <= 6 then
			tier, price = "mid", 400
		elseif maxPower <= 7 then
			tier, price = "premium", 800
		else
			tier, price = "flagship", 2000
		end

		-- Anchor within the observed competitor band when the data supports it.
		local minimum = tonumber(competitor.min) or price
		local maximum = tonumber(competitor.max) or price
		price = clamp(price, math.min(minimum, maximum), math.max(minimum, maximum))

		return {
			ok = true,
			data = {
				recommended_price = price,
				price_tier = tier,
				competitor_range = {
					min = minimum,
					max = maximum,
					avg = tonumber(competitor.avg) or ((minimum + maximum) / 2),
				},
				confidence = (tonumber(competitor.sample_size) or 0) >= 5 and "medium" or "low",
				rationale = string.format(
					"%s tier (peak power delta %d) anchored to the observed %s–%s R$ competitor band.",
					string.upper(string.sub(tier, 1, 1)) .. string.sub(tier, 2),
					maxPower,
					tostring(minimum),
					tostring(maximum)
				),
				pricing_risks = {},
				correlation_id = message.envelope.correlation_id,
			},
		}
	end

	------------------------------------------------------------------
	-- lua-script-writer (SYNC gate)
	------------------------------------------------------------------
	local function luaString(value)
		return string.format("%q", tostring(value))
	end

	local function sanitiseKey(name)
		return (string.gsub(tostring(name), "[^%w]", ""))
	end

	local function purchaseHandlerSource(concept, price)
		return table.concat({
			"--!strict",
			"-- Generated by lua-script-writer v1.0.0 for " .. luaString(concept.name),
			'local MarketplaceService = game:GetService("MarketplaceService")',
			'local Players = game:GetService("Players")',
			'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
			"",
			"local Config = require(ReplicatedStorage:WaitForChild(\"Gamepasses\"):WaitForChild(\"Config\"))",
			'local RequestPerk = ReplicatedStorage.Gamepasses.Remotes.RequestPerk',
			"",
			"local grantLocks: { [number]: boolean } = {}",
			"",
			"local function grantPerk(player: Player, gamepassId: number)",
			"	if grantLocks[player.UserId] then",
			"		return",
			"	end",
			"	grantLocks[player.UserId] = true",
			"	-- Ownership is verified server-side; the client never grants perks.",
			"	local owns = false",
			"	local ok, result = pcall(function()",
			"		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)",
			"	end)",
			"	if ok then",
			"		owns = result",
			"	end",
			"	if owns then",
			"		player:SetAttribute(" .. luaString("HasPerk_" .. sanitiseKey(concept.name)) .. ", true)",
			"		player:SetAttribute(\"GamepassPrice\", " .. tostring(price) .. ")",
			"	end",
			"	grantLocks[player.UserId] = nil",
			"end",
			"",
			"Players.PlayerAdded:Connect(function(player)",
			"	grantPerk(player, Config.gamepassId)",
			"end)",
			"",
			"MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)",
			"	if wasPurchased and gamepassId == Config.gamepassId then",
			"		grantPerk(player, gamepassId)",
			"	end",
			"end)",
			"",
			"RequestPerk.OnServerEvent:Connect(function(player)",
			"	-- Server re-checks ownership; no client-supplied perk data is trusted.",
			"	grantPerk(player, Config.gamepassId)",
			"end)",
			"",
			"return true",
		}, "\n")
	end

	local function configSource(concept, price)
		local perkLines = {}
		for _, perk in ipairs(concept.perks or {}) do
			table.insert(perkLines, "\t\t" .. luaString(perk) .. ",")
		end
		return table.concat({
			"--!strict",
			"-- Generated by lua-script-writer v1.0.0",
			"return {",
			"\tgamepassId = 0, -- fill with the published gamepass asset id",
			"\tconceptName = " .. luaString(concept.name) .. ",",
			"\tpriceRobux = " .. tostring(price) .. ",",
			"\tperks = {",
			table.concat(perkLines, "\n"),
			"\t},",
			"}",
		}, "\n")
	end

	agents["lua-script-writer"] = function(message)
		local data = message.payload.data or {}
		local required = { "perk_spec", "copy", "pricing", "correlation_id", "experience_context" }
		local missingFields = {}
		for _, field in ipairs(required) do
			if data[field] == nil then
				table.insert(missingFields, field)
			end
		end
		if #missingFields > 0 then
			return missing(missingFields)
		end
		if type(data.perk_spec) ~= "table" or not data.perk_spec.name then
			return missing({ "perk_spec.name" })
		end

		local concept = data.perk_spec
		local price = tonumber(data.pricing.price_robux or data.pricing.recommended_price) or 0
		local scripts = {
			{
				path = "ServerScriptService/Gamepasses/PurchaseHandler.server.lua",
				purpose = "Server-authoritative purchase and ownership verification",
				source = purchaseHandlerSource(concept, price),
			},
			{
				path = "ReplicatedStorage/Gamepasses/Config.lua",
				purpose = "Gamepass id, price, and perk manifest",
				source = configSource(concept, price),
			},
		}
		local remotes = {
			{ name = "RequestPerk", type = "RemoteEvent", direction = "client->server" },
		}

		return {
			ok = true,
			data = {
				decision = "approved",
				correlation_id = data.correlation_id,
				implementation = {
					scripts = scripts,
					remotes = remotes,
					config = {
						product_ids = { gamepass = 0 },
						feature_flags = { serverAuthority = true, idempotentGrants = true },
					},
				},
				test_notes = {
					"Join with and without ownership; only owners receive the perk attribute.",
					"Re-fire RequestPerk repeatedly; grants stay idempotent.",
				},
				security_notes = {
					"Ownership checked with MarketplaceService:UserOwnsGamePassAsync on the server.",
					"Client never supplies perk data or currency values.",
				},
				blocking_issues = {},
				timestamp = Protocol.isoNow(),
			},
		}
	end

	return agents
end

return Gamepass
