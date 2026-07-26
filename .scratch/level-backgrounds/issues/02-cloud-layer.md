Status: pending

# Cloud layer — drifting, wrapping clouds

## What to build
Cloud entity (`src/entities/cloud.lua`): drifts horizontally at `windX * windScale * speedVariance`, wraps at map edges (x < 0 → x + mapWidth, x > mapWidth → x - mapWidth). No collider. Accepts `depth`, `windScale`, `scaleVariance`, `speedVariance`.

Background loader spawns clouds from preset's `cloud` layer:
```lua
{ type = "clouds", region = {x=0, y=0, w=mapWidth, h=200}, count = 8,
  templates = {"cloud_small", "cloud_big"},
  windScale = 1.0, speedVariance = 0.3, scaleVariance = 0.2, depth = 0.8 }
```
- `region`: spawn rectangle (relative to map; `mapWidth`/`mapHeight` tokens allowed)
- `count`: number of clouds
- `templates`: array of template names (from `res/templates/`)
- `windScale`: multiplies global wind for this cloud layer
- `speedVariance`/`scaleVariance`: per-cloud random multipliers (1.0 ± variance)

New templates: `res/templates/cloud_small.tx`, `cloud_big.tx` referencing `props.tsx` cloud tiles.
New art: `res/img/cloud_1.png`, `cloud_2.png` → added as tiles to `props.tsx`.

Sandbox preset (`forest.lua`): add cloud layer config.

## Files to create/modify
- src/entities/cloud.lua (new)
- src/templates/cloud_small.tx, cloud_big.tx (new)
- res/img/cloud_1.png, cloud_2.png (new placeholder art)
- res/tilesets/props.tsx (add cloud tiles)
- src/backgrounds/forest.lua (add cloud layer)
- res/map/sandbox.tmx (update background property to "forest")
- res/map/sandbox.lua (re-export)
- tests/unit/cloud_test.lua (new)

## Test approach
Headless: loader creates exactly `count` clouds inside region; after simulated updates clouds move in wind direction; cloud pushed past map edge reappears on opposite side (assert wrapped x); zero wind → stationary; no colliders. Seeded RNG for determinism.

## Acceptance criteria
- [ ] Cloud layer spawns `count` clouds from template pool at load
- [ ] Clouds drift with global wind × layer `windScale` × per-cloud variance
- [ ] Clouds wrap at map edges; population stays constant
- [ ] Pool, count, region, variance all configured in preset
- [ ] Sandbox sky has drifting clouds
- [ ] No colliders created

## Blocked by
01 (loader + preset system must exist).