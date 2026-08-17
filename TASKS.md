# PLAN - Diorama: World-Edge Frame & Void Fill (NOTES.md)

A framing system for when the game world ends but the screen continues: a
**generic tiling background** fills the out-of-world screen strips (the void),
and a **world-space decorative frame** (edge tiles + 4 corner pieces +
interstitial ornaments) wraps the world boundary so the playfield reads as a
framed diorama. Confirmed decisions live in `NOTES.md` (2026-08-17 grill);
**Diorama** is the chosen system name (replaces the working name "border" —
the asset folder is renamed accordingly).

## Confirmed decisions (NOTES.md)

1. **Divider type**: a border **frame at the world's edge** — a framed diorama
   look. Not a fade, vignette, pattern void, or world extension.
2. **Void fill**: a **generic tiling background** fills the out-of-world screen
   strips ONLY, scissored to the 4 strips outside the projected world rect so
   it never shows through transparent gaps in a map's own backdrop.
3. **Parallax scope**: parallax backgrounds are "for view in the player world,
   not outside of it" — `ParallaxRenderer:drawBackground` today scales the
   image to cover the whole screen and bleeds into the void; it must be
   clipped to the world rect (scissor).
4. **Frame art**: edge-tile per side + 4 corner pieces + ornaments along each
   border to hide tiling repetition.
5. **Frame space**: **world space** — art repeats at world scale and zooms with
   everything else; reuses the world transform.
6. **Config**: one global code config, the same for all maps; **no seeds / no
   randomization** — fully deterministic.
7. **Ornament selection**: **pre-configured percentage-based** — each side's
   pool is `{img, weight}` pairs distributed proportionally along the edge in a
   fixed deterministic pattern.
8. **Frame placement**: **centered on the world boundary**; drawn after the
   world tiles; entities draw over it.

## Render layering (world → screen)

1. Void tiling (screen space, clipped to the 4 strips outside the world rect)
2. Map parallax background (clipped to the world rect — needs scissor)
3. World tiles (existing `map:draw2` main layers)
4. Frame (world space: edge tiles + corners + ornaments, centered on the world
   boundary)
5. Entities (existing `map:drawEntities`, over the frame)

## Verified grounding

- The camera's view rect is clamped **inside** the map bounds
  (`Camera.computeFraming`, `src/camera.lua:82-92`), so the out-of-world
  screen area is exactly `screen minus the projected world rect`.
- **The projected world rect in screen coords** must match how the world is
  actually drawn: `ParallaxRenderer:drawMainLayers`
  (`src/map/parallax_renderer.lua:47-52`) does
  `translate(math.floor(tx), math.floor(ty))` then `scale(sx, sy)`, so the
  rect is `{x = math.floor(tx), y = math.floor(ty), w = mapW*sx, h = mapH*sy}`
  with `mapW/mapH` from `map:getPixelSize()` (`src/map/init.lua:118`). Use the
  **floored** origin everywhere (void strips, bg scissor, frame transform) or a
  hairline strip shows through at fractional `tx`/`ty`.
- `ParallaxRenderer:drawBackground` (`src/map/parallax_renderer.lua:11-45`)
  draws each imagelayer scaled to cover the whole screen
  (`s = math.max(screenW/imgW, screenH/imgH)`, line 34) — this is the bleed.
  It already calls `lg.origin()` (line 17), so a scissor set there is in plain
  screen coordinates.
- **The only live `map:draw2` consumer is `InGameState:draw`**
  (`src/states/ingame_state.lua:222-225`: `map:draw2` then `map:drawEntities`).
  `Map:draw()` (fit-in-window variant) has no callers; the menu and game-over
  states never render the map. The render-order change is confined to
  `InGameState:draw`.
- Headless tiers never call `love.graphics` (the unit/integration mock has no
  scissor and draw is never reached), so all scissor/`love.graphics` draw code
  runs only under real rendering (e2e). Follow the `Sprite`/`AssetManager`
  guard pattern: `AssetManager.getImage` returns `nil` headless
  (`src/utils/asset_manager.lua:3-12`); draw methods must no-op gracefully
  without `love.graphics`.
- New unit test files must be registered in the explicit list in
  `tests/unit/run.lua`; e2e tests are auto-discovered from `tests/e2e/`.
- The void tiling texture exists: `res/img/border/border_background.png`
  (untracked, ~1.5MB). Per the user it is **the tiling void background** and
  the folder/system should be renamed away from "border".
- LÖVE `love.graphics.scissor` coordinates follow the current transform — set
  the scissor while `lg.origin()` is active (screen coords), never inside a
  pushed translate/scale.

## Assumptions / open

- Frame edge/corner/ornament art does **not** exist yet; the config keys are
  the contract. `Diorama` must skip any piece whose image fails to load
  (memoized `Log.warn` once per path) so the game runs before art lands.
- Void tiling is **static screen-space**: fixed to the screen, tiled from the
  origin, not scrolling, not aligned to the world grid.
- The frame shows whenever its edge is on screen, including the overview
  full-map view — by design.
- Config home: `Diorama.config` in `src/diorama.lua` (a plain module table,
  stateless singleton, same pattern as `src/camera.lua`). The NOTES.md
  `border = {...}` config-key sketch is superseded by this (see task 7).

## Validation baselines (fresh, 2026-08-17)

`./test-unit.sh`: **495 passed, 0 failed** (diorama adds 13 unit tests).
`./test-integration.sh`: **98 passed, 9 failed** (9 pre-existing failures, all
unrelated to this feature:
joystick-driven P1 movement, box-filling-a-hole walk-across, on/off switch
forward/reverse animations, exit-door open sound, Robot 30s respawn, Spider
wrap-release x2, external image-collection tileset).

## Tasks

- [x] 1. Rename the asset folder (1 path): create `res/img/diorama/`, move
  `res/img/border/border_background.png` → `res/img/diorama/diorama_void.png`,
  remove the now-empty `res/img/border/`. No code yet.
- [x] 2. Create `src/diorama.lua` (1 file, new). Stateless module with:
  `Diorama.config` (the one global code config: `void.img =
  'res/img/diorama/diorama_void.png'`; `frame.tiles` top/bottom/left/right;
  `frame.corners` topLeft/topRight/bottomLeft/bottomRight; `frame.spacing`
  (px between ornament slots); `frame.ornaments` = per-side `{img, weight}`
  pools — paths under `res/img/diorama/`); pure headless-testable geometry
  exposed via a `Diorama._internal` white-box seam (drawbridge/pressure_switch
  convention) with `worldScreenRect(tx, ty, sx, sy, mapW, mapH)` (floored),
  `computeVoidRects(screenW, screenH, wr)` → 4 strip rects outside the world
  rect (skip zero-size), `computeFrame(mapW, mapH, config)` → 4 corner
  positions + per-edge tile spans + ornament slot positions (slot count =
  `floor(edgeLen / spacing)`, inset from corners, centered on the boundary
  line), and `assignOrnaments(pool, slotCount)` → deterministic weighted
  distribution (pure function, no seed); plus thin draw methods `drawVoid(tx,
  ty, sx, sy, mapW, mapH)` (screen space, tiled, scissored to the strips under
  `lg.origin()`) and `drawFrame(tx, ty, sx, sy, mapW, mapH)` (world space,
  push/origin/translate(floor tx/ty)/scale(sx,sy)/pop, corners then tiled
  edges then ornaments, all centered on the boundary). No `love.*` at module
  scope; draw guards for missing `love.graphics`; missing images skip with a
  memoized `Log.warn`.
- [x] 3. Unit tests for the pure geometry (2 files): add
  `tests/unit/diorama_test.lua` and register it in `tests/unit/run.lua`. Cover:
  `worldScreenRect` floors tx/ty; void rects union exactly to
  screen-minus-world-rect with no overlap (wide-screen vertical strips and
  tall-screen horizontal strips); corners land at the 4 boundary corners;
  slot count = `floor(edgeLen / spacing)` with slots inset from the corners
  and centered on the boundary; `assignOrnaments` is deterministic (same
  input → same output), uses every pool item, and respects weights
  proportionally; config defaults present and stable. Run `./test-unit.sh`.
- [x] 4. Scissor the parallax background (1 file): in
  `src/map/parallax_renderer.lua`, `drawBackground` — under `lg.origin()`,
  before the imagelayer loop, `lg.scissor(math.floor(tx), math.floor(ty),
  mapW*sx, mapH*sy)`; `lg.setScissor()` to restore after the loop. Guard for
  `love.graphics` (headless no-op). Leave the draw math unchanged.
- [x] 5. Wire Diorama into the draw order (1 file): in
  `src/states/ingame_state.lua` `InGameState:draw` — before `map:draw2(...)`
  call `Diorama.drawVoid(tx, ty, sx, sy, mapW, mapH)`, and between
  `map:draw2(...)` and `map:drawEntities(...)` call
  `Diorama.drawFrame(tx, ty, sx, sy, mapW, mapH)` (mapW/mapH from
  `map:getPixelSize()`).
- [x] 6. E2E verification (1 file): add `tests/e2e/diorama_test.lua`. Real
  LÖVE; resize the window to a wide aspect (e.g. `love.window.setMode(1200,
  500)`) over a small map so void strips exist; pre-seed
  `AssetManager.textures[path]` (via `require('src.utils.asset_manager')`)
  with solid-color placeholder images for every config path (void tile + frame
  tiles + corners + ornaments) so geometry is verifiable without real art;
  step frames; render the game to an offscreen canvas and assert via
  `canvas:newImageData():getPixel(x, y)`: a void-strip point == void
  placeholder color, a point just outside a world edge == that edge's frame
  tile color, and a point inside the world == neither (and not the parallax
  bg). `Capture.capture` 2-3 named screenshots for review. Run
  `./test-e2e.sh tests/e2e/diorama_test.lua`.
- [x] 7. Docs + final validation (2 files): add a `Diorama` bullet to
  `AGENTS.md` (system name, config shape, the 5-layer render order, the
  floored-world-rect scissor contract, deterministic ornaments, missing-art
  tolerance) and lightly update `NOTES.md` (the proposed `border = {...}`
  config key is superseded by `Diorama.config`; the void texture is
  `res/img/diorama/diorama_void.png`); then `./test-unit.sh` and
  `./test-integration.sh` green with no regression (unit ~489 pass / 0 fail,
  integration 98 pass + same 9 pre-existing failures).