Status: pending

# Prop entities (trees, bushes) + procedural motion

## What to build
Shared `Prop` entity base (`src/entities/prop.lua`) — tile object from template, no collider, draws at placed position with `depth`, `windScale`. Motion is composable via `motion` config on the prop layer:

```lua
{ type = "props", name = "trees", template = "tree", count = 12,
  region = {x=0, y="ground_y-200", w="map_width", h=200},
  depth = 0.5, windScale = 1.0,
  motion = { sway = { strength = 0.02, speed = 0.5 } } }
```

- `region`: scatter area (supports `map_width`, `map_height`, `ground_y` tokens)
- `motion.sway`: sine-driven skew/rotation — `strength` = max angle (rad), `speed` = cycles/sec. Wind-driven: phase offset by `windX * windScale * time`.
- `motion.shake`: triggered impulse (decaying) for proximity rustle — handled in issue 04.

Templates: `res/templates/tree.tx`, `bush.tx` referencing `props.tsx` tiles (tree_1.png already there; add bush tile).
Art: `res/img/bush_1.png` → `props.tsx`.

Sandbox preset: add `trees` prop layer with sway.

## Files to create/modify
- src/entities/prop.lua (new base)
- src/entities/tree.lua (thin wrapper, or just use prop with template="tree")
- src/entities/bush.lua (thin wrapper)
- src/components/motion.lua (new — sway/shake helpers)
- res/templates/tree.tx, bush.tx (new)
- res/img/bush_1.png (new)
- res/tilesets/props.tsx (add bush tile)
- src/backgrounds/forest.lua (add trees prop layer)
- res/map/sandbox.tmx + .lua (update background property)
- tests/unit/prop_motion_test.lua (new)

## Test approach
Headless: prop layer spawns `count` entities in region; after simulated time, sway offset/rotation matches `sin(wind * windScale * speed * time) * strength`; `windScale=0` → no motion; no colliders.

## Acceptance criteria
- [ ] Trees placed from template, render at correct positions
- [ ] Trees sway procedurally, scaled by global wind × `windScale`
- [ ] Sine sway works on single-frame art (no frames needed)
- [ ] `depth` and `windScale` parsed with sensible defaults
- [ ] Placeholder bush art exists in-repo
- [ ] No colliders on props

## Blocked by
01 (loader), 02 (wind plumbing, cloud art/props.tsx updates).