# Fido and Kitch — Zoom-Coupled Parallax Backgrounds: Confirmed Requirements

Grill notes (2026-08-18). Feature: rework `ParallaxRenderer:drawBackground`
(`src/map/parallax_renderer.lua`) so parallax scales with camera zoom and the
background image never exposes its edge inside the world.

Current behaviour: each imagelayer is cover-fit to the screen
(`s = max(screenW/imgW, screenH/imgH)`), centered at
`offset = (1 - parallax) * cameraCenter + authoredOffset` (pure math in
`src/map/map_parallax.lua`, unit-tested in `tests/unit/map_parallax_test.lua`).
Image scale is NOT coupled to zoom; layers are scissored to the world rect but
can slide far enough to show a texture edge inside the world.

## Confirmed decisions (asked + answered)

1. **Zoom-coupled scale**: the background image is sized relative to the
   camera zoom so it always covers the whole world rect (world size × camera
   scale), not just the screen. Zooming in scales the background up with the
   world, which is what makes parallax more noticeable.
2. **Clamp guarantee**: hard-clamp each layer so its drawn rect always
   contains the world rect — a texture edge can never show. Zero/negative
   slack locks the layer to world-center.
3. **Parallax reference**: the average of the two players' positions —
   midpoint of the union of player collider bounds (the same rects
   `Camera.computeFraming` frames). The smoothed camera center was the
   original reference because it "already equals the players' average", but
   that equality only holds while the view is narrower than the map:
   `Camera.computeFraming` pins the view center to the map center whenever
   `viewW > mapW` (`viewX = (mapW - viewW)/2`), so at every zoomed-out view
   `center - mapSize/2 = 0` and the slide was always zero — the 10% zoom-out
   allowance was never spent (verified 2026-08-18). The recovered camera
   center remains only as a fallback when no player rects are supplied.
   Overview/game-over with the player reference become a static offset
   (players frozen → no visible motion), which is visually equivalent to
   no slide.
4. **Authored parallaxx/parallaxy are a "guide"**: they weight how much each
   layer participates in the slide. Slide range is player-position-driven,
   not `(1-p)` clamp-saturated.
5. **Slide law — proportional**: per axis,
   `layerCenter = worldCenter + slide`, with
   `slide = allowance * p * (playersAvg/mapSize - 0.5)`.
   `playersAvg/mapSize` = 0 at map-left/top, 1 at map-right/bottom. Extremes
   are both players on the far-left of the map vs both on the far-right.
   A `p=0` layer is pinned to world-center (scrolls with the world; no longer
   camera-tracking sky semantics). Line 4's existing parallax semantics are
   intentionally replaced.
6. **Two shared preset constants** (one place, all maps/backgrounds use them,
   nothing per-map):
   - `ZOOMED_OUT_ALLOWANCE = 0.10`
   - `ZOOMED_IN_ALLOWANCE = 0.30`
   - `allowance = lerp(zoomOut, zoomIn, zoomT)` (linear), where
     `zoomT = (scale - fullMapScale) / (closestScale - fullMapScale)` —
     camera scale normalized between full-map view and the closest view
     (currently `minViewTiles = 6`). At zoom-out the image is scaled to 110%
     of world-cover (max slide ~±5% of world for p=1); at closest zoom 130%
     (±15%).
   - Image screen scale = `(1 + allowance) * max(mapW/imgW, mapH/imgH) *
     cameraScale`. The `max`-cover guarantees at least `allowance` slack on
     each axis, so `slide <= allowance * p <= allowance` never exceeds the
     actual slack → edge can never show.
7. **Authored `offsetx`/`offsety` are DISCARDED** — they only exist to make
   the Tiled editor view nicer (`sky.tmx`'s `offsety=-200` is dropped).
   Everything anchors purely to world-center + proportional slide.
8. Keep the existing scissor to the projected world rect (background never
   bleeds into the Diorama void strips).

## Notes / invariants

- `cover = max(mapW/imgW, mapH/imgH)` is a constant per (map, image) pair in
  world units; multiply by `cameraScale` for the screen-space draw scale.
- World rect on screen: origin `(floor tx, floor ty)`, size `(mapW*sx,
  mapH*sy)`; world center on screen = `floor(tx) + mapW*sx*0.5` (and y).
- `p` is read per axis (`parallaxx` for x, `parallaxy` for y); keep the
  per-axis independence.
- Unit tests in `tests/unit/map_parallax_test.lua` must be updated: the
  current `computeLayerOffset` zoom-invariance and `(1-p)*delta` tests no
  longer describe the behaviour. Add tests for: proportional slide extremes,
  allowance lerp between presets, cover-guarantees-coverage at all zooms.
- Player rects flow into the renderer as `Map:draw2(tx, ty, sx, sy, targets)`
  (`InGameState:draw` passes `collectPlayerTargets()`); the renderer takes the
  union-bounds midpoint per axis. No player rects → fall back to the
  recovered camera center (unchanged legacy behaviour).
