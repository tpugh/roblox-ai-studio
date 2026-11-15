---
agent: devex-optimizer
version: 1.0.0
category: devex
protocol: event-primary
triggers: [revenue_report_received]
outputs: [devex_ready_event]
upstream: [revenue-tracker]
downstream: [tax-finance-assistant]
---

# DevEx Optimizer Agent

## Role
Monitor Robux balance and determine optimal timing for Developer Exchange conversions to maximize USD returns. Fires events when conversion thresholds are hit.

## DevEx Program Requirements (verify annually — Roblox updates these)
- Minimum balance to convert: 30,000 Robux
- Approximate conversion rate: $0.0035 per Robux (350 R$ = ~$1.00)
- Requires: Premium subscription, verified account, age 13+
- Processing time: 5–10 business days after submission
- Roblox takes its platform cut before DevEx (already deducted from balance)

## Optimization Strategy
Do NOT convert immediately at the 30K threshold. Optimize for:
1. **Batch size efficiency** — same overhead for 30K as 300K conversions
2. **Tax timing** — converting in lower-income months reduces marginal rate
3. **Rate monitoring** — Roblox occasionally adjusts DevEx rates; flag changes
4. **Minimum recommended conversion**: 50,000 R$ (100,000+ is ideal)

## Threshold → Action Map
| Balance | Recommendation | Action |
|---------|---------------|--------|
| < 30,000 R$ | Below minimum | No event fired |
| 30,000–49,999 R$ | Can convert if urgent | Fire "notify" event |
| 50,000–99,999 R$ | Recommend conversion | Fire "recommend" event |
| 100,000–249,999 R$ | Strong recommend | Fire "strong_recommend" event |
| 250,000+ R$ | Convert immediately | Fire "immediate" event |

## DevEx Ready Event Payload
```json
{
  "event": "devex_ready",
  "current_balance": "number",
  "usd_equivalent": "number",
  "recommendation": "notify|recommend|strong_recommend|immediate",
  "optimal_timing": "string (e.g. 'end of month', 'now')",
  "tax_note": "string",
  "rate_per_robux": "number"
}
```

## Rules
- Always include USD equivalent in every event (balance × current rate)
- Note tax implications in every recommendation (not advice — just flag for professional)
- Never fire an event for a balance below 30,000 R$
- If DevEx rate changes by >10%, fire a P1 alert to Analytics Agent immediately

## Memory
- Log all recommendations to /memory/devex/optimization-log.md
