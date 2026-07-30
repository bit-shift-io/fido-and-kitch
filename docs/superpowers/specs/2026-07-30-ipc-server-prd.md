# IPC Server for OpenCode Control

## Problem Statement
As an AI agent working on the Fido and Kitch codebase, I need a way to programmatically control the running game instance — resize the window, move players, query game state — without manual interaction. This enables automated testing, visual regression checks, and interactive debugging from the agent's environment.

## Solution
Embed a lightweight TCP server in the LÖVE game that accepts simple text commands from a local client (OpenCode tools). The server polls for connections each frame in `love.update`, parses commands, executes them via a GameAPI layer, and returns text responses.

OpenCode tools (TypeScript) connect to the server, send commands, and expose them as callable functions to the agent.

## User Stories
1. As an AI agent, I want to resize the game window so I can test responsive layouts and capture screenshots at different resolutions.
2. As an AI agent, I want to move the player character by relative coordinates so I can position them for testing or screenshots.
3. As an AI agent, I want to query the current game state (player positions, window size, current map) so I can make decisions or verify test conditions.
4. As an AI agent, I want to restart the current level or return to the menu so I can reset test conditions.
5. As a developer, I want the IPC server to be opt-in via a launch flag so it doesn't run in production or normal play.
6. As a developer, I want the server to be robust against malformed input so a bad command doesn't crash the game.
7. As an AI agent, I want TypeScript tool definitions so the agent can call commands with proper type checking and documentation.

## Implementation Decisions
- **Protocol**: Plain TCP, line-delimited text commands (`CMD arg1 arg2\n`), text responses (`OK: ...\n` or `ERROR: ...\n`)
- **Port**: 8080 on 127.0.0.1 (configurable via launch arg `ipc_port=8080`)
- **Launch flag**: `ipc` enables the server (e.g., `love . ipc ipc_port=9000`)
- **Connection model**: Short-lived — connect, send one command, read response, close
- **Server polling**: Non-blocking `server:accept()` in `love.update`, `client:settimeout(0.5)` for read/write
- **Command handlers**: Pure Lua functions in `src/ipc/command_handlers.lua`, dispatched by name
- **GameAPI**: Module `src/ipc/game_api.lua` with safe operations on global game state
- **OpenCode tools**: `.opencode/tools/fido-kitch-ipc.ts` with `tool()` definitions using `@opencode-ai/plugin`

## Testing Decisions
- **Unit tests**: `tests/unit/ipc_command_handlers_test.lua` — test each handler with mocked game state
- **Integration tests**: `tests/integration/ipc_server_test.lua` — start game with `ipc` flag, connect via LuaSocket, send commands, verify responses
- **E2E tests**: `tests/e2e/ipc_control_test.lua` — real game window, agent tools drive gameplay, capture frames
- **Test tools**: Use existing `GameHarness` + `FakeInput` pattern; add `IPCClient` helper in `tests/support/ipc_client.lua`

## Out of Scope
- Persistent connections / WebSocket / long-polling
- Authentication, encryption, or multi-user access
- Commands that modify game logic beyond movement/queries (no spawning entities, changing physics)
- Remote (non-localhost) access
- Binary protocols (Protocol Buffers, MessagePack)
- Bi-directional event streaming (game → agent notifications)

## File Structure
```
src/
  ipc/
    server.lua              # TCP server, polling in love.update
    command_handlers.lua    # Command parsing, dispatch, response formatting
    game_api.lua            # Safe game operations (resize, move, query, restart)
    init.lua                # Module entry, exposes start/stop
  main.lua                  # Modified: boot IPC server if 'ipc' flag present

.opencode/
  tools/
    fido-kitch-ipc.ts       # OpenCode tool definitions

tests/
  unit/
    ipc_command_handlers_test.lua
  integration/
    ipc_server_test.lua
  support/
    ipc_client.lua          # Test helper: connect, send, receive
  e2e/
    ipc_control_test.lua
```

## Acceptance Criteria
- [ ] Game starts with `love . ipc` and listens on 127.0.0.1:8080
- [ ] `RESIZE 1024 768` resizes window and returns `OK: Resized to 1024x768`
- [ ] `MOVE_PLAYER 1 50 -20` moves player 1 by (50, -20) and returns `OK: Player 1 at (x, y)`
- [ ] `GET_STATE` returns `OK: player1=(x,y) player2=(x,y) window=(w,h) map=name`
- [ ] `RESTART_LEVEL` reloads current map and returns `OK: Level restarted`
- [ ] `MENU` returns to main menu and returns `OK: Returned to menu`
- [ ] Malformed commands return `ERROR: ...` without crashing
- [ ] Server disabled by default (no `ipc` flag = no port open)
- [ ] OpenCode tools load and expose `resize_window`, `move_player`, `get_game_state`, `restart_level`, `go_to_menu`
- [ ] Unit tests pass for all command handlers
- [ ] Integration test verifies full request/response cycle
- [ ] E2E test demonstrates agent driving game via tools

## References
- AGENTS.md: Project conventions, test infrastructure, globals pattern
- docs/adr/0003-multi-file-entity-directories.md: Multi-file module pattern
- tests/support/game_harness.lua: Test bootstrapping pattern
- tests/support/fake_input.lua: Input simulation for e2e