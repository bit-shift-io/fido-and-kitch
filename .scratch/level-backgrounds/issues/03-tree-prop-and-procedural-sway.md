Status: pending

# Tree prop layer + procedural sway

## What to build
Tree prop layer in preset:
```lua
props = {
  {
    name        = "trees",
    template    = "tree",
    count       = 12,
    region      = {x = 0, y = "ground_y - 200", w = "map_width", h = 200},
    depth       = 0.8,
    windScale   = 1.0,
    motion      = { sway = { strength = 0.02, speed = 0.5 } },
  },
}
```

- `region`: supports `"ground_y"` token (resolved from collision/ground layer bounds)
- `motion.sway`: sine-driven skew/rotation — `strength` = max angle (rad), `speed` = cycles/sec. Phase offset by `windX * windScale * time` so trees sway with wind.

Tree template: `res/templates/tree.tx` referencing `props.tsx` tile 0 (`tree_1.png` already there).

Sandbox: `night_forest.lua` adds trees prop layer.

Wind: map property `windX` (number) overrides preset `defaultWindX`. Code default = 10. Effective wind for layer = global wind × `windScale`.

## Files to create/modify
- src/components/motion.lua (add sway helper)
- src/entities/tree.lua (thin wrapper or just use prop with template="tree")
- res/templates/tree.tx (new)
- src/backgrounds/night_forest.lua (add trees prop layer)
- res/map/sandbox.tmx + .lua (add windX property if desired)
- tests/unit/tree_prop_sway_test.lua (new)

## Test approach
Headless: prop layer spawns `count` entities in region; after simulated time, sway offset/rotation matches `sin(wind * windScale * speed * time) * strength`; `windScale=0` → no motion; no colliders.

## Acceptance criteria
- [ ] Trees placed from template, render at correct positions
- [ ] Trees sway procedurally, scaled by global wind × `windScale`
- [ ] Sine sway works on single-frame art (no frames needed)
- [ ] `depth` and `windScale` parsed with sensible defaults
- [ ] Map `windX` overrides preset default; code default when both absent
- [ ] No colliders on trees

## Blocked by
01 (loader), 02 (prop base + motion helpers).