# Bug Finder skill

A reusable skill that audits the configured Roblox experiences and produces a
prioritized, evidence-backed bug list.

- **Skill id:** `game_bug_finder` (available under Personal → Skills in Studio)
- **Load it:** `Roblox_Studio.skill({ skill_name: "game_bug_finder" })`
- **Game list:** [bug-finder-games.json](bug-finder-games.json) — edit this to add or remove games

## Adding a game

Append an object to the `games` array:

```json
{
  "name": "Experience name",
  "placeId": 0,
  "universeId": 0,
  "repoPath": "studio/examples",
  "ticketDoc": "docs/device-readiness-tickets.md",
  "notes": "What the game is and any device caveats"
}
```

The skill reads this file at run time, so no skill edit is needed.

## Running interactively

> Use the game_bug_finder skill to audit all configured games.

## Running on a schedule

The scheduler has no skill field — the prompt names the skill instead:

```
prompt: "Load the game_bug_finder skill via the skill tool and follow it exactly.
         Audit every game in docs/bug-finder-games.json, then post a short
         prioritized findings list in this thread."
schedule: { type: "fixed_time", timeOfDay: "09:00" }
```

Other schedule types: `once` (`runAt`), `interval` (`everyMs`, min 60000),
`webhook`. Set `bindToCurrentThread: true` to post results here, or `false` for
a fresh thread per run.

**Requirements at trigger time:** the app must be running, and since the skill
uses Roblox Studio MCP tools, the target place should be open in Studio. If that
is not guaranteed, inline the skill body into the scheduled prompt instead.
