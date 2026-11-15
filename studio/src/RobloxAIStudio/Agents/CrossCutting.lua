--!nonstrict
-- Deterministic implementation of the TOS compliance gate.
-- Mirrors agents/cross-cutting/tos-compliance-agent.md (absolute veto on publishes).

local Protocol = require(script.Parent.Parent.Protocol)

local CrossCutting = {}

local FORBIDDEN_PHRASES = {
	{ phrase = "free robux", rule = "Scam / deceptive offer", reference = "Community Standards: Deceptive Content" },
	{ phrase = "robux generator", rule = "Scam / deceptive offer", reference = "Community Standards: Deceptive Content" },
	{ phrase = "paypal", rule = "Third-party payment collection", reference = "Monetization: Off-platform payments" },
	{ phrase = "venmo", rule = "Third-party payment collection", reference = "Monetization: Off-platform payments" },
	{ phrase = "cashapp", rule = "Third-party payment collection", reference = "Monetization: Off-platform payments" },
	{ phrase = "gift card", rule = "Off-platform payment / scam signal", reference = "Community Standards: Deceptive Content" },
}

local URGENCY_PHRASES = { "ends tonight", "last chance", "only today", "act now" }

local function lower(text)
	return string.lower(tostring(text or ""))
end

local function contains(text, needle)
	return string.find(lower(text), needle, 1, true) ~= nil
end

local function collectStrings(value, out)
	if type(value) == "string" then
		table.insert(out, value)
	elseif type(value) == "table" then
		for _, item in pairs(value) do
			collectStrings(item, out)
		end
	end
end

local function reviewCopy(artifact, violations, instructions)
	local texts = {}
	collectStrings(artifact, texts)

	for _, entry in ipairs(texts) do
		for _, forbidden in ipairs(FORBIDDEN_PHRASES) do
			if contains(entry, forbidden.phrase) then
				table.insert(violations, {
					rule = forbidden.rule,
					description = "Content contains forbidden phrase: '" .. forbidden.phrase .. "'",
					severity = "blocker",
					tos_reference = forbidden.reference,
				})
			end
		end
		for _, phrase in ipairs(URGENCY_PHRASES) do
			if contains(entry, phrase) then
				table.insert(violations, {
					rule = "Deceptive urgency",
					description = "Marketing copy uses urgency phrasing '" .. phrase .. "'; verify the claim is true",
					severity = "warning",
					tos_reference = "Advertising Standards: Deceptive urgency",
				})
			end
		end
	end

	local copy = artifact.copy
	if type(copy) == "table" then
		if copy.title and #tostring(copy.title) > 50 then
			table.insert(violations, {
				rule = "Copy length",
				description = "Gamepass title exceeds 50 characters",
				severity = "warning",
				tos_reference = "Creator guidelines: Gamepass copy",
			})
			table.insert(instructions, "Trim the gamepass title to 50 characters or fewer.")
		end
		if copy.full_description and #tostring(copy.full_description) > 1000 then
			table.insert(violations, {
				rule = "Copy length",
				description = "Gamepass description exceeds 1000 characters",
				severity = "blocker",
				tos_reference = "Creator guidelines: Gamepass copy",
			})
			table.insert(instructions, "Trim the gamepass description to 1000 characters.")
		end
	end
end

local function reviewScripts(artifact, violations, instructions)
	local scripts = artifact.scripts
	if type(scripts) ~= "table" then
		return
	end
	local combined = {}
	for _, scriptEntry in ipairs(scripts) do
		if type(scriptEntry) == "table" and scriptEntry.source then
			table.insert(combined, scriptEntry.source)
		end
	end
	if #combined == 0 then
		return
	end
	local source = table.concat(combined, "\n")
	local hasOwnershipCheck = contains(source, "UserOwnsGamePassAsync") or contains(source, "ProcessReceipt")
	local hasPurchaseFlow = contains(source, "PromptGamePassPurchase") or contains(source, "ProcessReceipt")
	local hasServerEvent = contains(source, "OnServerEvent")

	if hasPurchaseFlow and not hasOwnershipCheck then
		table.insert(violations, {
			rule = "Client trust",
			description = "Purchase flow grants entitlements without a server-side ownership check",
			severity = "blocker",
			tos_reference = "Script safety: server-side validation",
		})
		table.insert(instructions, "Verify ownership server-side with MarketplaceService before granting perks.")
	end
	if hasServerEvent and not hasOwnershipCheck then
		table.insert(violations, {
			rule = "Client trust",
			description = "RemoteEvent handler grants gameplay effects without server validation",
			severity = "blocker",
			tos_reference = "Script safety: server-side validation",
		})
		table.insert(instructions, "Re-validate ownership and inputs on the server before granting anything.")
	end
	if contains(source, "loadstring") or contains(source, "getfenv") then
		table.insert(violations, {
			rule = "Code obfuscation",
			description = "Uses loadstring/getfenv, which hides behavior from reviewers",
			severity = "blocker",
			tos_reference = "Script safety: no obfuscation",
		})
		table.insert(instructions, "Remove loadstring/getfenv and ship readable source.")
	end
	if contains(source, "HttpService") and not contains(source, "allowlist") then
		table.insert(violations, {
			rule = "External data transmission",
			description = "Makes outbound HTTP calls; confirm the destination is disclosed and permitted",
			severity = "warning",
			tos_reference = "Script safety: external calls",
		})
	end
end

local function reviewDataNotes(artifact, violations, instructions)
	local notes = artifact.data_notes
	if type(notes) ~= "string" then
		return
	end
	for _, field in ipairs({ "username", "userid", "displayname", "email", "phone", "address" }) do
		if contains(notes, field) then
			table.insert(violations, {
				rule = "PII storage",
				description = "Data notes mention storing '" .. field .. "', which is not permitted",
				severity = "blocker",
				tos_reference = "Data privacy: no player PII",
			})
			table.insert(instructions, "Store only non-identifying gameplay data.")
		end
	end
end

local function reviewUgc(artifact, violations, instructions)
	local polygonCount = tonumber(artifact.polygon_count)
	if polygonCount and polygonCount > 4000 then
		table.insert(violations, {
			rule = "UGC limits",
			description = string.format("Polygon count %d exceeds the UGC accessory budget", polygonCount),
			severity = "blocker",
			tos_reference = "UGC: polygon limits",
		})
		table.insert(instructions, "Retopologise under the UGC polygon budget.")
	end
	if artifact.misleading_thumbnail == true then
		table.insert(violations, {
			rule = "Misleading thumbnail",
			description = "Thumbnail does not represent the shipped item",
			severity = "blocker",
			tos_reference = "Marketplace: accurate representation",
		})
	end
end

function CrossCutting.build(deps)
	local agents = {}

	agents["tos-compliance-agent"] = function(message)
		local data = message.payload.data or {}
		if data.asset_id == nil or data.asset_type == nil then
			return Protocol.error(
				"MISSING_DATA",
				"asset_id and asset_type are required for a compliance review",
				"tos-compliance-agent",
				message.envelope.correlation_id
			)
		end

		local artifact = data.artifact or {}
		local violations = {}
		local instructions = {}

		reviewCopy(artifact, violations, instructions)
		reviewScripts(artifact, violations, instructions)
		reviewDataNotes(artifact, violations, instructions)
		if data.asset_type == "ugc_item" or data.asset_type == "clothing" then
			reviewUgc(artifact, violations, instructions)
		end

		local blockers, warnings = 0, 0
		for _, violation in ipairs(violations) do
			if violation.severity == "blocker" then
				blockers += 1
			else
				warnings += 1
			end
		end

		local decision = "approved"
		if blockers > 0 then
			decision = "rejected"
		elseif warnings > 0 then
			decision = "needs_revision"
		end

		return {
			ok = true,
			data = {
				asset_id = data.asset_id,
				asset_type = data.asset_type,
				decision = decision,
				violations = violations,
				revision_instructions = instructions,
				approved_at = decision == "approved" and Protocol.isoNow() or nil,
				reviewed_by = "tos-compliance-agent v1.0.0",
				correlation_id = message.envelope.correlation_id,
				summary = {
					blockers = blockers,
					warnings = warnings,
				},
			},
		}
	end

	return agents
end

return CrossCutting
