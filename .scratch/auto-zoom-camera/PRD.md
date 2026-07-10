# Auto-Zoom Camera

## Problem Statement

The map is currently scaled to fit the whole screen, so every level must fit all its detail into one static view. Larger levels become unreadable: tiles get tiny, players get lost, and level design is capped by screen size. With multiple players sharing one screen, the game needs a camera that shows the action at a useful size while keeping everyone visible.

## Solution

A camera that automatically frames all players: it zooms in when they're close together (down to a 5×5-tile minimum view) and zooms out as they spread apart, up to showing the whole map. All movement — panning and zooming — is smoothly interpolated, never snapping. Players can toggle a full-map overview (spacebar or a gamepad button) at any time to plan their route while the game keeps running. Levels open fully zoomed out and glide in on the players; game over glides back out to the full map.

## User Stories

1. As a player, I want the camera to follow me and my co-player automatically, so that we can both always see our characters without anyone steering a camera.
2. As a player, I want the camera to zoom in when we're close together, so that the action is large and readable instead of the whole level being crammed on screen.
3. As a player, I want the camera to zoom out as we move apart, so that neither of us ever goes off-screen.
4. As a player, I want camera movement and zooming to be smooth and slick, so that jumping and quick direction changes don't cause jitter or nausea.
5. As a player, I want some breathing room around my character at the screen edge, so that I can see what I'm about to run or jump into.
6. As a player, I want to press a button (spacebar / gamepad button) to toggle a full-map overview, so that I can plan where to go next.
7. As a player, I want the game to keep running during the overview, so that toggling it is a tactical choice, not a pause.
8. As a player, I want the overview to smoothly zoom out and back in when toggled, so that I don't lose track of where my character is.
9. As a player, when the level starts I want to see the whole map first and then zoom in on our spawn point, so that I get a sense of the level before playing.
10. As a player, when my co-player dies I want the camera to already include their respawn point while they're dying, so that their reappearance isn't a jarring camera jump.
11. As a player, at game over I want the camera to zoom out to the whole map, so that the ending mirrors the level intro and I can see where we got to.
12. As a player, I never want to see garbage outside the map edges — the area beyond the map stays black, and the camera keeps the framing clamped to the map.
13. As a level designer, I want levels larger than one screen to be playable, so that I'm not limited to single-screen layouts.
14. As a developer, I want the camera's position and zoom queryable each frame, so that parallax (using the already-plumbed background `depth` values) can be built on top later.

## Implementation Decisions

- **New camera module** owning framing math and smoothing, replacing the unused `hump.camera` instance. Framing math is pure Lua (no LÖVE dependencies) so it is headless-testable.
- **Framing algorithm**, each frame:
  1. Collect framing targets: the world-space bounds of every alive player, plus (while a player is dying) that player's respawn position.
  2. Compute the union bounding box, expand by 2 tiles of margin on every side.
  3. Enforce the minimum view: grow the box (centred) so it is at least 5×5 tiles.
  4. Fit the box to the screen aspect ratio (letterbox-style: scale = min of horizontal/vertical fit).
  5. Clamp the resulting view rectangle to map bounds where possible; when the required view exceeds the map in an axis, centre the map on that axis (black beyond the edges, as today).
- **Smoothing:** exponential lerp of camera centre and zoom toward the target view, frame-rate independent, settling in under roughly half a second. Tunable constants in one place.
- **Overview toggle:** a camera mode (`follow` / `overview`). Overview's target view is the full map (the current fit-to-screen framing). Toggling switches mode; the same smoothing carries the transition. Bound to spacebar and a gamepad button (Back/Select). Gameplay is unaffected.
- **Lifecycle:** camera initialises at the full-map view on level load, then eases to the follow target. Game over sets the target to full-map view.
- **Render path:** keep the existing canvas-based map draw; the camera supplies the translate/scale that the draw path currently derives from fit-to-screen. HUD and menus remain in screen space, untouched by the camera transform.
- **Public surface:** the camera exposes its current centre and zoom each frame (the hook parallax will need later).
- **Dependency:** death/respawn and game-over camera behaviours integrate with the lives-and-kill-zones feature, which is planned but not yet implemented. Those behaviours are isolated in their own slice so the rest of the camera can ship first.

## Testing Decisions

- Tests follow the project's fast gameplay regression test convention: headless, dependency-free Lua run via `./test.sh`, no LÖVE window (see `tests/README.md`). Test files live in `tests/` named `*_test.lua`, matching the existing `player_movement_test.lua` / `bump_physics_test.lua` prior art.
- Good tests here assert external behaviour of the framing math: given target rectangles, map size, and screen size, the computed view has the right centre, the right zoom, respects the 5×5 minimum, the 2-tile margin, aspect-ratio fit, and map-bounds clamping.
- Smoothing tests assert convergence (view approaches target over simulated frames), frame-rate independence (different dt step sizes reach ~the same place in the same simulated time), and no overshoot/oscillation.
- Mode/lifecycle tests assert the target view switches correctly between follow, overview, level-start, and game-over states.
- Rendering (the actual translate/scale draw) is verified manually by playing; it is not headless-testable.

## Out of Scope

- Split-screen (a likely future direction when players are far apart; the hybrid auto-zoom→split-screen idea stays on the shelf for now).
- Parallax rendering from background `depth` values — explicitly deferred, but the camera must expose position + zoom so it can be added without rework (recommendation recorded in the final issue).
- Per-player cameras or any camera behaviour for more than one screen.
- Death/kill-zone/lives mechanics themselves (separate planned feature; this feature only adds camera reactions to those events once they exist).
- Camera shake, look-ahead in movement direction, or other camera juice.
- Pixel-perfect rendering / resolution-aware canvas sizing (zoomed-in views scale the existing 1:1 canvas up; acceptable for now).

## Acceptance Criteria

- [ ] With two players close together, the camera zooms in but never shows fewer than 5×5 tiles.
- [ ] As players separate, the camera zooms out so both stay on screen with ~2 tiles of margin, up to the full-map view.
- [ ] Camera pan and zoom are smooth — no snapping, no jitter during jumps — settling in under ~half a second.
- [ ] The view never shows non-black garbage outside the map; framing is clamped to map bounds.
- [ ] Spacebar and a gamepad button toggle a smooth transition to/from a full-map overview while gameplay continues.
- [ ] Level start: camera opens at full-map view and eases in on the players.
- [ ] While a player is dying, their respawn position is included in the framing before they reappear (once lives-and-kill-zones exists).
- [ ] Game over: camera eases out to the full-map view (once lives-and-kill-zones exists).
- [ ] HUD elements stay fixed in screen space at every zoom level.
- [ ] Camera centre and zoom are queryable per frame by other systems.
- [ ] Headless framing/smoothing tests pass via `./test.sh`.

## References

- Glossary: `CONTEXT.md` — Auto-zoom camera, Framing target, Overview toggle, Depth.
- Related planned features: `.scratch/lives-and-kill-zones/` (death/respawn/game-over hooks), `.scratch/level-backgrounds/` (depth/parallax plumbing).
