# Studio runtime — Roblox AI Studio

The Luau runtime that runs the agent system's protocols inside a Roblox place.
It is generated-adjacent: the registry tables come from `tools/build_registry.py`,
the behaviour lives here.

## Layout

```
studio/src/
├── RobloxAIStudio/                 → ReplicatedStorage.RobloxAIStudio (ModuleScript)
│   ├── Init.lua                    runtime assembly + public API
│   ├── Protocol.lua                envelopes, priorities, error objects, field checks
│   ├── Bus.lua                     PUSH/EVENT delivery, PULL providers, analytics hub
│   ├── Memory.lua                  append-only logs, ownership, PII guard
│   ├── Gates.lua                   SYNC gates, 30-minute escalation, approval ledger
│   ├── Publish.lua                 publish gate (no approval → no publish)
│   ├── Orchestrator.lua            routing, workflow state, retries, sync reviews
│   ├── Agents/Gamepass.lua         designer, balancer, copywriter, pricing, lua writer
│   ├── Agents/CrossCutting.lua     tos-compliance checklist engine
│   ├── Pipelines/Gamepass.lua      end-to-end pipeline with gates
│   └── Config/Generated/           GENERATED — agents, events, pipelines tables
└── RobloxAIStudioBootstrap.server.lua → ServerScriptService.RobloxAIStudioBootstrap
```

## Behaviour

| Module | Implements |
| --- | --- |
| `Protocol` | Universal envelope, P0–P3 SLAs, `SCHEMA_INVALID`/`MISSING_DATA`/`BALANCE_FAIL`/`TOS_VIOLATION`/`TIMEOUT`/`RATE_LIMITED`/`UPSTREAM_UNAVAILABLE`, per-event field validation |
| `Bus` | PUSH → inbox when the target has no handler; EVENT fan-out with unregistered subscribers filtered; cross-pipeline events mirrored to `analytics-agent`; PULL providers |
| `Memory` | Append-only entries `[ISO8601] | k: v | …`; writer must be the owning agent; analytics + orchestrator may read across categories; PII fields rejected |
| `Gates` | `open`/`respond`, owner-only decisions, rejections need a reason, 30-minute sweep → `TIMEOUT` escalation, approvals indexed by asset |
| `Publish` | `check` re-reads the approval ledger (never trusts a caller), blocks with `TOS_VIOLATION`, records receipts, supports rollback, optional `sink` hook |
| `Orchestrator` | Workflow state per `correlation_id`, stage history, retry with backoff for recoverable codes, `syncReview` (open → invoke → respond) |

### Gamepass pipeline

`analytics_opportunity` → **designer** (3 concepts, one QoL perk each, currency
perks auto-flagged high risk) → **perk-balancer** (SYNC: power > 7 flagged,
infinite resources rejected, exclusivity < 5 flagged) → **copywriter** (AIDA,
50/100/1000/20-char limits, A/B variant) → **pricing-analyst** (tier from peak
power, anchored to competitor band; `MISSING_DATA` without competitor data) →
`gamepass_ready` → **lua-script-writer** (SYNC: server-authoritative purchase
handler, ownership check, idempotent grants) → **tos-compliance** (SYNC publish
gate) → publish.

## Public API

```lua
local runtime = require(game.ReplicatedStorage.RobloxAIStudio)

runtime.runGamepass(opportunity, { competitor_data = {...}, correlation_id = "…" })
runtime.demonstrateGate()      -- 5 assertions: blocked before approval, scam rejected, clean approved…
runtime.snapshot()             -- registry/bus/gates/publish/orchestrator/memory counters
runtime.trace(correlationId)   -- workflow history
runtime.memoryDump()
runtime.publish:request{ asset = "…", asset_type = "game_update" }
```

## Install / re-sync

The modules are plain Luau files. To install or re-sync with an MCP-connected
Studio:

1. Ensure the instance tree exists: `ReplicatedStorage.RobloxAIStudio`
   (ModuleScript) with Folders `Config/Generated`, `Agents`, `Pipelines`; plus
   `Protocol`, `Memory`, `Bus`, `Gates`, `Publish`, `Orchestrator` ModuleScripts;
   `Agents/{Gamepass,CrossCutting}`, `Pipelines/Gamepass` ModuleScripts; and
   `ServerScriptService.RobloxAIStudioBootstrap` (Script).
2. For each file, set `.Source` to the file text (a local HTTP server plus
   `execute_luau` works well; `multi_edit` also works).
3. Verify:

```lua
local runtime = require(game.ReplicatedStorage.RobloxAIStudio)
return runtime.snapshot()
```

`Init.lua` becomes the root module's source; every other file maps to the
same-named child (directories map to Folders).

## Verification (Place1, 2026-11-15)

- 55 agents / 18 events / 5 pipelines loaded from the generated registry.
- Gamepass demo: `decision = "published"`, gates `balance`, `implementation`,
  `tos` all `approved`, receipt `gamepass/momentum-pass`, price 800 R$.
- Gate demo: 5/5 — unreviewed publish blocked (`TOS_VIOLATION`), scam copy
  rejected (4 blockers, 2 warnings), scam publish blocked, clean copy approved
  and published.
- Invalid analytics payload → `SCHEMA_INVALID` with the missing field list.
- Workflow trace shows every stage in order, including both SYNC gates.

## Not done yet

- Live play-mode run (bootstrap is installed; only Edit-mode calls were exercised).
- Persisting Studio memory to DataStores.
- A real `Publish.sink` (Open Cloud gamepass creation / asset upload).
- Deterministic implementations for the other 49 agents — they queue on the bus
  and run on the host instead.
