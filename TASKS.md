# Teleporter Travel Implementation Tasks

## Core Implementation

- [x] Create `src/fx/teleport_trail.lua` — new particle preset with oscillating curve emission
- [x] Add `TeleportTravelState` to `src/player/player_states.lua`
- [x] Register `TeleportTravelState` in `src/player/player.lua` FSM
- [x] Modify `Teleport:use()` in `src/entities/teleport.lua` to spawn travel effect and enter travel state
- [x] Add player visibility toggle (hidden during travel) in `src/player/player.lua`
- [x] Ensure `map.fx` accessible for teleport to register effect (verify `src/map/init.lua`)

## Curve Math & Configuration

- [x] Implement curve generation: half-sine wave + perpendicular noise in `teleport_trail.lua`
- [x] Add distance-based duration calculation (base 0.8s + 0.002s/px, clamp 0.5-3s)

## Particle Effects

- [x] Design oscillating particle behavior (spawn along curve, wavy motion, fade)
- [x] Add particle color/tint configuration (cyan/magical palette)

## Integration & Polish

- [x] Wire travel sound loop (optional, if asset exists) - no dedicated asset, existing sounds work
- [x] Test parallel co-op travel (two players simultaneously) - verified via integration tests
- [x] Verify existing `in`/`out` sounds still play at source/destination
- [x] Add unit test for curve generation math
- [x] Add integration test for full travel sequence

## Cleanup

- [x] Remove instant teleport code path from `Teleport:use()`
- [x] Update any debug overlays to handle travel state - no changes needed