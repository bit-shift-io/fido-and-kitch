Status: done

# Terrain generation with guaranteed traversal

## What to build
Generated levels now have real structure: multiple zones (platforms, floors, vertical shafts) connected only by transitions the game actually supports — contiguous walkable ground within a zone, and ladders spanning vertical gaps between zones. **The player cannot jump** (confirmed against `src/player/`: no jump input, impulse, or state exists — only walking, ladder climbing, and authored jump-pad paths/drawbridges/pushables, which are out of scope for this issue and land in later issues). So issue 02 never bridges a gap with anything but a ladder; any gap without a ladder is not traversable and the layout stage must not create one. A movement model reads ground-truth constants from `src/` (tile size, walk/climb speeds, ladder mount rules) — extracting small testability seams in `src/` if a constant isn't cleanly requirable — and the layout stage only creates transitions (walk-adjacency or ladder-spanned) the model guarantees. `--size small|medium|large` controls map dimensions (~20×15 to ~60×40). Every zone is reachable from the spawns via walking and/or ladders; the demo is generating a map and walking/climbing to every part of it.

## Files to create/modify
- tools/level_generator/movement_model.lua
- tools/level_generator/layout.lua
- tools/level_generator/main.lua
- src/ (small constant-access seams only, if needed)

## Test approach
Headless: movement-model assertions against real `src/` constants (only claims transitions the game's actual walk/ladder mechanics support — no gap crossing without a ladder); reachability test — for many seeds/sizes, every zone is reachable from spawn via the model's transition graph (walk-adjacency + ladder edges only); ladder placement only where a ladder object actually spans the gap. Manual: `love . debug drawphysics map=...` and traverse the whole map.

## Acceptance criteria
- [ ] Every generated zone reachable from spawn via walking and/or ladders (verified programmatically across many seeds)
- [ ] No gap in the layout lacks a ladder spanning it — the model never assumes a jump
- [ ] Movement model constants come from `src/`, not literals in the tool
- [ ] `--size` visibly changes dimensions within the agreed ranges
- [ ] Ladders emitted as proper ladder objectgroup rects the game recognises
- [ ] No floating/orphaned platforms unreachable by design

## Blocked by
01
