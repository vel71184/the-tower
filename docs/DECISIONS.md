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

## Suggested, not yet confirmed

- Kenney packs: Mini Characters 1, Mini Dungeon, Furniture Kit, Modular Dungeon Kit,
  UI Pack – Adventure, RPG Audio, and Mobile Controls if combat needs a joystick.
- Short levels that save when they end (the slice does this).
- Simple lighting so it runs well on phones (the slice uses one light and the
  Compatibility renderer).

## Still open

- **Combat** for the kill route: real-time, turn-based, or light. Deferred until after the
  investigation slice.
- **Floor 1's boss.** The slice uses a draft (Marta, the Gatekeeper) to test the systems.
- **Which two axes the prototype tracks.** The slice uses speed ↔ patience and
  others ↔ self, because level 1 can measure them without combat.
- Death and the roguelite variant; the floor-100 reveal; the game's name.
