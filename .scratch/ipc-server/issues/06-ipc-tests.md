Status: pending

# 06: IPC Tests — Unit, Integration, E2E

## What to build

### Unit: `tests/unit/ipc_command_handlers_test.lua`
- Mock GameAPI with stub functions returning known results
- Test each command handler:
  - Valid args → returns `OK: ...`
  - Invalid args (wrong count, non-numbers) → returns `ERROR: ...`
  - Unknown command → `ERROR: Unknown command`
  - Handler throws → caught, returns `ERROR: ...`
- Test response format always ends with newline

### Unit: `tests/unit/ipc_game_api_test.lua`
- Mock `game`, `game.fsm.currentState`, `players`, `love.window`, `love.graphics`
- Test each GameAPI function:
  - Returns `{ok=true, msg=...}` on success
  - Returns `{ok=false, err=...}` on failure (no game, wrong state, bad index)
  - `resize` calls `love.window.setMode`
  - `movePlayer` updates player position
  - `restartLevel` calls `game:setGameState` + `game:load`
  - `goToMenu` calls `game:setGameState('MenuState')`

### Unit: `tests/unit/ipc_server_test.lua`
- Mock `socket.tcp()`, verify bind/listen/settimeout
- Test `server:update(dt)` accepts connection, reads line, calls handler, writes response

### Integration: `tests/integration/ipc_server_test.lua`
- Use `GameHarness.startGame('res/map/sandbox.tmx', {real=false})`
- Start game with `ipc` flag (modify harness or test setup)
- Connect via real `socket.tcp()` to localhost:8080
- Send each command, verify response format and game state change
- Test error cases

### Support: `tests/support/ipc_client.lua`
```lua
local IPCClient = {}
function IPCClient.connect(port) ... end
function IPCClient:send(cmd) ... end
function IPCClient:receive() ... end
function IPCClient:close() ... end
return IPCClient
```

### E2E: `tests/e2e/ipc_control_test.lua`
- `GameHarness.startGame(..., {real=true})`
- Use OpenCode tools via test runner (or simulate tool calls)
- Verify window resize, player movement, state query work visually
- Capture frames before/after commands

## Files to create/modify
- `tests/unit/ipc_command_handlers_test.lua`
- `tests/unit/ipc_game_api_test.lua`
- `tests/unit/ipc_server_test.lua`
- `tests/integration/ipc_server_test.lua`
- `tests/support/ipc_client.lua`
- `tests/e2e/ipc_control_test.lua`
- `tests/unit/run.lua` (add new test files)
- `tests/integration/run.lua` (add new test files)
- `tests/e2e/run.lua` (add new test files)

## Test approach
- Run unit: `./test-unit.sh tests/unit/ipc_*_test.lua`
- Run integration: `./test-integration.sh tests/integration/ipc_server_test.lua`
- Run E2E: `./test-e2e.sh tests/e2e/ipc_control_test.lua`
- All: `./test-all.sh`

## Acceptance criteria
- [ ] All unit tests pass
- [ ] Integration test connects to real server, sends commands, verifies responses
- [ ] E2E test runs with real window, tools drive game
- [ ] Tests included in `./test-all.sh` output
- [ ] No flaky tests (deterministic)

## Blocked by
01-05 complete