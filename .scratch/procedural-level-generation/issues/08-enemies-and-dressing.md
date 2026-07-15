Status: pending

# Enemy placement and background dressing

## What to build
Generated levels stop looking naked and gain pressure. Dressing: a background gradient object, a cloud spawner region, wind property, and a sprinkle of background props from the existing templates/tilesets; coins placed along and slightly off the solution path. Enemies (spider, robot) placed at difficulty-scaled density in zones where they harass traffic but can never make the level unwinnable (enemies are hindrances by design — no placement near single-route chokepoints at high density). Difficulty 1 may have zero enemies. Demo: a generated level that looks dressed, has coins worth detouring for, and enemies that interfere without breaking completability.

## Files to create/modify
- tools/level_generator/decorate.lua
- tools/level_generator/tmx_writer.lua (background objectgroup, map properties)

## Test approach
Headless: dressing objects match hand-made conventions (gradient/cloud_spawner/props in the background objectgroup, `windX` map property); enemy count scales with difficulty; enemies never placed inside kill zones or unreachable pockets; coins reachable per the movement model. Manual: visual pass in Tiled and in-game; confirm enemies chase/harass and the level stays completable.

## Acceptance criteria
- [ ] Gradient, clouds, wind, and props emitted per glossary conventions
- [ ] Coins reachable, mostly on/near the solution path
- [ ] Enemy density scales with difficulty; difficulty 1 can be enemy-free
- [ ] Enemies never make a level uncompletable (hindrance, not blocker)
- [ ] Output still opens cleanly in Tiled and plays in-game

## Blocked by
03 (dressing/coins). Enemy placement additionally blocked externally: enemies (spider, robot) must be implemented in the game first.
