# IPC Server for Fido and Kitch

## Problem Statement
OpenCode agents need a way to programmatically control and inspect the Fido and Kitch game during development and testing — resizing the window, moving players, querying state — without manual interaction.

## Solution
A lightweight TCP-based IPC server embedded in the LÖVE game, listening on localhost. OpenCode tools connect via raw TCP sockets and send plain-text commands. The server is configured through LÖVE's `conf.lua` and exposes a minimal, extensible command set.

## User Stories
1. As an AI agent, I want to resize the game window so I can test responsive layouts.
2. As an AI agent, I want to move the player character so I can position it for screenshots or testing.
3. As an AI agent, I want to query the current game state (player positions, window size) so I can make decisions.
4. As a developer, I want the IPC server toggleable via config so it doesn't run in production builds.
5. As a developer, I want the server port configurable so I can run multiple instances.

## Implementation Decisions

### Modules
- `src/ipc/server.lua` — `IPCServer` class: non-blocking TCP server, polls in `love.update`
- `src/ipc/commands.lua` — `CommandHandler`: parses commands, dispatches to `GameAPI`
- `src/ipc/game_api.lua` — `GameAPI`: safe game operations (resize, move player, get state)
- `conf.lua` — add `ipc_port` and `ipc_enabled` to `conf.t`
- `src/main.lua` — instantiate server in `love.load`, poll in `love.update`
- `.opencode/tools/fido-kitch-ipc.ts` — OpenCode tool definitions

### Interfaces
**IPCServer**
```lua
IPCServer:new(port)           -- create server bound to 127.0.0.1:port
server:update(dt)             -- call each frame to accept/handle connections
server:close()                -- cleanup on quit
```

**CommandHandler**
```lua
CommandHandler:new(gameAPI)   -- inject GameAPI for command implementations
handler:handle(line) -> string -- process one command line, return response
```

**GameAPI**
```lua
api.resize(w, h)              -- love.window.setMode
api.movePlayer(idx, dx, dy)   -- modify player position
api.getState() -> string      -- formatted state snapshot
api.getPlayerPos(idx) -> string
```

### Protocol
- Transport: TCP, localhost only (127.0.0.1)
- Framing: line-delimited (newline-terminated)
- Encoding: plain text commands, plain text responses
- Commands (initial):
  - `RESIZE <w> <h>`
  - `MOVE_PLAYER <1|2> <dx> <dy>`
  - `GET_STATE`
  - `GET_PLAYER_POS <1|2>`
- Responses:
  - `OK <message>`
  - `STATE key=val key=val ...`
  - `ERROR <message>`

### Architecture
```
OpenCode Tool (TypeScript)
    │ TCP connect to 127.0.0.1:8080
    ▼
LÖVE Game (src/main.lua)
    │ love.update(dt)
    ├─► IPCServer:update(dt)  ──► accept client
    │                              │
    │                              ▼
    │                         CommandHandler:handle(line)
    │                              │
    │                              ▼
    │                         GameAPI.resize / movePlayer / getState
    │                              │
    │                              ▼
    │                         response string
    │                              │
    └──────────────────────────────┘ (sent back to client)
```

## Testing Decisions
- Unit: `tests/unit/ipc_commands_test.lua` — test command parsing, GameAPI functions with mocked game state
- Integration: `tests/integration/ipc_test.lua` — start game via GameHarness, connect via LuaSocket, send commands, verify responses
- E2E: manual verification via OpenCode tools

## Out of Scope
- Authentication/authorization (localhost-only trust model)
- WebSocket or HTTP transport
- Bidirectional async notifications (push from game to client)
- Commands beyond the initial four
- Persistent connections (each command is a new connection in MVP)

## File Structure
```
src/
  ipc/
    server.lua      -- TCP server
    commands.lua    -- command parsing + dispatch
    game_api.lua    -- game operations exposed to commands
.opencode/
  tools/
    fido-kitch-ipc.ts   -- OpenCode tool definitions
tests/
  unit/
    ipc_commands_test.lua
  integration/
    ipc_test.lua
```

## Acceptance Criteria
- [ ] Game starts with IPC server listening on configured port (default 8080)
- [ ] `RESIZE 1024 768` resizes the game window
- [ ] `MOVE_PLAYER 1 50 0` moves player 1 right by 50 pixels
- [ ] `GET_STATE` returns formatted state with both player positions and window size
- [ ] `GET_PLAYER_POS 2` returns player 2 position
- [ ] OpenCode tools `resize_window`, `move_player`, `get_game_state` work end-to-end
- [ ] Server can be disabled via `conf.t.ipc_enabled = false`
- [ ] Port configurable via `conf.t.ipc_port`

## References
- Example code provided by user (TCP server in main.lua, OpenCode tools in TypeScript)
- AGENTS.md: test infrastructure, GameHarness for integration tests
- LÖVE 11.5 API: `love.window.setMode`, `socket` module