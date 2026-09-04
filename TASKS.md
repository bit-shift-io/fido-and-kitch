# Voronoi dynamic split-screen (2026-09-03)

Replace the vertical 50/50 split-screen with a Voronoi dynamic split-screen:
an angled dividing line whose angle follows player relative position, each
player gets a full-window camera, and a GLSL shader composites the two views.
Plan generated from grill-me session and `NOTES.md` "Voronoi dynamic
split-screen (2026-09-03)". Run `./test-unit.sh` / `./test-integration.sh`
after each phase; re-verify `./test-e2e.sh` after anything touching rendering.
Mark `[x]` as tasks land.

## Phase 1 — Camera system rework (Euclidean distance, angle tracking)

Modify `src/camera.lua` to use Euclidean distance for the split decision and
add angle tracking for the Voronoi dividing line. Keep the existing pure
framing math (`computeFraming`) and the per-camera easing. Remove the
union-bounds span approach and pane sub-rect concepts.

- [x] `src/camera.lua` — replace `splitHiTiles`/`splitLoTiles` with `d_merged`
  and `d_split` (pixel thresholds for Euclidean distance). Default:
  `d_merged = 4 * tileW`, `d_split = 8 * tileW`. Remove `paneTargets` (no
  per-pane target lists; each player camera gets its own player's rect +
  extras).
- [x] `src/camera.lua` — rewrite `CameraManager:updateSplit(playerTargets)`:
  compute Euclidean distance D between the two players' center points
  (`{x + w/2, y + h/2}`); `splitTarget = clamp((D - d_merged) / (d_split -
  d_merged), 0, 1)`; ease `splitFactor` toward `splitTarget` using
  exponential decay (`1 - e^(-decay * dt)`).
- [x] `src/camera.lua` — add `splitAngle` and `splitAngleTarget` fields to
  CameraManager. Compute `splitAngleTarget = atan2(py2-py1, px2-py1)` in
  `updateSplit`. Smooth via exponential lerp with a per-frame max rotation
  clamp (~150 deg/s). Use shortest-path atan2 interpolation (adjust by +/- pi
  to avoid spinning the long way). Below a minimum angle threshold (~5 deg),
  don't rotate (prevents jitter when players are aligned).
- [x] `src/camera.lua` — remove `Camera.shouldPan` (split decision no longer
  uses union-bounds span).
- [x] `src/camera.lua` — remove `Camera.paneViewports` (no pane sub-rects;
  each camera frames against the full window).
- [x] `src/camera.lua` — remove `CameraManager:paneSide` and
  `assignPaneSides` (replaced by shader angle). Remove `paneSideLocked`.
- [x] `src/camera.lua` — add `getSplitAngle()` accessor to CameraManager.
- [x] `src/camera.lua` — update `CameraManager:ensurePane` to create
  per-player cameras with `minViewTiles = 4` (tighter zoom per-player).
- [x] `tests/unit/camera_test.lua` — rewrite CameraManager tests: Euclidean
  distance split decision, angle computation and smoothing, linear
  interpolation split_factor. Remove tests for `shouldPan`, `paneViewports`,
  `paneTargets`, `paneSide`.

## Phase 2 — Voronoi shader

Create the GLSL fragment shader for Voronoi compositing.

- [x] `res/shaders/voronoi_split.glsl` (new) — GLSL fragment shader: takes
  two canvases (CanvasA, CanvasB), screen-space UV targets for each player,
  a split_factor [0..1], line_thickness, and line_color. At split_factor=0,
  passes through to CanvasA. At split_factor>0, assigns each pixel to the
  closer player's canvas, draws a dividing line in between. Final output:
  `mix(colA, voronoiResult, split_factor)`.
- [x] Verify shader loads correctly in LÖVE (manual or e2e smoke test).

## Phase 3 — InGameState drawing rework (Voronoi compositing)

Replace the vertical 50/50 split rendering with Voronoi compositing. Two
full-window canvases, each drawn with its own camera, composited by the
Voronoi shader.

- [x] `src/states/ingame_state.lua` — add `self.voronoiCanvases = {nil, nil}`
  (two full-window canvases, recreated on resize). Add
  `getVoronoiCanvases()` lazily (same pattern as old `getCrossfadeCanvases`).
- [x] `src/states/ingame_state.lua` — add `self.voronoiShader` loaded lazily
  in `getVoronoiShader()` (headless-safe, same pattern as old
  `getBlendShader`). Remove `self.blendShader` and `getBlendShader`.
- [x] `src/states/ingame_state.lua` — remove `self.crossfadeCanvases` and
  `getCrossfadeCanvases` (replaced by voronoiCanvases).
- [x] `src/states/ingame_state.lua` — remove `self.paneRects` and
  `computePaneRects` (no more 50/50 pane rects). Remove `self.paneSide` and
  `paneSideLocked`.
- [x] `src/states/ingame_state.lua` — remove `drawSplit` (old blend-band
  crossfade). Remove `BLEND_BAND_FRACTION` and `BLEND_SHADER` constants.
  Remove `splitBlendHalf`.
- [x] `src/states/ingame_state.lua` — add `computeVoronoiUVs()` method: given
  the two players' world positions and the current camera state, compute
  normalized screen-space UVs for P1 and P2 (the shader's p1_screen and
  p2_screen uniforms). At split_factor=0, both UVs are at (0.5, 0.5). As
  factor rises, UVs spread based on player positions relative to camera
  center. At split_factor=1, derive UVs from player world positions via
  angle (matching doc's fully-split formula).
- [x] `src/states/ingame_state.lua` — add `drawVoronoiSplit()` method:
  1. Get split_factor from camera.
  2. Render CanvasA: draw merged camera view blended with P1's view based on
     split_factor (lerp camera center and zoom between merged and P1). Run
     full diorama pipeline.
  3. Render CanvasB: draw P2's camera view (full diorama pipeline).
  4. Compute UVs, send shader uniforms, composite onto screen.
- [x] `src/states/ingame_state.lua` — rewrite `draw()`: when split_factor
  approx 0 and not transitioning, draw merged view directly (single pass,
  no shader). When split_factor > CROSSFADE_EPS, call `drawVoronoiSplit()`.
  HUD always drawn after shader compositing.
- [x] `src/states/ingame_state.lua` — rename `drawPane(viewRect, paneRect,
  paneIndex)` to `drawWorldView(viewRect)` — remove paneRect parameter and
  scissor logic (each canvas is full-window). Keep the diorama pipeline
  (void, parallax, tiles, frame, entities, bubbles).
- [x] `src/states/ingame_state.lua` — update `drawPaneOverlays`: remove
  paneRect scissoring, draw overlays full-window into the canvas.
- [x] `src/states/ingame_state.lua` — remove `drawPaneIndicators` (player
  indicators removed). Remove `self.playerIndicator`.
- [x] `src/states/ingame_state.lua` — update `resize`: recreate
  voronoiCanvases (replaces crossfadeCanvases recreation). Remove
  crossfadeCanvases recreation.
- [x] `tests/integration/split_screen_test.lua` — rewrite: test split/merge
  transitions with Euclidean distance, verify canvas rendering (headless),
  verify shader loads.
- [x] `tests/e2e/split_screen_test.lua` — rewrite: visual verification of
  Voronoi compositing (capture screenshots of split state, verify dividing
  line angle, verify both players visible).

## Phase 4 — Overview mode

Ensure overview mode bypasses the Voronoi shader.

- [x] `src/states/ingame_state.lua` — when `camera:isOverview()`, draw a
  single merged full-map view directly (no shader, no canvases). Same
  behavior as today but without pane sub-rects.
- [x] Verify overview toggle (space/back) still works with the new system.

## Phase 5 — Cleanup

Remove dead code and files that no longer apply.

- [x] `src/split_screen.lua` — remove entirely. Pane partitioning no longer
  applies. `smoothstep` is only used in the removed `computePaneRects`.
- [x] `src/ui/player_indicator.lua` — remove entirely. Player indicators not
  needed in Voronoi mode (both players are always visible on screen via the
  shader).
- [x] `tests/unit/split_screen_test.lua` — remove entirely (tests pane
  partitioning).
- [x] `tests/unit/player_indicator_test.lua` — remove entirely (indicators
  removed).
- [x] `tests/unit/run.lua` — remove `split_screen_test.lua` and
  `player_indicator_test.lua` from the test list.
- [x] `tests/integration/run.lua` — update test list (remove or update
  `split_screen_test.lua`).
- [x] Verify `./test-unit.sh` passes after all removals.
- [x] Verify `./test-integration.sh` passes after all removals.
- [x] Verify `./test-e2e.sh` passes after all removals. (The only remaining
  e2e failure -- `all_maps_screenshot_test` map-count assertion -- is
  pre-existing and unrelated to the Voronoi work; the rewritten
  `split_screen_test.lua` passes all 3 cases.)

## Phase 6 — Polish

Angular hysteresis, aspect ratio, and edge cases.

- [x] Split/join continuity: the dividing line only appears once the panes have
  actually diverged (SPLIT_DIVERGENCE_FLOOR), and the render switches to the
  Voronoi split with the anchors and pane zoom at 0 / merged ― so the split
  reads as a continuous glide, never a jolt. `getSplitZoomBlend()` (driven by
  divergence, shared by the anchor offsets and the pane zoom blend in
  `CameraManager:getPaneDrawParams`) keeps position and zoom aligned with the
  still-merged view at onset and on merge.
- [x] Player kept in-frame near map edges: `Camera:computeTargetView` now
  honours `clampToMap` (passed through to `computeFraming`), so per-pane
  cameras (`clampToMap=false`) stay centred on their player even at the map
  border; the anchor base is screen centre so a player is never dragged
  off-screen.
- [x] Dividing-line direction: derived from the players' world positions (not
  the pane-camera centres, which could be stale/clamped), so the line is always
  perpendicular to the players' separation.
- [x] The line never passes through a player: each player renders at the centre
  of their own Voronoi half (VORONOI_PANE_OFFSET from screen centre along the
  separation axis), cleared of the dividing line.
- [ ] Verify angular smoothing: players circling each other produce a smooth,
  non-jerky dividing line rotation. Tune the per-frame max rotation clamp
  (~150 deg/s) and minimum angle threshold (~5 deg) as needed.
- [ ] Consider aspect ratio compensation: when the dividing line is
  near-horizontal (players above/below each other), each player's vertical FOV
  is constrained. Optionally adjust per-player camera zoom based on angle.
  This is a polish item, not critical for v1.
- [ ] Verify HUD (lives, coins, debug overlays) renders correctly after the
  shader compositing pass.
- [ ] Verify diorama void/frame draws correctly on each canvas (no bleeding at
  the Voronoi dividing line).
- [ ] Verify resize handling: canvases recreate at correct size, shader
  uniforms update.
- [ ] Full test suite run: `./test-all.sh`.
