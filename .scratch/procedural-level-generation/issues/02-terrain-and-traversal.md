Status: pending

# Terrain generation with guaranteed traversal

## What to build
Generated levels now have real structure: multiple zones (platforms, floors, vertical shafts) connected by jumps the player can actually make and ladders where jumps can't reach. A movement model reads ground-truth constants from `src/` (tile size, jump height/distance, walk/climb speeds) — extracting small testability seams in `src/` if a constant isn't cleanly requirable — and the layout stage only creates transitions the model guarantees. `--size small|medium|large` controls map dimensions (~20×15 to ~60×40). Every zone is reachable from the spawns; the demo is generating a map and walking/climbing to every part of it.

## Files to create/modify
- tools/level_generator/movement_model.lua
- tools/level_generator/layout.lua
- tools/level_generator/main.lua
- src/ (small constant-access seams only, if needed)

## Test approach
Headless: movement-model assertions against real `src/` constants (never claims a jump beyond player physics); reachability test — for many seeds/sizes, every zone is reachable from spawn via the model's transition graph; ladder placement only where a ladder object actually spans the gap. Manual: `love . debug drawphysics map=...` and traverse the whole map.

## Acceptance criteria
- [ ] Every generated zone reachable from spawn (verified programmatically across many seeds)
- [ ] Movement model constants come from `src/`, not literals in the tool
- [ ] `--size` visibly changes dimensions within the agreed ranges
- [ ] Ladders emitted as proper ladder objectgroup rects the game recognises
- [ ] No floating/orphaned platforms unreachable by design

## Blocked by
01
