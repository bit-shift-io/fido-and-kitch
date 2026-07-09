# Agent Context for Fido and Kitch

## Project overview

Fido and Kitch is a LÖVE 2D puzzle-platformer with local couch co-op. It uses Lua/LuaJIT and Tiled maps exported to Lua via Simple Tiled Implementation (STI). The game has two playable characters (dog and cat) and bite-sized puzzle levels with entities such as keys, switches, doors, teleporters, ladders, cages, birds, coins, and jump pads.

## Tech stack

- Runtime: LÖVE 2D `12.0` (`conf.lua`)
- Language: LuaJIT-style Lua
- Map editor: Tiled (`.tmx` source maps exported as `.lua` under `res/map`)
- UI: Slab (`lib.Slab`) for menu UI
- Class/vector/camera helpers: hump (`lib.hump.class`, `vector`, `camera`)
- Tile maps: STI (`lib.sti`)
- Tweening: `lib.tween.tween`
- Physics abstraction:
  - Active backend is selected in `conf.lua` via `t.physics`
  - Current setting: `bump`
  - Implementations live under `src/physics/bump` and `src/physics/love`

Dependencies are expected in `lib/` after running setup/install scripts. The checked-out `lib/` directory may be empty in a fresh clone.

## Important commands

Run from the repository root:

```sh
./setup.sh
```

Installs LÖVE through the host package manager when available and fetches Lua dependencies into `lib/`. Package-manager LÖVE versions may lag behind 12.0, so prefer keeping a local LÖVE 12 AppImage at `bin/love.AppImage` for development.

```sh
./run.sh
```

Runs the game. The script uses `bin/love.AppImage` when present, otherwise it falls back to `love` from `PATH`.

Useful direct run/debug forms:

```sh
love .
love . debug
love . debug drawphysics map=sandbox.lua
love . debug drawphysics map=ll1.lua
love . profile
```

Build/package:

```sh
./build.sh
```

This opens an interactive makelove target menu. `makelove.toml` defines default targets: `win32`, `win64`, `macos`, and `appimage`.

## Repository layout

- `main.lua` — minimal root entrypoint; requires `src.main`.
- `conf.lua` — LÖVE configuration and physics backend selection.
- `src/main.lua` — global dependency bootstrap and LÖVE callbacks.
- `src/game.lua` — top-level game object and game state FSM.
- `src/game_states.lua` — menu and in-game states.
- `src/map.lua` — STI map wrapper, entity loading from Tiled object layers, collision/ladders, map scaling/drawing.
- `src/entity.lua` — base entity class with component lifecycle and queued removal/destruction.
- `src/components/` — reusable components (`Collider`, `Sprite`, `StateMachine`, `Inventory`, `Pickup`, `Usable`, etc.).
- `src/entities/` — Tiled object entity implementations. The object `type` in a map should match a module name here, e.g. `key` -> `src/entities/key.lua`.
- `src/player/` — player entity and movement/ladder/fall states.
- `src/physics/` — abstracted physics backends for `bump` and LÖVE/Box2D.
- `src/ui/` — Slab UI helpers such as the map list.
- `src/utils/` — table/string/rect/signal/proxy helpers.
- `res/map/` — Tiled maps (`.tmx`) and exported STI Lua maps (`.lua`).
- `res/img/`, `res/tilesets/`, `res/templates/` — game assets.
- `.zed/tasks.json` — Zed task for `./run.sh`.
- `.vscode/launch.json` — debug/profile launch configs.

## Runtime flow

1. Root `main.lua` requires `src.main`.
2. `src/main.lua` loads globals used throughout the codebase:
   - `conf`, `str`, `utils`
   - `Vector`, `Class`, `Camera`, `Tween`, `Slab`
   - core classes/components such as `World`, `Entity`, `StateMachine`, `Collider`, `Map`, `Player`, `Game`
3. `love.load(args)` calls `setupConf(args)`, initializes Slab, and creates `game = Game()`.
4. `Game` owns a `StateMachine` initialized to `MenuState`.
5. If a command-line arg like `map=sandbox.lua` is present, `Game:init` immediately starts that map.
6. `MenuState` uses `MapList` and Slab to choose maps from `res/map`.
7. `InGameState:load` creates global `world`, `map`, and `camera`, then spawns two players at Tiled objects with type `spawn`.
8. Per frame:
   - `love.update` -> `game:update(dt)` -> active game state update
   - in-game update calls `map:update(dt)` then `world:update(dt)`
   - `love.draw` -> `game:draw()` -> active state draw

## Architecture conventions

### Globals are intentional here

This project currently relies on globals initialized in `src/main.lua` (`Class`, `Vector`, `world`, `map`, `conf`, etc.). When making targeted changes, follow the existing pattern unless the task is specifically to refactor dependency management.

### Classes

Most classes use hump class syntax:

```lua
local Thing = Class{}

function Thing:init(props)
end

return Thing
```

Entities often inherit from the base entity:

```lua
local Thing = Class{__includes = Entity}
```

### Entity/component model

- Base entities call `Entity.init(self)` in `init`.
- Components are attached with `self:addComponent(Component{...})`.
- `Entity:update(dt)` and `Entity:draw()` forward to components that implement those methods.
- Use `queueRemove()` or `queueDestroy()` rather than removing map-layer entities immediately during iteration.
- `destroy()` calls component `destroy()` hooks and emits `destroySignal`.

### State machines

`src/components/state_machine.lua` supports two modes:

- `states` for already-created state instances/objects.
- `stateClasses` for classes that should be instantiated and wired to an `entity`.

Undefined method calls on the state machine are proxied to `currentState`.

### Map/entity loading

`src/map.lua` loads Tiled object groups and replaces map objects with runtime entities:

- `Map.typeIgnores = {'', 'spawn'}` prevents empty/spawn objects from being loaded as entity modules.
- Entity modules are looked up under `src.entities.`.
- Tiled object `type` must match a module filename.
- Each loaded entity is stored on `object.entity` and inserted into `layer.entities`.
- Tiled object properties can contain executable event snippets processed by `object:exec(propertyName, entity)`. Be careful when editing this: it uses `utils.loadCode` and globals.

### Physics

Use the abstraction exposed through `src/components/collider.lua` and `src/world.lua` rather than directly depending on a backend unless the task is backend-specific.

- `conf.lua` selects the backend with `t.physics`.
- Current backend is `bump`.
- `Collider{...}` props commonly include:
  - `shape_type`
  - `shape_arguments`
  - `body_type`
  - `position`
  - `sprite`
  - `sensor`
  - collision callbacks (`enter`, `postSolve`, etc.)
- The bump backend emulates enough Box2D-like behavior for this game. Be careful to keep backend APIs aligned if changing shared collider/world behavior.

### Tiled maps

- Source maps are `.tmx` files in `res/map`.
- Runtime maps are exported Lua files in `res/map` and loaded via STI.
- README notes Tiled should embed tilesets and maps must be exported as `.lua` to be loaded.
- Map object `type` drives entity creation.
- Layer custom properties used by code include `collision` and `ladder`.

## Controls

Player 1:

- Move: arrow keys
- Use: right shift

Player 2:

- Move: WASD
- Use: Q

Joystick support maps axes to movement and button `1` to use.

## Debugging and profiling

Command-line flags parsed in `src/main.lua` / `Game:init`:

- `debug` — starts `lldebugger` and sets `conf.debug`.
- `drawphysics` — enables physics debug drawing via `conf.drawphysics`.
- `profile` — requires `src.profile` and prints a short load profile in `InGameState:load`.
- `map=<file>` — skips the menu and loads `res/map/<file>`.

`F12` captures a screenshot from `Game:keypressed`.

## Coding style notes

- Keep changes small and consistent with existing Lua style.
- Prefer single quotes for require paths/strings where nearby code does.
- Existing indentation is mixed, but most new code should use tabs only when the surrounding file does; otherwise follow nearby spaces.
- Avoid broad refactors unless requested. This codebase has several intentional/legacy global patterns.
- Prefer adding functionality through entities/components/states rather than putting everything into `game_states.lua`.
- When adding a new map entity, create `src/entities/<type>.lua` and set Tiled object type to `<type>`.
- When adding visual/physical behavior to an entity, attach `Sprite` and `Collider` components and ensure `entity` references are present where query/collision code expects them.

## Validation guidance

There is no obvious automated test suite in this repository. For code changes, validate with the most targeted manual/runtime check available, for example:

```sh
love . debug drawphysics map=sandbox.lua
```

If dependencies are missing, run `./setup.sh` first. For packaging changes, use `./build.sh` or `makelove` with the relevant target, but note `./build.sh` is interactive.

## Known issues / things to watch

- GitHub workflows mention `./install.sh`, but this repository currently has `setup.sh`; do not assume `install.sh` exists unless it is added.
- `lib/` may be empty until setup runs.
- CI workflows also call `./install.sh`; packaging CI may need updating if that script remains absent.
- The project targets LÖVE 12.0. `conf.lua` should use v12 config fields such as `t.graphics.gammacorrect`, `t.highdpi`, and `t.window.displayindex`.
- `makelove.toml` `love_files` patterns include shallow globs such as `./src/*` and `./res/*`; verify packaging includes nested files if changing build behavior.
- Map event properties execute Lua snippets. Treat map-provided code as trusted project content, and avoid exposing user-provided input to it.
- The active bump backend has different semantics from LÖVE physics. Keep the abstraction in mind when modifying `Collider`/`World` APIs.
