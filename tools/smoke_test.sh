#!/usr/bin/env bash
# End-to-end smoke test for tools/studio.py.
# Uses throwaway runtime/memory directories so the repo stays clean.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

CLI="python3 tools/studio.py"
export STUDIO_RUNTIME_DIR="$(mktemp -d)"
export STUDIO_MEMORY_ROOT="$(mktemp -d)"

PASS=0
FAIL=0

check() {
	local name="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		printf 'PASS  %s\n' "$name"
		PASS=$((PASS + 1))
	else
		printf 'FAIL  %s (expected %s, got %s)\n' "$name" "$expected" "$actual"
		FAIL=$((FAIL + 1))
	fi
}

json_get() {
	python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {}, {'d': d}))" "$1"
}

# 1. Registry is wired.
AGENTS=$($CLI state | json_get "d['agents']")
check "registry agents" "55" "$AGENTS"
PIPELINES=$($CLI state | json_get "d['pipelines']")
check "registry pipelines" "5" "$PIPELINES"

# 2. An EVENT fans out to registered subscribers only.
cat >"$STUDIO_RUNTIME_DIR/opportunity.json" <<'JSON'
{"segment": "mid-game grinders", "avg_session_minutes": 18, "top_activity": "dungeon runs", "drop_off_point": "upgrade timer wall", "player_count": 1240}
JSON
SENT=$($CLI send --from analytics-agent --protocol event --type analytics_opportunity \
	--payload "$STUDIO_RUNTIME_DIR/opportunity.json" --correlation demo-1 | json_get "d['sent']")
check "event fan-out" "3" "$SENT"

INBOX=$($CLI inbox gamepass-designer --json | json_get "d['count']")
check "designer inbox" "1" "$INBOX"

# 3. event schema is enforced.
if $CLI send --from analytics-agent --protocol event --type analytics_opportunity \
	--data '{"segment": "x"}' --correlation demo-2 >/dev/null 2>&1; then
	check "event schema enforcement" "blocked" "accepted"
else
	check "event schema enforcement" "blocked" "blocked"
fi

# 4. Publish is blocked before TOS approval.
GATE=$($CLI sync-open --from lua-script-writer --gate-owner tos-compliance-agent \
	--asset gamepass/demo --asset-type game_update --correlation demo-1 | json_get "d['gate_id']")
if $CLI publish --asset gamepass/demo --check >/dev/null 2>&1; then
	check "publish blocked before approval" "blocked" "allowed"
else
	check "publish blocked before approval" "blocked" "blocked"
fi

# 5. Wrong agent cannot answer a gate.
if $CLI sync-respond --from gamepass-designer --gate "$GATE" --decision approved --reason nope >/dev/null 2>&1; then
	check "gate owner enforcement" "blocked" "accepted"
else
	check "gate owner enforcement" "blocked" "blocked"
fi

# 6. Approval unlocks publish.
DECISION=$($CLI sync-respond --from tos-compliance-agent --gate "$GATE" --decision approved \
	--reason "checklist clean" | json_get "d['decision']")
check "tos decision recorded" "approved" "$DECISION"
$CLI publish --asset gamepass/demo --check >/dev/null 2>&1
check "publish check after approval" "0" "$?"
STATUS=$($CLI publish --asset gamepass/demo --correlation demo-1 | json_get "d['status']")
check "publish receipt" "published" "$STATUS"

# 7. Memory is append-only and refuses PII.
$CLI log --agent gamepass-designer --field correlation_id=demo-1 --field concepts=3 >/dev/null
if $CLI memory --agent gamepass-designer --tail 5 | grep -q "concepts: 3"; then
	check "memory append" "present" "present"
else
	check "memory append" "present" "missing"
fi
if $CLI log --agent gamepass-designer --field username=player123 >/dev/null 2>&1; then
	check "pii rejection" "blocked" "accepted"
else
	check "pii rejection" "blocked" "blocked"
fi

# 8. Trace ties the workflow together.
TRACE=$($CLI trace --correlation demo-1 | tail -1)
check "trace resolved" "3 messages, 1 gates" "$TRACE"

rm -rf "$STUDIO_RUNTIME_DIR" "$STUDIO_MEMORY_ROOT"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
