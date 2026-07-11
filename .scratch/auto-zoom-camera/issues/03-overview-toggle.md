Status: done

# Map overview toggle (spacebar / gamepad)

## What to build

During play, pressing spacebar (or a gamepad button, proposed Back/Select) toggles the camera between player-follow and a full-map overview. The transition is the same smooth zoom as normal follow. Gameplay keeps running throughout — players can still move while the overview is up. Pressing again returns smoothly to the follow view. Any player's gamepad can trigger the toggle.

Implementation: a camera mode (`follow` / `overview`). In overview mode the target view is the full-map view (the old fit-to-screen framing); in follow mode it is the player framing. Input handled in the in-game state's keypressed/gamepadpressed. Death, respawn, and level transitions leave the mode as the player set it (returning to the menu resets it, since the camera is recreated on load).

## Files to create/modify

- src/camera.lua (mode state; target selection by mode)
- src/game_states.lua (InGameState:keypressed / gamepadpressed bindings)
- tests/camera_test.lua (mode tests)

## Test approach

Headless tests: toggling mode switches the target view between player framing and full-map view; toggling twice returns to the original target; smoothing carries the transition (view is between the two framings mid-transition). Manual: press space mid-jump — game keeps running, camera glides out to the whole map and back; same via gamepad button on both controllers.

## Acceptance criteria

- [ ] Spacebar toggles overview during play; gameplay continues while zoomed out
- [ ] A gamepad button toggles it too, from any player's pad
- [ ] Transition out and back is smooth, same feel as normal follow
- [ ] No conflict with existing input bindings (space in menu still starts the game)
- [ ] Headless mode tests pass via `./test.sh`

## Blocked by

02
