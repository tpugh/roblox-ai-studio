# Roblox AI Studio — Agent System

A multi-agent AI system for running a profitable Roblox development studio. 38 specialized agents across 10 revenue categories, coordinated through a central analytics hub with strict communication protocols.

---

## Revenue Streams Covered

| Category | Agents | Revenue Type |
|----------|--------|-------------|
| Gamepass | 4 | One-time in-game purchases |
| Dev Products | 4 | Repeatable purchases / consumables |
| Subscriptions | 3 | Monthly recurring Robux |
| Private Servers | 2 | Monthly server fees |
| UGC Items | 5 | Avatar marketplace sales |
| Clothing | 3 | Shirt / pants / t-shirt catalog |
| Plugins | 4 | Studio tool sales |
| Freelance | 4 | Commissioned development work |
| DevEx / Finance | 3 | Robux → USD conversion + accounting |
| Cross-cutting | 6 | Analytics, compliance, SEO, community, intel, scheduling |
| **Total** | **38** | All Roblox revenue streams |

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

The `agent-lint.yml` workflow validates on every push to `agents/`, `protocols/`, or `shared/schemas/`. It checks:
- All agent files have required sections (`## Role`, `## Rules`, `## Memory`)
- All agent files have required frontmatter fields
- All memory directories exist
- `events.json` is valid JSON with all required fields

---

---

## Roblox Studio Setup & MCP Integration (Windows)

This repository is a **spec/workflow system** (agent definitions, protocols, events, memory). To execute agent work directly in Roblox Studio, connect an MCP-capable AI client to the built-in [Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp).

### 1. Windows: set up Roblox Studio
1. **Install/update Roblox Studio:** Download and install the latest Roblox Studio from [Roblox Create](https://create.roblox.com/) (sign in → **Start Creating**) and allow it to update.
2. **Open a place:** Launch Studio, sign in, and open or create an experience/place so there is an active session to target.
3. **Install an MCP client:** Install your preferred MCP-capable client on the same Windows PC (e.g. Claude Desktop, Cursor, VS Code, Codex CLI, Gemini CLI, Claude Code, Antigravity).

### 2. Connect to the Roblox Studio MCP server
The Studio MCP server is built into Studio, runs locally, and communicates over **stdio**.

**Enable in Studio**
1. Open your place in Roblox Studio.
2. Open **Assistant** → **… (More)** → **Manage MCP Servers**.
3. Turn on **Enable Studio as MCP server**.
4. Confirm the green indicator shows connected clients after your client connects.

**Connect your client (Windows)**
- **Quick connect (if supported):** **Assistant Settings → MCP Servers** → expand **Quick connect** and toggle your installed client (restart Studio if it doesn’t appear).
- **JSON configuration:** add/merge into your client’s MCP config:
  ```json
  {
    "mcpServers": {
      "Roblox_Studio": {
        "command": "cmd.exe",
        "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
      }
    }
  }
  ```
- **CLI command (if required by client):**
  ```bat
  cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
  ```
- Restart the MCP client (keep Studio open with MCP enabled) and verify the connection indicator in Studio.

**Notes**
- Every MCP tool call requires a `studio_id`; use `list_roblox_studios` to select the correct open instance.
- MCP clients can read/modify open places—connect only trusted clients.
- If it doesn’t connect: restart Studio/client, confirm `%LOCALAPPDATA%\Roblox\mcp.bat` exists, and validate your MCP config JSON.

### 3. Leverage this repo with Roblox MCP
Use the MCP connection as the **execution/integration layer** so an MCP-capable orchestrator can perform the actions described by the agents in an open Studio session (while enforcing repo protocols and gates).

| Repo agents / workflows | Example MCP tools/capabilities to leverage |
|---|---|
| `lua-script-writer`, `roblox-lua-engineer`, `plugin-lua-developer` | `script_read`, `script_search`, `script_grep`, `multi_edit`, `execute_luau`, `search_game_tree`, `inspect_instance` |
| `ui-ux-builder`, `level-world-builder`, `animation-vfx-audio-agent`, asset/creative flows | Data model exploration + asset tools (e.g. `insert_asset`, `search_asset`, `generate_*`, `upload_image`) |
| `qa-playtest-agent` | `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture`, navigation/input simulation, `execute_luau` |
| `build-release-agent`, `roblox-api-publishing-agent` | `save_place` and Studio-side release steps; pair with publishing/compliance flows (and Open Cloud via MCP where applicable) |
| `orchestrator-runtime-agent`, `project-production-manager` | Enforce PUSH/PULL/EVENT/SYNC and TOS gates, pass `correlation_id`s, append `memory/` logs, target correct `studio_id` |

**Operational checklist:** keep Studio open with MCP enabled → run an orchestrator that reads `agents/*.md`, routes per `shared/schemas/events.json` and `protocols/PROTOCOL_RULES.md` → allow MCP tool calls for real edits/tests/saves → preserve **TOS Compliance** (SYNC publish gate) and **Analytics** event-bus rules.

*References: [Connect to the Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp), [Use Open Cloud with the Studio MCP server](https://create.roblox.com/docs/studio/mcp-open-cloud).*

*Internal studio use only. Not for distribution.*

