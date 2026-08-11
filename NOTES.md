# Fido and Kitch — Pixel-Map Export Tool: Confirmed Requirements

Grill notes (2026-08-11). Feature: replace the ASCII map export with a
pixel map / segmentation map (1 tile -> 1 pixel PNG) for feeding an AI
agent (e.g. to generate art). Supersedes the ASCII exporter decisions in
the previous NOTES.md.

## Related code (grounding)

- Run-flag precedent: `e2e=<file>` detours early in `src/main.lua` `love.load`
  (`findE2ETestFile`, `src/main.lua:98-117`) — `export=<map>` mirrors it:
  detect arg, hand off, `return` before the normal `Game()` construction.
- Solid ground: `src/map/init.lua:91` builds static bodies from **any** layer
  (tile layer or objectgroup) whose `properties.collision` is truthy. ll1 uses
  a `ground` tile layer with `collision=true`; sandbox uses a `collision`
  objectgroup (`collision=true`) of rect objects. The exporter must read the
  same signal, not the layer name.
- Killzones: `src/entities/kill_zone.lua` reads `properties.deathType`,
  **defaulting to `'unknown'`**; code supports `water`, `spikes`, `lava`,
  `fire`. Current maps only use `water` (sandbox.tmx:39, fab1.tmx:42/47).
  Killzone rects live in objectgroups (sandbox `kill` group).
- `src/map/tmx.lua` parses `.tmx` directly; maps are tile grids
  (e.g. ll1 = 36x22, sandbox = 20x20, tile = 32px).
- Current pixel-map exporter: `src/export_png.lua`, unit tests in
  `tests/unit/export_png_test.lua` (color-grid and ImageData blocks),
  run-flag note in `README.md` "Pixel-Map Export".
- LÖVE 12 can build a PNG headlessly: `love.image.newImageData` + setPixel +
  `imageData:encode('png')` returns a FileData accepted by
  `love.filesystem.write` (same save-dir write as today). No window needed —
  the current `export=` detour already runs without one.

## Confirmed decisions (asked + answered)

1. **Format**: PNG image — `export_<map>.png`, each tile drawn as a
   **128x128 block** (image dimensions = map.width x 128 by map.height x 128),
   written to the LÖVE save dir via `love.filesystem.write`. stdout prints
   the path, tile count, pixel dimensions, and a color legend (not the pixel
   grid — it's an image now).
2. **Colors** (fully opaque):
   - `(0, 0, 0)` black = nothing
   - `(0, 255, 0)` green = terrain / collision
   - `(0, 0, 255)` blue = killzone / water
3. **Hazards collapse to one blue**: water, fire, lava, and spikes all paint
   the same blue, regardless of `deathType`. The old w/f/l/s distinction is
   gone (today's maps only use water anyway).
4. **Replace, don't keep**: `export=<map>` now writes only the PNG. The text
   rendering (`renderText`, legend table) and its unit tests are deleted; no
   parallel text flag. README + NOTES.md are rewritten.
5. **Run flag unchanged**: `love . export=sandbox` / `./run.sh export=sandbox`.

## Semantics carried over from the ASCII exporter

- **Solid source**: layers (tile layer or objectgroup) with `collision=true`.
  Tile layer = any nonzero gid paints green; objectgroup = rectangle objects
  paint green.
- **Hazard source**: `kill_zone` objects only (any deathType); a cell covered
  by a killzone rect paints blue, winning over solid green.
- **Partial overlap**: `paintRect` paints every tile a rect overlaps
  (top-left-anchored, floor/ceil clamping). Same cell math as today.
- **Scope**: terrain only. Gameplay objects (ladders, keys, doors, cages,
  coins, spawns, drawbridges, NPCs, ...) are excluded.

## Open / deferred

- Overlapping killzone rects with different deathTypes — last-wins ordering
  is fine (they're all blue now anyway).
- Upscaling the tiny PNG (e.g. 20x20) for human viewing is a viewer concern,
  not the exporter's.

## Who reads this

Implemented: `src/export_ascii.lua` became `src/export_png.lua`, keyed off
the existing `export=` flag and reusing `src/map/tmx.lua` / the Map load
path to rasterize cells without constructing a full `Game`. `renderText`
was replaced by a pure `buildColorGrid` plus a `buildImageData(grid,
width, height, scale)` that paints each tile as a `scale`x`scale` block
(128 in `run()`, a `TILE_BLOCK_SIZE` constant); the encode step is exercised in the real `love . export=`
run and the ImageData mapping under a stubbed `love.image` in the unit
tier. `tests/unit/export_ascii_test.lua` became `export_png_test.lua`.
README carries the "Pixel-Map Export" note. Verify by running
`love . export=<map>` and checking `export_<map>.png` in the save dir.
