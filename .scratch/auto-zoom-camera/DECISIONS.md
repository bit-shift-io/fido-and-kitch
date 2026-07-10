# Decisions — Auto-Zoom Camera

Grill session 2026-07-10.

### Q1: Zoom extremes and map edges
**Decision:** Max zoom-in shows at least a 5×5-tile view; zoom out as far as needed to fit all players, up to the whole level; keep the existing black background beyond map edges; clamp framing to map bounds.
- **Why:** 5×5 is a starting point to tune by feel. Split-screen (the real answer to "players too far apart") is deferred, so unbounded zoom-out is the interim behaviour. Black-outside-map already works.
- **Implication:** No new edge rendering needed. The framing algorithm needs a min-view clamp and a map-bounds clamp.
- **Alternatives considered:** Max zoom-out cap — rejected; a cap without split-screen would let players leave the screen.

### Q2: Overview button semantics
**Decision:** Press-to-toggle (not hold); gameplay keeps running during overview; bind to spacebar and a gamepad button (Back/Select proposed).
- **Why:** Overview is a planning tool; keeping the game running makes using it a tactical choice. Gamepad players need access too.
- **Implication:** Camera needs an explicit mode (follow/overview). Input handling must not conflict with existing spacebar use in menus (menu uses space to start the game — different state, no conflict).

### Q3: Camera feel
**Decision:** Smooth exponential lerp for both follow tracking and the overview transition. "Slick and smooth", settling in under ~half a second, tuned by feel.
- **Why:** Rigid tracking of jumping players jitters; user explicitly wants no jitter.
- **Implication:** Lerp must be frame-rate independent (exponential decay parameterised by dt, not per-frame fractions).

### Q4: Players appearing/disappearing
**Decision:**
1. When a player is dying, their respawn position immediately becomes an additional framing target ("as if there are 3 players"), so the camera is already framing the respawn point when they reappear.
2. Game over → camera eases out to full-map view. Symmetrically, level start begins at full-map view and eases in on the players.
3. Framing is clamped to the map; a player outside the map is a bug, not something the camera accommodates.
- **Why:** Death takes time, so pre-framing the respawn removes the camera jump. The start/end zoom mirrors nicely as level intro/outro.
- **Implication:** Camera consumes death/respawn/game-over events from the lives-and-kill-zones feature — which is **not yet implemented** (all its issues pending as of 2026-07-10). That slice is blocked on it.

### Q5: Parallax scope
**Decision:** Parallax (background `depth` values) is out of scope, but the camera must expose current centre + zoom per frame, and the final issue carries an explicit recommendation not to forget parallax.
- **Why:** Get the camera core solid first; depth values are already stored and plumbed by the level-backgrounds plan.
- **Implication:** Camera API is designed as a queryable object, not draw-path-internal math.

### Q6: Framing padding
**Decision:** 2 tiles of margin around the players' union bounding box, applied before the 5×5 min-view clamp; tune by feel.
- **Why:** Players at the framing edge need to see what's ahead.

### Q7: Screen-space elements
**Decision:** HUD (lives hearts, future UI) and menus stay in screen space; only the world (map layers, entities, background) goes through the camera transform. No known exceptions.
- **Why:** Nothing is currently drawn in world space that should be screen space or vice versa.

### Implementation decision: render path
**Decision:** Keep the existing canvas-based map rendering (`Map:draw2` already accepts translate/scale) and drive it from a new pure-Lua camera module. Retire the unused `hump.camera` instance rather than adopting it.
- **Why:** The draw path already parameterises tx/ty/sx/sy — the camera just needs to supply different values than "fit whole map". A pure module is headless-testable per the project's fast gameplay regression test convention; hump.camera couples to LÖVE graphics and is currently dead code.
- **Alternatives considered:** Using hump.camera's attach/detach — rejected; it would restructure the canvas draw (which exists to fix tearing/scissoring) for no gain.
- **Trade-off accepted:** The full map is still drawn to a 1:1 canvas each frame and scaled up when zoomed in — blurrier and no cheaper at high zoom. Acceptable for now; noted in HANDOFF as a future optimisation.

### Key assumptions
- Player world positions/bounds come from each player's collider; players are drawn inside map layers, so a single world transform moves everything coherently.
- Two players today, but the framing math takes N targets.
- `Map:resize` currently computes fit-to-screen scale; that computation becomes the camera's "full map view" target and remains the overview/start/game-over framing.

### CONTEXT.md entries added
- **Auto-zoom camera** — the single shared camera that frames all players.
- **Framing target** — anything the camera must keep in view (player bounds, a dying player's respawn point).
- **Overview toggle** — the player-triggered full-map camera mode.
