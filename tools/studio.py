#!/usr/bin/env python3
"""Roblox AI Studio — protocol CLI.

Deterministic transport, SYNC gates, publish gate, and append-only memory for
the agent system described in protocols/PROTOCOL_RULES.md. Agents do the
thinking; this tool does the bookkeeping and enforcement.

Layout:
  shared/generated/registry.json       agent registry (generated)
  shared/generated/events.json         event schema (generated)
  shared/generated/pipelines.json      pipeline graphs (generated)
  runtime/state.json                   transport + gate state (gitignored)
  runtime/audit.jsonl                  append-only audit trail
  memory/<category>/<agent>-log.md     append-only agent memory

Exit codes: 0 success, 1 blocked or invalid, 2 usage error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / "shared" / "generated"
RUNTIME = Path(os.environ.get("STUDIO_RUNTIME_DIR") or (ROOT / "runtime"))
MEMORY_ROOT = Path(os.environ.get("STUDIO_MEMORY_ROOT") or (ROOT / "memory"))
STATE_PATH = RUNTIME / "state.json"
AUDIT_PATH = RUNTIME / "audit.jsonl"

PRIORITIES = {"P0": 0, "P1": 3600, "P2": 86400, "P3": 604800}
DECISIONS = {"approved", "rejected", "needs_revision"}
PII_FIELDS = {"username", "userid", "display_name", "email", "phone", "address", "playerid"}
GATE_TIMEOUT_SECONDS = 1800
CONTROL_TARGETS = {"build-queue", "all_agents", "all_pipeline_agents", "all_publish_pipelines", "varies_by_affected_pipeline"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def registry() -> dict[str, Any]:
    return load_json(GENERATED / "registry.json")


def events() -> dict[str, Any]:
    return load_json(GENERATED / "events.json")["events"]


def pipelines() -> dict[str, Any]:
    return load_json(GENERATED / "pipelines.json")["pipelines"]


def empty_state() -> dict[str, Any]:
    return {
        "version": "1.0.0",
        "created_at": iso_now(),
        "messages": [],
        "gates": {},
        "approvals": {},
        "published": {},
        "blocked": [],
    }


def load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return empty_state()
    return load_json(STATE_PATH)


def save_state(state: dict[str, Any]) -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=RUNTIME, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(tmp, STATE_PATH)


def audit(kind: str, **fields: Any) -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    entry = {"at": iso_now(), "kind": kind, **fields}
    with AUDIT_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def emit(payload: Any) -> None:
    print(json.dumps(payload, indent=2, ensure_ascii=False))


def die(message: str, code: int = 1, payload: Any | None = None) -> None:
    if payload is not None:
        emit(payload)
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(code)


def known_agent(reg: dict[str, Any], slug: str) -> dict[str, Any]:
    agent = reg["agents"].get(slug)
    if not agent:
        die(f"unknown agent '{slug}'")
    return agent


def memory_path(agent: dict[str, Any]) -> Path:
    for entry in agent.get("memory", []):
        match = re.search(r"/memory/[A-Za-z0-9_./-]+\.md", entry)
        if match:
            speculative = ROOT / match.group(0).lstrip("/")
            if MEMORY_ROOT != ROOT / "memory":
                return MEMORY_ROOT / speculative.relative_to(ROOT / "memory")
            return speculative
    return MEMORY_ROOT / agent["category"] / f"{agent['slug']}-log.md"


def display(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def message_envelope(message: dict[str, Any]) -> dict[str, Any]:    return {
        "envelope": {
            "message_id": message["message_id"],
            "protocol": message["protocol"],
            "from_agent": message["from_agent"],
            "to_agent": message["to_agent"],
            "timestamp": message["timestamp"],
            "version": "1.0.0",
            "priority": message["priority"],
            "correlation_id": message["correlation_id"],
        },
        "payload": {"type": message["payload_type"], "data": message["payload"]},
    }


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #


def cmd_agents(args: argparse.Namespace) -> None:
    reg = registry()
    if args.action == "list":
        rows = []
        for slug, agent in sorted(reg["agents"].items()):
            if args.category and agent["category"] != args.category:
                continue
            rows.append(
                {
                    "slug": slug,
                    "name": agent["name"],
                    "category": agent["category"],
                    "protocol": agent["protocol"],
                    "triggers": agent["triggers"],
                    "gated": "sync" in agent["protocol"],
                }
            )
        if args.json:
            emit({"count": len(rows), "agents": rows})
        else:
            for row in rows:
                gate = " [gate]" if row["gated"] else ""
                print(f"{row['slug']:<32} {row['category']:<16} {row['protocol']:<14}{gate}")
            print(f"\n{len(rows)} agents")
        return
    agent = known_agent(reg, args.slug)
    if args.json:
        emit(agent)
        return
    print(f"{agent['name']} ({agent['slug']}) v{agent['version']}")
    print(f"category: {agent['category']}   protocol: {agent['protocol']}   schedule: {agent['schedule'] or '-'}")
    print(f"triggers: {', '.join(agent['triggers']) or '-'}")
    print(f"upstream: {', '.join(agent['upstream']) or '-'}")
    print(f"downstream: {', '.join(agent['downstream']) or '-'}")
    print(f"\n{agent['role']}\n")
    print(f"spec: {agent['spec_path']}")
    print(f"memory: {display(memory_path(agent))}")


def cmd_events(args: argparse.Namespace) -> None:
    evs = events()
    if args.action == "list":
        for name, event in sorted(evs.items()):
            print(f"{name:<28} {event['priority']:<3} {event['source']:<28} -> {', '.join(event['subscribers'])}")
        print(f"\n{len(evs)} events")
        return
    event = evs.get(args.name)
    if not event:
        die(f"unknown event '{args.name}'")
    emit(event)


def cmd_pipelines(args: argparse.Namespace) -> None:
    pipes = pipelines()
    if args.action == "list":
        for name, pipeline in pipes.items():
            gates = sum(1 for stage in pipeline["stages"] if stage["gate"])
            print(f"{name:<10} {len(pipeline['stages'])} stages, {gates} gates  — {pipeline['name']}")
        return
    pipeline = pipes.get(args.name)
    if not pipeline:
        die(f"unknown pipeline '{args.name}'")
    if args.json:
        emit(pipeline)
        return
    print(f"{pipeline['name']}  (correlation entry: {pipeline['entry_event'] or 'manual'})")
    for stage in pipeline["stages"]:
        flag = " GATE" if stage["gate"] else ""
        print(f"  {stage['index']}. {stage['agent']:<28} {stage['in_protocol']:<6} -> {stage['produces']:<24}{flag}")


def cmd_send(args: argparse.Namespace) -> None:
    reg = registry()
    evs = events()
    state = load_state()

    sender = known_agent(reg, args.sender)
    if args.protocol in ("sync", "pull"):
        die(f"protocol '{args.protocol}' needs sync-open or a provider, not send")
    if args.protocol not in ("push", "event"):
        die(f"invalid protocol '{args.protocol}'")
    priority = args.priority or "P2"
    if priority not in PRIORITIES:
        die(f"invalid priority '{priority}'")
    correlation = args.correlation or str(uuid.uuid4())

    payload: Any
    if args.payload_file:
        payload = load_json(Path(args.payload_file))
    elif args.data:
        try:
            payload = json.loads(args.data)
        except json.JSONDecodeError as error:
            die(f"--data is not valid JSON: {error}")
    else:
        payload = {}

    recipients: list[str]
    if args.protocol == "event":
        event = evs.get(args.payload_type)
        if not event:
            die(f"unregistered event '{args.payload_type}'")
        missing = [name for name in event["fields"] if name not in payload]
        if missing and not args.force:
            die(
                "payload missing required event fields: " + ", ".join(missing),
                payload={"error": {"code": "MISSING_DATA", "missing": missing}},
            )
        recipients = [agent for agent in event["subscribers"] if agent in reg["agents"]]
        if args.to and args.to not in recipients:
            die(f"'{args.to}' does not subscribe to '{args.payload_type}'")
        if args.to:
            recipients = [args.to]
        if not recipients:
            die(f"event '{args.payload_type}' has no registered subscribers")
    else:
        if not args.to:
            die("push requires --to")
        known_agent(reg, args.to)
        recipients = [args.to]

    created = []
    for recipient in recipients:
        message = {
            "message_id": str(uuid.uuid4()),
            "protocol": args.protocol,
            "from_agent": sender["slug"],
            "to_agent": recipient,
            "payload_type": args.payload_type,
            "payload": payload,
            "priority": priority,
            "correlation_id": correlation,
            "timestamp": iso_now(),
            "read": False,
        }
        state["messages"].append(message)
        created.append(message)

    save_state(state)
    for message in created:
        audit("message", message_id=message["message_id"], protocol=message["protocol"], source=message["from_agent"], target=message["to_agent"], correlation_id=correlation)
    emit(
        {
            "sent": len(created),
            "correlation_id": correlation,
            "messages": [
                {"message_id": m["message_id"], "to": m["to_agent"], "type": m["payload_type"], "priority": m["priority"]}
                for m in created
            ],
        }
    )


def cmd_inbox(args: argparse.Namespace) -> None:
    reg = registry()
    known_agent(reg, args.agent)
    state = load_state()
    pending = [m for m in state["messages"] if m["to_agent"] == args.agent and not m["read"]]
    if args.ack:
        for message in pending:
            message["read"] = True
        save_state(state)
        audit("inbox_ack", agent=args.agent, count=len(pending))
    if args.json:
        emit({"agent": args.agent, "count": len(pending), "messages": pending if args.full else [message_envelope(m) for m in pending]})
        return
    for message in pending:
        print(f"{message['message_id']}  {message['timestamp']}  {message['protocol']}/{message['payload_type']}  from {message['from_agent']}  prio {message['priority']}")
        print("  " + json.dumps(message["payload"], ensure_ascii=False)[:240])
    print(f"\n{len(pending)} unread for {args.agent}")


def cmd_sync_open(args: argparse.Namespace) -> None:
    reg = registry()
    requester = known_agent(reg, args.requester)
    owner = known_agent(reg, args.gate_owner)
    state = load_state()
    if "sync" not in owner["protocol"] and owner["slug"] != "tos-compliance-agent":
        die(f"'{owner['slug']}' is not a SYNC-gate agent (protocol {owner['protocol']})")
    gate_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).timestamp()
    gate = {
        "gate_id": gate_id,
        "requester": requester["slug"],
        "owner": owner["slug"],
        "asset": args.asset,
        "asset_type": args.asset_type,
        "reason": args.reason or "",
        "correlation_id": args.correlation or str(uuid.uuid4()),
        "state": "waiting",
        "opened_at": iso_now(),
        "deadline_epoch": now + GATE_TIMEOUT_SECONDS,
        "decision": None,
        "resolved_at": None,
    }
    state["gates"][gate_id] = gate
    save_state(state)
    audit("gate_open", gate_id=gate_id, asset=args.asset, owner=owner["slug"], correlation_id=gate["correlation_id"])
    emit({"gate_id": gate_id, "state": "waiting", "owner": owner["slug"], "asset": args.asset, "correlation_id": gate["correlation_id"]})


def cmd_sync_respond(args: argparse.Namespace) -> None:
    reg = registry()
    agent = known_agent(reg, args.agent)
    state = load_state()
    gate = state["gates"].get(args.gate)
    if not gate:
        die(f"unknown gate '{args.gate}'")
    if gate["owner"] != agent["slug"]:
        die(f"only '{gate['owner']}' may answer this gate")
    if gate["state"] != "waiting":
        die(f"gate is already {gate['state']}")
    if args.decision not in DECISIONS:
        die(f"invalid decision '{args.decision}'")
    if args.decision != "approved" and not args.reason:
        die("a rejection requires --reason")

    gate["state"] = "resolved"
    gate["decision"] = args.decision
    gate["reason"] = args.reason or ""
    gate["resolved_at"] = iso_now()
    record = {
        "gate_id": gate["gate_id"],
        "asset": gate["asset"],
        "asset_type": gate["asset_type"],
        "owner": gate["owner"],
        "requester": gate["requester"],
        "decision": args.decision,
        "reason": gate["reason"],
        "correlation_id": gate["correlation_id"],
        "decided_at": gate["resolved_at"],
    }
    if args.decision == "approved":
        state["approvals"].setdefault(gate["asset"], []).append(record)
    save_state(state)
    audit("gate_decision", **record)
    emit(record)


def cmd_gates(args: argparse.Namespace) -> None:
    state = load_state()
    items = list(state["gates"].values())
    if args.pending:
        items = [gate for gate in items if gate["state"] == "waiting"]
    if args.json:
        emit({"count": len(items), "gates": items})
        return
    for gate in items:
        print(f"{gate['gate_id']}  {gate['state']:<9} {gate['asset']:<34} owner={gate['owner']} decision={gate['decision']}")
    print(f"\n{len(items)} gates")


def cmd_publish(args: argparse.Namespace) -> None:
    state = load_state()
    approvals = state["approvals"].get(args.asset, [])
    approval = approvals[-1] if approvals else None
    if not approval or approval["decision"] != "approved":
        blocked = {
            "error": {
                "code": "TOS_VIOLATION",
                "message": f"asset '{args.asset}' has no TOS compliance approval",
                "agent": "build-release-agent",
                "recoverable": False,
                "retry_after_seconds": None,
                "correlation_id": args.correlation or "",
            }
        }
        state["blocked"].append({"asset": args.asset, "at": iso_now(), "code": "TOS_VIOLATION", "correlation_id": args.correlation})
        save_state(state)
        audit("publish_blocked", asset=args.asset, correlation_id=args.correlation)
        emit(blocked)
        sys.exit(1)

    if args.check:
        emit({"asset": args.asset, "approved": True, "gate_id": approval["gate_id"], "owner": approval["owner"]})
        return

    receipt = {
        "asset": args.asset,
        "asset_type": args.asset_type or approval["asset_type"],
        "status": "published",
        "published_at": iso_now(),
        "correlation_id": args.correlation or approval["correlation_id"],
        "approved_by": approval["owner"],
        "gate_id": approval["gate_id"],
    }
    state["published"][args.asset] = receipt
    save_state(state)
    audit("publish", **receipt)
    emit(receipt)


def cmd_log(args: argparse.Namespace) -> None:
    reg = registry()
    agent = known_agent(reg, args.agent)
    fields: dict[str, str] = {}
    for item in args.field or []:
        if "=" not in item:
            die(f"--field expects key=value, got '{item}'")
        key, value = item.split("=", 1)
        if key.strip().lower() in PII_FIELDS:
            die(f"PII field '{key}' may not be written to memory", payload={"error": {"code": "SCHEMA_INVALID", "message": f"PII field rejected: {key}"}})
        fields[key.strip()] = value.strip()

    path = memory_path(agent)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(f"# {agent['name']} — Log\n\nAppend-only run history.\n\n", encoding="utf-8")
    line = f"[{iso_now()}]" + "".join(f" | {key}: {value}" for key, value in sorted(fields.items()))
    with path.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")
    audit("memory_append", agent=agent["slug"], path=display(path), fields=fields)
    emit({"ok": True, "agent": agent["slug"], "path": display(path), "line": line})


def cmd_memory(args: argparse.Namespace) -> None:
    reg = registry()
    agent = known_agent(reg, args.agent)
    path = memory_path(agent)
    if not path.exists():
        die(f"no memory file yet at {display(path)}")
    lines = path.read_text(encoding="utf-8").splitlines()
    for line in lines[-args.tail :]:
        print(line)


def cmd_trace(args: argparse.Namespace) -> None:
    state = load_state()
    messages = [m for m in state["messages"] if m["correlation_id"] == args.correlation]
    gates = [g for g in state["gates"].values() if g["correlation_id"] == args.correlation]
    publish = [p for p in state["published"].values() if p.get("correlation_id") == args.correlation]
    blocked = [b for b in state["blocked"] if b.get("correlation_id") == args.correlation]
    if args.json:
        emit({"correlation_id": args.correlation, "messages": messages, "gates": gates, "published": publish, "blocked": blocked})
        return
    print(f"correlation {args.correlation}")
    for message in messages:
        print(f"  {message['timestamp']}  {message['protocol']:<6} {message['from_agent']} -> {message['to_agent']}  {message['payload_type']}")
    for gate in gates:
        print(f"  gate {gate['gate_id']}  {gate['state']}  {gate['asset']}  decision={gate['decision']}")
    for receipt in publish:
        print(f"  published {receipt['asset']} at {receipt['published_at']}")
    for entry in blocked:
        print(f"  blocked {entry['asset']} at {entry['at']} ({entry['code']})")
    print(f"\n{len(messages)} messages, {len(gates)} gates")


def cmd_validate(args: argparse.Namespace) -> None:
    message = load_json(Path(args.file))
    envelope = message.get("envelope", {})
    problems = []
    for field in ("message_id", "protocol", "from_agent", "to_agent", "timestamp", "version", "priority"):
        if not envelope.get(field):
            problems.append(f"missing envelope field: {field}")
    if envelope.get("protocol") not in ("push", "pull", "event", "sync"):
        problems.append(f"invalid protocol: {envelope.get('protocol')}")
    if envelope.get("priority") not in PRIORITIES:
        problems.append(f"invalid priority: {envelope.get('priority')}")
    if not isinstance(message.get("payload"), dict) or not message["payload"].get("type"):
        problems.append("missing payload.type")
    event = events().get(message.get("payload", {}).get("type"))
    if event:
        missing = [name for name in event["fields"] if name not in message["payload"].get("data", {})]
        if missing:
            problems.append("missing event fields: " + ", ".join(missing))
    if problems:
        emit({"valid": False, "problems": problems})
        sys.exit(1)
    emit({"valid": True, "protocol": envelope["protocol"], "payload_type": message["payload"]["type"]})


def cmd_state(args: argparse.Namespace) -> None:
    state = load_state()
    reg = registry()
    waiting = [g for g in state["gates"].values() if g["state"] == "waiting"]
    payload = {
        "agents": len(reg["agents"]),
        "events": len(events()),
        "pipelines": len(pipelines()),
        "messages": len(state["messages"]),
        "unread": sum(1 for m in state["messages"] if not m["read"]),
        "gates": len(state["gates"]),
        "gates_waiting": len(waiting),
        "approved_assets": sum(1 for records in state["approvals"].values() if records and records[-1]["decision"] == "approved"),
        "published": len(state["published"]),
        "blocked_publishes": len(state["blocked"]),
        "memory_entries": sum(1 for _ in ROOT.joinpath("memory").rglob("*-log.md")),
    }
    emit(payload)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="studio", description="Roblox AI Studio protocol CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    agents = sub.add_parser("agents", help="inspect the generated agent registry")
    agents.add_argument("action", choices=["list", "show"])
    agents.add_argument("slug", nargs="?")
    agents.add_argument("--category")
    agents.add_argument("--json", action="store_true")
    agents.set_defaults(func=cmd_agents)

    ev = sub.add_parser("events", help="inspect the event registry")
    ev.add_argument("action", choices=["list", "show"])
    ev.add_argument("name", nargs="?")
    ev.set_defaults(func=cmd_events)

    pipes = sub.add_parser("pipelines", help="inspect pipeline graphs")
    pipes.add_argument("action", choices=["list", "show"])
    pipes.add_argument("name", nargs="?")
    pipes.add_argument("--json", action="store_true")
    pipes.set_defaults(func=cmd_pipelines)

    send = sub.add_parser("send", help="send a PUSH or EVENT message")
    send.add_argument("--from", dest="sender", required=True)
    send.add_argument("--to")
    send.add_argument("--protocol", required=True)
    send.add_argument("--type", dest="payload_type", required=True)
    send.add_argument("--payload", dest="payload_file")
    send.add_argument("--data")
    send.add_argument("--priority", default="P2")
    send.add_argument("--correlation")
    send.add_argument("--force", action="store_true", help="send even if event fields are missing")
    send.set_defaults(func=cmd_send)

    inbox = sub.add_parser("inbox", help="read an agent's unread messages")
    inbox.add_argument("agent")
    inbox.add_argument("--ack", action="store_true")
    inbox.add_argument("--json", action="store_true")
    inbox.add_argument("--full", action="store_true")
    inbox.set_defaults(func=cmd_inbox)

    sync_open = sub.add_parser("sync-open", help="open a blocking SYNC gate")
    sync_open.add_argument("--from", dest="requester", required=True)
    sync_open.add_argument("--gate-owner", required=True)
    sync_open.add_argument("--asset", required=True)
    sync_open.add_argument("--asset-type", default="asset")
    sync_open.add_argument("--reason")
    sync_open.add_argument("--correlation")
    sync_open.set_defaults(func=cmd_sync_open)

    sync_respond = sub.add_parser("sync-respond", help="answer a SYNC gate")
    sync_respond.add_argument("--from", dest="agent", required=True)
    sync_respond.add_argument("--gate", required=True)
    sync_respond.add_argument("--decision", required=True)
    sync_respond.add_argument("--reason")
    sync_respond.set_defaults(func=cmd_sync_respond)

    gates = sub.add_parser("gates", help="list SYNC gates")
    gates.add_argument("--pending", action="store_true")
    gates.add_argument("--json", action="store_true")
    gates.set_defaults(func=cmd_gates)

    publish = sub.add_parser("publish", help="publish only with a TOS approval on record")
    publish.add_argument("--asset", required=True)
    publish.add_argument("--asset-type")
    publish.add_argument("--correlation")
    publish.add_argument("--check", action="store_true", help="exit 0 only if the asset is approved")
    publish.set_defaults(func=cmd_publish)

    log = sub.add_parser("log", help="append an entry to an agent's memory log")
    log.add_argument("--agent", required=True)
    log.add_argument("--field", action="append")
    log.set_defaults(func=cmd_log)

    memory = sub.add_parser("memory", help="show an agent's memory log")
    memory.add_argument("--agent", required=True)
    memory.add_argument("--tail", type=int, default=20)
    memory.set_defaults(func=cmd_memory)

    trace = sub.add_parser("trace", help="trace one correlation id")
    trace.add_argument("--correlation", required=True)
    trace.add_argument("--json", action="store_true")
    trace.set_defaults(func=cmd_trace)

    validate = sub.add_parser("validate", help="validate an envelope JSON file")
    validate.add_argument("file")
    validate.set_defaults(func=cmd_validate)

    state = sub.add_parser("state", help="summarise runtime state")
    state.set_defaults(func=cmd_state)

    ev.set_defaults  # noqa: B018
    return parser


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "agents" and args.action == "show" and not args.slug:
        die("agents show requires a slug", 2)
    if args.command in ("events", "pipelines") and args.action == "show" and not getattr(args, "name", None):
        die(f"{args.command} show requires a name", 2)
    args.func(args)


if __name__ == "__main__":
    main()
