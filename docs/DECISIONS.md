# Decisions

What's settled for The Tower, and where it came from. The full design lives in
[The Tower — Game Design Doc](https://claude.ai/artifact/9chnnz1zTjYc1NeqCQTxKF). This file
records decisions made in chat that the doc may not have yet.

## Settled

| Decision | Detail | Source |
|---|---|---|
| No way back | People can never come back down or out of the tower. Things and animals can: something thrown from an opening, a bird with a note tied to it. It's unreliable, so people outside mostly live on rumor and hope. | Chat, 2026-11-28 |
| Marta's motive | The last climber she let up burned Floor 1's houses on the way to the stair; she only heard after they'd gone up. Then birds came down from Floor 2 with burnt feathers and worse notes. So she won't open the stair until she's watched a climber all the way across her floor: how you treat Floor 1 is her test. | Chat, 2026-11-28 |
| Floor 0 people | Nobody on Floor 0 has been inside. The Camp is people who haven't gone in yet (waiting, scared, changing their minds), families watching the tower for birds, and people who live off climbers. | Chat, 2026-11-28 |
| The Bridge | A hurt climber heading for the tower. The plank was cut by a rival climber ahead of you, someone you may meet inside. | Chat, 2026-11-28 |
| The world shows what you did | Things you pick up disappear; things you open stay open (a level's "after_use": "taken" or {"open": true}), and that's remembered. Looking again gives an "after" line. | Chat, 2026-11-27 |
| Hidden things don't announce themselves | No captions like "Something pale in the grass". A loose board rocks and shows itself when you step on it (with a short phone buzz); that's the hint. Things in plain sight just sit there: whether the player checks them is part of what the game measures. | Chat, 2026-11-27 |
| Renderer | Mobile on Android, Forward+ on PC; Compatibility only as the automatic fallback for old devices. | Chat, 2026-11-27 |
| Camera | A slight perspective (30° field of view, 48° tilt) instead of flat orthographic, so things have depth. Default zoom pulls back a little on wide phones. | Chat, 2026-11-27 |
| Outlines | Thin dark outlines on characters, props and things you can use. | Chat, 2026-11-27 |
| Speech | Bubbles anchored to whoever speaks, queued so they never overlap; things you notice get a dark caption. Conversations use the bottom panel with the speaker's portrait. Hits and staggers pop off as quick words. | Chat, 2026-11-27 |
| Names over things | Only the thing you'd use right now shows its name. | Chat, 2026-11-27 (recommended default) |
| Touch controls | Replaces tap-to-walk: a thumb anywhere on the left half becomes a floating stick; a gamepad-style cluster bottom right using Kenney Mobile Controls: classic A/B/X/Y in a diamond plus L, no words, each doing what that button does on a controller (A use, X hit, Y kick, B block, L lock) is always there, faint until useful (Use when something is in your ring, Lock when someone's near, fight buttons when locked on or fighting). A quick tap on a person or thing still walks to it; tapping empty ground does nothing. Pinch zooms. Stays inside the phone's safe area. | Chat, 2026-11-27 |
| Controls guidance | "How to play" on the title menu, written for the device in use, plus the sparring partner. Still no hints in play. | Chat, 2026-11-27 (recommended default) |
| UI style | Kenney UI Pack – Adventure, recolored to the game's palette, in a later UI pass. | Chat, 2026-11-27 (recommended default) |
| Visual passes still to do | Smooth curving paths and less grid-like ground; lighting and moods; world edge and sky; the tower always visible on Floor 0; hand-placed set pieces; muted props (no orange "traffic cones", no glaring whites); a real entry gate; Waiting Hall built from Kenney pieces; hit feedback, ambient life, transitions, a pause menu with settings, and sound (RPG Audio). | Chat, 2026-11-27 (recommended default) |
| Code fixes | Done now: Continue never deletes a save, placing the climber stops the walk, stopped scenes leave nothing behind, the floor opening isn't lost if you quit on it, fighters can't overlap, skips during a choice still count, call-outs stay quiet in scenes. Before more levels: flags scoped per level, and save versioning. Later: split main.gd, load props off the main thread. | Chat, 2026-11-27 (recommended default) |
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
| Opening text | "Welcome to the Tower. Once you begin the climb, there is no way back..." on a black screen between Floor 0 and Floor 1, as the gate shuts. Ominous, lines fade in, then Climb. | Chat, 2026-11-27 |
| Fonts | Cinzel for titles and the opening; Nunito for speech, names, dialogue and menus (both OFL). | Chat, 2026-11-27 |
| Title screen and opening scene | The game opens on a live Road; a new climb plays The Road as a skippable scene, and Wil's request is the first input. No button hints: characters teach everything. Combat is taught in a sparring ring at the Climbers' Camp. | Chat, 2026-11-27 |
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

## Still open

- **Combat details:** stats and leveling, and whether falling ever means death.
- **Floor 1's boss.** The slice uses a draft (Marta, the Gatekeeper) to test the systems.
- **Which two axes the prototype tracks.** The slice uses speed ↔ patience and
  others ↔ self, because level 1 can measure them without combat.
- **Era order:** roughly chronological up the tower, or shuffled.
- **Climber's color leaking into higher floors** as environmental drift.
- Death and the roguelite variant; the floor-100 reveal; the game's name.
