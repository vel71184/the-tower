# The Tower

A 100-floor climb where the final boss, on floor 100, is the climber. Each floor is nine
levels of investigation and one boss you can kill, negotiate with, or neutralize. A hidden
baseline records who the climber is becoming, and the tower adapts to it.

- Design: [The Tower — Game Design Doc](https://claude.ai/artifact/9chnnz1zTjYc1NeqCQTxKF)
- What's decided and what's open: [docs/DECISIONS.md](docs/DECISIONS.md)

**Status:** first playable slice, Floor 1 · Level 9 (The Waiting Hall), with placeholder art.

Floor 1 is the tower's exterior and the way in. Levels 1–8 (outside) aren't built yet, so a new
climb starts at level 9, the hall just inside the gate. Level 10 is the Gatekeeper.

**Saving is automatic.** The game saves when a level starts, after every conversation, at the end
of each level, and whenever the app is closed or sent to the background. **Continue** puts you
back exactly where you stopped.

## Playing a build

Every push builds the game on GitHub:

1. Open the repo on GitHub → **Actions** → the latest **Test and build** run.
2. Under **Artifacts**, download:
   - `the-tower-android-apk` for Android (unzip, copy `the-tower.apk` to the phone, open it;
     allow installs from that source the first time). Every build is signed with the same
     debug key in `android/debug.keystore`, so new builds install over old ones.
   - `the-tower-windows` or `the-tower-linux` for PC.

## Controls

- **Walk:** tap (phone) or click (PC) where you want to go.
- **Look, talk, use:** tap a thing. Names appear when you're close.
- **Zoom:** pinch, or the mouse wheel.
- **Dev overlay** (shows the hidden baseline, for playtesting only): three-finger tap, or F3.

## Project layout

| Path | What it is |
|---|---|
| `scripts/autoload/baseline.gd` | The hidden baseline: tendency axes, flags, knowledge, history, save/load |
| `scripts/game/main.gd` | Game flow: title, levels, tap-to-walk, proximity, dialogue, level end |
| `scripts/game/level.gd` | Builds a level from its map and objects; grid pathfinding |
| `scripts/game/interactable.gd` | Things to examine, people, hidden things, exits |
| `scripts/game/climber.gd`, `iso_camera.gd` | The player character and the fixed isometric camera |
| `scripts/ui/game_ui.gd` | Dialogue panel, cards, toasts, dev overlay |
| `content/floors/floor_NN/level_NN.json` | Level content (see below) |
| `tests/` | Headless checks that CI runs before building |

## Writing a level

A level is one JSON file, registered in `LEVELS` in `scripts/game/main.gd` (the key is
`"floor-level"`, e.g. `"1-9"`). A new climb starts at the lowest registered level.

- `map`: rows of characters. `#` wall, `.` floor, `S` spawn; any other character is an object
  from `objects`. Rows run toward the camera; the bottom row and right column are drawn as
  low walls so the camera can see in.
- `objects`: each has a `char`, `id`, `name` and `kind`:
  - `examine`: `lines` (pages of text).
  - `npc`: `dialogue` with `start`, optional `start_if` (`[{flag, start}]`) and `nodes`. A
    node has `text`, and either `next` or `choices`. A choice has `text`, `next`, and
    optionally `effects`, `requires` / `hide_if` (flags) or `action: "end_level"`.
    `call_out` (`radius`, `text`, `flag`) makes them speak up when the climber comes near.
  - `hidden`: unseen until the climber is next to it; then like `examine`.
  - `exit`: usually a dialogue whose choice has `action: "end_level"`.
  - Look: `shape` (`box`, `cylinder`, `npc`, `plank`, `arch`), `size` `[x, y, z]`, `color`.
- `effects` (on objects, nodes, choices and end rules):
  `{"nudge": {"patience": 1}, "set_flags": [...], "clear_flags": [...], "learn": [...]}`.
  Poles are `force`/`persuasion`, `honesty`/`deception`, `speed`/`patience`,
  `others`/`self`. Effects on objects, nodes and choices apply only once, so they can't be
  farmed.
- `end_rules`: checked when the level ends. Conditions: `if` / `unless` (flags),
  `min_examined` / `max_examined` (distinct things looked at). This is how "missed vs
  declined" works: in level 1, never noticing Tobin costs nothing, but hearing him call out
  and walking past leans the climber toward `self`.

## Running locally (optional)

Open the folder in Godot 4.7 and press Play. To run the tests:

```bash
godot --headless --path . res://tests/test_runner.tscn
```
