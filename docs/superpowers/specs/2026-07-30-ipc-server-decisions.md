# IPC Server Decisions

### Q1: Transport Protocol
**Decision:** Plain TCP (raw sockets)
- **Why:** Simple, no dependencies beyond LuaSocket (included in LÖVE), matches user example
- **Implication:** Line-delimited framing needed; no built-in request/response correlation
- **Alternatives considered:** HTTP (more overhead, needs parser), WebSocket (overkill), Unix sockets (not cross-platform)

### Q2: Command Format
**Decision:** Plain text, space-delimited
- **Why:** Easy to implement, human-readable for debugging, matches user example
- **Implication:** No structured types; parsing is simple string matching
- **Alternatives considered:** JSON (more robust but verbose), MessagePack (binary, needs decoder)

### Q3: Initial Command Set
**Decision:** Basic four commands (RESIZE, MOVE_PLAYER, GET_STATE, GET_PLAYER_POS)
- **Why:** Covers window control, player control, state inspection — enough for screenshots, positioning, decision-making
- **Implication:** Extensible via CommandHandler; new commands added without protocol changes
- **Alternatives considered:** Extended set (spawn, pause, time scale) — deferred to future work

### Q4: Configuration
**Decision:** Via `conf.lua` (`conf.t.ipc_port`, `conf.t.ipc_enabled`)
- **Why:** Consistent with existing config pattern (drawphysics, debug, map=); no new config system needed
- **Implication:** Read in `src/main.lua` like other conf options; defaults to 8080/enabled
- **Alternatives considered:** CLI args (`port=8080`), env vars — less discoverable, inconsistent

### Q5: Authentication
**Decision:** None (localhost-only trust)
- **Why:** Server binds to 127.0.0.1 only; only local processes can connect; dev tool only
- **Implication:** Any local process can control the game; acceptable for dev environment
- **Alternatives considered:** Token, IP allowlist — adds complexity for no real threat model

### Q6: OpenCode Tools Location
**Decision:** `.opencode/tools/fido-kitch-ipc.ts` (project-local)
- **Why:** User requested local; name matches game branding; tools versioned with game
- **Implication:** Tools only available when working in this repo; no global install needed
- **Alternatives considered:** Global plugin — more complex distribution, version skew risk

### Q7: OpenCode Communication
**Decision:** Direct TCP from TypeScript tools to game
- **Why:** Matches game's TCP server; no intermediate proxy; low latency
- **Implication:** Tools use Node `net` module; simple request/response per command
- **Alternatives considered:** HTTP wrapper (if game used HTTP), stdio (if game child process)

### Q8: Connection Model
**Decision:** Short-lived connections (connect, send, receive, close per command)
- **Why:** Simpler server (no connection state), matches HTTP-like semantics, easier to reason about
- **Implication:** Slight overhead per command; acceptable for low-frequency dev tool use
- **Alternatives considered:** Persistent connections with request IDs — more complex, not needed yet

### Q9: GameAPI Design
**Decision:** Pure functions operating on global game state (`game`, `map`, `world`, `players`)
- **Why:** Follows existing codebase pattern (globals intentional per AGENTS.md); minimal coupling
- **Implication:** GameAPI assumes InGameState is active; commands fail gracefully in MenuState
- **Alternatives considered:** Dependency injection, event bus — over-engineering for this scope

### Q10: Error Handling
**Decision:** Text responses with `ERROR` prefix; server never crashes on bad input
- **Why:** Robustness; client can parse `ERROR` prefix; server continues accepting connections
- **Implication:** All command handlers wrapped in pcall; malformed input returns ERROR not crash
- **Alternatives considered:** Exceptions, structured error codes — unnecessary complexity

## Key Assumptions
- LuaSocket (`socket` module) is available in LÖVE 11.5 (it is, bundled)
- Game runs in InGameState when commands are sent (MenuState has no players/world)
- Single-threaded LÖVE event loop; server polling in `love.update` is sufficient
- OpenCode runs on same machine as game (localhost)

## CONTEXT.md Updates
- **IPC Server** — Embedded TCP server in the LÖVE game for external tool control
- **CommandHandler** — Parses text commands, dispatches to GameAPI
- **GameAPI** — Safe game operations exposed to IPC commands (resize, move, query)
- **OpenCode Tools** — TypeScript tool definitions in `.opencode/tools/` for agent access