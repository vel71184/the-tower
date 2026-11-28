# Asset inventory

All packs are by Kenney (kenney.nl), CC0: free for any use, credit optional. The original
zips live in `kenney_zips/` (ignored by Godot). What the game uses gets extracted into
`assets/kenney/<pack>/`.

Every pack uses Kenney's single colormap-texture style, so they sit together visually. Each
pack has **its own** colormap layout, so colour names in `content/characters/parts.json` only
apply to Mini Characters.

## Environments and props

| Pack | Models | Era / use |
|---|---|---|
| Mini Dungeon | 30 | Medieval: walls, floors, chests, keys, potions, traps, gates, stairs |
| Modular Dungeon Kit | 39 | Medieval: corridors, rooms, gates, stairs (modular) |
| Castle Kit | 76 | Medieval: walls, towers, gates, siege weapons |
| Fantasy Town Kit | 167 | Medieval: houses, market, walls, roads, trees |
| Mini Arena | 22 | Ancient: Roman arena pieces, weapons |
| Pirate Kit | 72 | Age of sail: ships, docks, forts, palms, cannons, chests |
| Graveyard Kit | 91 | Spooky: graves, crypts, fences, lanterns, trees (zombie floor) |
| Mini Forest | 22 | Nature: trees, rocks, plants |
| Furniture Kit | ~150 | Modern interiors (some pieces are timeless: beds, books, tables, chairs) |
| City Kit (Commercial, Industrial, Suburban, Roads) | 41 + 37 + 40 + 95 | Modern: shops, factories, houses, streets |
| Mini Shop | 30 | Modern: shop fittings, products |
| Mini Arcade | 20 | Modern: arcade machines |
| Mini Skate | 42 | Modern: skate park |
| Space Kit | 153 | Future: station modules, craft, rockets, terrain |
| Building Kit | 79 | Any era: snap-together walls, doorways, windows, columns, floors, stairs, flat roofs, boarded-up doors and windows, opening doors. Good for the tower's own walls and the Floor 1 exterior |
| Modular Buildings | 108 | Town and city: stackable house fronts, corners, windows, balconies, awnings, gable and slanted roofs, plus sample houses and 4 sample towers |
| Food Kit | 200 | Any era (mostly): bread, cheese, meat, fish, fruit, vegetables, pots, pans, plates, barrels, sacks; plus modern food (burgers, pizza, soda, sushi). Markets, kitchens, camps, and things to examine |

## Characters

| Character(s) | Pack | Works with the parts system? | Notes |
|---|---|---|---|
| 20 people, robots, aliens, zombies | Mini Characters | **Yes** (in use) | Any head on any body, recolourable, 32 animations |
| human, orc | Mini Dungeon | **Yes** (in use) | |
| walls, floors, columns, banners, furniture | Mini Dungeon | **Yes** (in use) | The Waiting Hall |
| soldier (Roman) | Mini Arena | **Yes** (in use) | No wheelchair animations |
| archer | Mini Forest | **Yes** (in use) | |
| employee | Mini Shop | **Yes** (in use) | |
| employee, gamer | Mini Arcade | **Yes** (in use) | |
| skate boy, skate girl | Mini Skate | **Yes** (in use) | 36 animations (adds skating) |
| ghost, keeper, skeleton, vampire, zombie | Graveyard Kit | **No**: rigid parts, no head/body split | 32 animations, so usable as whole, fixed-look characters |
| alien, astronaut A/B | Space Kit | **No**: not rigged, no animations | Statues or set dressing only |

All 29 "Mini" characters mix freely: any head on any body. Each pack has its own colormap
(a "family" in `parts.json`); recolouring picks the nearest colour each family has.

## Also downloaded

- **UI Pack – Adventure:** panels, buttons, icons for menus and dialogue.
- **RPG Audio:** footsteps, doors, items, combat sounds.
- **Mobile Controls:** on-screen joystick and buttons (not needed: tap-to-walk and controllers).
