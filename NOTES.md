# Dynamic split-screen camera (2026-09-03)

Grill-me session: add dynamic split-screen for N players (first version 2
players), merging back to a single camera when players are close or in
overview. Confirmed decisions:

1. **Split trigger — purely spatial.** Split when the `minViewTiles` comfort
   zoom can't fit the players' union-bounds; merge when it can again. Reuses
   `Camera.computeFraming` (+ its `minViewTiles`/`marginTiles` semantics) — no
   new trigger concept.
2. **Transition — animated with hysteresis.** Split at span > `Hi`; merge only
   when span < `Lo` (`Hi > Lo`) to avoid flicker at the boundary. The divider
   (and split state) eases like camera zoom (`DEFAULT_DECAY`-style
   exponential), not a hard cut.
3. **Rendering — full re-render per pane.** Each pane runs the whole draw
   pipeline (void → parallax → tiles → frame → entities → bubbles) scissored
   to its screen rect. Consequence: `Map:draw2`, `Map:drawEntities`,
   `Diorama.drawVoid`/`drawFrame`, and `ParallaxRenderer:drawBackground` must
   become view-rect-scoped — stop reading full-window `getWidth()/getHeight()`
   and instead take the pane's sub-rect. That refactor is the main cost, not a
   new concept.
4. **Layout — one divider, dominant-axis auto-selected for 2 players.** Vertical
   divider (left/right halves) when the two players are further apart
   horizontally; horizontal divider (top/bottom) when further apart
   vertically. N>2 (quadrants) is a follow-up, not day-one.
5. **World model — one shared world/simulation.** Both players act on the same
   world/entities/physics; only *rendering* is duplicated per pane. Each pane
   is self-contained (shows only what its own camera frames) with an
   **off-screen player indicator** (edge arrow/portrait pointing to the other
   player).
6. **Modes.** Overview (`space`/back) collapses split into a single full-map
   pane for everyone. A dying player's pane frames its respawn point (mirrors
   today's `addExtraTarget` extra-target behavior, scoped per-pane) while alive
   players keep their panes. Full game-over (all players dead) collapses the
   whole screen to the full-map view.
7. **Control — purely automatic.** Spatial trigger + hysteresis alone decide
   split/merge; no manual override. `space`/back stays overview-only. Merge
   returns exactly to today's single shared `computeFraming` union-bounds
   framing.
8. **HUD/overlays.** Shared `GameHud` (lives/coins/mode) stays drawn once in its
   current on-screen location — not re-anchored to a pane (lives/coins are
   shared level pools). Debug overlays (physics, sprite outlines, grid) toggle
   on/off for **all** panes at once when their flag is set; under split each
   pane gets its own overlay pass using its own viewRect (dev-only, cheap).
