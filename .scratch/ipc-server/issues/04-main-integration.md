Status: pending

# 04: Main Integration — Launch Flags and Server Lifecycle

## What to build
Modify `src/main.lua` and `conf.lua`:

**conf.lua** — add to `conf.t`:
```lua
conf.t.ipc_port = 8080
conf.t.ipc_enabled = false
```

**src/main.lua** — in `setupConf(args)`:
- Detect `ipc` flag: `conf.ipc = tbl.includes(conf.args, 'ipc')`
- Detect `ipc_port=<num>` flag: parse and set `conf.ipc_port`

In `love.load(args)`:
```lua
if conf.ipc then
  ipc = require('src.ipc.init')
  ipc.start(conf.ipc_port)
end
```

In `love.update(dt)`:
```lua
if ipc then
  ipc.update(dt)
end
game:update(dt)
```

In `love.quit()`:
```lua
if ipc then
  ipc.stop()
end
```

**src/ipc/init.lua** — module entry:
```lua
local server = require('src.ipc.server')
local commands = require('src.ipc.command_handlers')
local game_api = require('src.ipc.game_api')

local handler = commands.new(game_api)
local ipc_server = server.new(handler)

return {
  start = function(port) ipc_server:start(port) end,
  update = function(dt) ipc_server:update(dt) end,
  stop = function() ipc_server:close() end
}
```

## Files to create/modify
- `conf.lua` (modify)
- `src/main.lua` (modify)
- `src/ipc/init.lua` (new)

## Test approach
- Integration: `tests/integration/ipc_server_test.lua`
- Start game with `ipc` flag via GameHarness
- Connect via LuaSocket, send commands, verify responses
- Verify server doesn't start without `ipc` flag

## Acceptance criteria
- [ ] `love .` — no server, port 8080 closed
- [ ] `love . ipc` — server listening on 127.0.0.1:8080
- [ ] `love . ipc ipc_port=9000` — server on port 9000
- [ ] `ipc.update(dt)` called each frame, non-blocking
- [ ] `ipc.stop()` called on quit, port released
- [ ] Commands work end-to-end through full stack

## Blocked by
01-ipc-server-core, 02-ipc-command-handlers, 03-ipc-game-api