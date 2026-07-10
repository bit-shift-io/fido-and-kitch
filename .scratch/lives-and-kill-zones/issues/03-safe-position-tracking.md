Status: done

# Safe-position tracking

## What to build

Each player continuously remembers their "last safe position" — the most recent spot where they stood on solid ground for a stability threshold (~0.5 s), so respawns never put them on the crumbling pixel-edge of a ledge. After this slice, a debug marker drawn in the world shows each player's current safe position: it starts at the spawn point, follows the player along the ground with a slight lag, and stays put while they are airborne or on ladders.

## Files to create/modify

- `src/player/safe_position.lua` (new seam module, pattern: `src/player/player_movement.lua`) — a pure tracker: created with an initial position and threshold; fed `(dt, grounded, x, y)` each update; accumulates grounded time, resets the timer when not grounded, and commits `(x, y)` as the safe position once continuous grounded time passes the threshold (keep committing while stably grounded so the point trails the player). Exposes the current safe position.
- `src/player/player.lua` — create the tracker in `Player:init` seeded with the spawn position; update it each `Player:update` using grounded state. "Grounded" should be true only in the walk/idle FSM state with `queryOnGround()` true — falling, jumping, and `LadderState` never count.
- `src/game_states.lua` or `src/player/player.lua` — temporary debug draw of the safe position marker (small cross/circle at the tracked point), easy to strip later.

## Test approach

Headless (`tests/safe_position_test.lua` via `./test.sh`): initial position is the seed; grounded for less than the threshold does not move the safe position; grounded past the threshold commits the new position; going airborne resets the timer so a brief touch-down mid-fall never commits; position keeps updating during long stable grounding. Manual: run the game, watch the marker — walk along a platform (marker follows behind), jump off a ledge into the water area (marker stays at the ledge, not mid-air), climb a ladder (marker unchanged).

## Acceptance criteria

- [ ] Safe position starts at the player's spawn point
- [ ] Only updates after ~0.5 s of continuous grounding; airborne/ladder time resets the timer
- [ ] Tracked independently per player
- [ ] `tests/safe_position_test.lua` passes via `./test.sh`

## Blocked by

None — can start immediately (parallel with 01 and 02).
