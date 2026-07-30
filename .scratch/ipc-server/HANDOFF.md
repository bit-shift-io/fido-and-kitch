# IPC Server Handoff

## Summary
Embed a lightweight TCP server in Fido and Kitch that allows OpenCode agents to control the game programmatically. Commands: resize window, move players, query state, restart level, return to menu. Configured via `conf.lua`, enabled with `ipc` launch flag. OpenCode tools in `.opencode/tools/fido-kitch-ipc.ts`.

## Implementation Order

1. **`src/ipc/commands.lua`** — CommandHandler + GameAPI (no LÖVE deps except in GameAPI)
2. **`src/ipc/server.lua`** — IPCServer class (LuaSocket, non-blocking)
3. **`conf.lua`** — Add `ipc_port`, `ipc_enabled` to `conf.t`
4. **`src/main.lua`** — Parse `ipc` flag, instantiate server, poll in `love.update`
5. **`.opencode/tools/fido-kitch-ipc.ts`** — OpenCode tool definitions
6. **Tests** — Unit, integration, E2E

## Key Files

| File | Purpose |
|------|---------|
| `src/ipc/commands.lua` | Command parsing, dispatch, GameAPI |
| `src/ipc/server.lua` | TCP server, client handling |
| `conf.lua` | Config options |
| `src/main.lua` | Integration |
| `.opencode/tools/fido-kitch-ipc.ts` | Agent tools |

## Gotchas

- **LuaSocket**: LÖVE includes `socket` module (`require('socket')` works). No luarocks needed.
- **Non-blocking**: `server:settimeout(0)`, `client:settimeout(0.5)` for read
- **Global state**: GameAPI uses `game`, `map`, `world`, `love` globals from `src/main.lua`
- **State guard**: GameAPI functions must check `game.fsm.currentState == 'InGameState'` — return ERROR otherwise
- **Line framing**: Each command = one line. Client closes after response.
- **Port config**: Default 8080, override via `conf.t.ipc_port` or launch flag `port=XXXX`

## Testing

- `tests/unit/ipc_command_handlers_test.lua` — mock GameAPI, test handlers
- `tests/integration/ipc_server_test.lua` — GameHarness + LuaSocket client
- `tests/e2e/ipc_control_test.lua` — real game, real window, OpenCode tools

## References

- PRD: `.scratch/ipc-server/PRD.md`
- Decisions: `.scratch/ipc-server/DECISIONS.md`
- Issues: `.scratch/ipc-server/issues/01-*.md` through `06-*.md`
- ADR: none (decisions low-stakes, logged in DECISIONS.md)

## Commands to Implement

| Command | Args | GameAPI | Response |
|---------|------|---------|----------|
| `RESIZE` | `w h` | `resize(w, h)` | `OK: Resized to WxH` |
| `MOVE_PLAYER` | `idx dx dy` | `movePlayer(idx, dx, dy)` | `OK: Player N at X,Y` |
| `GET_STATE` | — | `getState()` | `STATE p1x=X p1y=Y p2x=X p2y=Y w=W h=H` |
| `GET_PLAYER_POS` | `idx` | `getPlayerPos(idx)` | `OK: Player N at X,Y` |
| `RESTART_LEVEL` | — | `restartLevel()` | `OK: Level restarted` |
| `MENU` | — | `goToMenu()` | `OK: Returned to menu` |

## Start Implementation

```bash
# In a new chat:
/implement-feature .scratch/ipc-server/
```