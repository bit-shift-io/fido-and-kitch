Status: done

# Robot dies in a kill zone and respawns at its origin

## What to build

End-to-end: a Robot that touches a kill zone dies (locks its behavior, flashes/fades out over
~1.2s, becomes non-solid), stays fully gone for 30 seconds, then respawns at its original
Tiled spawn position and facing, flashing/fading back in, resuming normal wander behavior with
no stale stun/target/ban state.

This slice also does the foundational work the Spider slice depends on:
- Extracts the player's death/spawn flash-and-fade sequence (currently inlined across
  `Player:die`, `player_states.DeadState`, `Player:startSpawnFlash`) into logic shared with
  `NPC`, and refactors `Player` to call it (no behavior change for the player — this is a
  pure extraction, verified by existing player death/respawn tests still passing).
- Captures a full origin (`homeX`, `homeY`, facing) on `NPC:init`, replacing the current
  `homeX`-only capture.
- Adds a generic NPC kill-zone poll (reusing `PlayerSensors.queryKillZone`'s underlying query
  against an NPC's collider) and an `NPC:die(deathType)` / `NPC:respawn()` pair plus a shared
  `DeadState` in `npc_states.lua`, including the 30-second post-flash delay before respawn and
  the full state reset (clear stun/target/ban) on respawn.

## Files to create/modify

- New shared death/respawn flash module (e.g. alongside `src/components/flash.lua`)
- `src/player/player.lua`
- `src/player/player_states.lua`
- `src/player/player_sensors.lua` (or wherever `queryKillZone` ends up living so both `Player`
  and `NPC` can reach it)
- `src/npc/npc.lua`
- `src/npc/npc_states.lua`
- `src/npc/npc_brain.lua` (if stun/ban reset logic needs a reusable "clear all" helper)
- `src/entities/robot.lua` (if facing needs anything robot-specific beyond what `NPC` captures)

## Test approach

- Unit test the shared flash/fade module directly (headless): interval/blinks timing, alpha
  tween direction, blocking vs. non-blocking completion behavior.
- Unit test `NPC:die`/`NPC:respawn`/`DeadState` transitions headlessly: dying locks the FSM,
  the 30s window gates respawn (test with time advanced past/short-of the threshold), respawn
  restores captured origin position/facing and clears stun/target/ban state.
- Regression: existing player death/respawn unit and integration tests continue passing
  unchanged after the extraction (proves the shared module preserves player behavior).
- Integration test: a Robot walking/pushed into a kill zone in a real fixture map dies, is
  non-solid and invisible during its gone window, and reappears at its original position after
  the delay elapses.

## Acceptance criteria

- [ ] A Robot that touches a kill zone flashes/fades out over ~1.2s and becomes non-solid.
- [ ] It stays gone (invisible, non-solid, FSM idle) for 30 seconds after the flash completes.
- [ ] It then respawns at its original Tiled spawn position and facing, flashing/fading back
      in the same way a player respawn does.
- [ ] Respawned Robot has no stale stun, chase target, or wander ban state.
- [ ] A stunned Robot that touches a kill zone still dies normally.
- [ ] Existing player death/respawn behavior is unchanged (tests pass without modification to
      their assertions).
- [ ] The flash/fade sequence code is shared, not duplicated, between `Player` and `NPC`.

## Blocked by

None — can start immediately.
