# Cleanup Tasks from Audit

## High Priority

- [x] Delete `src/emitters/ribbon_emitter.lua` (unused, superseded by mesh_ribbon_emitter.lua)
- [x] Replace debug `print()` calls in `src/components/speed_streak.lua:30,35` with `Log.debug()`

## Medium Priority

- [x] Create `src/player/states/` directory
- [x] Extract `LadderState` from `src/player/player_states.lua` to `src/player/states/ladder_state.lua`
- [x] Extract `WalkIdleState` from `src/player/player_states.lua` to `src/player/states/walk_idle_state.lua`
- [x] Extract `FallState` from `src/player/player_states.lua` to `src/player/states/fall_state.lua`
- [x] Extract `DeadState` from `src/player/player_states.lua` to `src/player/states/dead_state.lua`
- [x] Extract `WrappedState` from `src/player/player_states.lua` to `src/player/states/wrapped_state.lua`
- [x] Extract `TeleportTravelState` from `src/player/player_states.lua` to `src/player/states/teleport_travel_state.lua`
- [x] Extract `JumpTravelState` from `src/player/player_states.lua` to `src/player/states/jump_travel_state.lua`
- [x] Update `src/player/player_states.lua` to require and re-export all state classes
- [x] Update `src/player/player.lua` to use new state module paths (no change needed - already uses `PlayerStates` table)

- [x] Split `src/ipc/game_api.lua` into domain handlers:
  - [x] Create `src/ipc/handlers/player.lua` (getPlayerPos, movePlayer, injectInput, holdKey)
  - [x] Create `src/ipc/handlers/map.lua` (loadMap, getTileGrid, restartLevel, goToMenu)
  - [x] Create `src/ipc/handlers/entity.lua` (getEntities, spawnEntity, getState)
  - [x] Create `src/ipc/handlers/debug.lua` (toggleDebugDraw, takeScreenshot, resize, stepFrames, toggleCamera)
  - [x] Update `src/ipc/game_api.lua` to delegate to handlers
  - [x] Update `src/ipc/command_handlers.lua` to use new handler structure (no change needed - uses gameAPI delegation)

## Low Priority

- [ ] Move inline TODO from `src/entities/blocker.lua:130` to `TODO.md`
- [ ] Add missing sound assets (8 files listed in TODO.md) or remove references
- [ ] Add `Tint = require('src.components.tint')` to `src/main.lua` globals
- [ ] Consider extracting dialogue rendering from `src/entities/story.lua` into a component

## Done

- [x] Audit complete - findings documented in `AUDIT.md`
- [x] High priority cleanup tasks completed
- [x] Medium priority cleanup tasks completed (player states extraction, IPC handler split)