Status: pending

# Cloud prop entities — drift + wrap

## What to build
Shared `Prop` entity base (`src/entities/prop.lua`): tile object from template, no collider, draws at position with `depth`, `windScale`. Accepts `motion` config for composable behaviours.

Cloud prop layer in preset:
```lua
props = {
  {
    name        = "clouds",
    template    = "cloud_small",
    count       = 8,
    region      = {x = 0, y = 0, w = "map_width", h = "map_height * 0.5"},
    depth       = 0.7,
    windScale   = 1.0,
    motion      = { drift = { speed = 1.0, wrap = true } },
  },
}
```

- `region`: spawn rectangle (supports `"map_width"`, `"map_height"` tokens)
- `motion.drift`: horizontal drift at `windX * windScale * speed`; `wrap = true` wraps at map edges (x < 0 → x + mapWidth, x > mapWidth → x - mapWidth)

Cloud template: `res/templates/cloud_small.tx` referencing `props.tsx` cloud tile.
New art: `res/img/cloud_1.png`, `cloud_2.png` → added as tiles to `props.tsx`.

Loader spawns `count` cloud props at random positions within `region`, random template variant if template is an array.

Sandbox: `night_forest.lua` adds cloud prop layer.

## Files to create/modify
- src/entities/prop.lua (new base)
- src/entities/cloud.lua (thin wrapper or just use prop with template="cloud_small")
- src/components/motion.lua (new — drift + wrap helpers)
- res/templates/cloud_small.tx (new)
- res/img/cloud_1.png, cloud_2.png (new placeholder art)
- res/tilesets/props.tsx (add cloud tiles)
- src/backgrounds/night_forest.lua (add cloud prop layer)
- tests/unit/cloud_prop_test.lua (new)

## Test approach
Headless: loader creates exactly `count` cloud props inside region; after simulated updates clouds move in wind direction; cloud pushed past map edge reappears on opposite side (assert wrapped x); zero wind → stationary; no colliders. Seeded RNG for determinism.

## Acceptance criteria
- [ ] Cloud layer spawns `count` clouds from template pool at load
- [ ] Clouds drift with global wind × layer `windScale` × per-cloud variance
- [ ] Clouds wrap at map edges; population stays constant
- [ ] Pool, count, region, variance all configured in preset
- [ ] Sandbox sky has drifting clouds
- [ ] No colliders created

## Blocked by
01 (loader + image layers must exist).