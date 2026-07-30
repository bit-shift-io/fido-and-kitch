# Handoff: IPC Server for OpenCode Control

## Summary
Embed a TCP server in the LÖVE game that accepts text commands from OpenCode tools. Enables programmatic control: resize window, move players, query state, restart level, return to menu. Opt-in via `ipc` launch flag.

## Implementation Order
1. **01-ipc-server-core** — TCP server module, polling in `love.update`, non-blocking accept/read/write
2. **02-ipc-command-handlers** — Command parsing, dispatch, response formatting, error handling
3. **03-ipc-game-api** — Safe game operations (resize, move player, query state, restart, menu)
4. **04-ipc-main-integration** — Boot server in `main.lua` when `ipc` flag present; pass config
5. **05-opencode-tools** — TypeScript tool definitions in `.opencode/tools/fido-kitch-ipc.ts`
6. **06-ipc-tests** — Unit, integration, and e2e tests

## Key Files
- `src/ipc/server.lua` — Server lifecycle, polling
- `src/ipc/command_handlers.lua` — Command registry, dispatch
- `src/ipc/game_api.lua` — Game operations (uses globals: `game`, `map`, `world`, `love`)
- `src/ipc/init.lua` — Module entry point
- `src/main.lua` — Integration (add `ipc` flag handling)
- `.opencode/tools/fido-kitch-ipc.ts` — OpenCode tool exports

## Gotchas
- **LuaSocket bundled with LÖVE 11.5** — `require('socket')` works, no extra deps
- **Globals are intentional** — GameAPI uses `game`, `map`, `world`, `love` directly per AGENTS.md
- **Only works in InGameState** — Handlers should check state and return ERROR in MenuState
- **Non-blocking only** — `server:settimeout(0)`, `client:settimeout(0.5)`, poll in `love.update`
- **Short-lived connections** — One command per connection simplifies server logic
- **Launch flags**: `ipc` (enable), `ipc_port=8080` (optional port override)
- **Error format**: `ERROR: <message>\n` — client parses prefix
- **Success format**: `OK: <message>\n` — client parses prefix

## Test Infrastructure
- `tests/support/ipc_client.lua` — Helper: `connect()`, `send(cmd)`, `receive()`
- Unit tests mock `game`, `map`, `world`, `love` globals
- Integration tests use `GameHarness.startGame(..., {real=false})` + real LuaSocket
- E2E tests use `GameHarness.startGame(..., {real=true})` + OpenCode tools via test runner

## References
- PRD: `.scratch/ipc-server/PRD.md`
- Decisions: `.scratch/ipc-server/DECISIONS.md`
- AGENTS.md: Conventions, test tiers, globals pattern