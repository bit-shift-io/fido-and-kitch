Status: pending

# Sandbox conversion — remove old tile layers

## What to build
Final cleanup: remove sandbox's old `sky` and `trees` tile layers entirely. The `background = "night_forest"` preset now fully owns the background.

Verify: collision/ladder/game/waypoint/collision/kill objectgroups untouched. Players, spawns, entities all work as before.

## Files to modify
- res/map/sandbox.tmx (delete sky/trees layers, keep background property)
- res/map/sandbox.lua (re-export)
- tests/ (ensure all_maps_load_test still passes)

## Test approach
Headless: load sandbox, assert `sky` and `trees` layers absent from loaded map; all other layers present. Visual pass in-game: map looks at least as good as before.

## Acceptance criteria
- [ ] Sandbox no longer has `sky`/`trees` tile layers
- [ ] Background comes entirely from `night_forest` preset
- [ ] Full test suite passes (unit + integration + e2e)
- [ ] Gameplay in sandbox unchanged (ground, water, ladders, entities)

## Blocked by
05 (all background elements in place before removing old layers).