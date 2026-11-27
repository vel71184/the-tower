# The Tower

A 100-floor climb where the final boss, on floor 100, is the climber. Each floor is nine
levels of investigation and one boss you can kill, negotiate with, or neutralize. A hidden
baseline records who the climber is becoming, and the tower adapts to it.

- Design: [The Tower — Game Design Doc](https://claude.ai/artifact/9chnnz1zTjYc1NeqCQTxKF)
- What's decided and what's open: [docs/DECISIONS.md](docs/DECISIONS.md)

**Status:** two levels are playable, with Kenney art and real-time combat:
- **Floor 0 · The Road.** Floor 0 (The Approach) is the 4-level prologue outside the tower.
- **Floor 1 · The Waiting Hall.** This is Floor 1, Level 1, the lobby just inside the gate. It has the Brann brawl.

Levels that aren't built yet are skipped. As you go in through the gate, the tower's intro appears.
You can walk back to earlier levels of the floor you're on, but you can't leave a floor until
its boss is resolved.

**Saving is automatic.** The game saves when a level starts, after every conversation, when you
move between levels, and whenever the app is closed or sent to the background. **Continue** puts
you back exactly where you stopped.

## Playing a build

Every push builds the game on GitHub:

1. Open the repo on GitHub → **Actions** → the latest **Test and build** run.
2. Under **Artifacts**, download:
   - `the-tower-android-apk` for Android (unzip, copy `the-tower.apk` to the phone, open it;
     allow installs from that source the first time). Every build is signed with the same
     debug key in `android/debug.keystore`, so new builds install over old ones.
   - `the-tower-windows` or `the-tower-linux` for PC.

## Controls

| | Phone | Controller (8BitDo Pro 2, Xbox, PlayStation) | Keyboard |
|---|---|---|---|
| Walk | Thumb anywhere on the left half: a stick appears | Left stick or d-pad (smooth) | WASD or arrows |
| Look, talk, use | A, or tap the thing | **Bottom** face button (uses the ringed thing) | E or Enter |
| Attack | X | **Left** face button | Space or J |
| Kick (knockback, no wound) | Y | **Top** face button | K or F |
| Block | Hold B | Hold **right** face button | Hold Shift |
| Lock on / next target | L | L1 / R1 | Q / Tab |
| Zoom | Pinch | Triggers | − / = or mouse wheel |
| Dev overlay (hidden baseline) | Three-finger tap | Select | F3 |

A swing only hits people already fighting you, or the person you've locked on to, so you never
hurt a bystander by accident. Locking on to someone peaceful and attacking is a deliberate first
strike, and it's remembered.

**8BitDo Pro 2:** set the switch on the back to **X** (X-input). Buttons are matched by
**position**, not by the printed letter.

## Project layout

| Path | What it is |
|---|---|
| `scripts/autoload/baseline.gd` | The hidden baseline: tendency axes, flags, knowledge, history, save/load |
| `scripts/game/main.gd` | Game flow: title, levels, touch stick and taps, proximity, dialogue, level end |
| `scripts/game/level.gd` | Builds a level from its map and objects; grid pathfinding |
| `scripts/game/interactable.gd` | Things to examine, people, hidden things, exits |
| `scripts/game/climber.gd`, `iso_camera.gd` | The player character and the fixed isometric camera |
| `scripts/ui/game_ui.gd` | Dialogue panel, cards, toasts, dev overlay |
| `scripts/autoload/controls.gd` | Keyboard and controller bindings |
| `scripts/characters/` | Characters built from Kenney parts, and floor-palette looks |
| `content/characters/parts.json` | Every model's colour slots, items, the climber's look, reserved colours |
| `content/floors/floor_NN/floor.json` | A floor's name, era and people palette |
| `assets/kenney/` | Kenney models in use (CC0). The original zips are in `kenney_zips/` |
| `content/floors/floor_NN/level_NN.json` | Level content (see below) |
| `tests/` | Headless checks that CI runs before building |

## Writing a level

A level is one JSON file, registered in `LEVELS` in `scripts/game/main.gd` (the key is
`"floor-level"`, e.g. `"1-1"`). A new climb starts at the lowest registered level.

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
