# Roblox AI Studio — Agent System

A multi-agent AI system for running a profitable Roblox development studio. 55 specialized agents across 10 revenue categories, coordinated through a central analytics hub with strict communication protocols.

---

## Revenue Streams Covered

| Category | Agents | Revenue Type |
|----------|--------|-------------|
| Gamepass | 5 | One-time in-game purchases |
| Dev Products | 4 | Repeatable purchases / consumables |
| Subscriptions | 3 | Monthly recurring Robux |
| Private Servers | 2 | Monthly server fees |
| UGC Items | 6 | Avatar marketplace sales |
| Clothing | 4 | Shirt / pants / t-shirt catalog |
| Plugins | 4 | Studio tool sales |
| Freelance | 4 | Commissioned development work |
| DevEx / Finance | 3 | Robux → USD conversion + accounting |
| Cross-cutting | 20 | Analytics, compliance, SEO, community, intel, scheduling |
| **Total** | **55** | All Roblox revenue streams |

Counts reflect every spec in `agents/` (verified by `tools/build_registry.py` from
file metadata, not by hand). The original design shipped 38; the 17 added later
are summarized in [`ADDED_AGENTS.md`](ADDED_AGENTS.md).

---

## Repository Structure

```
roblox-ai-studio/
├── README.md                          # This file
├── .github/
│   └── workflows/
│       └── agent-lint.yml             # CI: validates all agent files
├── agents/
│   ├── gamepass/
│   │   ├── gamepass-designer.md
│   │   ├── perk-balancer.md
│   │   ├── conversion-copywriter.md
│   │   └── pricing-analyst.md
│   ├── dev-products/
│   │   ├── spending-trigger-analyst.md
│   │   ├── economy-architect.md
│   │   ├── consumable-designer.md
│   │   └── bundle-strategist.md
│   ├── subscriptions/
│   │   ├── subscription-designer.md
│   │   ├── retention-agent.md
│   │   └── churn-analyst.md
│   ├── private-servers/
│   │   ├── private-server-configurator.md
│   │   └── pricing-optimizer-ps.md
│   ├── ugc/
│   │   ├── trend-spotter.md
│   │   ├── ugc-concept-artist.md
│   │   ├── item-naming-agent.md
│   │   ├── limited-drop-strategist.md
│   │   └── accessory-scripter.md
│   ├── clothing/
│   │   ├── clothing-trend-analyst.md
│   │   ├── clothing-designer.md
│   │   └── volume-publisher.md
│   ├── plugins/
│   │   ├── plugin-ideation-agent.md
│   │   ├── plugin-lua-developer.md
│   │   ├── plugin-docs-writer.md
│   │   └── plugin-support-agent.md
│   ├── freelance/
│   │   ├── client-comms-agent.md
│   │   ├── scope-estimator.md
│   │   ├── proposal-writer.md
│   │   └── portfolio-builder.md
│   ├── devex/
│   │   ├── revenue-tracker.md
│   │   ├── devex-optimizer.md
│   │   └── tax-finance-assistant.md
│   └── cross-cutting/
│       ├── analytics-agent.md         # Event hub — connects all pipelines
│       ├── tos-compliance-agent.md    # Publish gate — absolute veto power
│       ├── update-scheduler.md
│       ├── community-manager.md
│       ├── competitor-intel-agent.md
│       └── seo-discovery-agent.md
├── memory/
│   ├── gamepass/                      # designer-log, balance-log, copy-log, pricing-log
│   ├── dev-products/                  # economy-log, product-log, trigger-log, bundle-log
│   ├── subscriptions/                 # design-log, retention-log, churn-log
│   ├── private-servers/               # config-log, pricing-log
│   ├── ugc/                           # concept-log, trend-log, naming-log, drop-log, build-log
│   ├── clothing/                      # design-log, trend-log, publish-log
│   ├── plugins/                       # ideation-log, build-log, docs-log, support-log
│   ├── freelance/                     # client-log, scope-log, proposal-log, portfolio.md
│   ├── devex/                         # revenue-log, optimization-log, finance-ledger.md
│   └── cross-cutting/                 # analytics-kpi-log, community-log, compliance-log,
│                                      # intel-log, release-calendar.md, seo-log
├── protocols/
│   └── PROTOCOL_RULES.md             # All inter-agent communication rules
├── shared/
│   ├── schemas/
│   │   └── events.json               # All named events: schema + subscribers
│   └── templates/
│       └── agent-template.md         # Template for creating new agents
└── docs/
    └── migrations/                   # Schema migration notes (created when agents update)
```

---

## Communication Protocols

| Protocol | Type | Behavior |
|----------|------|---------|
| **PUSH** | Fire-and-move-on | Sends payload downstream, doesn't wait |
| **PULL** | Self-initiated fetch | Agent fetches what it needs before acting |
| **EVENT** | Async broadcast | Fires named event, any subscriber reacts |
| **SYNC** | Blocking gate | Pipeline pauses until agent confirms |

Full rules: [`protocols/PROTOCOL_RULES.md`](protocols/PROTOCOL_RULES.md)

---

## The Two Absolute Rules

### 1. TOS Compliance Agent has final veto on all publishes
Nothing — no gamepass, UGC item, plugin, game update, or marketing post — ships without `tos-compliance-agent` returning `decision: "approved"`. This is a hard SYNC gate, not a suggestion.

### 2. Analytics Agent is the event bus
All cross-pipeline signals route through `analytics-agent`. It is the only agent with read access to all memory logs, and all P0/P1 alerts originate from it.

---

## Pipeline Flow Diagrams

### Gamepass Pipeline
```
Analytics Agent (opportunity event)
    → Gamepass Designer (3 concepts)
    → Perk Balancer (SYNC: balance check)
    → Conversion Copywriter (title + description)
    → Pricing Analyst (price + "gamepass_ready" event)
    → Lua Script Writer (SYNC: implementation)
    → TOS Compliance Agent (SYNC: publish gate)
    → Published ✓
```

### UGC Item Pipeline
```
Trend Spotter (weekly PULL → trend report)
    → UGC Concept Artist (item concepts)
    → Item Naming Agent (searchable names)
    → Limited Drop Strategist (PULL: drop schedule → "drop_scheduled" event)
    → Accessory Scripter (SYNC: build confirmation)
    → TOS Compliance Agent (SYNC: publish gate)
    → Community Manager (teaser posts)
    → Published ✓
```

### Plugin Pipeline
```
Plugin Ideation Agent (weekly PULL → ranked ideas)
    → Plugin Lua Developer (SYNC: build)
    → Plugin Docs Writer (README + DevForum post)
    → Plugin Support Agent (always-on monitor → loops back)
    → TOS Compliance Agent (SYNC: publish gate)
    → Published ✓
```

### Freelance Pipeline
```
Client Comms Agent (inbound → qualify → "qualified_lead" event)
    → Scope Estimator (task breakdown + pricing)
    → Proposal Writer (client-facing proposal)
    → Client Comms Agent (delivery + negotiation)
    → [Project execution]
    → Portfolio Builder (PULL: completion → update portfolio)
```

### DevEx Pipeline
```
Revenue Tracker (daily PULL → consolidated report)
    → DevEx Optimizer (threshold monitoring → "devex_ready" event)
    → Tax/Finance Assistant (ledger + quarterly reports)
```

---

---

## Runtimes

The specs are executable through two runtimes that share one generated registry:

| Runtime | Entry point | What it enforces |
|---------|-------------|------------------|
| Host | `python3 tools/studio.py` + `.opencode/agents/*` | transport, SYNC gates, memory, publish gate, one subagent per agent spec |
| Studio | `studio/src/RobloxAIStudio/` → `ReplicatedStorage.RobloxAIStudio` | envelope routing, event bus, gates, memory, publish gate, gamepass pipeline |

```sh
python3 tools/build_registry.py   # specs → registry JSON + Luau + subagents
bash tools/smoke_test.sh          # 13 protocol checks
```

Operating rules: [`AGENTS.md`](AGENTS.md). Studio runtime details:
[`studio/README.md`](studio/README.md). Pipeline graphs:
[`shared/schemas/pipelines.json`](shared/schemas/pipelines.json).

## Getting Started

### Add a New Agent
1. Copy `shared/templates/agent-template.md`
2. Fill in all required sections (Role, Input Schema, Workflow, Output Format, Rules, Memory)
3. Create the memory log file at `memory/[category]/[agent-slug]-log.md`
4. Register any new events in `shared/schemas/events.json`
5. Update this README's structure map
6. Run CI (`agent-lint.yml`) to validate

### Trigger a Pipeline Manually
Each agent's `triggers` frontmatter lists what starts it. For manual runs:
1. Identify the first agent in the pipeline
2. Construct a valid payload matching its `Input Schema`
3. Send it with the correct protocol envelope (see `PROTOCOL_RULES.md`)

### Add a Memory Entry (agent completing a run)
Append to the agent's log file using this format:
```
[2026-11-14T00:00:00Z] | [key_field]: value | [key_field]: value | [key_field]: value
```

---

## Priority Levels

| Level | SLA | Use Case |
|-------|-----|---------|
| P0 | Immediate | Revenue loss, game down, TOS violation going live |
| P1 | < 1 hour | Major metric decline, churn spike, competitor threat |
| P2 | < 24 hours | New features, drops, optimizations |
| P3 | < 1 week | Background improvements, analytics |

---

## CI Status

The `agent-lint.yml` workflow validates on every push to `agents/`, `protocols/`, `shared/`, `studio/`, `tools/`, or `.opencode/`. It checks:
- All agent files have required sections (`## Role`, `## Rules`, `## Memory`)
- All agent files have required frontmatter fields
- All memory directories exist
- `events.json` is valid JSON with all required fields
- The generated registry, Luau config, and subagents match the specs (no drift)
- The protocol CLI passes its smoke tests

---

*Internal studio use only. Not for distribution.*
