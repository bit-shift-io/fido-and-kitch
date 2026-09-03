# Dynamic split-screen camera (2026-09-03)

Plan generated from `NOTES.md` "Dynamic split-screen camera (2026-09-03)".
Adds dynamic split-screen for N players (first version 2), merging back to a
single camera when players are close or in overview. Each task touches at
most 1–2 files. Run `./test-unit.sh` / `./test-integration.sh` after each
phase; re-verify `./test-e2e.sh` after anything touching rendering. Mark `[x]`
as tasks land. Task ordering favours pure/high-risk math first, wiring last.

## Phase 1 — Core split-decision math (pure, no love.*)

The framing math in `src/camera.lua` is already pure (headless-testable). Add
the split/merge decision and per-pane framing as pure functions so they're
unit-testable without a window.

- [ ] `src/camera.lua` — add pure `Camera.shouldPan(worldBounds, opts)` /
  `Camera.paneViewports(...)` helpers: given the players' union-bounds span and
  `minViewTiles`, decide whether the comfort zoom is violated (split) and
  compute a single pane's sub-rect framing. Keep N-generic (list of pane
  targets). No behaviour change to existing `computeFraming`.
- [ ] `tests/unit/camera_test.lua` — unit tests for the new split-decision
  helpers: split threshold at union-bounds span, merge hysteresis (Hi/Lo
  bounds), and per-pane framing from a subset of targets.

## Phase 2 — Split layout / pane partitioning (2 players, dominant axis)

- [ ] `src/split_screen.lua` (new) — pure layout module: given N pane centers
  (or player rects) and the window size, decide the divider axis by dominant
  separation (further apart horizontally → vertical divider) and return each
  pane's screen sub-rect `{x, y, w, h}`. 2 players first.
- [ ] `tests/unit/split_screen_test.lua` (new) — unit tests: vertical vs
  horizontal axis selection, pane rect partitioning sums to the window, and
  degenerate 1-player (no split) case.

## Phase 3 — View-rect scoping of the draw pipeline

Today `ParallaxRenderer:drawBackground` and `Diorama.drawVoid/drawFrame`
derive their screen math from full-window `love.graphics.getWidth()/getHeight()`.
They must instead accept the pane's sub-rect so each pane re-renders its own
view.

- [ ] `src/map/parallax_renderer.lua` — `drawBackground` takes a pane
  `{x, y, w, h}` (default to full window when absent, preserving current
  behaviour) and uses it for its screen-space math/scissor instead of
  `getWidth()/getHeight()`.
- [ ] `src/diorama.lua` — `drawVoid`/`drawFrame` accept a pane sub-rect
  (default full window when absent) and use it for void-rect and screen
  geometry.
- [ ] `tests/unit/parallax_test.lua` (or existing `map_parallax_test.lua`),
  `tests/unit/diorama_test.lua` — add tests for pane-sub-rect-driven math:
  void strips computed against a sub-rect, parallax scissor bounded to the
  sub-rect. No regressions to the full-window default path.

## Phase 4 — Extract the per-pane draw pass

Refactor `InGameState:draw`'s body into a reusable pane draw so the same
pipeline runs once per pane (void → parallax → tiles → frame → entities →
bubbles), each scissored to its sub-rect.

- [ ] `src/states/ingame_state.lua` — extract a `drawPane(viewRect, paneRect)`
  helper that encapsulates the existing draw order translated/scissored to a
  sub-rect; keep a single-pane path that reproduces today's output exactly
  (single pane = full window) so nothing changes when not split.

## Phase 5 — Camera ownership for multiple panes

- [ ] `src/camera.lua` — support multiple camera instances/panes (one per
  player pane) plus a shared "merged" camera. Overview (`mode == "overview"`
  or `"gameover"`) collapses all panes to a single full-map view. Add per-pane
  extra-target handling (respawning player's pane frames its safe position).
- [ ] `tests/unit/camera_test.lua` — tests for per-pane cameras, overview
  collapse to a single full-map pane, and per-pane respawn framing.

## Phase 6 — InGameState wiring (split + merge, animated with hysteresis)

- [ ] `src/camera.lua` — add the split/merge transition state machine with
  hysteresis (split at span > Hi, merge only when span < Lo) and an animated
  divider/pan split factor that eases toward its target. Merge returns exactly
  to today's shared `computeFraming` union-bounds framing.
- [ ] `src/states/ingame_state.lua` — drive the split decision from
  `collectPlayerTargets()` each frame: when split, update each pane's camera
  and draw each pane via `drawPane`; when merged, draw one pane as today.
  Keep `space`/back overview-only.
- [ ] `tests/integration/split_screen_test.lua` (new) — integration test
  driving two players far apart → splits into two panes (two camera views);
  close together → merges back to one. Assert pane count and camera state.

## Phase 7 — Off-screen player indicator

- [ ] `src/ui/player_indicator.lua` (new) — screen-space edge indicator
  (arrow/portrait) pointing to a player who is off that pane's view; drawn
  post-entities, pre-HUD, per pane.
- [ ] `src/states/ingame_state.lua` — draw the indicator per pane after the
  pane's entities (and after bubbles), passing the pane rect and the other
  player's world position.

## Phase 8 — HUD & debug overlays under split

- [ ] `src/states/ingame_state.lua` — keep the shared `GameHud` drawn once in
  its current on-screen location (not per pane). Debug overlays (physics,
  sprite outlines, grid) draw per pane using each pane's viewRect, all toggled
  by the existing single flags.

## Phase 9 — Verify full suite

- [ ] Run `./test-unit.sh` — all logic changes pass; no pre-existing-suite
  regressions introduced by the split work.
- [ ] Run `./test-integration.sh` — split/merge integration test passes; real
  stack (maps through the love.* mock) unaffected when not split.
- [ ] Run `./test-e2e.sh` — headed render verification: visually confirm a
  real split renders both panes, the shared HUD stays put, the indicator shows,
  and overview/game-over collapse to a single pane. (Requires headed LÖVE.)
