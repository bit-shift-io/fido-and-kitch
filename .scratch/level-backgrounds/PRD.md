# Level Backgrounds (Tiled Background Map)

## Problem Statement

Level backgrounds are currently plain tile layers (`sky`, `trees` in sandbox) drawn from the tileset atlas. This means backgrounds can only be static 32px tiles: no rich imagery, no parallax depth. Most maps (e.g. ll1) have no background at all because tile-based backgrounds are tedious to author. Level authors need a proper background system.

## Solution

A **Tiled background map** loaded as a separate STI map. Level authors create a background map in Tiled (e.g. `res/backgrounds/night_forest.tmx`) with image layers, set `parallaxx`/`parallaxy` per layer for parallax speed, and the game loads it alongside the main map. The background map draws before the main map layers.

Background elements are pure visuals: no colliders, never obstruct the player. All layers carry `parallaxx`/`parallaxy` for parallax. Scope: system + background map library + sandbox conversion only.

## User Stories

1. As a level author, I want to create a background in Tiled using image layers, so I can see it at real size in the editor.
2. As a level author, I want to set `parallaxx`/`parallaxy` on each layer in Tiled, so parallax is authored visually.
3. As a level author, I want a library of background maps (`night_forest`, `cave`, `sky`) to pick from.
4. As a level author, I want to select a background for my map via a single map property `background = "night_forest"`.
5. As a player, I want background layers to move at different speeds relative to the camera (parallax) so the world feels deep.
6. As a player, I want background elements to never block movement or collide with me.
7. As a developer, I want new background maps to be just a `.tmx` + `.lua` pair in `res/backgrounds/` — no code changes.
8. As a level author, I want sandbox converted to the new system so there's a working reference map.

## Implementation Decisions

- **Authoring model**: Background authored in Tiled as a separate `.tmx` file with image layers. Exported to `.lua` for the game. Map property `background` (string) names the background map (without extension).
- **Background location**: `res/backgrounds/<name>.tmx` + `res/backgrounds/<name>.lua`. Images referenced relatively from there (`../img/backgrounds/...`).
- **Loading**: In `Map:new`, after loading main map, if `map.properties.background` exists, load `sti('res/backgrounds/' .. backgroundName)` as `self.backgroundMap`.
- **Drawing**: In `Map:draw2`, before the main layer loop, draw `self.backgroundMap` layers with parallax. STI's native parallax uses layer `parallaxx`/`parallaxy` multiplied by camera position. We'll compute parallax offset from the map's draw transform (`tx`, `ty`).
- **Parallax math**: Layer draw position = `layer.offsetx + tx * (1 - layer.parallaxx)`, `layer.offsety + ty * (1 - layer.parallaxy)`. At `parallaxx=0`, layer scrolls with world. At `parallaxx=1`, layer fixed to screen.
- **Tiling**: Enable `repeatx = true` on all background image layers (images ~1200px wide, maps can be wider). Set in Tiled or at load time.
- **No physics**: Background map creates no colliders.
- **Dual-file rule**: Background maps also need `.tmx` and `.lua` export.

## Background Map Schema (Tiled)

```tiled
Map: night_forest.tmx (30x20 tiles, 32x32)
Layers (image layers):
  - background (sky):        parallaxx=0.0,  parallaxy=0.0,  offsetx=-480, offsety=-320, image=../img/backgrounds/background_night_sky.png
  - midground (mountains):   parallaxx=0.5,  parallaxy=0.5,  offsetx=-544, offsety=-96,  image=../img/backgrounds/midground_night_mountains.png
  - foreground (forest):     parallaxx=0.8,  parallaxy=0.8,  offsetx=-512, offsety=0,    image=../img/backgrounds/foreground_night_forest.png
```

All layers: `repeatx = true` (enable in Tiled or at load time).

## Testing Decisions

- Tests target external behaviour via headless Lua test harness (`tests/`, run with `./test-unit.sh`).
- Good tests: background map loads; layers have correct `parallaxx`/`parallaxy`; parallax offset formula correct for given `tx`; tiling draws correct repeat count; `background` map property drives selection; no colliders created.
- Modules tested: background map loading, parallax draw logic.
- Prior art: lives-and-kill-zones tests and existing `tests/` suites.
- Lua project — follow existing `tests/` naming/layout conventions.

## Out of Scope

- Camera/auto-zoom rework (parallax uses existing draw transform).
- Backgrounds for ll1 or any map other than sandbox.
- Props (trees, bushes, clouds), motion (sway, drift), proximity (bush rustle), frame animation.
- Weather (rain/snow), day/night cycles.
- Foreground/overlay decoration layers (in front of player).
- Editor tooling beyond standard Tiled image layers + parallax properties.

## File Structure

- `res/backgrounds/` — background maps (`night_forest.tmx/.lua`, `cave.tmx/.lua`, `sky.tmx/.lua`)
- `res/img/backgrounds/` — background images (sky, mountains, forest PNGs)
- `src/map.lua` — modified to load and draw background map
- `res/map/sandbox.tmx` + `res/map/sandbox.lua` — add `background = "night_forest"` property, remove `sky`/`trees` tile layers
- `tests/unit/background_map_test.lua` — new test file

## Acceptance Criteria

- [ ] Sandbox has `background = "night_forest"` map property
- [ ] Sandbox loads `res/backgrounds/night_forest.lua` as background map
- [ ] 3 background layers draw behind all main map tile layers
- [ ] Layers draw in correct order (background → midground → foreground)
- [ ] Parallax works: layers move at different speeds relative to camera (verify by moving camera in-game)
- [ ] Horizontal tiling works (images repeat across map width)
- [ ] Map property `background` drives background selection
- [ ] New background = new `.tmx`/`.lua` pair in `res/backgrounds/` — no code changes
- [ ] No physics colliders created from background map
- [ ] Sandbox's old `sky`/`trees` tile layers removed; map looks at least as good as before
- [ ] Headless tests cover loading, parallax math, tiling math