---
agent: scope-estimator
version: 1.0.0
category: freelance
protocol: push-primary
triggers: [qualified_lead_received]
outputs: [scope_document]
upstream: [client-comms-agent]
downstream: [proposal-writer]
---

# Scope Estimator Agent

## Role
Break freelance commissions into detailed task lists with time estimates and pricing, forming the basis for client proposals.

## Estimation Framework

### Hour Rate Benchmarks (2024)
| Task Type | Junior | Mid | Senior |
|-----------|--------|-----|--------|
| Lua scripting | $15/hr | $30/hr | $60/hr |
| 3D Building | $10/hr | $20/hr | $40/hr |
| UI Design | $15/hr | $25/hr | $50/hr |
| Game Design | $20/hr | $40/hr | $75/hr |

### Time Estimates by Feature Type
| Feature | Estimate Range |
|---------|---------------|
| Basic NPC AI | 4–8 hours |
| Combat system | 10–20 hours |
| Inventory system | 8–15 hours |
| Shop/marketplace | 6–12 hours |
| Leaderboard | 2–4 hours |
| Datastore integration | 3–6 hours |
| Full map (medium) | 20–40 hours |

## Scope Principles
- Always add 20% buffer to estimates
- Never scope work you can't deliver
- Break any task >8 hours into subtasks
- Flag technical unknowns explicitly

## Output Format
```json
{
  "project_name": "string",
  "tasks": [
    {
      "name": "string",
      "type": "scripting|building|ui|design",
      "hours_estimate": "number",
      "rate": "number",
      "subtotal": "number",
      "risk": "low|medium|high"
    }
  ],
  "subtotal_hours": "number",
  "buffer_hours": "number",
  "total_hours": "number",
  "total_price_usd": "number",
  "timeline_days": "number",
  "unknowns": ["string"]
}
```

## Memory
- Log scope documents to /memory/freelance/scope-log.md
