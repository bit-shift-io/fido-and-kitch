Status: done

# Death & respawn flow

## What to build

Falling into the water now actually costs a life. When a player overlaps a kill zone (issue 01) and lives remain: the shared pool decrements (issue 02's seam), the player locks in place and their sprite flashes a few times, then they teleport to their last safe position (issue 03) and flash again while remaining fully controllable. The other player and all level state are untouched. The kill zone's `deathType` is carried into the death state (unused for presentation yet, but plumbed for future per-type animations). A death at 0 lives should, for this slice, call a clearly-named hook on the in-game state that just debug-prints "game over" — issue 06 fills it in.

## Files to create/modify

- `src/utils/` or `src/components/` — small reusable flash helper (blink visibility N times over a duration, invoke a completion callback). Both DeadState and the spawn flash (issue 05) use it. Simplest viable approach: toggle a `visible` flag the player's draw path respects, or set the sprite alpha.
- `src/player/player_states.lua` — add `DeadState`: on enter, take `deathType`, set collider kinematic with zero gravity and zero velocity (`LadderState:enter` shows the lock technique), ignore input, start the death flash; when the flash completes, ask the game state to resolve the death. Add respawn handling: teleport the collider to the safe position, switch to the normal state machine flow (`WalkIdleState`/`FallState`), and start a spawn flash that does NOT block movement or input.
- `src/player/player.lua` — replace issue 01's debug print: on `queryKillZone()` hit (and only when not already dead/spawning-invulnerable-to-double-kill), enter `DeadState` with the zone's `deathType`. Expose a `Player:respawn(position)` used by the flow.
- `src/game_states.lua` — `InGameState` owns death resolution: on a player's death-flash completion, run `Lives.applyDeath`; on `respawn`, respawn that player at their safe position; on `gameover`, call the stub hook (debug print). Remove issue 02's temporary debug decrement key. HUD updates automatically since it draws from the live pool.

## Test approach

Headless: the lives seam is already covered (issue 02); if death resolution grows any pure decision logic (e.g. mapping seam outcome + player → actions), extract and test it in `tests/` — otherwise no new headless tests. Manual (`./run.sh`): fall in water → player freezes and flashes in the water, a heart disappears, player reappears at the last ledge flashing and immediately movable; second player unaffected mid-death; collected coins/switch state survive; dying twice then a third time prints the game-over stub; player cannot be re-killed while dead/flashing.

## Acceptance criteria

- [ ] Kill-zone contact with lives remaining: lock + death flash at the point of death, then respawn at that player's last safe position with a non-blocking spawn flash
- [ ] Shared lives decrement by exactly 1 per death; HUD reflects it immediately
- [ ] Only the dead player is affected; level state (coins, keys, switches, other player) persists
- [ ] `deathType` reaches `DeadState`
- [ ] Death at 0 lives triggers the game-over hook (debug print for now), and does not respawn the player
- [ ] No double-death while already in the death/respawn sequence
- [ ] `./test.sh` still passes

## Blocked by

01, 02, 03.
