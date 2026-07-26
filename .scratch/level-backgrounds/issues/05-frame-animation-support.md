Status: pending

# Frame animation support for props

## What to build
Props can optionally play frame animations via existing Sprite + Timeline components, composable with procedural motion (sway + frames simultaneously).

Preset config per prop layer:
```lua
props = {
  {
    name        = "fireflies",
    template    = "firefly",
    count       = 12,
    region      = {x = 0, y = 0, w = "map_width", h = "map_height * 0.3"},
    depth       = 0.4,
    windScale   = 0.0,
    motion      = { sway = { strength = 0.01, speed = 0.3 } },
    animation   = { frames = "res/img/firefly_${i}.png", frameCount = 4, duration = 0.5, loop = true },
  },
}
```

- `animation` table follows Sprite conventions: `frames` (string template or spritesheet), `frameCount`, `duration`, `loop`, etc.
- Loader passes `animation` to prop entity; prop adds Sprite + Timeline components when present.
- Motion (sway/shake) still applies to the drawn sprite (transform in draw).

Demonstrate on one sandbox prop (placeholder frames OK — e.g. reuse coin frames or simple colour shifts).

## Files to create/modify
- src/entities/prop.lua (add animation wiring)
- src/backgrounds/night_forest.lua (add animated prop layer demo)
- res/img/ (placeholder frames if needed)
- res/map/sandbox.tmx + .lua
- tests/unit/prop_animation_test.lua (extend)

## Test approach
Headless: prop with animation advances frame index over simulated time; prop with animation + sway has both active; prop with neither stays static. Load sandbox and assert old `sky`/`trees` tile layers gone.

## Acceptance criteria
- [ ] Props optionally play frame animations via Sprite+Timeline
- [ ] Frame animation and procedural motion compose on one prop
- [ ] Sandbox demonstrates at least one animated prop
- [ ] No regressions in motion/proximity/clouds

## Blocked by
03 and 04 (all background elements in place before adding animation demo).