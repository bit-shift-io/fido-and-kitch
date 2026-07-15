Status: pending

# Props reset to spawn on level restart (not on death)

## What to build
All pushable props and pressure-switch states reset to their spawn state when the level restarts; a player death/respawn (losing a life) leaves props untouched. Each prop captures a spawn snapshot (position; for the switch, its off/latched-off state) at load and re-applies it only on level restart.

## Files to create/modify
- src/components/pushable.lua and src/entities/pressure_switch.lua (capture spawn snapshot at init; expose a `resetToSpawn()`)
- the level-restart path (LOCATE FIRST — likely in src/game_states.lua around InGameState:load / the game-over → reload flow, or src/game.lua map loading; confirm whether restart re-instantiates entities from the map, in which case reset is automatic and this slice only needs to verify death does NOT reset)
- tests/pushable_reset_test.lua (new, register in tests/run.lua) — if reset is a real code path rather than a full reload
- (reference) src/game_states.lua onPlayerDied / lives flow, src/map.lua entity creation

## Test approach
First determine how restart works today: if a level restart rebuilds the map and re-instantiates entities, props reset for free and the work is to confirm death/respawn does not go through that path. If restart reuses live entities, add and test `resetToSpawn()`. Headless test (if a code path exists): move a prop / activate a switch, call reset → prop back at spawn x, switch off. Manual: rearrange props then restart the level → all reset; rearrange props then die and respawn → props unchanged.

## Acceptance criteria
- [ ] On level restart, every prop returns to its spawn position and every pressure switch returns to its spawn (off) state.
- [ ] On player death/respawn, props and switch states are unchanged.
- [ ] Reset behaviour verified (headless test if a reset code path exists; otherwise documented manual verification of both paths).

## Blocked by
Issues 03 and 05 (props and switches must exist to reset). Can be done after 05; boulder (04) reset falls out of the same mechanism.
