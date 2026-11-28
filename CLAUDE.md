# The Tower: notes for Claude

A 100-floor isometric climb built in **Godot 4.7** (GDScript), Android first, with Windows and
Linux builds. Claude writes the code and pushes to GitHub; GitHub Actions tests and builds on
every push; the owner installs the builds and playtests. Godot on the owner's laptop is
optional, so CI is the main way to see whether something works.

## First: check which model you are

Before starting any task, check which model you're running as, then compare it with the
table below for the work you've been asked to do.

- **If it matches:** go ahead.
- **If it doesn't match:** do what you can with the model you are. Then say in one or two
  lines which model the guide suggests for this work and why, and suggest switching with
  `/model`. The owner can tell you to carry on without switching. If they do, keep going and
  don't bring it up again for that task.

Never refuse or stall a task because of the model. The suggestion is advice, not a gate.

## Which model for which work

| Model | Use it for |
|---|---|
| **Opus** | Building new systems or mechanics; changing core game logic (game flow, combat, saving, the hidden baseline, how systems talk to each other); bugs whose cause spans several parts of the game; restructuring or reorganizing code; design work such as bosses, floor arcs, and how the tower reacts to the climber. |
| **Sonnet** | Adding or editing content that uses existing systems (new levels, rooms, characters, dialogue, text); visual tweaks like recolouring and placing props; writing tests for behaviour that already exists; small, contained fixes; documentation updates. |
| **Fable** (if the plan includes it) | The hardest problems: a bug that has resisted repeated attempts, or a deep rework of how the game is built. |
| **Haiku** | Quick questions about the project, like where something lives or what a setting does. |

A good rhythm: plan a feature with Opus, then let Sonnet fill in levels and content.

## Read before changing things

- **`docs/DECISIONS.md` is the rulebook.** Everything under "Settled" is decided. Don't
  contradict it. If a change needs to break a settled rule, ask first. When the owner settles
  something new in chat, add a row with the date and source.
- **The design doc** is linked from `README.md`. DECISIONS.md wins where the two disagree.
- **`README.md`** explains the project layout, controls, and how to write a level (map
  characters, objects, dialogue nodes, effects, end rules).
- **`docs/ASSETS.md`** lists the Kenney packs and what each is for.

## Design rules that are easy to break

- No hints or captions announce hidden things. Buttons never brighten or fade to signal
  something (Lock is the only exception).
- Residents, not enemies. Attacks are only deliberate (lock-on or already fighting), and an
  unprovoked attack is remembered.
- Losing a fight knocks you out; it doesn't kill you.
- Effects on objects, nodes and choices apply only once.
- Sign boards stay blank; their text is read by looking at them.
- Prefer recolouring Kenney pieces over swapping models.

## Working in the repo

- **Tests:** `godot --headless --path . res://tests/test_runner.tscn`. CI fails on any
  `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, `FAIL ` or `ERROR:` in the output.
  Add a check to `tests/test_runner.gd` for new behaviour.
- **Godot version:** CI pins `4.7.2` in `.github/workflows/build.yml`.
- **New levels** are registered in `LEVELS` in `scripts/game/main.gd` (key `"floor-level"`,
  e.g. `"1-2"`).
- **Screenshots:** CI renders them and force-pushes to the `ci-screenshots` branch. Look at
  them after visual changes. Never push to that branch yourself.
- **Kenney assets:** `kenney_zips/` holds the original downloads and is ignored by Godot.
  Don't edit or unpack them in place. Extract only the models you need into
  `assets/kenney/<pack>/`. Each pack has its own colormap, so colour names in
  `content/characters/parts.json` only apply to Mini Characters.
- **Android signing:** `android/debug.keystore` is deliberately committed so builds install
  over each other. Don't replace it.

## Talking to the owner

Write in plain language. The owner playtests on an Android phone and a PC with an 8BitDo Pro 2
controller. After a push, say what changed in play and what to try, not just what changed in
the code.
