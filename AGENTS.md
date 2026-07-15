# Agent Context for Fido and Kitch

Fido and Kitch is a LÖVE 2D (12.0) puzzle-platformer with local couch co-op: two players (dog and cat) solve bite-sized levels built in Tiled. Written in LuaJIT-style Lua. `CLAUDE.md` and `GEMINI.md` point here; `CONTEXT.md` is a glossary of domain terms (camera, framing targets, etc.); design decisions live in `docs/adr/`.

## Commands

```sh
./setup.sh    # install LÖVE + fetch Lua deps into lib/ (lib/ may be empty in a fresh clone)
./run.sh      # run the game (prefers bin/love.AppImage, falls back to `love` on PATH)
./test.sh     # fast headless Lua tests (no LÖVE window); pass a file to run just one
./build.sh    # interactive makelove packaging (targets: win32, win64, macos, appimage)
```

Useful run flags (parsed in `src/main.lua` / `Game:init`):

```sh
love . debug drawphysics map=sandbox.lua
```

- `debug` — starts lldebugger, sets `conf.debug`
- `drawphysics` — physics debug drawing
- `profile` — prints a load profile in `InGameState:load`
- `map=<file>` — skips the menu, loads `res/map/<file>`
- `F12` — screenshot

## Layout

- `main.lua` / `conf.lua` — entrypoint (requires `src.main`) and LÖVE config; `t.physics` selects the physics backend (currently `bump`)
- `src/main.lua` — bootstraps globals (`conf`, `utils`, `Vector`, `Class`, `Camera`, `Tween`, `Slab`, `World`, `Entity`, `Map`, `Player`, `Game`, …) and LÖVE callbacks
- `src/game.lua`, `src/game_states.lua` — top-level game object and menu/in-game/game-over state FSM
- `src/map.lua` — STI map wrapper; loads Tiled object layers into runtime entities, collision/ladders
- `src/camera.lua` — shared auto-zoom camera framing all players
- `src/entity.lua`, `src/components/` — base entity with component lifecycle; components like `Collider`, `Sprite`, `StateMachine`, `Inventory`, `Pickup`, `Usable`
- `src/entities/` — map entity implementations; Tiled object `type` must match a filename here (`key` → `src/entities/key.lua`)
- `src/player/` — player entity, movement/ladder/fall states, lives, safe-position respawn
- `src/physics/` — swappable backends (`bump`, `love`/Box2D) behind `Collider`/`World`
- `src/ui/` — Slab menu UI, map list, lives HUD
- `res/map/` — Tiled `.tmx` sources and exported `.lua` maps (STI loads only the `.lua`; tilesets must be embedded)
- `tests/` — dependency-free headless tests (see `tests/README.md`)

## Conventions

- **Globals are intentional.** Core classes and `world`/`map`/`camera` are globals set up in `src/main.lua`. Follow the pattern; don't refactor dependency management unless asked.
- **Classes** use hump: `local Thing = Class{}` … `function Thing:init(props)`; entities use `Class{__includes = Entity}` and call `Entity.init(self)` in `init`.
- **Components** attach via `self:addComponent(Component{...})`; `Entity:update/draw` forward to components. Use `queueRemove()`/`queueDestroy()` instead of removing entities mid-iteration.
- **State machines** (`src/components/state_machine.lua`) accept `states` (instances) or `stateClasses` (instantiated and wired to `entity`); unknown method calls proxy to `currentState`.
- **New map entity** = new `src/entities/<type>.lua` + Tiled object with matching `type`. `Map.typeIgnores = {'', 'spawn'}` skips those types. Tiled object properties may contain executable Lua event snippets (`object:exec`) — treat map code as trusted, don't feed it user input.
- **Physics:** go through `Collider`/`World`, not a backend directly, unless the task is backend-specific. The bump backend emulates Box2D-ish semantics; keep the two backends' APIs aligned when changing shared behavior.
- Match nearby style (quotes, indentation — it's mixed). Keep changes small; prefer new entities/components/states over growing `game_states.lua`.

## Validation

Run `./test.sh` for logic changes; add a headless test when practical. For gameplay checks use a targeted manual run, e.g. `love . debug drawphysics map=sandbox.lua`. Note `./build.sh` is interactive — don't run it non-interactively.

## Gotchas

- CI workflows reference `./install.sh`, which doesn't exist — the script is `setup.sh`.
- `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.
- Controls: P1 arrows + right-shift (use); P2 WASD + Q; joystick axes + button 1.
