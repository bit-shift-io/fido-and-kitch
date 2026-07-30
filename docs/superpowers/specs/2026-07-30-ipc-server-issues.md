# Issues: IPC Server for OpenCode Control

## 01-ipc-server-core
**Title:** Implement non-blocking TCP server module
**Type:** Feature
**Priority:** High
**Labels:** ipc, core

**Description:**
Create `src/ipc/server.lua` with an `IPCServer` class that:
- Binds to 127.0.0.1:port (default 8080) using LuaSocket
- Sets non-blocking mode (`settimeout(0)`)
- Exposes `update(dt)` method to poll for connections in `love.update`
- Accepts clients, reads one line (newline-terminated), processes via callback, sends response, closes client
- Handles socket errors gracefully (log, continue)
- Exposes `close()` for cleanup in `love.quit`

**Acceptance Criteria:**
- [ ] `IPCServer:new(port)` creates server socket
- [ ] `server:update(dt)` accepts connections without blocking
- [ ] Reads complete line from client (handles partial reads)
- [ ] Calls registered handler with command string, gets response string
- [ ] Sends response + newline, closes client socket
- [ ] `server:close()` cleans up socket
- [ ] Errors in handler don't crash server (pcall)

**Dependencies:** None

---

## 02-ipc-command-handlers
**Title:** Command parsing, dispatch, and response formatting
**Type:** Feature
**Priority:** High
**Labels:** ipc, commands

**Description:**
Create `src/ipc/command_handlers.lua` with:
- `CommandHandler:new(gameAPI)` — stores reference to GameAPI
- `handler:register(name, fn)` — registers command handler function
- `handler:handle(line)` — parses line, dispatches, returns response string
- Built-in commands (delegated to GameAPI):
  - `RESIZE <w> <h>` → `gameAPI.resize(w, h)`
  - `MOVE_PLAYER <idx> <dx> <dy>` → `gameAPI.movePlayer(idx, dx, dy)`
  - `GET_STATE` → `gameAPI.getState()`
  - `GET_PLAYER_POS <idx>` → `gameAPI.getPlayerPos(idx)`
  - `RESTART_LEVEL` → `gameAPI.restartLevel()`
  - `MENU` → `gameAPI.goToMenu()`
- Response format: `OK: <msg>\n` or `ERROR: <msg>\n`
- Unknown command → `ERROR: Unknown command: <cmd>\n`
- Malformed args → `ERROR: Invalid arguments for <cmd>\n`

**Acceptance Criteria:**
- [ ] Parses space-delimited command + args
- [ ] Dispatches to registered handlers
- [ ] Returns `OK: ...` on success
- [ ] Returns `ERROR: ...` on handler error or bad args
- [ ] Unknown command returns error
- [ ] All 6 commands registered and functional

**Dependencies:** 03-ipc-game-api (GameAPI interface)

---

## 03-ipc-game-api
**Title:** Game operations exposed to IPC commands
**Type:** Feature
**Priority:** High
**Labels:** ipc, game-api

**Description:**
Create `src/ipc/game_api.lua` with pure functions operating on globals:
- `resize(w, h)` — calls `love.window.setMode(w, h)`, returns success msg
- `movePlayer(idx, dx, dy)` — finds player in `game.fsm.currentState.players[idx]`, adds dx/dy to position via `player:setPosition()` or direct `x/y`; returns new position
- `getState()` — returns formatted string: `player1=(x,y) player2=(x,y) window=(w,h) map=<name>`
- `getPlayerPos(idx)` — returns `x=<x> y=<y>` for player idx
- `restartLevel()` — gets current map from `game.fsm.currentState.currentMap`, calls `game:setGameState('InGameState')` + `game:load({map=currentMap})`
- `goToMenu()` — calls `game:setGameState('MenuState')`
- All functions check `game` and `game.fsm.currentState` exist; return error if in MenuState

**Acceptance Criteria:**
- [ ] `resize` works and updates camera via `game:resize` callback
- [ ] `movePlayer` moves player instantly (not via input simulation)
- [ ] `getState` returns parseable format with all required fields
- [ ] `restartLevel` reloads current map cleanly
- [ ] `goToMenu` transitions to MenuState
- [ ] All functions return `{ok=true, msg=...}` or `{ok=false, err=...}` for CommandHandler

**Dependencies:** None (uses existing globals)

---

## 04-ipc-main-integration
**Title:** Wire IPC server into main.lua with launch flags
**Type:** Feature
**Priority:** High
**Labels:** ipc, integration

**Description:**
Modify `src/main.lua`:
- Detect `ipc` flag in `conf.args` (like `debug`, `drawphysics`)
- Detect `ipc_port=<num>` flag, default 8080
- If `ipc` flag present:
  - Require `src.ipc.init` (module entry)
  - Call `ipc.start(port)` in `love.load` (after `game = Game()`)
  - Call `ipc.update(dt)` in `love.update` (before `game:update(dt)`)
  - Call `ipc.stop()` in `love.quit`
- Add `ipc` to `conf.t` in `conf.lua` with defaults

**Acceptance Criteria:**
- [ ] `love .` — no IPC server started
- [ ] `love . ipc` — server starts on port 8080
- [ ] `love . ipc ipc_port=9000` — server starts on port 9000
- [ ] Server polls in `love.update` without blocking
- [ ] Clean shutdown on quit
- [ ] No errors when IPC disabled

**Dependencies:** 01-ipc-server-core, 02-ipc-command-handlers, 03-ipc-game-api

---

## 05-opencode-tools
**Title:** OpenCode tool definitions for IPC commands
**Type:** Feature
**Priority:** High
**Labels:** ipc, opencode, tools

**Description:**
Create `.opencode/tools/fido-kitch-ipc.ts` with tools:
- `resize_window` — `{width: number, height: number}` → sends `RESIZE`
- `move_player` — `{player: 1|2, dx: number, dy: number}` → sends `MOVE_PLAYER`
- `get_game_state` — `{}` → sends `GET_STATE`, parses response to typed object
- `get_player_pos` — `{player: 1|2}` → sends `GET_PLAYER_POS`, parses response
- `restart_level` — `{}` → sends `RESTART_LEVEL`
- `go_to_menu` — `{}` → sends `MENU`

Each tool uses `@opencode-ai/plugin` `tool()` factory, connects via `net` module to 127.0.0.1:8080 (configurable via env `FIDO_KITCH_IPC_PORT`), sends command + newline, reads response line, returns parsed result or throws on ERROR.

**Acceptance Criteria:**
- [ ] All 6 tools defined and exported
- [ ] Tools connect to configurable port (env var with default 8080)
- [ ] Tools handle connection errors gracefully
- [ ] Response parsing returns typed results (not raw strings)
- [ ] Tools usable by agent immediately after `opencode` loads

**Dependencies:** 04-ipc-main-integration (server must exist)

---

## 06-ipc-tests
**Title:** Test coverage for IPC server
**Type:** Feature
**Priority:** Medium
**Labels:** ipc, test

**Description:**
- **Unit** `tests/unit/ipc_command_handlers_test.lua`: Mock GameAPI, test each command handler returns correct response format, error cases
- **Integration** `tests/integration/ipc_server_test.lua`: Use `GameHarness.startGame('res/map/sandbox.tmx', {real=false})`, connect via LuaSocket, send commands, verify responses
- **Support** `tests/support/ipc_client.lua`: `IPCClient.connect(port)`, `send(cmd)`, `receive()`, `close()`
- **E2E** `tests/e2e/ipc_control_test.lua`: Real game window (`{real=true}`), use OpenCode tools via test runner, verify window resize, player movement, state query

**Acceptance Criteria:**
- [ ] Unit tests pass (`./test-unit.sh tests/unit/ipc_command_handlers_test.lua`)
- [ ] Integration tests pass (`./test-integration.sh tests/integration/ipc_server_test.lua`)
- [ ] E2E test runs and captures frames (`./test-e2e.sh tests/e2e/ipc_control_test.lua`)
- [ ] All test tiers included in `./test-all.sh`

**Dependencies:** 01-05 complete

---

## Notes
- Issues ordered by dependency (01→02→03→04→05→06)
- Can parallelize 02+03, then 04, then 05+06
- Each issue = one PR/commit set
- Update `tests/README.md` if new test patterns added