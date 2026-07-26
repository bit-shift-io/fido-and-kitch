Status: done

# Additional background maps + sandbox cleanup

## What to build
Create two more background maps in `res/backgrounds/`:
- `cave.tmx`/.lua — single dark layer (e.g. dark sky or cave walls)
- `sky.tmx`/.lua — simple sky layer

Remove sandbox's old `sky` and `trees` tile layers entirely. The `background = "night_forest"` property now fully owns the background.

Verify: collision/ladder/game/waypoint/collision/kill objectgroups untouched. Players, spawns, entities all work as before.

## Files to modify
- res/backgrounds/cave.tmx, cave.lua (new)
- res/backgrounds/sky.tmx, sky.lua (new)
- res/map/sandbox.tmx (delete sky/trees layers, keep background property)
- res/map/sandbox.lua (re-export)
- tests/ (ensure all_maps_load_test still passes)

## Test approach
Headless: load sandbox, assert `sky` and `trees` layers absent from loaded map; all other layers present. Load each background map, verify layer structure. Visual pass in-game: map looks at least as good as before.

## Acceptance criteria
- [ ] Sandbox no longer has `sky`/`trees` tile layers
- [ ] Background comes entirely from `night_forest` background map
- [ ] `cave` and `sky` background maps load without error
- [ ] Full test suite passes (unit + integration + e2e)
- [ ] Gameplay in sandbox unchanged (ground, water, ladders, entities)

## Blocked by
01 (background map loader + parallax draw must exist).