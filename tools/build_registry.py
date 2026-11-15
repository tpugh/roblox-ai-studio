#!/usr/bin/env python3
"""Build the machine-readable registry from the agent specs.

The markdown files in agents/ are the single source of truth. This script
parses them (frontmatter + sections), validates them against the protocol
rules and the event registry, and emits:

  shared/generated/registry.json      canonical agent registry
  shared/generated/events.json        normalised event registry
  shared/generated/pipelines.json     pipelines with resolved agents
  studio/src/RobloxAIStudio/Config/Generated/*.lua   Luau mirrors for Studio
  .opencode/agents/*.md               runnable OpenCode subagents

Run with:  python3 tools/build_registry.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = ROOT / "agents"
MEMORY_DIR = ROOT / "memory"
SCHEMAS_DIR = ROOT / "shared" / "schemas"
GENERATED_DIR = ROOT / "shared" / "generated"
STUDIO_CONFIG_DIR = ROOT / "studio" / "src" / "RobloxAIStudio" / "Config" / "Generated"
OPENCODE_AGENTS_DIR = ROOT / ".opencode" / "agents"

REQUIRED_FRONTMATTER = ("agent", "version", "category", "protocol")
REQUIRED_SECTIONS = ("Role", "Rules", "Memory")
PROTOCOLS = ("push", "pull", "event", "sync")
PROTOCOL_PROFILES = ("push-primary", "pull-primary", "event-primary", "sync-gate", "event-hub")

# Frontmatter values that are not event names but control-plane tokens.
CONTROL_TRIGGERS = {
    "manual_request",
    "workflow_start",
    "agent_message",
    "retry_requested",
    "any_publish_action",
    "perk_spec_received",
    "approved_spec_received",
    "copy_received",
}
CONTROL_TARGETS = {"all_agents", "build-queue", "all_publish_pipelines", "all_pipeline_agents", "varies_by_affected_pipeline"}

RULE_SNIPPET = """Read your agent spec before acting: `agents/{category}/{slug}.md`.
Enforce `protocols/PROTOCOL_RULES.md`:
- Validate incoming payloads against your Input Schema before processing.
- Log every SYNC decision and every threshold/priority change with `python3 tools/studio.py log`.
- Nothing publishes without a TOS approval record; call `python3 tools/studio.py publish-check --asset <id>` before any publish step.
- Append-only memory: only write your own log file, never another agent's.
- Use `correlation_id` on every message; route cross-pipeline events through the analytics agent.
- On invalid or missing input return a structured error (`SCHEMA_INVALID` / `MISSING_DATA`), never plain text.
Use the protocol CLI for all transport:
- `python3 tools/studio.py agents show <slug>` — registry view
- `python3 tools/studio.py inbox <slug>` — fetch PUSH/EVENT work
- `python3 tools/studio.py send --from {slug} --to <slug> --protocol push --type <payload_type> --payload <file> --correlation <id>`
- `python3 tools/studio.py sync-open --from {slug} --gate-owner <slug> --asset <id> --correlation <id>`
- `python3 tools/studio.py sync-respond --from <slug> --gate <id> --decision approved|rejected|needs_revision --reason "<text>"`
- `python3 tools/studio.py log --agent {slug} --field key=value --field key=value`"""


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def split_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    if not text.startswith("---"):
        fail("agent file does not start with frontmatter")
    end = text.find("\n---", 3)
    if end == -1:
        fail("frontmatter is not closed with ---")
    raw = text[3:end].strip("\n")
    body = text[end + 4 :]
    data = yaml.safe_load(raw) or {}
    if not isinstance(data, dict):
        fail("frontmatter did not parse to a mapping")
    return data, body


def split_sections(body: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    matches = list(re.finditer(r"^##\s+(.+?)\s*$", body, flags=re.MULTILINE))
    for i, match in enumerate(matches):
        name = match.group(1).strip()
        start = match.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        sections[name] = body[start:end].strip()
    return sections


def listify(value: Any) -> list[str]:
    if value is None or value == "":
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    return [part.strip() for part in str(value).split(",") if part.strip()]


def fenced_json(block: str) -> Any:
    match = re.search(r"```(?:json)?\s*(.+?)```", block, flags=re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return None


def numbered_items(block: str) -> list[str]:
    items = []
    for line in block.splitlines():
        match = re.match(r"^\s*\d+\.\s+(.*)$", line)
        if match:
            items.append(match.group(1).strip())
    return items


def bullet_items(block: str) -> list[str]:
    items = []
    for line in block.splitlines():
        match = re.match(r"^\s*[-*]\s+(.*)$", line)
        if match:
            items.append(match.group(1).strip())
    return items


def load_agents() -> list[dict[str, Any]]:
    agents: list[dict[str, Any]] = []
    for path in sorted(AGENTS_DIR.glob("*/*.md")):
        text = path.read_text(encoding="utf-8")
        meta, body = split_frontmatter(text)
        sections = split_sections(body)
        for field in REQUIRED_FRONTMATTER:
            if field not in meta:
                fail(f"{path}: missing frontmatter field '{field}'")
        for section in REQUIRED_SECTIONS:
            if section not in sections:
                fail(f"{path}: missing required section '## {section}'")
        slug = str(meta["agent"])
        if slug != path.stem:
            fail(f"{path}: frontmatter agent '{slug}' does not match file name")
        category = str(meta["category"])
        if category != path.parent.name:
            fail(f"{path}: category '{category}' does not match directory '{path.parent.name}'")
        protocol = str(meta["protocol"])
        if protocol not in PROTOCOL_PROFILES:
            fail(f"{path}: unknown protocol profile '{protocol}'")
        heading = re.search(r"^#\s+(.+?)\s*$", body, flags=re.MULTILINE)
        name = heading.group(1).strip() if heading else slug.replace("-", " ").title()
        name = re.sub(r"\s+Agent$", "", name).strip()

        agents.append(
            {
                "slug": slug,
                "name": name,
                "version": str(meta["version"]),
                "category": category,
                "protocol": protocol,
                "triggers": listify(meta.get("triggers")),
                "outputs": listify(meta.get("outputs")),
                "upstream": listify(meta.get("upstream")),
                "downstream": listify(meta.get("downstream")),
                "connects_to": listify(meta.get("connects_to")),
                "schedule": str(meta.get("schedule") or ""),
                "role": sections.get("Role", "").strip(),
                "input_schema": fenced_json(sections.get("Input Schema", "")),
                "workflow": numbered_items(sections.get("Workflow", "")),
                "output_schema": fenced_json(sections.get("Output Format", "")),
                "rules": bullet_items(sections.get("Rules", "")),
                "memory": bullet_items(sections.get("Memory", "")),
                "spec_path": f"agents/{category}/{path.name}",
            }
        )
    return agents


def normalise_trigger_name(token: str) -> str:
    base = token
    for suffix in ("_event", "_received", "_requested", "_ready", "_complete", "_update"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    return base


def is_local_trigger(token: str, events: dict[str, Any]) -> bool:
    """Workflow-local tokens (cron, monitors, manual asks) are not registry events."""
    if token in CONTROL_TRIGGERS:
        return True
    if token in ("schedule", "always_on_monitor", "session_event_stream", "inbound_inquiry", "weekly_cron"):
        return True
    if token.endswith("_cron"):
        return True
    return normalise_trigger_name(token) in events


def validate(agents: list[dict[str, Any]], events: dict[str, Any], pipelines: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    unresolved_triggers: dict[str, list[str]] = {}
    slugs = {a["slug"] for a in agents}
    for agent in agents:
        for target in agent["upstream"] + agent["downstream"] + agent["connects_to"]:
            if target not in slugs and target not in CONTROL_TARGETS and target not in events:
                warnings.append(f"{agent['slug']}: references unknown agent/event '{target}'")
        for trigger in agent["triggers"]:
            if trigger not in events and not is_local_trigger(trigger, events):
                unresolved_triggers.setdefault(trigger, []).append(agent["slug"])
        memory_path = MEMORY_DIR / agent["category"]
        if not memory_path.is_dir():
            warnings.append(f"{agent['slug']}: memory directory missing for category '{agent['category']}'")
        if not agent["rules"]:
            warnings.append(f"{agent['slug']}: no Rules bullets parsed")
    for pipeline_name, pipeline in pipelines["pipelines"].items():
        for stage in pipeline["stages"]:
            if stage["agent"] not in slugs:
                warnings.append(f"pipeline '{pipeline_name}' stage '{stage['id']}': unknown agent '{stage['agent']}'")
            emits = stage.get("emits")
            if emits and emits not in events:
                warnings.append(f"pipeline '{pipeline_name}' stage '{stage['id']}': emits unregistered event '{emits}'")
            if stage.get("gate") and stage["agent"] != "tos-compliance-agent" and not stage.get("gate_error"):
                if not any(a["slug"] == stage["agent"] and "sync" in a["protocol"] for a in agents):
                    warnings.append(
                        f"pipeline '{pipeline_name}' stage '{stage['id']}': gate agent '{stage['agent']}' is not sync-gated"
                    )
    if unresolved_triggers:
        summary = ", ".join(f"{token} ({len(owners)})" for token, owners in sorted(unresolved_triggers.items()))
        warnings.append(f"{len(unresolved_triggers)} trigger tokens are not registry events: {summary}")
    return warnings


def lua_quote(value: Any) -> str:
    text = "" if value is None else str(value)
    out = ['"']
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 32:
            out.append(f"\\{ord(ch)}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def lua_value(value: Any, indent: int = 0) -> str:
    pad = "\t" * indent
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = ["{"]
        for key, item in value.items():
            lines.append(f"{pad}\t[{lua_quote(key)}] = {lua_value(item, indent + 1)},")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "{}"
        if all(not isinstance(v, (dict, list)) for v in value):
            return "{ " + ", ".join(lua_value(v) for v in value) + " }"
        lines = ["{"]
        for item in value:
            lines.append(f"{pad}\t{lua_value(item, indent + 1)},")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return lua_quote(value)


def lua_module(header: str, name: str, value: Any) -> str:
    return (
        f"--!strict\n-- {header}\n-- GENERATED by tools/build_registry.py — do not edit by hand.\n\n"
        f"local {name} = {lua_value(value)}\n\nreturn {name}\n"
    )


def opencode_agent(agent: dict[str, Any]) -> str:
    role_first = agent["role"].split(". ")[0].strip().rstrip(".")
    description = f"{role_first}. ({agent['category']} agent, {agent['protocol']}.)"
    description = description.replace('"', "'").replace("\n", " ")[:280]
    rules = "\n".join(f"- {rule}" for rule in agent["rules"]) or "- Follow the spec's Rules section."
    body = RULE_SNIPPET.format(slug=agent["slug"], category=agent["category"])
    return f"""---
description: {json.dumps(description, ensure_ascii=False)}
mode: subagent
permissions:
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "python3 tools/studio.py *"
    effect: allow
  - action: shell
    resource: "git status"
    effect: allow
  - action: edit
    resource: "memory/**"
    effect: allow
  - action: edit
    resource: "*"
    effect: deny
  - action: subagent
    resource: "*"
    effect: deny
---

You are `{agent['slug']}`, the {agent['name']} in the Roblox AI Studio agent system.

{body}

## Non-negotiable rules (from the spec)
{rules}
"""


def main() -> None:
    raw_events = json.loads((SCHEMAS_DIR / "events.json").read_text(encoding="utf-8"))
    events = raw_events["events"]
    raw_pipelines = json.loads((SCHEMAS_DIR / "pipelines.json").read_text(encoding="utf-8"))
    agents = load_agents()

    if len(agents) != 38:
        print(f"WARN: expected 38 agents, parsed {len(agents)}")

    warnings = validate(agents, events, raw_pipelines)
    for warning in warnings:
        print(f"WARN: {warning}")

    normalised_events = {}
    for name, event in events.items():
        normalised_events[name] = {
            "name": name,
            "description": event.get("description", ""),
            "source": event.get("source", ""),
            "subscribers": list(event.get("subscribers", [])),
            "priority": event.get("priority", "P2"),
            "fields": event.get("fields", {}),
        }

    resolved_pipelines = {}
    for name, pipeline in raw_pipelines["pipelines"].items():
        stages = []
        for index, stage in enumerate(pipeline["stages"]):
            stages.append(
                {
                    "index": index + 1,
                    "id": stage["id"],
                    "agent": stage["agent"],
                    "in_protocol": stage["in_protocol"],
                    "out_protocol": stage["out_protocol"],
                    "produces": stage["produces"],
                    "gate": bool(stage.get("gate", False)),
                    "gate_error": stage.get("gate_error"),
                    "publish_gate": bool(stage.get("publish_gate", False)),
                    "emits": stage.get("emits"),
                }
            )
        resolved_pipelines[name] = {
            "name": pipeline["name"],
            "category": pipeline["category"],
            "entry_event": pipeline.get("entry_event"),
            "publish_gate": pipeline.get("publish_gate"),
            "stages": stages,
        }

    by_slug = {agent["slug"]: agent for agent in agents}
    registry = {
        "version": "1.0.0",
        "generated_from": "agents/*/*.md",
        "count": len(agents),
        "categories": sorted({agent["category"] for agent in agents}),
        "by_category": {
            category: [a["slug"] for a in agents if a["category"] == category]
            for category in sorted({agent["category"] for agent in agents})
        },
        "agents": by_slug,
    }

    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    (GENERATED_DIR / "registry.json").write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (GENERATED_DIR / "events.json").write_text(
        json.dumps({"version": raw_events.get("version"), "events": normalised_events}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    (GENERATED_DIR / "pipelines.json").write_text(
        json.dumps({"version": raw_pipelines.get("version"), "pipelines": resolved_pipelines}, indent=2, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )

    STUDIO_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    (STUDIO_CONFIG_DIR / "Agents.lua").write_text(
        lua_module("Agent registry for the Roblox AI Studio runtime.", "Agents", by_slug), encoding="utf-8"
    )
    (STUDIO_CONFIG_DIR / "Events.lua").write_text(
        lua_module("Event schema registry (shared/schemas/events.json).", "Events", normalised_events), encoding="utf-8"
    )
    (STUDIO_CONFIG_DIR / "Pipelines.lua").write_text(
        lua_module("Pipeline graphs (shared/schemas/pipelines.json).", "Pipelines", resolved_pipelines), encoding="utf-8"
    )

    OPENCODE_AGENTS_DIR.mkdir(parents=True, exist_ok=True)
    for old in OPENCODE_AGENTS_DIR.glob("*.md"):
        old.unlink()
    for agent in agents:
        (OPENCODE_AGENTS_DIR / f"{agent['slug']}.md").write_text(opencode_agent(agent), encoding="utf-8")

    # Round-trip every generated subagent so a bad description can never ship.
    for path in OPENCODE_AGENTS_DIR.glob("*.md"):
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---"):
            fail(f"{path}: generated agent has no frontmatter")
        meta, _ = split_frontmatter(text)
        if meta.get("mode") != "subagent" or not meta.get("description"):
            fail(f"{path}: generated agent is missing description/mode")

    print(f"OK: {len(agents)} agents, {len(normalised_events)} events, {len(resolved_pipelines)} pipelines")
    print(f"OK: wrote {GENERATED_DIR}")
    print(f"OK: wrote {STUDIO_CONFIG_DIR}")
    print(f"OK: wrote {OPENCODE_AGENTS_DIR}")
    if warnings:
        print(f"WARN: {len(warnings)} validation warnings")


if __name__ == "__main__":
    main()
