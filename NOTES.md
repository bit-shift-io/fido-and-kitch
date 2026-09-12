# Voronoi dynamic split-screen (2026-09-03)

Grill-me session: replace the vertical 50/50 split-screen with a Voronoi
dynamic split-screen. Design doc: `Dynamic_Voronoi_Split_Screen_Love2D.md`.
Confirmed decisions:

1. **Scope — full replacement.** Replace the entire split system: the 3-state
   lifecycle (merged, transition, split), the Voronoi angled-line shader
   compositing, the zoom-out transition, removing the 50/50 vertical pane
   model and velocity-based side assignment.
2. **Per-player cameras — full-window.** Each player gets a full-window Camera
   sized to the full window (not a 50/50 half). Per-player cameras use tighter
   zoom: `minViewTiles = 4` (vs merged camera's 6). Each player sees more
   world (a full window), which is the point of Voronoi split.
3. **Split decision — Euclidean distance.** Use Euclidean pixel distance D =
   `||P1 - P2||` between player center points for the split threshold. The
   merged camera zooms out based on D to keep both players visible. Replaces
   the union-bounds span approach.

   **[SUPERSEDED — see `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]**
   Shipped behaviour replaces the raw distance threshold with a *framing*
   trigger: `CameraManager:updateSplit` computes the uncapped framing scale
   required to fit both players and compares it against the floor scale the
   follow-mode zoom cap (`Camera.MAX_VIEW_TILES`) enforces — split once the
   capped camera can no longer fit both players, not once they cross a fixed
   pixel distance.
4. **Hysteresis — doc's linear interpolation.** `split_factor = clamp((D -
   d_merged) / (d_split - d_merged), 0, 1)`. This gives a dead zone between 0
   and 1 that prevents flickering. No separate hi/lo logic needed. Default
    thresholds: `d_merged = 2 * tileW`, `d_split = 4 * tileW`.

   **[SUPERSEDED — see `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]**
   `d_merged`/`d_split` and their multipliers are gone entirely — there is no
   distance-based hysteresis left to interpolate. The dead band is now
   expressed in the *scale* domain: `SPLIT_TRIGGER_SCALE_MARGIN` (1.0) and
   `SPLIT_RELEASE_SCALE_MARGIN` (1.1), local to `src/camera.lua`, bracket the
   cap's floor scale. `split_factor` itself is still an eased 0..1 value, but
   its target is now this scale comparison, not a linear interpolation
   between two distances.
5. **Split factor easing — exponential.** Use the existing exponential ease
   (`1 - e^(-decay * dt)`) which never overshoots and settles in ~0.5s.
   Already proven in the codebase; a separate decay rate for the split factor.
6. **Angle smoothing — lerp + clamp.** The dividing line angle follows
   `atan2(py2-py1, px2-py1)`. Smooth via exponential lerp with a per-frame
   max rotation clamp (~150 deg/s). Shortest-path atan2 interpolation
   (adjust by +/- pi to avoid spinning the long way). Minimum angle threshold
   (~5 deg) prevents jitter when players are aligned.

   **[SUPERSEDED — see `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]**
   The angle math itself (atan2 of the players' separation, exponential lerp,
   150°/s clamp, 5° dead zone) shipped unchanged. What's superseded is the
   *site* model underneath it: the angle no longer describes a line through
   two player-derived sites at all — `CameraManager.computeSplitLine` builds
   a line pinned to screen centre from the angle alone, and the shader takes
   that point+normal directly rather than deriving a bisector from projected
   player positions.
7. **Transition — both cameras ease from merged.** In the transition zone
   (split_factor between 0 and 1), both per-player cameras START at the
   merged midpoint/zoom and EASE OUT to their individual positions. At
   split_factor=0 both show the merged view; as factor rises each camera eases
   toward its own player. Completely smooth, no visual pop.

   **[SUPERSEDED — see `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]**
   Pane cameras still seed from the merged camera (on split *onset*, not on
   pane creation — `CameraManager:updatePane`/`updateSplit`), but "easing out
   to their individual positions" is no longer the whole picture: what a pane
   renders at is `getPaneDrawParams`' anchor — the eased centroid of that
   player's split region — combined with a separately-eased zoom blend
   (`getSplitZoomBlend`, driven by pane divergence, not `split_factor`
   directly). Two eased quantities compose the transition now, not one.
8. **CanvasA — blended merged->P1 camera.** During transition, CanvasA renders
   a camera that blends between the merged midpoint view and P1's individual
   view based on split_factor. At split_factor=0, CanvasA shows the merged
   view (correct merged state). As factor rises, CanvasA eases to P1's view.
   CanvasB always renders P2's camera view. The Voronoi shader composites
   them. Matches the doc's reference implementation exactly.

   **[SUPERSEDED — see `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]**
   CanvasA/CanvasB are symmetric now — both are "P1's/P2's own camera",
   never one blended and one plain. `split_factor <= 0` short-circuits the
   shader to CanvasA alone (see decision 9), and the merged↔pane-zoom blend
   under any nonzero split_factor is `getSplitZoomBlend`, a divergence-driven
   eased value shared by *both* canvases identically, not a blend applied to
   CanvasA only.
9. **Overview — single canvas.** When the player presses space/back (overview),
   all cameras collapse to the full-map view exactly as today. The Voronoi
   shader is bypassed (passthrough to a single canvas showing the full-map
   view). No Voronoi compositing in overview mode.
10. **Diorama — full per canvas.** Each full-window canvas draws the full
    diorama pipeline (void strips, parallax bg, frame, entities) clipped to
    that camera's view. The void/frame appear correctly on each side of the
    Voronoi line because each canvas has its own map-edge context.
11. **Player indicators — removed.** In Voronoi mode, both players are always
    visible on screen (the shader determines which canvas shows for each
    pixel). The other player is never truly 'off-screen'. Remove
    `PlayerIndicator` entirely.
12. **Rendering — full re-render per canvas.** Each canvas runs the whole draw
    pipeline (void, parallax, tiles, frame, entities, bubbles). The merged
    camera's zoom is determined by `computeFraming` with both players' rects
    (handles map bounds, padding, min view size). Per-player cameras use
    `computeFraming` with just their own player's rect + `minViewTiles = 4`.
13. **World model — one shared world/simulation.** Both players act on the same
    world/entities/physics; only rendering is duplicated per canvas.
14. **Modes.** Overview collapses split into a single full-map view. A dying
    player's respawn point is a framing target on that player's camera. Full
    game-over collapses the whole screen to the full-map view.
15. **Control — purely automatic.** Spatial trigger (Euclidean distance) +
    linear interpolation alone decide split/merge; no manual override.
    Space/back stays overview-only.
16. **HUD/overlays.** Shared GameHud stays drawn once in its current on-screen
    location. Debug overlays draw per-canvas using each canvas's viewRect.
17. **Shader file location.** `res/shaders/voronoi_split.glsl` — GLSL fragment
    shader, loaded lazily (headless-safe). Shader parameters: `line_thickness`
    ~0.006, `line_color` dark grey `{0.1, 0.1, 0.1, 1.0}`.

    **[SUPERSEDED (shader parameters only) — see
    `docs/adr/0007-centred-split-line-centroid-anchored-panes.md`]** The file
    location and lazy/headless-safe loading stand. The parameters shipped
    differently: `line_thickness` is `VORONOI_LINE_THICKNESS = 10.0` **screen
    pixels** (not a 0..1 UV fraction — the shader computes a pixel-space
    signed distance to an explicit `line_point`/`line_normal`, so a constant
    pixel width holds at any resolution or aspect ratio), and `line_color` is
    `VORONOI_LINE_COLOR = {0.0, 0.0, 0.0}` (black), not dark grey. Both are
    named constants in `src/states/ingame_state.lua`.
18. **Removed files.** `src/split_screen.lua` (pane partitioning no longer
    applies), `src/ui/player_indicator.lua` (indicators removed). Removed
    tests: `tests/unit/split_screen_test.lua`, `tests/unit/player_indicator_test.lua`.
