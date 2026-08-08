Status: done

# Enemy placement and background dressing

## What to build
**Scope correction (2026-08-08, DECISIONS.md Q16):** gradient/cloud_spawner/wind are documented in CONTEXT.md's glossary but have zero implementation anywhere in `src/` — no entity, no renderer. Emitting them would just spam error logs (`entity_factory.lua` fails the `require` for any unrecognised object type and logs an error) for props that render as nothing. Dressing uses what's actually real instead: the map's `background` property, a genuine three-way choice (`night_forest`/`mushroom_cave`/`sky`, backed by `res/backgrounds/*.tmx`) already used by every hand-made map. Generated levels stop looking naked and gain pressure via: a randomly-chosen background, coins scattered on reachable zone surfaces (always within the movement model's guarantee, since every zone is reachable by construction), and enemies (spider, robot) placed at difficulty-scaled density on zone surfaces, away from ladder columns. Difficulty 1 has zero enemies. Demo: a generated level with a real background, coins worth detouring for, and enemies that interfere without breaking completability.

## Files to create/modify
- tools/level_generator/decorate.lua
- tools/level_generator/tmx_writer.lua (background objectgroup, map properties)

## Test approach
Headless: the background property is always one of the three real options; coin placements always land on a zone's own surface (reachable per the movement model, since every zone is); enemy count scales with difficulty and never places on a ladder column. Integration: a generated level's coins/enemies load as real `coin`/`npc_spider`/`npc_robot` entities. Manual: visual pass in Tiled and in-game; confirm enemies chase/harass and the level stays completable.

## Acceptance criteria
- [ ] Background property set to a real, valid choice on every generated level
- [ ] Coins reachable, placed on zone surfaces
- [ ] Enemy density scales with difficulty; difficulty 1 is enemy-free
- [ ] Enemies never placed on a ladder column (hindrance, not blocker of the mandatory climb)
- [ ] Output still opens cleanly in Tiled and plays in-game

## Blocked by
03 (dressing/coins). External blocker (enemies) resolved before implementation started (see HANDOFF.md).
