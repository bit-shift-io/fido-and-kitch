# Handoff — Auto-Zoom Camera

## Summary

Replace the current fit-whole-map-to-screen rendering with an auto-zoom camera: one shared camera that frames all players (2-tile margin, 5×5-tile minimum view, full-map maximum, clamped to map bounds) with smooth frame-rate-independent easing on pan and zoom. Spacebar or a gamepad button toggles a full-map overview while gameplay keeps running. Levels open at full-map view and ease in; game over eases back out; a dying player's respawn point joins the framing targets so respawn isn't jumpy. Split-screen and parallax are out of scope, but the camera must expose centre + zoom per frame so parallax can be built on it later.

## Implementation order

1. **01-camera-follow-core** — pure framing math module + wiring into the draw path. Everything else layers on this.
2. **02-smooth-motion-and-level-start** — smoothing and the level-intro zoom-in.
3. **03-overview-toggle** — input + camera mode; small once 02 exists.
4. **04-death-respawn-and-game-over-framing** — depends on the (currently unimplemented) lives-and-kill-zones feature for its events; camera mechanisms and headless tests can be built anytime after 02, the event hookup waits for that feature. Carries the parallax follow-up recommendation.

## Documents

- PRD: `.scratch/auto-zoom-camera/PRD.md`
- Decisions & rationale: `.scratch/auto-zoom-camera/DECISIONS.md`
- Glossary entries: `CONTEXT.md` (Auto-zoom camera, Framing target, Overview toggle)
- No ADRs — nothing met the gate; render-path decision logged in DECISIONS.

## Implementer notes & gotchas

- **Current render path** (`src/map.lua`): `Map:resize` computes fit-to-screen tx/ty/scale; `Map:draw2(tx, ty, sx, sy)` draws all layers 1:1 onto a full-map canvas, then draws that canvas translated/scaled. The camera should *supply* tx/ty/s to this existing path — don't restructure the canvas dance (it fixes tearing and scissoring). The fit-to-screen math in `resize` is exactly the "full map view" used for overview/level-start/game-over.
- **`hump.camera` is dead code**: created in `src/game_states.lua` (InGameState:load and :resize) but never used to draw. Remove it rather than building on it.
- **Players draw inside map layers** (inserted into `layer.entities` at spawn), so one world transform moves map + players + props together. Player bounds come from `player.collider` (`getX`/`getY`/`getBounds`).
- **Framing math must be LÖVE-free** so it runs under the dependency-free headless runner (`./test.sh`, see `tests/README.md`). Keep `love.*` out of `src/camera.lua`'s math; follow the existing testability-seam pattern.
- **Window resize**: `InGameState:resize` must feed the new screen size to the camera (and the map canvas already gets recreated in `Map:resize` — keep that).
- **Map pixel size**: `map.width * tilewidth` / `map.height * tileheight` as in `Map:resize`; tile size for the 5×5/margin constants should come from the map, not be hardcoded (tiles are square in current maps but read `tilewidth`/`tileheight` anyway).
- **Known accepted limitation**: zoomed-in views scale the 1:1 canvas up (linear filter → some blur) and the whole map is still drawn every frame. Fine for now; potential future optimisation, not this feature.
- **Issue 04 dependency**: lives-and-kill-zones (`.scratch/lives-and-kill-zones/`) was all `Status: pending` at planning time (2026-07-10). Check its status before starting 04; if still unimplemented, build the camera mechanisms + tests and leave event hookup as a marked TODO.
- **Don't forget parallax** after this ships — see the recommendation at the end of issue 04.
