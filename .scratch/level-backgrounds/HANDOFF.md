# Level Backgrounds (Tiled Background Map) — Handoff

## Summary

A Tiled background map system: level authors create a background map in Tiled (image layers with `parallaxx`/`parallaxy`), export to `.lua`, and select it via a single map property `background = "night_forest"`. The game loads the background map as a second STI map and draws its layers with parallax before the main map layers. Background elements are pure visuals: no colliders, never obstruct the player. Scope: system + background map library (`night_forest`, `cave`, `sky`) + sandbox conversion only.

## Suggested implementation order

1. **01-background-map-loader-and-parallax-draw** — In `Map:new`, load background map from `res/backgrounds/<name>.lua` if `map.properties.background` set. In `Map:draw2`, draw background map layers first using STI's parallax formula (`tx * parallaxx`). Enable `repeatx` on all background layers. Sandbox gets `background = "night_forest"`.
2. **02-additional-background-maps-and-sandbox-cleanup** — Create `cave` and `sky` background maps; remove sandbox's old `sky`/`trees` tile layers; verify full test suite passes.

**User directive:** every issue updates the sandbox map as part of its slice (each slice demoable in sandbox when done).

## Key integration points

- Map load: `Map:new` (src/map.lua ~line 32) → after `createEntitiesFromObjectGroupLayers`, if `self.map.properties.background` exists, load `sti('res/backgrounds/' .. backgroundName)` as `self.backgroundMap`.
- Background map: standard STI map with image layers. Layers have `parallaxx`, `parallaxy`, `offsetx`, `offsety`, `repeatx`. Images referenced relatively (`../img/backgrounds/...`).
- Draw order: `Map:draw2` → before main layer loop, draw `self.backgroundMap` layers with parallax.
- Parallax math (from STI): `px = math.floor(tx * (layer.parallaxx or 1))`, `py = math.floor(ty * (layer.parallaxy or 1))`. Draw layer at `(px + layer.offsetx, py + layer.offsety)` with horizontal repeat if `layer.repeatx`.
- Tiling: enable `repeatx = true` on all background image layers (images ~1200px, maps can be wider). Can set in Tiled or at load time in code.
- No physics: background map creates no colliders (don't call `box2d_init` or collision body creation for it).

## Gotchas

- **Dual-file rule**: background maps also need `.tmx` AND `.lua` export (hand-edit both if Tiled unavailable).
- **Image paths**: background map `.lua` references images as `../img/backgrounds/...` relative to `res/backgrounds/`. STI resolves from the map file's directory — this works.
- **Layer order**: background map layers drawn in their declared order (sky → midground → foreground). Correct for depth.
- **Camera transform**: `tx`, `ty` in `Map:draw2` are the camera offsets (negative when camera is right/down of origin). Parallax formula uses these directly.
- **repeatx in export**: Tiled's `repeatx` may not export if false by default — enforce `layer.repeatx = true` in code after loading background map.
- **Background map size**: `night_forest.tmx` is 30x20 tiles (960x640px). Main map is 20x20 (640x640px). Background map can be different size — just draws its layers.

## Links

- [PRD](PRD.md) — requirements, stories, acceptance criteria
- [DECISIONS](DECISIONS.md) — grill Q&A and rationale
- Issues: [01](issues/01-background-map-loader-and-parallax-draw.md) [02](issues/02-additional-background-maps-and-sandbox-cleanup.md)
- No ADRs created — no decision met the hard-to-reverse gate; rationale in DECISIONS.md.