Status: pending

# 03: IPC GameAPI — Safe Game Operations

## What to build
Create `src/ipc/game_api.lua` with pure functions operating on globals:

```lua
local GameAPI = {}

-- Resize game window
function GameAPI.resize(w, h)
  -- love.window.setMode(w, h)
  -- Returns {ok=true, msg="Resized to WxH"} or {ok=false, err="..."}
end

-- Move player by delta
function GameAPI.movePlayer(idx, dx, dy)
  -- state = game.fsm.currentState
  -- player = state.players[idx]
  -- player:setPosition(player.x + dx, player.y + dy)
  -- Returns {ok=true, msg="Player N at X,Y"} or {ok=false, err="..."}
end

-- Get full state snapshot
function GameAPI.getState()
  -- state = game.fsm.currentState
  -- p1 = state.players[1], p2 = state.players[2]
  -- Returns {ok=true, msg="p1x=X p1y=Y p2x=X p2y=Y w=W h=H map=NAME"}
end

-- Get single player position
function GameAPI.getPlayerPos(idx)
  -- Returns {ok=true, msg="Player N at X,Y"}
end

-- Reload current level
function GameAPI.restartLevel()
  -- map = game.fsm.currentState.currentMap
  -- game:setGameState('InGameState'); game:load{map=map}
  -- Returns {ok=true, msg="Level restarted"}
end

-- Return to main menu
function GameAPI.goToMenu()
  -- game:setGameState('MenuState')
  -- Returns {ok=true, msg="Returned to menu"}
end

return GameAPI
```

All functions check `game` and `game.fsm.currentState == 'InGameState'` — return error if in MenuState.

## Files to create/modify
- `src/ipc/game_api.lua` (new)

## Test approach
- Unit: `tests/unit/ipc_game_api_test.lua`
- Mock `game`, `game.fsm.currentState`, `players`, `love.window`
- Test each function returns correct table format
- Test error cases: no game, wrong state, invalid player index

## Acceptance criteria
- [ ] `resize(w, h)` calls `love.window.setMode`, updates camera
- [ ] `movePlayer(idx, dx, dy)` modifies player position instantly
- [ ] `getState()` returns parseable string with all required fields
- [ ] `getPlayerPos(idx)` returns single player position
- [ ] `restartLevel()` reloads current map cleanly
- [ ] `goToMenu()` transitions to MenuState
- [ ] All functions return `{ok=true, msg=...}` or `{ok=false, err=...}`
- [ ] Functions fail gracefully (return error) in MenuState or no game

## Blocked by
None — can start immediately (parallel with 02)