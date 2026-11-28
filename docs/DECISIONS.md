# Decisions

What's settled for The Tower, and where it came from. The full design lives in
[The Tower — Game Design Doc](https://claude.ai/artifact/9chnnz1zTjYc1NeqCQTxKF). This file
records decisions made in chat that the doc may not have yet.

## Settled

| Decision | Detail | Source |
|---|---|---|
| Signs | Sign boards are blank: no words painted in the world. What's written on them is read by looking at them. | Chat, 2026-11-28 |
| Recolouring | Any Kenney piece can be recoloured by colour family ("recolor": {"#kenney colour": "#new"}), keeping its shading; levels can recolour their walls, floor tiles and fences too. Prefer recolouring to swapping models for colour. | Chat, 2026-11-28 |
| Tower stone | The tower is one warm grey stone inside and out (Gate wall, backdrop tower, Waiting Hall). Lanterns are dark iron, rocks warm grey, tents canvas, fences weathered wood. | Chat, 2026-11-28 |
| Waiting Hall look | Rebuilt from Kenney Mini Dungeon (same "Mini" style as the characters): stone walls and tiled floor, columns, the Gatekeeper's red banners, bedrolls, a cold fire ring, a notice board, table and chairs, barrels and chests by the passage, lanterns for light. | Chat, 2026-11-28 |
| Losing a fight | You're knocked out, not killed: you come to at the level's resting spot with one wound, and the text says where. Whoever beat you goes back to what they were doing (or leaves, if the fight says so). A spar is different: you're helped up in the ring and patched up. | Chat, 2026-11-28 |
| Healing | Every level has one resting spot (a flat rock, the camp fire, a bench, the bedrolls). Resting closes every wound. Not while someone's attacking you. | Chat, 2026-11-28 |
| People remember | Someone you attacked won't chat as if nothing happened; anyone who saw an unprovoked attack keeps their distance. Scripted fights (defending Tobin, Dunmore's toll) and spars don't count as unprovoked. | Chat, 2026-11-28 |
| People leave by walking | Someone who leaves walks away and is gone for good; someone who steps away comes back on a later visit. People can move once something has happened (Bryn sits with Pell). | Chat, 2026-11-28 |
| Fences and bodies | Fences run along a line and join up; people and small things are round. You can walk right up to either. | Chat, 2026-11-28 |
| Lock-on | While locked on you keep facing the target (strafing), and swings turn toward them. | Chat, 2026-11-28 |
| No way down | People can't go back down. It's the tower itself, a kind of magic with no reason given: you can walk to the door, even stand there as someone comes up, but you can't make yourself step through. Floor bosses are the only exception. | Chat, 2026-11-28 |
| Things going up | Animals and things sometimes make it up, but usually get lost; things can turn up on the wrong floor. Ropes never work. The only reliable way is to hand it to a climber and hope they meet the person. | Chat, 2026-11-28 |
| The dead | Stay on their floor. Each floor buries or keeps its own. | Chat, 2026-11-28 |
| News between floors | Floor bosses talk regularly with the bosses directly above and below. Everything else is local and physical: smoke or noise from the stair only reaches the level next to it; cracks to throw things down or see outside are rare finds. | Chat, 2026-11-28 |
| Reputation | The boss you just passed tells the next boss about you. Bosses keep what they know among bosses, but can tell their own people how to treat you, without saying why. Climbers ahead of you spread word among ordinary people. | Chat, 2026-11-28 |
| Marta's motive | The last climber she let up burned Floor 1's houses on the way to the stair, far from where she could see the smoke; she heard only after they'd gone up. Floor 2's boss has told her what that climber is doing up there. So she won't open the stair until she's watched a climber all the way across her floor: how you treat Floor 1 is her test. | Chat, 2026-11-28 |
| Sparring ring | Hitting a partner who has yielded is possible and remembered. | Chat, 2026-11-28 (recommended default) |
| The Gate | A person keeps it, so getting in rehearses kill, negotiate or neutralize: force, talk, pay, or the bread hatch. | Chat, 2026-11-28 (recommended default) |
| Floor 0 people | Nobody on Floor 0 has been inside. The Camp is people who haven't gone in yet (waiting, scared, changing their minds), families watching the tower for birds, and people who live off climbers. | Chat, 2026-11-28 |
| The Bridge | A hurt climber heading for the tower. The plank was cut by a rival climber ahead of you, someone you may meet inside. | Chat, 2026-11-28 |
| The world shows what you did | Things you pick up disappear; things you open stay open (a level's "after_use": "taken" or {"open": true}), and that's remembered. Looking again gives an "after" line. | Chat, 2026-11-27 |
| Hidden things don't announce themselves | No captions like "Something pale in the grass". A loose board rocks and shows itself when you step on it (with a short phone buzz); that's the hint. Things in plain sight just sit there: whether the player checks them is part of what the game measures. | Chat, 2026-11-27 |
| Renderer | Mobile on Android, Forward+ on PC; Compatibility only as the automatic fallback for old devices. | Chat, 2026-11-27 |
| Camera | A slight perspective (30° field of view, 48° tilt) instead of flat orthographic, so things have depth. Default zoom pulls back a little on wide phones. | Chat, 2026-11-27 |
| Outlines | Thin dark outlines on characters, props and things you can use. | Chat, 2026-11-27 |
| Speech | Bubbles anchored to whoever speaks, queued so they never overlap; things you notice get a dark caption. Conversations use the bottom panel with the speaker's portrait. Hits and staggers pop off as quick words. | Chat, 2026-11-27 |
| Names over things | Only the thing you'd use right now shows its name. | Chat, 2026-11-27 (recommended default) |
| Touch controls | Replaces tap-to-walk: a thumb anywhere on the left half becomes a floating stick; a gamepad-style cluster bottom right using Kenney Mobile Controls: classic A/B/X/Y in a diamond plus L, no words, each doing what that button does on a controller (A use, X hit, Y kick, B block, L lock) is always there and always the same (see "Buttons don't signal" below). A quick tap on a person or thing still walks to it; tapping empty ground does nothing. Pinch zooms. Stays inside the phone's safe area. | Chat, 2026-11-27 |
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
| Android Back | Back on the title leaves the app; mid-climb it asks "Leave the game?", and Back again keeps climbing. Never quits by accident (the edge swipe is easy to hit with a thumb on the stick). | Audit, 2026-11-28 |
| New climb | With a climb saved, New climb asks before throwing it away. | Audit, 2026-11-28 |
| Buttons don't signal | A, X, Y and B never change: they don't brighten near something usable (that points out what's worth checking) and never look faint (that reads as "not allowed", when you can swing or kick any time). Lock is the only button that changes: on when someone is in reach to lock on to (in any direction; you turn to face them) or a lock is on, faint otherwise. People are plain to see, so that tells you nothing new. Reverses "faint until useful". | Chat, 2026-11-28 |
| No ring or name on things | Things never announce themselves: no ring under them and no name until you've looked at them once. People keep the ring (they're obvious anyway) but show no name until you've talked to them. Use with nothing in front still does something (a crouch to check the ground), so pressing it can't test whether something is there. On a phone it's less obvious which of two close things Use will pick; "nearest, mostly in front" carries that. | Chat, 2026-11-28 |

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
