# Roblox AI Studio — Agent Communication Protocol Rules

> Version: 1.0.0  
> Every agent in this system MUST follow these rules without exception.

---

## 1. The Four Protocol Types

### 1.1 PUSH (Fire-and-move-on)
Agent sends its output payload to a downstream agent and continues without waiting for acknowledgment. Used for linear handoffs where the next agent can begin independently.

**Required envelope fields:** `from_agent`, `to_agent`, `payload_type`, `payload`, `timestamp`, `correlation_id`

### 1.2 PULL (Self-initiated fetch)
Agent fetches data it needs from a source before it can produce output. The agent is responsible for initiating this call. Used when live state is needed before acting.

**Required envelope fields:** `pulling_agent`, `data_source`, `query_params`, `timestamp`

### 1.3 EVENT (Async broadcast)
Agent fires a named event and continues without waiting. Any agent subscribed to that event reacts independently. Used for monitoring agents and cross-pipeline notifications.

**Required envelope fields:** `event_name`, `source_agent`, `payload`, `subscribers`, `timestamp`

### 1.4 SYNC (Blocking gate)
The pipeline pauses until this agent responds with a decision. Used for high-stakes gates: code shipping, compliance approval, balance reviews. If no response is received within 30 minutes, escalate to human review.

**Required envelope fields:** `blocking_agent`, `requesting_agent`, `asset`, `decision`, `timestamp`

---

## 2. Universal Message Envelope

All inter-agent messages MUST use this JSON envelope:

```json
{
  "envelope": {
    "message_id": "uuid-v4",
    "protocol": "push|pull|event|sync",
    "from_agent": "agent-slug",
    "to_agent": "agent-slug|broadcast",
    "timestamp": "ISO8601",
    "version": "1.0.0",
    "priority": "P0|P1|P2|P3",
    "correlation_id": "uuid (links all messages in one workflow chain)"
  },
  "payload": {
    "type": "string (payload schema name from events.json)",
    "data": {}
  }
}
```

---

## 3. Priority Levels

| Level | Label | Response SLA | When to Use |
|-------|-------|-------------|-------------|
| P0 | Critical | Immediate | Revenue loss, game down, data corruption, TOS violation going live |
| P1 | High | < 1 hour | Significant metric decline, churn spike, competitor threat |
| P2 | Medium | < 24 hours | Optimization opportunities, new features, non-urgent drops |
| P3 | Low | < 1 week | Background improvements, analytics refinements |

P0 and P1 events bypass the daily digest and are routed directly to relevant agents immediately.

---

## 4. Agent Responsibilities

### Every agent MUST:
- Validate the incoming message schema before processing
- Log every received and sent message to its memory log file
- Include `correlation_id` in all messages within the same workflow
- Handle failures gracefully — never silently drop a message
- Respond within its protocol type's defined behavior

### Upstream agents (senders) MUST:
- Always send complete payloads (never partial data)
- Set the correct priority level for the content
- Not retry a PUSH if no ACK received — use monitoring to detect failure

### Downstream agents (receivers) MUST:
- Acknowledge receipt for SYNC protocol messages
- Never block indefinitely — escalate to human after 30-minute wait
- Return structured error objects, never plain text error strings

---

## 5. Error Handling

### Error Response Format
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "agent": "string",
    "recoverable": "boolean",
    "retry_after_seconds": "number|null",
    "correlation_id": "string"
  }
}
```

### Error Code Reference
| Code | Meaning | Recommended Action |
|------|---------|-------------------|
| `SCHEMA_INVALID` | Payload doesn't match expected schema | Reject + notify sender with schema diff |
| `MISSING_DATA` | Required field absent from payload | Request resend with complete data |
| `BALANCE_FAIL` | Economy/perk balance check failed | Return flagged items to designer |
| `TOS_VIOLATION` | Content violates Roblox TOS | Hard reject + log to compliance — do not retry |
| `TIMEOUT` | SYNC agent didn't respond in 30 min | Escalate to human review immediately |
| `RATE_LIMITED` | Too many requests to this agent | Queue + retry with exponential backoff |
| `UPSTREAM_UNAVAILABLE` | Pull source is unreachable | Retry every 15 min for 2 hours, then alert Analytics Agent |

---

## 6. The Publish Gate — Non-Negotiable

**No asset ships to production without TOS Compliance Agent approval.**

The mandatory publish pipeline is:

```
Build Complete
    ↓
TOS Compliance Agent (SYNC — blocking)
    ↓ approved
SEO/Discovery Agent (optimize listing copy)
    ↓
Community Manager (announcement post)
    ↓
Published ✓
```

Any agent that bypasses this gate triggers a P0 alert, the publish is rolled back, and the violation is logged permanently in the compliance log.

---

## 7. Memory Protocol

### Every agent MUST:
- **Read** its memory log at the START of every run
- **Append** a summary entry at the END of every run
- **Never overwrite** historical entries (append-only, except noted in agent spec)
- Use format: `[ISO8601] | [field]: [value] | [field]: [value]`

### Memory access scope:
- Agents can read all memory files in their own category
- Cross-category reads require explicit permission in the agent's frontmatter
- **Analytics Agent has read access to ALL memory logs**
- No agent may write to another agent's memory file

### Sensitive data rules:
- Never log player PII (Roblox usernames, user IDs) in any memory file
- Anonymize all client identifiers in freelance logs
- Financial data files are confidential — access logged

---

## 8. Event Bus Architecture

The Analytics Agent is the event bus for all cross-pipeline communication.

**For cross-pipeline events:**
1. Source agent fires event to Analytics Agent
2. Analytics Agent routes to relevant downstream agents
3. Analytics Agent logs the routing decision

**Direct agent-to-agent events are only permitted when:**
- The target agent is known exactly
- The event is local to one pipeline (not cross-pipeline)
- Analytics Agent does not need visibility into it

---

## 9. Cron Schedule Coordination

Cron-triggered agents MUST NOT overlap. Stagger all scheduled runs:

| Agent | Schedule | UTC Offset Rule |
|-------|----------|----------------|
| Revenue Tracker | Daily 00:00 UTC | End of day — first to run |
| Competitor Intel | Sunday 06:00 UTC | Before week begins |
| Trend Spotter (UGC) | Monday 09:00 UTC | Start of UGC planning week |
| Clothing Trend Analyst | Tuesday 09:00 UTC | After UGC trends are set |
| Plugin Ideation | Wednesday 09:00 UTC | Mid-week |
| Update Scheduler | 1st of month 08:00 UTC | Before team planning |
| Tax/Finance Assistant | 1st of month 08:30 UTC | After scheduler runs |
| SEO Audit | 15th of month 09:00 UTC | Mid-month check |

---

## 10. Versioning & Migration

When an agent's input/output schema changes:
1. Bump the `version` in the agent's frontmatter
2. Create a migration note in `/docs/migrations/YYYY-MM-DD-agent-slug.md`
3. Messages in queue are processed under the version they were sent with
4. Downstream agents must handle both versions during the transition window (max 7 days)
5. After 7 days, old version support can be dropped

---

## 11. The Golden Rules (Summary)

1. **Nothing publishes without TOS Compliance approval** — absolute veto power
2. **All agents read memory before running** — context from prior runs informs every decision
3. **Analytics Agent is the event bus** — all cross-pipeline signals route through it
4. **SYNC gates block the pipeline** — Lua Writer, Perk Balancer, TOS approvals are non-negotiable
5. **Memory is append-only** — historical data is never overwritten or deleted
6. **P0 alerts are immediate** — never batch a critical alert into a digest
7. **Correlate everything** — use `correlation_id` so workflows can be traced end-to-end
