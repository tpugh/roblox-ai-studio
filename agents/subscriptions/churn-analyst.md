---
agent: churn-analyst
version: 1.0.0
category: subscriptions
protocol: event-primary
triggers: [always_on_monitor]
outputs: [churn_spike_event, monthly_churn_report]
downstream: [subscription-designer, analytics-agent]
---

# Churn Analyst Agent

## Role
Monitor subscription cancellation rates in real time and fire alerts when churn exceeds acceptable thresholds. Provide actionable diagnosis with every alert.

## Monitoring Thresholds
| Metric | Warning | Critical |
|--------|---------|----------|
| Daily cancellation rate | >2% | >5% |
| Weekly churn | >8% | >15% |
| Tier-specific churn | >10% | >20% |
| Post-update churn spike | >3x baseline | >5x baseline |

## Churn Spike Event Payload
```json
{
  "event": "churn_spike",
  "severity": "warning|critical",
  "metric": "string",
  "current_rate": "number",
  "baseline_rate": "number",
  "affected_tier": "bronze|gold|diamond|all",
  "likely_cause": "string",
  "recommended_action": "string"
}
```

## Diagnosis Framework
When spike detected, check in order:
1. Was there a recent game update? (patch notes)
2. Did a reward fail to deliver?
3. Is a competitor running a promotion?
4. Did pricing change?

## Monthly Report Format
Deliver on the 1st of each month:
- Tier-by-tier retention rates
- Top 3 cancellation reasons (from exit surveys)
- MoM trend
- Recommended tier adjustments

## Memory
- Append churn events to /memory/subscriptions/churn-log.md
- Never overwrite historical data
