# Decisions

What's settled for The Tower, and where it came from. The full design lives in
[The Tower — Game Design Doc](https://claude.ai/artifact/9chnnz1zTjYc1NeqCQTxKF). This file
records decisions made in chat that the doc may not have yet.

## Settled

| Decision | Detail | Source |
|---|---|---|
| Isometric view | Switched from first person. The floor-100 twist lands through the boss using the climber's own moves and habits, not a face reveal. | Design doc + chat, 2026-11-20 |
| Engine: Godot 4 | Built with Godot 4.7 (CI pins `4.7.2`). | Chat, 2026-11-20 |
| Platforms | Android first, also playable on PC (Windows and Linux builds). | Chat, 2026-11-20 |
| Who builds it | Claude writes the project and pushes to GitHub. GitHub Actions builds Android and PC versions on every push. You install the builds and playtest. Godot on your laptop is optional. | Chat, 2026-11-20 |
| Art | Kenney assets. Every pack is free on kenney.nl; the $19.95 bundle is optional and undecided. | Chat, 2026-11-20 |
| 3D, fixed isometric camera | Kenney Mini 3D packs later; placeholder shapes until then. | Confirmed 2026-11-21 |
| Tap to walk | Tap on phones, click on PC. | Confirmed 2026-11-21 |
| Placeholders first | Build with simple shapes now; swap in Kenney art when the packs are in the repo. | Confirmed 2026-11-21 |
| First slice | Floor 1, Level 1: walk, examine, talk, find a hidden letter, hidden baseline tracking, save at level end. | Confirmed 2026-11-21 |

| All eras | The tower spans ancient to post-modern. Each floor is one place, era and look. | Chat, 2026-11-21 |
| Themed floors | Whole floors of zombies, robots, aliens, orcs and so on, as communities. | Chat, 2026-11-21 |
| Residents, not enemies | No monsters. Every character is a resident; killing is possible and always remembered. | Chat, 2026-11-21 |
| Characters from parts | Any Mini Characters head on any body (22 × 22), recolored by a palette-swap shader. Floor palettes act as factions. 99 bosses get unique combos, a signature color and item; the climber has a reserved color no floor may use. | Chat, 2026-11-21 |
| Floor 0, The Approach | The outside is a 4-level prologue, not one of the hundred: The Road, The Bridge, The Climbers' Camp, The Gate. No boss. | Chat, 2026-11-27 |
| Floor 1 starts inside | The Waiting Hall is Floor 1, Level 1 (the lobby). Marta is Floor 1's boss at level 10. | Chat, 2026-11-27 |
| The tower's intro | "THE TOWER. A hundred floors. Ten levels each." appears as the gate shuts behind you, not on the title screen. | Chat, 2026-11-27 |
| Moving between levels | You can usually go back to earlier levels of your floor, but can't leave the floor until its boss is resolved. Levels remember what happened in them. | Chat, 2026-11-27 |
| Real-time combat | Replaces turn-based: Zelda-style swing, kick, block, lock-on. Anyone can be attacked, but only deliberately (lock-on or already fighting). | Chat, 2026-11-21 |
| Free movement | Smooth stick walking; a ring marks what you'll interact with. | Chat, 2026-11-21 |
| Floors grow as you climb | All levels within a floor are the same size; each floor is larger than the last. About 5 minutes per level on floor 1, growing fast early and leveling off at about 30 minutes per level near the top. | Chat, 2026-11-21 |
| Automatic saving | Saves when a level starts, after every conversation, at level end, and when the app is closed or backgrounded. Continue resumes exactly where you stopped. | Chat, 2026-11-21 |
| Wounds | Everyone has 3 wounds; a hit takes one; wounds last until rest. The maximum can grow later (armor, gear). At zero the climber falls and loses the fight; someone on their last wound may yield. | Chat, 2026-11-21 |
| First fight | The optional Waiting Hall brawl with Brann, before Marta. | Chat, 2026-11-21 |
| More characters | The nine other Kenney "Mini" characters on the same rig join the parts system (29 heads × 29 bodies). | Chat, 2026-11-21 |
| Controllers | Full controller and keyboard support, matched by button position. 8BitDo Pro 2 in X-input mode. | Chat, 2026-11-21 |
| CI screenshots | CI renders screenshots and force-pushes them to the `ci-screenshots` branch. | Chat, 2026-11-21 |
| Kenney zips | Kept in `kenney_zips/` (ignored by Godot); used parts get extracted to `assets/`. | Chat, 2026-11-21 |

## Suggested, not yet confirmed

- Kenney packs: Mini Characters 1, Mini Dungeon, Furniture Kit, Modular Dungeon Kit,
  UI Pack – Adventure, RPG Audio, and Mobile Controls if combat needs a joystick.
- Short levels that save when they end (the slice does this).
- Simple lighting so it runs well on phones (the slice uses one light and the
  Compatibility renderer).

## Still open

- **Combat details:** stats and leveling, and whether falling ever means death.
- **Floor 1's boss.** The slice uses a draft (Marta, the Gatekeeper) to test the systems.
- **Which two axes the prototype tracks.** The slice uses speed ↔ patience and
  others ↔ self, because level 1 can measure them without combat.
- **Era order:** roughly chronological up the tower, or shuffled.
- **Climber's color leaking into higher floors** as environmental drift.
- Death and the roguelite variant; the floor-100 reveal; the game's name.
