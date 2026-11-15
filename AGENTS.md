# Roblox AI Studio — agent operating instructions

This repository is the source of truth for a 55-agent studio system. Markdown specs in
`agents/` define behaviour; generated artifacts are derived from them; two
runtimes enforce the protocols:

- **Host runtime** — `tools/studio.py` (transport, gates, memory, publish gate)
  plus the 55 generated OpenCode subagents in `.opencode/agents/`.
- **Studio runtime** — Luau modules under `studio/src/RobloxAIStudio/`, installed
  in the place as `ReplicatedStorage.RobloxAIStudio`.

## Non-negotiables

1. **Nothing publishes without TOS approval.** `tos-compliance-agent` holds an
   absolute veto. `publish` refuses any asset without an `approved` gate record.
2. **The analytics agent is the event bus.** Cross-pipeline events route through
   `analytics-agent`; direct agent-to-agent events only for local pipeline work.
3. **Memory is append-only.** Read your log at the start of a run, append at the
   end. Never write another agent's log. Never log player PII.
4. **Correlate everything.** One `correlation_id` per workflow, on every message.
5. **Structured errors only** — `SCHEMA_INVALID`, `MISSING_DATA`, `BALANCE_FAIL`,
   `TOS_VIOLATION`, `TIMEOUT`, `RATE_LIMITED`, `UPSTREAM_UNAVAILABLE`.

## Running an agent

Every agent spec has a matching subagent named after its slug:

```
subagent({ agent: "gamepass-designer", prompt: "Design concepts for the payload in runtime/inbox/gamepass-designer/<id>.json" })
```

Subagents cannot launch further subagents. They may only edit `memory/**` and
run `python3 tools/studio.py …`; their output is the schema in their spec.

Typical loop inside an agent:

```sh
python3 tools/studio.py inbox <slug> --json     # read work
python3 tools/studio.py agents show <slug>      # refresh the spec
# … produce the output specified in the spec …
python3 tools/studio.py send --from <slug> --to <next> --protocol push \
  --type <payload_type> --payload out.json --correlation <id>
python3 tools/studio.py log --agent <slug> --field correlation_id=<id> --field decision=...
```

## Protocol CLI

| Command | Purpose |
| --- | --- |
| `state` | counts: agents, messages, gates, published, blocked |
| `agents list\|show` | registry view (category, protocol, triggers, memory path) |
| `events list\|show` | event schema, subscribers, priority |
| `pipelines list\|show` | stage graph with gate flags |
| `send --from --to --protocol push\|event --type --payload\|--data` | transport |
| `inbox <agent> [--ack]` | unread work |
| `sync-open --from --gate-owner --asset` | start a blocking gate |
| `sync-respond --from --gate --decision approved\|rejected\|needs_revision --reason` | answer it (owner only) |
| `gates [--pending]` | gate ledger |
| `publish --asset [--check]` | publish, only with approval on record |
| `log --agent --field k=v` | append memory (PII rejected) |
| `memory --agent [--tail N]` | read a log |
| `trace --correlation` | messages, gates, publish, blocks for one workflow |
| `validate file.json` | check an envelope against the rules |

State lives in `runtime/state.json` with an append-only `runtime/audit.jsonl`.

## Walkthrough (gamepass pipeline)

```sh
python3 tools/studio.py send --from analytics-agent --protocol event \
  --type analytics_opportunity --payload opportunity.json --correlation run-1
# gamepass-designer picks it up
python3 tools/studio.py send --from gamepass-designer --to perk-balancer \
  --protocol push --type perk_spec_doc --payload concepts.json --correlation run-1
python3 tools/studio.py sync-open --from conversion-copywriter \
  --gate-owner perk-balancer --asset gamepass/<name>/balance --correlation run-1
python3 tools/studio.py sync-respond --from perk-balancer --gate <id> \
  --decision approved --reason "all perks within power/exclusivity bands"
# …copy → pricing → lua-script-writer → TOS…
python3 tools/studio.py sync-respond --from tos-compliance-agent --gate <id> \
  --decision approved --reason "checklist clean"
python3 tools/studio.py publish --asset gamepass/<name> --correlation run-1
```

## Studio runtime

`ReplicatedStorage.RobloxAIStudio` is a ModuleScript with children:

```
RobloxAIStudio (ModuleScript)
├── Config/Generated/{Agents,Events,Pipelines}   generated from the repo
├── Protocol   Bus   Memory   Gates   Publish   Orchestrator
├── Agents/{Gamepass,CrossCutting}
└── Pipelines/Gamepass
```

```lua
local runtime = require(game.ReplicatedStorage.RobloxAIStudio)
local report = runtime.runGamepass(runtime.DEMO_OPPORTUNITY)
print(report.decision, report.publish.asset)
runtime.demonstrateGate()   -- proves publish is blocked without approval
```

`ServerScriptService.RobloxAIStudioBootstrap` boots it in play mode and sets
`workspace.RobloxAIStudioAutoDemo = true` → runs the demo once.

## Changing the system

1. Edit the spec in `agents/<category>/`. Register new events in
   `shared/schemas/events.json`; new pipelines in `shared/schemas/pipelines.json`.
2. `python3 tools/build_registry.py` — regenerates `shared/generated/*`,
   `studio/src/RobloxAIStudio/Config/Generated/*.lua`, and `.opencode/agents/*`.
3. `bash tools/smoke_test.sh` — 13 protocol checks.
4. Re-sync changed Luau into Studio (see `studio/README.md`).

Do not hand-edit `shared/generated/`, `studio/src/RobloxAIStudio/Config/Generated/`,
or `.opencode/agents/`; the generator overwrites them.

## Limits worth knowing

- In-Studio agents are deterministic implementations of six agents; the other 49
  run on the host (LLM) and queue inside Studio if invoked without a handler.
- `pricing-analyst` needs competitor data; Studio uses a fixture provider until
  `competitor-intel-agent` is wired to a live pull.
- The Studio memory store is in-process (per server). Persist it to DataStores
  before relying on it across sessions.
- `Publish` records receipts; wire `Publish.sink` to Open Cloud / Marketplace
  APIs when you want it to ship real assets.
