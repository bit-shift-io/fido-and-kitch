# PLAN - Zoom-Coupled Parallax Backgrounds (NOTES.md)

Rework `ParallaxRenderer:drawBackground` (`src/map/parallax_renderer.lua`) so a
background image layer scales with camera zoom and its drawn rect always
contains the projected world rect — a texture edge can never show inside the
world. Confirmed decisions live in `NOTES.md` (2026-08-18 grill).

## Confirmed decisions (NOTES.md)

1. **Zoom-coupled scale**: the background is sized relative to camera zoom so
   it always covers the whole world rect (world size × camera scale), not just
   the screen. Zooming in scales the background up with the world.
2. **Clamp guarantee**: hard-clamp each layer so its drawn rect always contains
   the world rect; zero/negative slack locks the layer to world-center.
3. **Parallax reference**: the smoothed camera center, recovered from
   tx/ty/sx/sy (`mapParallax.computeCameraCenter`) — equals the average of the
   two players' positions; auto-handles overview/game-over (no slide).
4. **Authored `parallaxx`/`parallaxy` are a guide**: they weight how much each
   layer participates in the slide (per axis, kept independent).
5. **Slide law (proportional)**: per axis,
   `layerCenter = worldCenter + allowance * p * (center - mapSize/2)`, where
   `center` is the recovered camera center in world units; `p=0` pins the layer
   to world-center (no more camera-tracking sky semantics).
6. **Two shared preset constants** (one place, nothing per-map):
   `ZOOMED_OUT_ALLOWANCE = 0.10`, `ZOOMED_IN_ALLOWANCE = 0.30`, with
   `allowance = lerp(zoomOut, zoomIn, zoomT)` and
   `zoomT = (scale - fullMapScale) / (closestScale - fullMapScale)` (camera
   scale normalized between full-map view and the closest view, currently
   `minViewTiles = 6`). Image screen draw scale =
   `(1 + allowance) * max(mapW/imgW, mapH/imgH) * cameraScale`; the `max`-cover
   guarantees ≥ `allowance` slack per axis, so the slide never exceeds the
   slack.
7. **Authored `offsetx`/`offsety` are DISCARDED** (e.g. `sky.tmx`'s
   `offsety=-200`). Everything anchors to world-center + proportional slide.
8. Keep the existing scissor to the projected world rect (background never
   bleeds into the Diorama void strips).

## Verified grounding

- `map_parallax.lua` is the pure-math home (love/sti-free, unit-tested in
  `tests/unit/map_parallax_test.lua`); `computeCameraCenter` already round-trips
  the camera center from tx/ty/sx/sy at any zoom.
- `drawBackground` (`src/map/parallax_renderer.lua:11-55`) currently uses
  `s = max(screenW/imgW, screenH/imgH)` (screen-cover, zoom-invariant) and the
  `(1-p)` screen-space slide with authored offsets — this whole loop body is
  replaced. The world-rect scissor (floored origin `floor(tx), floor(ty)`,
  size `mapW*sx, mapH*sy`) and the `lg.origin()`/scissor contract stay.
- World center on screen = `floor(tx) + mapDrawW*0.5` (and y); world-space
  slide is `allowance * p * (cx - mapW/2)` which becomes screen space × `sx`.
- Camera constants to match: `DEFAULT_MIN_VIEW_TILES = 6`,
  `DEFAULT_TILE_SIZE = 32` (`src/camera.lua:10-11`); full-map view scale from
  `Camera.fullMapView`/`computeFraming` (`src/camera.lua:47-129`). Derive
  `fullMapScale`/`closestScale` consistently with those definitions from the
  map's pixel size + tile size and the current screen size.
- `tests/unit/run.lua` already registers `tests/unit/map_parallax_test.lua`;
  no new test files are needed.

## Tasks

- [ ] 1. Add the zoom-coupled math + shared presets to `src/map/map_parallax.lua`
  (1 file): module-level constants `ZOOMED_OUT_ALLOWANCE = 0.10` and
  `ZOOMED_IN_ALLOWANCE = 0.30`; `computeZoomT(scale, fullMapScale,
  closestScale)` returning the clamped [0,1] normalization
  `(scale - fullMapScale) / (closestScale - fullMapScale)`; `computeAllowance
  (zoomT)` = linear lerp between the two presets; `computeCover(mapW, mapH,
  imgW, imgH)` = `math.max(mapW/imgW, mapH/imgH)`; replace `computeLayerOffset`
  with `computeSlide(allowance, parallax, center, mapSize)` =
  `allowance * parallax * (center - mapSize * 0.5)` in world units (drop the
  old `(1-parallax)` screen-space math and the authored `offsetx/offsety`
  params). Keep the module love/sti-free and keep `computeCameraCenter`
  unchanged. Run `./test-unit.sh tests/unit/map_parallax_test.lua` — the old
  tests will fail; that's expected until task 3 lands.
- [ ] 2. Rework `ParallaxRenderer:drawBackground` in `src/map/parallax_renderer.lua`
  (1 file): keep the `lg.origin()` + floored world-rect scissor + per-layer
  loop. Per layer: derive `zoomT` from the current camera scale (`sx`) vs the
  full-map view scale and closest (min `6`-tile) view scale computed from
  screen/map/tile dims (match `Camera.computeFraming` semantics), then
  `allowance = computeAllowance(zoomT)`; draw scale
  `s = (1 + allowance) * computeCover(mapW, mapH, imgW, imgH) * sx`; recover the
  camera center via `computeCameraCenter(tx, ty, sx, sy, screenW, screenH)`; set
  the layer center to world-center-on-screen (`floor(tx) + mapDrawW*0.5`, and y)
  plus the screen-space slide
  `allowance * parallaxx * (cx - mapW/2) * sx` (and y); hard-clamp the center so
  the drawn rect always contains the world rect (clamp within
  `±(drawW - mapDrawW)/2`, lock to world-center when slack ≤ 0); drop authored
  `offsetx`/`offsety` entirely; draw with `lg.draw(image, drawX, drawY, 0, s,
  s)`. Keep the world-rect scissor restore. Run
  `./test-unit.sh tests/unit/map_parallax_test.lua` (still expected to fail
  until task 3).
- [ ] 3. Update `tests/unit/map_parallax_test.lua` (1 file): keep the
  `computeCameraCenter` round-trip test; delete the tests that describe the
  replaced semantics (zoom-invariance of the layer draw offset, pan shifts by
  `(1-parallax)*delta`, parallax=1 pinned to its authored offset, parallax=0
  tracks the camera center + authored offset). Add: proportional slide extremes
  (p=1 at map-left → `-allowance*mapW/2`, at map-right → `+allowance*mapW/2`,
  p=0 → 0 = pinned to world-center, both axes independent); `computeZoomT`
  clamps at both ends and `computeAllowance` lerps to 0.10/0.20/0.30 at
  zoomT 0/0.5/1; cover-guarantees-coverage — for a range of image aspects and
  camera scales spanning full-map → closest, the drawn rect from
  `(1+allowance)*cover*scale` always contains the world rect (slack ≥ slide
  magnitude on each axis). Run `./test-unit.sh tests/unit/map_parallax_test.lua`
  → all green.
- [ ] 4. Final validation + docs (2 files): update the `src/map/`
  `parallax_renderer.lua` and `map_parallax.lua` bullets in `AGENTS.md` to
  describe the zoom-coupled scale, proportional slide, discarded authored
  offsets, and the two shared allowance presets; run `./test-unit.sh` (all
  green) and `./test-integration.sh` (no new failures beyond the known
  pre-existing ones).