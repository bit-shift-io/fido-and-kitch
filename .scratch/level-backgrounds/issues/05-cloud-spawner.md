Status: pending

# Cloud spawner with template pool and wrap-around drift

## What to build
A level author draws a rect object with `type=cloud_spawner` in the `background` layer. On load, the spawner populates its region with `count` clouds picked from a pool of Tiled templates (referenced via `file` properties `spawn1`, `spawn2`, …), each with randomized position and speed/scale within configured variance. Clouds drift horizontally at wind × the spawner's `windScale` × their per-cloud variance, and wrap around the map bounds so the sky stays populated forever.

Sandbox map updated: a cloud spawner covering the sky region, pooled with two cloud templates (art from issue 02).

## Files to create/modify
- src/entities/cloud_spawner.lua (new)
- src/entities/cloud.lua or shared prop base (drift + wrap behaviour)
- res/templates/cloud_small.tx, res/templates/cloud_big.tx (new, referencing props.tsx cloud tiles)
- res/map/sandbox.tmx + res/map/sandbox.lua (spawner object)
- tests/ (new test file)

## Test approach
Headless: spawner creates exactly `count` clouds, all initially inside its rect, drawn from the template pool; after simulated updates clouds move in the wind direction; a cloud pushed past the map edge reappears on the opposite side (assert wrapped x); zero wind → stationary clouds; clouds have no colliders. Seeded/injected randomness if the harness needs determinism.

## Acceptance criteria
- [ ] Spawner populates its region from its template pool at load
- [ ] Clouds drift with global wind × spawner `windScale`, with per-cloud variance
- [ ] Clouds wrap at map edges; population stays constant
- [ ] Pool, count, and variance are all set via Tiled properties
- [ ] Sandbox sky has drifting clouds

## Blocked by
02 (cloud art + props.tsx tiles) and 03 (wind).
