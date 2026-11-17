# Level / World Builder — Log

Append-only run history for world and level build specs.

Format:
`[ISO8601] | correlation_id: <id> | map: <name> | areas: <count> | checklist_items: <count>`
[2026-11-15T22:27:27Z] | areas: 5 | checklist_items: 18 | collidable: 314 | correlation_id: street-court-review-2 | map: StreetBasketballCourt | parts: 511 | rim_height_studs: 10.9 | verdict: approved
[2026-11-17T02:38:21Z] | areas: 4 | checklist_items: 4 | collidable: 0 | correlation_id: christmas-2026-bundle | map: CourtStands | parts: 880 | fans: 84 | note: three-tier bleachers behind all four hoops, reindeer/elf/people fans, animated cheers | relocation: SantaCourt shifted 58 studs west to butt against the main court snow bank and scoreboard
[2026-11-17T03:02:00Z] | areas: 2 | checklist_items: 2 | collidable: 0 | correlation_id: christmas-2026-bundle | map: CourtLights + falling-snow | spotlights: 8 | snow_fields: 18 | note: four shadowless warm floodlight masts per court, 18 alpha-textured particle fields falling across both courts and the plaza
[2026-11-17T03:12:00Z] | areas: 1 | checklist_items: 2 | collidable: 1 | correlation_id: christmas-2026-bundle | map: GrassGround | parts: 25 | note: 900x900 walkable grass meadow at y=0.15 over bare baseplate, 24 low snow drifts, court floors and snow paths remain above the surface
[2026-11-17T03:24:00Z] | areas: 2 | checklist_items: 4 | collidable: 0 | correlation_id: christmas-2026-bundle | map: CourtMarkings | segments: 184 | note: added 23-stud three-point arcs with straight corners, free-throw lines, south keys and foul circles to both courts; matches the street game 2/3-point scoring radius
