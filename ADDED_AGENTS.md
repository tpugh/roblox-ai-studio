# Added Missing Agents (Adherence to Repo Standards)

This folder contains **missing agent specs** created to extend `tpugh/roblox-ai-studio` for end-to-end Roblox building, following the repository standards (frontmatter fields, `## Role`, `## Input Schema`, `## Workflow`, `## Output Format`, `## Rules` with >=3 constraints, `## Memory` read/append behavior).

## New agents

### Gamepass (referenced but missing)
- `agents/gamepass/lua-script-writer.md` — implements `gamepass_ready` perks as secure Luau (SYNC gate). Memory: `memory/gamepass/implementation-log.md`.

### UGC production
- `agents/ugc/ugc-3d-modeler.md` — produces UGC mesh/texture/rig-ready asset packages from concepts. Memory: `memory/ugc/model-log.md`.

### Clothing production
- `agents/clothing/clothing-asset-producer.md` — creates template-based clothing asset files/manifests from design specs. Memory: `memory/clothing/production-log.md`.

### Cross-cutting build, production, integration, and security
- `agents/cross-cutting/gameplay-systems-designer.md` — core loops/progression/system specs. Memory: `memory/cross-cutting/systems-design-log.md`.
- `agents/cross-cutting/roblox-lua-engineer.md` — general Luau gameplay/systems implementation. Memory: `memory/cross-cutting/lua-engineering-log.md`.
- `agents/cross-cutting/ui-ux-builder.md` — UI/UX specs and implementation notes. Memory: `memory/cross-cutting/ui-ux-log.md`.
- `agents/cross-cutting/level-world-builder.md` — level/world/layout/performance specs. Memory: `memory/cross-cutting/world-build-log.md`.
- `agents/cross-cutting/qa-playtest-agent.md` — blocking QA/playtest and regression gate. Memory: `memory/cross-cutting/qa-log.md`.
- `agents/cross-cutting/build-release-agent.md` — versioning, publish/rollback coordination (requires QA+TOS gates). Memory: `memory/cross-cutting/release-log.md`.
- `agents/cross-cutting/creative-asset-agent.md` — thumbnails/icons/promo/store art briefs and manifests. Memory: `memory/cross-cutting/creative-log.md`.
- `agents/cross-cutting/animation-vfx-audio-agent.md` — animation/VFX/audio specs and manifests. Memory: `memory/cross-cutting/avfx-log.md`.
- `agents/cross-cutting/roblox-api-publishing-agent.md` — platform publishing/config/metadata integration execution (SYNC, TOS-gated). Memory: `memory/cross-cutting/publishing-log.md`.
- `agents/cross-cutting/live-data-ingestion-agent.md` — pulls/normalizes Roblox metrics into analytics pipeline (PULL). Memory: `memory/cross-cutting/ingestion-log.md`.
- `agents/cross-cutting/moderation-status-monitor.md` — tracks moderation outcomes and emits status/alerts (EVENT). Memory: `memory/cross-cutting/moderation-log.md`.
- `agents/cross-cutting/project-production-manager.md` — task breakdown, dependencies, delivery coordination. Memory: `memory/cross-cutting/production-log.md`.
- `agents/cross-cutting/orchestrator-runtime-agent.md` — runtime enforcement/routing for PUSH/PULL/EVENT/SYNC and traceability. Memory: `memory/cross-cutting/orchestrator-log.md`.
- `agents/cross-cutting/code-review-security-agent.md` — Luau/security/quality review gate. Memory: `memory/cross-cutting/code-review-log.md`.

## Supporting updates
- `shared/schemas/events.json` — extended registry (v1.1.0) adding build/publish/ingestion/moderation/orchestration events and wiring key subscribers; merge with upstream `events.json` as appropriate.

## Integration notes
- All publish-facing outputs remain subject to the **TOS Compliance SYNC gate** and cross-pipeline routing via the **Analytics event bus** per `protocols/PROTOCOL_RULES.md`.
- Place these files into the corresponding paths in the upstream repo, register any additional subscribers/events needed, and let `agent-lint.yml` validate structure/frontmatter/memory/schema.
- Memory files are initialized as append-only logs; agents append run summaries per their `## Memory` sections.
