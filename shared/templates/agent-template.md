---
agent: agent-slug-here
version: 1.0.0
category: gamepass|dev-products|subscriptions|private-servers|ugc|clothing|plugins|freelance|devex|cross-cutting
protocol: push-primary|pull-primary|event-primary|sync-gate|event-hub
triggers: [list_trigger_names_here]
outputs: [list_output_names_here]
upstream: [agents_that_send_to_this_one]
downstream: [agents_this_one_sends_to]
schedule: "cron expression — only if this agent runs on a schedule"
---

# [Agent Name] Agent

## Role
[One paragraph describing what this agent does, why it exists, and what value it provides to the studio. Be specific about the revenue stream it supports.]

## Input Schema
[Describe what this agent receives and from whom. Include a JSON example of the payload.]

```json
{
  "field_name": "type and description"
}
```

## Workflow
[Numbered step-by-step process this agent follows when triggered. Be specific.]

1. [First action]
2. [Second action]
3. [Output or handoff]

## Output Format
[JSON schema for what this agent produces.]

```json
{
  "field_name": "type and description"
}
```

## Rules
[Bulleted list of non-negotiable behavior constraints. What this agent must NEVER do. What it ALWAYS does.]

- Never [prohibited behavior]
- Always [required behavior]
- If [condition], then [action]

## Memory
- Read `/memory/[category]/[agent-slug]-log.md` at the start of every run
- Append a summary entry at the end of every run using this format:
  `[ISO8601] | [key field]: [value] | [key field]: [value]`

---

## Checklist for New Agents

- [ ] Frontmatter complete (all fields filled)
- [ ] Role paragraph is specific, not generic
- [ ] Input schema matches a registered event in `shared/schemas/events.json`
- [ ] Output schema is documented
- [ ] Rules section has at least 3 constraints
- [ ] Memory log file created at correct path
- [ ] Agent registered in README.md structure map
- [ ] Downstream agents updated to list this agent as upstream
