Status: done

# Death/respawn framing and game-over zoom-out

## What to build

When a player dies, the camera immediately starts framing their respawn position as an extra target — as if a third player were standing at the respawn point — so by the time they reappear the camera is already there and there's no jarring jump. When the game ends (game over), the camera smoothly zooms out to the full-map view as the game-over presentation plays, mirroring the level-start zoom-in.

Implementation: the camera's framing-target collection gains non-player targets. On a death event, add a target at the dying player's respawn position (their last safe position) for the duration of the death/respawn sequence, removing it once the player is alive again. On the game-over event, switch the camera target to the full-map view (same mechanism as overview mode).

## Files to create/modify

- src/camera.lua (transient extra framing targets; game-over full-map targeting)
- src/game_states.lua (hook death/respawn/game-over events to the camera)
- tests/camera_test.lua (extra-target and game-over framing tests)
- (exact hook points depend on how lives-and-kill-zones lands — adjust when implementing)

## Test approach

Headless tests: adding an extra target expands the computed view to include it; removing it shrinks the view back; game-over state yields the full-map target regardless of player positions. Manual (requires lives-and-kill-zones in place): walk one player into a kill zone far from their last safe position — camera glides to include the respawn point before the player reappears; exhaust the lives pool — camera zooms out to the whole map under the game-over screen.

## Acceptance criteria

- [ ] During a death sequence, the respawn position is framed before the player reappears
- [ ] The extra target is removed after respawn; framing returns to live players only
- [ ] Game over smoothly zooms out to the full-map view
- [ ] Headless tests for extra targets and game-over framing pass via `./test.sh`

## Blocked by

02. Also depends on the lives-and-kill-zones feature (`.scratch/lives-and-kill-zones/`, issues 03 safe-position-tracking, 04 death-and-respawn, 06 game-over-screen) being implemented — it provides the death/respawn/game-over events and the last-safe-position data this slice consumes. If it hasn't landed yet, implement the camera mechanisms and headless tests now and leave the event hookup as a marked TODO for that feature.

## Follow-up recommendation (do not forget)

**Parallax.** Background elements already carry a `depth` value that is "stored and plumbed but visually inert", reserved for exactly this camera. Once this feature is done, the camera exposes centre + zoom per frame — a follow-up feature should use it to render background layers/props at depth-scaled offsets. Plan it as its own feature (`/plan-feature`); don't let the plumbed depth values rot.
