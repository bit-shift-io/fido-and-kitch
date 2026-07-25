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
- `tests/` — three test tiers (unit, integration, e2e) plus shared support/fixtures (see `tests/README.md`)

## Conventions

- **Globals are intentional.** Core classes and `world`/`map`/`camera` are globals set up in `src/main.lua`. Follow the pattern; don't refactor dependency management unless asked.
- **Classes** use hump: `local Thing = Class{}` … `function Thing:init(props)`; entities use `Class{__includes = Entity}` and call `Entity.init(self)` in `init`.
- **Components** attach via `self:addComponent(Component{...})`; `Entity:update/draw` forward to components. Use `queueRemove()`/`queueDestroy()` instead of removing entities mid-iteration.
- **State machines** (`src/components/state_machine.lua`) accept `states` (instances) or `stateClasses` (instantiated and wired to `entity`); unknown method calls proxy to `currentState`.
- **New map entity** = new `src/entities/<type>.lua` + Tiled object with matching `type`. `Map.typeIgnores = {'', 'spawn'}` skips those types. Tiled object properties may contain executable Lua event snippets (`object:exec`) — treat map code as trusted, don't feed it user input.
- **Physics:** go through `Collider`/`World`, not a backend directly, unless the task is backend-specific. The bump backend emulates Box2D-ish semantics; keep the two backends' APIs aligned when changing shared behavior. Set `collider.walkable = true` on an entity-owned collider that a player should be able to stand and walk on (see Gotchas below) — plain terrain doesn't need this.
- Match nearby style (quotes, indentation — it's mixed). Keep changes small; prefer new entities/components/states over growing `game_states.lua`.

## Validation

Run `./test-unit.sh` for logic changes; add a unit test when practical. For gameplay checks that need a real map, use `./test-integration.sh`; for checks that need to be watched or need frame capture, use `./test-e2e.sh`. Note `./build.sh` is interactive — don't run it non-interactively.

## Gotchas

- CI workflows reference `./install.sh`, which doesn't exist — the script is `setup.sh`.
- `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.
- Controls: P1 arrows + right-shift (use); P2 WASD + Q; joystick axes + button 1.
- **An entity's own solid collider isn't "ground" by default.** `Player:queryOnGround()`/`GroundSupport` only treat a collider with no owning entity as ground; a custom entity collider a player should be able to stand and walk on (e.g. `src/entities/drawbridge.lua`'s deck) needs `collider.walkable = true` set explicitly, or the player gets stuck in `FallState` — physically supported but unable to walk — the moment they step onto it. Only discovered under real rendering (`tests/e2e/`), since the headless mock never exercises `love.graphics`.
- **A solid collider flush with the ground's top edge does not block horizontal movement.** Two static solid rects of the same height both starting at the walking surface resolve as a walkable step under `lib/bump`'s simple AABB collision, not a wall. A collider meant to stop horizontal entry (a locked door, a closed drawbridge) needs to be taller than the walking surface, following the pattern in `Map:createStaticPhysicsBodyBoundary`. See `tests/README.md`'s "Physics gotchas" section for the fuller writeup.
