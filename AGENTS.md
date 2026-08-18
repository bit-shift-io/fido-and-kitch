# Agent Context for Fido and Kitch

Fido and Kitch is a LÖVE 2D (12.0) puzzle-platformer with local couch co-op: two players (dog and cat) solve bite-sized levels built in Tiled. Written in LuaJIT-style Lua. `CLAUDE.md` and `GEMINI.md` point here; `CONTEXT.md` is a glossary of domain terms (camera, framing targets, etc.); design decisions live in `docs/adr/`.

## Commands

```sh
./setup.sh            # install LÖVE + fetch Lua deps into lib/ (lib/ may be empty in a fresh clone)
./run.sh               # run the game (prefers bin/love.AppImage, falls back to `love` on PATH)
./test-unit.sh          # fast headless Lua tests (no LÖVE window, no map loading); pass a file to run just one
./test-integration.sh   # headless real-stack tests (maps loaded through a love.* mock)
./test-e2e.sh           # headed tests: real LÖVE, real window, real rendering, frame capture
./test-all.sh           # runs all three tiers, reports each tier's outcome, skips e2e in CI
./build.sh              # interactive makelove packaging (targets: win32, win64, macos, appimage)
```

Useful run flags (parsed in `src/main.lua` / `Game:init`):

```sh
love . debug drawphysics map=sandbox
```

- `debug` — starts lldebugger, sets `conf.debug`
- `drawphysics` — physics debug drawing
- `profile` — prints a load profile in `InGameState:load`
- `map=<file>` — skips the menu, loads `res/map/<file>`
- `F12` — screenshot
- `F1` — physics debug overlay (hitboxes, sensors, kill zones, safe positions, camera bounds, NPC paths); toggles `conf.drawphysics`
- `F2` — particle-system outlines (emitter emit-box + per-particle quads); toggles `conf.draw_particles`
- `F3` — sprite outlines (each entity's rendered art box); toggles `conf.draw_sprite_outlines`

## Layout

- `main.lua` / `conf.lua` — entrypoint (requires `src.main`) and LÖVE config
- `src/main.lua` — bootstraps globals (`conf`, `utils`, `Vector`, `Class`, `Camera`, `Tween`, `Slab`, `World`, `Entity`, `Map`, `Player`, `Game`, …) and LÖVE callbacks
- `src/game.lua` — top-level game object
- `src/states/` — game state FSM modules (`menu_state.lua`, `ingame_state.lua`, `game_over_state.lua`)
- `src/map.lua` — thin wrapper delegating to `src/map/init.lua`
- `src/map/` — map system modules:
  - `init.lua` — Map class, STI/TMX loading, public API, background map
  - `entity_factory.lua` — Tiled object layer → runtime entity instantiation + ladder annotation
  - `ladder_merger.lua` — pure per-rung → merged ladder rect grouping (by column + vertical contiguity + identical props)
  - `collision_builder.lua` — static bodies, map boundaries
  - `parallax_renderer.lua` — background image layers, parallax math, screen-space draw
  - `tmx.lua`, `tmx_template.lua`, `tmx_xml.lua`, `external_tileset.lua` — TMX parsing
- `src/camera.lua` — shared auto-zoom camera framing all players
- `src/diorama.lua` — **Diorama**: when the camera's view extends past the map bounds, fills the out-of-world screen strips with a generic tiling void (`res/img/diorama/diorama_void.png`) and draws a decorative world-space frame (edge tiles + 4 corner ornaments + deterministic interstitial ornaments) sitting on a frame line pushed `frame.outset` out from the world boundary (so the frame hugs the border instead of overlapping the playfield). One global stateless config `Diorama.config` (no seeds): `void.img`; `frame.tileSize` (tiling band width, default 32), `frame.outset` (default 14), `frame.tiles.{top,bottom,left,right}` (top/bottom share one horizontal tile texture, left/right share one vertical), `frame.ornaments.corners.{topLeft,topRight,bottomLeft,bottomRight}` (corners are ornaments — same draw stage, each with its own `scale`), `frame.ornaments.{top,bottom,left,right}` = flat lists of `{img, pos, scale?}` (discrete ornaments, one list entry per piece — never tiled — each placed at its `pos`, a 0..1 percentage along the edge: 0 = left/top corner, 1 = right/bottom corner; optional `scale` is an `{x, y}` pair, default `{x=1, y=1}` — negative values flip along that axis, arbitrary values stretch). Tiling model: each edge texture's **short dimension maps 1:1 to `tileSize`** (the band width) and its **long dimension runs along the edge, repeating until the whole edge is tiled** (`computeTileCount` = `ceil(edgeLen/tileLen)`, overruns covered by the corner ornament); textures are authored landscape for top/bottom edges and portrait for left/right. Draw order in `InGameState:draw`: void tiling → parallax bg → world tiles → **frame (tiles, then corners, then ornaments)** → entities. Geometry contract: the projected world rect is `{x=floor(tx), y=floor(ty), w=mapW*sx, h=mapH*sy}` (floored origin must match `ParallaxRenderer:drawMainLayers`' translate); use the same floored origin for the void strips, the parallax scissor, and the frame transform or a hairline strip shows at fractional `tx/ty`. Pure geometry (worldScreenRect/computeVoidRects/computeTileCount/computeFrame) exposed via `Diorama._internal` for headless unit tests; draw methods no-op without `love.graphics`, and missing art is skipped with a memoized `Log.warn` so the game runs before assets land. e2e pre-seeds `AssetManager.textures[path]` with placeholder images to verify geometry
- `src/entity.lua`, `src/components/` — base entity with component lifecycle; components like `Collider`, `Sprite`, `StateMachine`, `Inventory`, `Pickup`, `Usable`, `UsableSparkle` (gentle "glow" sparkles emitted while a player is near a usable item; auto-attached by `Usable:onAttach`)
- `src/entities/` — map entity implementations; Tiled object `type` must match a filename here (`key` → `src/entities/key.lua`)
- `src/entities/ladder.lua` — ladders are authored as per-rung template tile objects (32px gid tiles, bottom-anchored: object `y` is the rung's BOTTOM edge, top = y − height). `entity_factory`'s `annotateLadders` merges rungs by column + vertical contiguity + identical properties into one logical ladder; the lowest rung is the lead and builds the merged collider/sprite stack, upper rungs are thin aliases. `Ladder:switch` toggles on/off (hide + disable climb vs restore, keeping grown size). All ladder geometry is bottom-anchored — `resizeTileHeight`/`grow` move the top edge only
- `src/entities/mover_platform.lua` — rideable platform travelling a `path`-referenced polyline at constant `speed` (px/s, default 100), `endBehavior='pingpong'|'loop'` (default pingpong), `pause` seconds at every path point (incl. both ends). STI re-anchors polyline points to **absolute** on load — the resolver must NOT re-add the object origin (jump_pad depends on the same contract). The drawn polyline is the **deck line**: the platform hangs half its height BELOW the waypoints (top riding surface rides exactly on the line), so authors draw paths along floor heights, never doing half-height math. One-way top-only collision via per-collider `colFilterFn` (players under the deck + `LAND_TOL` cross/jump-through; everyone else falls through to defaults). Rider carry = platform-own `world:queryOverlap` probe (feet within `RIDER_TOL` of the deck top), nudged by the exact per-frame delta; players only, boxes/NPCs collide solidly. `Switchable` stop-in-place / resume. Pure path math exposed via `MoverPlatform._internal` (`polylineWaypoints`, `applyDeckOffset`, `buildLegs`, `newStepper`, `advance`, `RIDER_TOL`, `LAND_TOL`).
- `src/entities/replicator.lua` — a ceiling- or floor-mounted gate machine with a `Switchable` linked to a toggle `Switch`. **Switch-pulse contract**: every switch press spawns once until `maxSpawns` (default 1, no refunds) is spent — the switch's on/off state is irrelevant (the handler ignores `enabled`). No timer. The emit point comes from Tiled `rotation` (0 = ceiling → one tile below `object.y`; 180 = floor → `object.y - 2*height`) unless an optional object `polyline` overrides it (mock `x`/`y` = `polyline[1]`, which IS absolute post-STI — do not re-add the object origin). Spawn reuses `map:loadEntity(spawnType, layer, mockObject)` with a top-anchored mock object (no `gid`, `properties = {}`) sized to the replicator's authored dims, so the prop materialises as an instant solid drop. `_internal` seam exposes `DEFAULT_SPAWN_TYPE`, `DEFAULT_MAX_SPAWNS`, `emitY(object)`.
- `src/player/` — player entity and subsystems:
  - `player.lua` — bootstrap: components, signals, animation FSM, movement FSM
  - `player_sensors.lua` — `queryKillZone`, `queryLadder`, `queryLadderBelow`, `queryOnGround`, `queryFullySupported`
  - `player_movement.lua` — horizontal movement math, jump/climb velocity, bounce, edge cases
  - `player_states.lua` — FSM states (WalkIdle, Fall, Ladder, Dead, Wrapped)
  - `safe_position.lua` — safe position tracking
  - `ground_support.lua` — `isFullySupported`
  - `lives.lua` — lives management
- `src/physics/bump/` — the physics backend (bump.lua), behind `Collider`/`World`. A Box2D/love backend was removed for implementing too little of the Collider contract to actually run the game; re-add it as a real, fully-implemented backend if ever needed, not a partial one
- `src/fx/` — one-shot particle presets (`coin_pickup.lua`, `dust_burst.lua`, `spark_trail.lua` built on `src/fx/base.lua`); `src/particles.lua` is the low-level emitter engine behind them
- `src/ui/` — Slab menu UI, map list, lives HUD, debug overlay, sprite-outline overlay
- `src/utils/` — utility modules:
  - `asset_manager.lua` — texture caching (`getImage`, `clear`, `getTextureCount`)
  - `event_bus.lua` — global event bus (`emit`, `on`, `off`, `clear`)
  - `settings.lua` — player preferences persisted as `settings.json` in the save dir (currently `lastMap`, the map the menu reopens on); best-effort, never fatal
  - `json.lua` — small JSON encode/decode behind `settings.lua`
- `src/input/` — input management:
  - `input_manager.lua` — keyboard/joystick handling, persistent config
  - `input_config.lua` — persistent key bindings (save/load to `love.filesystem`)
  - `action_map.lua` — action to key/button mappings
- `res/map/` — Tiled `.tmx` sources loaded directly (see `res/map/ladder.tmx`); the game runs `.tmx` via `src/map/tmx.lua`, tilesets must be embedded
- `tests/` — three test tiers (unit, integration, e2e) plus shared support/fixtures (see `tests/README.md`)

## Conventions

- **Globals are intentional.** Core classes and `world`/`map`/`camera` are globals set up in `src/main.lua`. Follow the pattern; don't refactor dependency management unless asked.
- **Classes** use hump: `local Thing = Class{}` … `function Thing:init(props)`; entities use `Class{__includes = Entity}` and call `Entity.init(self)` in `init`.
- **Components** attach via `self:addComponent(Component{...})`; `Entity:update/draw` forward to components. Use `queueRemove()`/`queueDestroy()` instead of removing entities mid-iteration.
- **State machines** (`src/components/state_machine.lua`) accept `states` (instances) or `stateClasses` (instantiated and wired to `entity`); unknown method calls proxy to `currentState`.
- **New map entity** = new `src/entities/<type>.lua` + Tiled object with matching `type`. `Map.typeIgnores = {'', 'spawn'}` skips those types. Tiled object properties may contain executable Lua event snippets (`object:exec`) — treat map code as trusted, don't feed it user input. An entity that needs more than one file gets a directory named after the entity type instead (`src/entities/<type>/<type>.lua` + siblings, real filenames kept, no `init.lua`) — stay flat until you need a second file. See ADR 0003 (`docs/adr/0003-multi-file-entity-directories.md`). A pure-logic `_support.lua` split purely to dodge "can't construct headless" is no longer needed — `tests/support/headless_bootstrap.lua` (see ADR 0005) makes a real entity constructible in `tests/unit/`; `src/entities/drawbridge.lua` and `src/entities/pressure_switch.lua` are the examples, each with its own decision helpers kept private and exposed to its test file only via an `_internal` white-box seam (`Drawbridge._internal`, `PressureSwitch._internal`).
- **Player entity** is split across `src/player/player.lua` (bootstrap), `src/player/player_sensors.lua` (spatial queries), `src/player/player_movement.lua` (movement math), and `src/player/player_states.lua` (FSM states). New sensor/movement logic goes in the respective module.
- **Game states** live in `src/states/` — one file per state (`menu_state.lua`, `ingame_state.lua`, `game_over_state.lua`).
- **Physics:** go through `Collider`/`World`, not `src.physics.bump` directly, unless the task is backend-specific. Set `collider.walkable = true` on an entity-owned collider that a player should be able to stand and walk on (see Gotchas below) — plain terrain doesn't need this.
- **Sound:** `Sound:play` checks a private `isHeadless()` (true when `love.audio` is absent) and returns early, and `Log.warn`s about missing files; headless tests need no dummy WAV files.
- **Debug overlay:** when `conf.drawphysics` is active, `DebugOverlay:draw(world, map, players, camera)` renders hitboxes, ladder sensors, kill zones, safe positions, camera framing bounds, and NPC paths in a single pass.
- Match nearby style (quotes, indentation — it's mixed). Keep changes small; prefer new entities/components/states over growing `src/states/`.

## Validation

Run `./test-unit.sh` for logic changes; add a unit test when practical. For gameplay checks that need a real map, use `./test-integration.sh`; for checks that need to be watched or need frame capture, use `./test-e2e.sh`. Note `./build.sh` is interactive — don't run it non-interactively.

## AI Agent Control

The test infrastructure doubles as a programmable control layer for AI agents. Any agent can drive the game by requiring the test support modules:

```lua
local GameHarness = require('tests.support.game_harness')
local FakeInput = require('tests.support.fake_input').FakeInput
local FrameStepper = require('tests.support.frame_stepper')
local holdFor = require('tests.support.fake_input').holdFor
local Capture = require('tests.support.capture')  -- e2e tier only

-- Start game (headless integration: omit {real=true}; headed e2e: include it)
local game = GameHarness.startGame('res/map/level1.lua', {real = true})
local controller = FakeInput.new()

-- Keyboard input (P1 uses arrow keys + rshift; P2 uses WASD + Q)
controller:press('right')
holdFor(game, controller, 'right', 2)  -- hold for 2 seconds
controller:release('right')

-- Gamepad input (P1 = index 1, P2 = index 2)
local joy = controller:assignJoystick(1)
joy:setAxes(1, 0)      -- right stick X axis
joy:setButtonDown(1, true)  -- button 1 (use)

-- Step simulation at fixed 1/60s timestep
FrameStepper.step(game, 60)  -- advance 60 frames

-- Window control (e2e tier only; requires real LÖVE window)
-- These call through to love.window in e2e, no-op in headless integration
love.window.setFullscreen(true, 'desktop')   -- fullscreen
love.window.setFullscreen(false)             -- windowed
love.window.maximize()                       -- maximize
love.window.minimize()                       -- minimize
love.window.restore()                        -- restore from minimized/maximized
love.window.setMode(1024, 768)               -- resize window

-- Frame capture (e2e tier only)
local path = Capture.capture('my_screenshot')  -- writes to tests/screenshots/<test>/my_screenshot.png
```

**Tiers:**
| Tier | Command | Window | Rendering | Frame Capture |
|------|---------|--------|-----------|---------------|
| Integration | `./test-integration.sh` | Mock (no window) | No | No |
| E2E | `./test-e2e.sh` / `love . e2e=...` | Real | Yes | Yes |

E2E flags: `--paced` (1 sim frame = 1 real frame, watchable), `--filmstrip` / `--filmstrip=N` (capture every N frames).

Key files:
- `tests/support/fake_input.lua` — `FakeInput` API (`press`, `release`, `assignJoystick`, `holdFor`, `runUntil`)
- `tests/support/game_harness.lua` — boots real game stack
- `tests/support/frame_stepper.lua` — fixed-timestep frame advancement
- `tests/support/capture.lua` — frame capture (e2e only)
- `tests/integration/key_test.lua` — minimal working example

No special prompts needed — the test infrastructure *is* the control layer.

## IPC Server (OpenCode Tools)

The game includes a TCP-based IPC server for programmatic control via OpenCode (or any TCP client).

**Launch with IPC:**
```bash
./run.sh ipc map=sandbox           # default port 8081
./run.sh ipc ipc_port=9000 map=ll1 # custom port/map
```

**Protocol:** Plain TCP, line-delimited commands, responses end with newline.

**Commands:**
| Command | Args | Response |
|---------|------|----------|
| `RESIZE` | `<w> <h>` | `OK: Resized to WxH` |
| `MOVE_PLAYER` | `<1\|2> <dx> <dy>` | `OK: Player N at X,Y` |
| `INPUT` | `<1\|2> <action> <down\|up>` | `OK: Injected action=...` |
| `HOLD_KEY` | `<1\|2> <action> <seconds>` | `OK: Held action for Ns` |
| `TOGGLE_CAMERA` | — | `OK: Camera overview toggled` |
| `GET_STATE` | — | `p1x=X p1y=Y p2x=X p2y=Y w=W h=H map=NAME` |
| `GET_PLAYER_POS` | `<1\|2>` | `Player N at X,Y` |
| `GET_ENTITIES` | — | JSON: `{ok, count, entities[]}` |
| `RESTART_LEVEL` | — | `OK: Level restarted` |
| `MENU` | — | `OK: Returned to menu` |
| `LOAD_MAP` | `<map_name>` | `OK: Loaded <map>` |
| `TAKE_SCREENSHOT` | `[filename]` | `OK: Screenshot saved to ...` |
| `GET_TILE_GRID` | — | JSON: 2D matrix (0=empty, 1=solid, 2=ladder, 3=killzone) |
| `SPAWN_ENTITY` | `<type> <x> <y> [props_json]` | `OK: Spawned <type> at x,y` |
| `STEP_FRAMES` | `<count>` | `OK: Stepped N frames` |
| `GET_LOG` | `[count]` | Console output (print statements, debug logs) |

**OpenCode Tools** (auto-loaded from `.opencode/tools/fido-kitch-ipc.ts`):
| Tool | Description |
|------|-------------|
| `launch_game` | Start game with IPC, waits until ready |
| `get_game_state` | Full state string |
| `get_player_pos` | Single player position |
| `get_entities` | All entities as JSON (players, items, colliders, etc.) |
| `resize_window` | Resize window |
| `press_key` / `release_key` | Simulate key press/release |
| `hold_key` | Hold key for duration |
| `move_player` | Direct position change |
| `restart_level` | Reload current map |
| `go_to_menu` | Return to main menu |
| `toggle_camera` | Toggle camera overview mode |
| `load_map` | Load specific map dynamically |
| `take_screenshot` | Capture current game screen |
| `get_tile_grid` | Get map tile grid as 2D matrix |
| `spawn_entity` | Spawn entity into live game world |
| `step_frames` | Advance simulation by N frames |
| `get_log` | Console output (print statements, debug logs) |

Set `FIDO_KITCH_IPC_PORT` env var for custom port (default 8081).

## Gotchas

- CI workflows reference `./install.sh`, which doesn't exist — the script is `setup.sh`.
- `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.
- Controls: P1 arrows + right-shift (use); P2 WASD + Q; joystick axes + button 1.
- **An entity's own solid collider isn't "ground" by default.** `Player:queryOnGround()`/`GroundSupport` only treat a collider with no owning entity as ground; a custom entity collider a player should be able to stand and walk on (e.g. `src/entities/drawbridge.lua`'s deck) needs `collider.walkable = true` set explicitly, or the player gets stuck in `FallState` — physically supported but unable to walk — the moment they step onto it. Only discovered under real rendering (`tests/e2e/`), since the headless mock never exercises `love.graphics`.
- **A solid collider flush with the ground's top edge does not block horizontal movement.** Two static solid rects of the same height both starting at the walking surface resolve as a walkable step under `lib/bump`'s simple AABB collision, not a wall. A collider meant to stop horizontal entry (a locked door, a closed drawbridge) needs to be taller than the walking surface, following the pattern in `Map:createStaticPhysicsBodyBoundary`. See `tests/README.md`'s "Physics gotchas" section for the fuller writeup.
- **`World.colFilter` consults an optional per-collider `colFilterFn(a,b)` first** (checked on `b`, then `a`; non-nil `'cross'`/`'slide'` wins, nil falls through to the default rules). Wire it via `Collider:setColFilterFn(fn)`. Mover platforms use this to implement one-way top-only collision so players jump up through the deck and pass the sides but land/stand on top — without it the platform is an opaque box.
- **A mover platform also carries its riders itself** (`world:queryOverlap` probe, feet within `RIDER_TOL` of the deck top, nudged by the exact per-frame delta) because ground detection is boolean-only and can't say *which* collider a player stands on. Carry must run before the physics step — `InGameState:update` already orders `map:update(dt)` before `world:update(dt)`. Players only; boxes/NPCs collide solidly and are never carried.
