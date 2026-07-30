Status: pending

# 01: IPC Server Core — Non-blocking TCP Server

## What to build
Create `src/ipc/server.lua` with an `IPCServer` class that:
- Binds to 127.0.0.1:port using LuaSocket
- Sets non-blocking mode (`settimeout(0)`)
- Exposes `update(dt)` to poll for connections in `love.update`
- Accepts clients, reads one newline-terminated line, invokes a callback with the command string, sends the response + newline, closes client
- Handles socket errors gracefully (logs, continues)
- Exposes `close()` for cleanup in `love.quit`

## Files to create/modify
- `src/ipc/server.lua` (new)
- `src/ipc/init.lua` (new, module entry: `start(port)`, `update(dt)`, `stop()`)

## Test approach
- Unit: mock `socket.tcp()`, verify bind/listen/settimeout calls
- Integration: start server, connect via `socket.tcp()`, send command, verify callback invoked, response received
- Support: `tests/support/ipc_client.lua` — `connect(port)`, `send(cmd)`, `receive()`, `close()`

## Acceptance criteria
- [ ] `IPCServer:new(8080)` creates server socket bound to localhost:8080
- [ ] `server:update(dt)` accepts connections without blocking game loop
- [ ] Client can connect, send `TEST\n`, callback receives `"TEST"`, client receives response
- [ ] Multiple sequential commands work (new connection each)
- [ ] Malformed/no-newline data handled (buffer until newline or timeout)
- [ ] `server:close()` cleans up socket
- [ ] Errors in callback don't crash server (pcall wrapper)

## Blocked by
None — can start immediately