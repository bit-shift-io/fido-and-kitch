Status: pending

# 02: IPC Command Handlers — Parsing, Dispatch, Response Format

## What to build
Create `src/ipc/command_handlers.lua` with:
- `CommandHandler:new(gameAPI)` — stores GameAPI reference
- `handler:register(name, fn)` — registers command handler
- `handler:handle(line)` — parses, dispatches, returns response string

Built-in commands (delegate to GameAPI):
| Command | Args | GameAPI call |
|---------|------|--------------|
| `RESIZE` | `<w> <h>` | `gameAPI.resize(w, h)` |
| `MOVE_PLAYER` | `<idx> <dx> <dy>` | `gameAPI.movePlayer(idx, dx, dy)` |
| `GET_STATE` | — | `gameAPI.getState()` |
| `GET_PLAYER_POS` | `<idx>` | `gameAPI.getPlayerPos(idx)` |
| `RESTART_LEVEL` | — | `gameAPI.restartLevel()` |
| `MENU` | — | `gameAPI.goToMenu()` |

Response format:
- Success: `OK: <message>\n`
- Error: `ERROR: <message>\n`
- Unknown command: `ERROR: Unknown command: <cmd>\n`
- Bad args: `ERROR: Invalid arguments for <cmd>\n`

## Files to create/modify
- `src/ipc/command_handlers.lua` (new)

## Test approach
- Unit: `tests/unit/ipc_command_handlers_test.lua`
- Mock GameAPI returning known responses
- Test each command: valid args → OK, invalid args → ERROR, unknown → ERROR
- Test response format always ends with newline

## Acceptance criteria
- [ ] Parses space-delimited command + args
- [ ] Dispatches to registered handlers
- [ ] Returns `OK: ...\n` on success
- [ ] Returns `ERROR: ...\n` on handler error or bad args
- [ ] Unknown command returns error
- [ ] All 6 commands registered and functional
- [ ] Handler errors caught (pcall), return ERROR not crash

## Blocked by
03-ipc-game-api (GameAPI interface)