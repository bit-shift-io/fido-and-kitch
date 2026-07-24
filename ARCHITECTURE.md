# ARCHITECTURE.md — System Architecture & Codebase Map (Fido & Kitch)

> **Purpose:** This document provides a structural map, architectural guidelines, and module breakdown for both human developers and AI assistants. Keep this file updated as key modules, traits, or data flows evolve.

---

## 1. Executive Overview

**Project Goal:** A LÖVE 2D (v12.0) puzzle-platformer with local couch co-op: two players (dog and cat) solve bite-sized levels built in Tiled. Written in LuaJIT-style Lua.

### Key Technology Stack
* **Runtime:** LÖVE 12.0 (LuaJIT)
* **Physics Backend:** `bump.lua` (AABB) — default; `love.physics` (Box2D) available via `conf.t.physics`
* **UI:** Slab (immediate-mode UI) for menus/HUD
* **Class System:** hump.class
* **Tweening:** hump.tween
* **Vector Math:** hump.vector
* **Map Loader:** STI (Simple Tiled Implementation) — loads exported `.lua` maps
* **Tiled Map Editor:** `.tmx` sources in `res/map/`; embedded tilesets required
* **Testing:** Headless Lua tests in `tests/` (run via `./test.sh`)

---

## 2. Directory & Module Hierarchy

```text
.
├── main.lua              # LÖVE entrypoint (loads src/main.lua)
├── conf.lua              # LÖVE config (t.physics selects physics backend)
├── ARCHITECTURE.md       # This file
├── AGENTS.md             # AI agent guidelines, commands, conventions
├── CONTEXT.md            # Glossary of domain terms (camera, framing targets, etc.)
├── setup.sh              # Installs LÖVE + fetches Lua deps into lib/
├── run.sh                # Runs the game (prefers bin/love.AppImage)
├── test.sh               # Fast headless Lua tests (no LÖVE window)
├── build.sh              # Interactive makelove packaging (win32/win64/macos/appimage)
├── lib/                  # Vendored Lua deps (bump, Slab, tween, hump, sti, etc.)
├── src/
│   ├── main.lua          # Bootstraps globals (conf, utils, Vector, Class, Camera, Tween, Slab, World, Entity, Map, Player, Game, …) and LÖVE callbacks
│   ├── game.lua          # Top-level Game object; FSM over game states
│   ├── game_states.lua   # MenuState, InGameState, GameOverState (FSM states)
│   ├── map.lua           # STI wrapper; loads Tiled object layers into runtime entities, collision, ladders
│   ├── camera.lua        # Shared auto-zoom camera framing all players
│   ├── entity.lua        # Base Entity with component lifecycle
│   ├── world.lua         # Thin wrapper selecting physics backend (bump/love)
│   ├── components/       # Reusable components (Collider, Sprite, StateMachine, Inventory, Pickup, Usable, Variable, Flash, Timeline, Path, PathFollow)
│   ├── entities/         # Map entity implementations; Tiled object `type` must match filename (key → src/entities/key.lua)
│   ├── player/           # Player entity, movement/ladder/fall states, lives, safe-position respawn
│   ├── physics/          # Swappable backends (bump, love/Box2D) behind Collider/World
│   ├── ui/               # Slab menu UI, map list, lives HUD
│   └── utils/            # str, tbl, utils, rect, signal
├── res/
│   └── map/              # Tiled .tmx sources + exported .lua maps (STI loads .lua only)
└── tests/                # Dependency-free headless tests (see tests/README.md)
```

---

## 3. Core Subsystems & Module Breakdown

### 3.1 Core & Entrypoint (`src/main.lua`, `conf.lua`)
* **`main.lua`**: Loads all globals (`conf`, `utils`, `Vector`, `Class`, `Camera`, `Tween`, `Slab`, `World`, `Entity`, `Map`, `Player`, `Game`, …), parses CLI flags (`debug`, `drawphysics`, `profile`, `map=<file>`), creates `Game()` in `love.load`.
* **`conf.lua`**: LÖVE config; `t.physics` selects physics backend (`"bump"` or `"love"`).

### 3.2 Game Object & State Machine (`src/game.lua`, `src/game_states.lua`)
* **`Game`**: Holds a `StateMachine` (`stateClasses = GameStates`, `entity = self`, `currentState = 'MenuState'`). Delegates all LÖVE callbacks (`update`, `draw`, `keypressed`, …) to `self.fsm`.
* **States** (`game_states.lua`):
  * **`MenuState`**: Slab-based map list (`MapList`), handles keyboard/gamepad/mouse/touch to start a map or quit.
  * **`InGameState`**: Loads map via `Map:new()`, creates `World`, `AutoCamera`, spawns 2 `Player` entities at `spawn` objects, manages shared lives pool (`Lives`), handles player death/respawn/game-over, camera framing.
  *   **`GameOverState`**: Simple menu (Restart / Main Menu) with keyboard/gamepad/mouse/touch input.

### 3.3 Map & Entity Loading (`src/map.lua`)
* Wraps **STI** (`sti(path, {"box2d"})`); proxies STI methods to itself via `utils.proxyClass`.
* **Object Layers → Entities**: Iterates object layers; for each object with `type` not in `typeIgnores = {'', 'spawn'}`, `require('src.entities.' .. type)(object)` and inserts into `layer.entities`.
* **Layer Update/Draw**: Injects `update(dt)` and `draw()` onto each object layer to iterate its entities.
* **Collision**: Reads layer properties `collision=true` and `ladder=true` to create static physics bodies / ladder sensor volumes.
* **Map Boundaries**: Adds four static boundary colliders around the map.
* **Lua Snippets**: Objects may have properties containing executable Lua (`object:exec`) — treated as trusted map code.

### 3.4 Camera (`src/camera.lua`)
* **Pure-Lua auto-zoom camera**: Frames all alive players (+ transient extra targets like a dying player's respawn point).
* **Modes**: `follow` (default), `overview` (full map, toggled via Space/Back), `gameover` (owned by GameOverState).
* **Framing Math** (`Camera.computeFraming`): Union of target rects → margin → min view (5×5 tiles) → clamp to map → scale to fit screen.
* **Smoothing**: Frame-rate-independent exponential ease (`decay = 12` → ~0.5 s settle).
* **Headless-testable**: No `love.*` calls in framing math; `InGameState` supplies screen/map size and reads back draw params.

### 3.5 Entity & Component System (`src/entity.lua`, `src/components/`)
* **`Entity`**: Base class; holds `components[]`, `destroySignal`; `update(dt)`/`draw()` forward to components; `queueRemove()`/`queueDestroy()` for safe mid-iteration removal.
* **Components** (attach via `self:addComponent(Component{…})`):
  * **`Collider`**: Physics body wrapper (delegates to backend via `src/physics/<backend>/collider.lua`).
  * **`Sprite`**: Animated sprite sheets (frame count, duration, loop, offset, facing).
  *   **`StateMachine`**: Generic FSM; accepts `states` (instances) or `stateClasses` (instantiated & wired to `entity`); unknown method calls proxy to `currentState`.
  * **`Inventory`**: Simple item count map (`addItems`, `hasItem`, `removeItem`).
  * **`Pickup`**: Marks entity as collectible (`itemName`, `itemCount`); player `Inventory` picks up on contact.
  * **`Usable`**: Interaction target (`canUse(player)`, `use(player)`).
  * **`Variable`**: Named value storage for map-triggered logic.
  * **`Flash`**: Timed visibility toggling (spawn/respawn blink).
  * **`Timeline` / `Path` / `PathFollow`**: Scripted movement along waypoints.

### 3.6 Player (`src/player/`)
* **`Player`** (`player.lua`): Extends `Entity`; two instances (index 1 = dog/arrows+RShift, index 2 = cat/WASD+Q + gamepad).
*   **Components**: `Collider` (kinematic, fixed rotation), `StateMachine` (animation states: idle/walk/fall/climb), `StateMachine` (movement states: `WalkIdleState`, `LadderState`, `FallState`, `DeadState`), `Inventory`, `SafePosition`.
*   **Input**: `isDown(action)` maps actions to keys/gamepad per player index.
*   **Safe Position**: Tracks last fully-supported ground position for respawn (`SafePosition` module).
*   **Death/Respawn**: `die(deathType)` → `DeadState` → flash → `resolveDeath()` signals `InGameState` → `respawn()` teleports to safe position + spawn flash.

### 3.7 Physics (`src/physics/`)
* **Backend Selection**: `conf.t.physics` (`"bump"` or `"love"`).
* **`World`**: Thin wrapper; `newCollider`, `update(dt)`, `draw()`, `queryRectangleArea`, `queryBounds`.
* **`Collider`**: Unified API (`setPosition`, `getBounds`, `setType`, `setSensor`, `setGroupIndex`, callbacks: `enter`, `exit`, `preSolve`, `postSolve`).
* **Bump Backend** (`src/physics/bump/`): `bump.lua` world; emulates Box2D-ish semantics (slide response, sensor cross, group-index filtering, kinematic cross).
* **Love/Box2D Backend** (`src/physics/love/`): Thin wrapper over `love.physics`.

### 3.8 Map Entities (`src/entities/`)
* **Convention**: New entity = new file `src/entities/<type>.lua` + Tiled object with matching `type`.
* **Examples**: `key`, `cage`, `switch`, `exit_door`, `ladder`, `kill_zone`, `jump_pad`, `teleport`, `bird`, `coin`, `variable`.
* **Map Hooks**: Tiled object properties may contain Lua snippets (`onUse`, `onTrigger`, etc.) executed via `object:exec`.

### 3.9 UI (`src/ui/`)
* **`MapList`**: Slab-based scrollable map selector.
* **`LivesHud`**: Draws heart squares top-left from `Lives` count.

---

## 4. Primary Data & Event Flow

### Level Load (`InGameState:load`)
```
love.load
  → Game:init() → StateMachine(MenuState)
  → MenuState:startGame({map}) → Game:setGameState('InGameState') → Game:load(props)
  → InGameState:load(props)
       → World:new(0, 90.81, true)
       → Map:new(mapPath, world, true)
            → STI loads map
            → createEntitiesFromObjectGroupLayers() → require('src.entities.<type>') for each object
            → createStaticPhysicsBodies (collision layers)
            → createLadderVolumes (ladder layers)
            → createStaticPhysicsBodyBoundary (map edges)
       → AutoCamera.new({screenW, screenH, mapW, mapH, tileW, tileH})
       → Lives.defaultCount() → LivesHud
       → Spawn 2 Players at 'spawn' objects
            → Player:init → components (Collider, StateMachine×2, Inventory, SafePosition)
            → connect destroySignal/deathSignal to InGameState handlers
```

### Frame Update (`InGameState:update`)
```
dt
  → map:update(dt)        -- updates all layer entities
  → world:update(dt)      -- physics step
  → if gameOverTimer:
       camera:update(dt, playerTargets)  -- easing to full-map view
       gameOverTimer -= dt; if ≤0 → transitionToGameOver()
    else:
       updateDeathFramingTargets()       -- add respawn points as extra camera targets
       camera:update(dt, collectPlayerTargets())
```

### Camera Framing (`AutoCamera:update`)
```
playerTargets = { {x,y,w,h} for each alive player }
extraTargets  = { respawn rects for dead players }
targetView = computeFraming(playerTargets ∪ extraTargets)
cx, cy, scale ← exponential ease toward targetView
return tx, ty, sx, sy for Map:draw2
```

### Player Death Flow
```
Player:update → queryKillZone() → die(deathType)
  → fsm:setState('DeadState') → Flash component blinks
  → DeadState:update → flash done → resolveDeath()
       → deathSignal:emit(player, deathType)
  → InGameState:onPlayerDied → Lives.applyDeath(lives)
       → if gameover: onGameOver() → camera:setMode('gameover') → timer
       → else: player:respawn() → teleport to safePosition → WalkIdleState + spawn flash
```

---

## 5. Architectural Invariants & Key Rules

1. **Globals Are Intentional**: Core classes (`World`, `map`, `camera`, `world`, `game`, `conf`, `utils`, `Vector`, `Class`, `Tween`, `Slab`, `Entity`, `Map`, `Player`, `Game`, …) are globals set up in `src/main.lua`. Follow the pattern; don't refactor dependency management unless asked.

2. **Classes**: Use hump.class: `local Thing = Class{} … function Thing:init(props)`. Entities: `Class{__includes = Entity}` and call `Entity.init(self)` in `init`.

3. **Components**: Attach via `self:addComponent(Component{…})`; `Entity:update/draw` forward to components. Use `queueRemove()`/`queueDestroy()` instead of removing entities mid-iteration.

4. **State Machines** (`src/components/state_machine.lua`): Accept `states` (instances) or `stateClasses` (instantiated and wired to `entity`); unknown method calls proxy to `currentState`.

5. **New Map Entity** = new `src/entities/<type>.lua` + Tiled object with matching `type`. `Map.typeIgnores = {'', 'spawn'}` skips those types. Tiled object properties may contain executable Lua snippets (`object:exec`) — treat map code as trusted, don't feed it user input.

6. **Physics**: Go through `Collider`/`World`, not a backend directly, unless the task is backend-specific. The bump backend emulates Box2D-ish semantics; keep the two backends' APIs aligned when changing shared behavior.

7. **Match Nearby Style**: Quotes, indentation — it's mixed. Keep changes small; prefer new entities/components/states over growing `game_states.lua`.

---

## 6. How to Extend

### Adding a New Map Entity
1. Create `src/entities/<type>.lua` (see `src/entities/key.lua` for minimal example).
2. In Tiled, add an object with `Type = <type>` (case-sensitive).
3. Properties on the object become `object.properties` table passed to the entity constructor.

### Adding a New Component
1. Create `src/components/<name>.lua` following `Collider`/`Sprite` pattern.
2. Attach via `entity:addComponent(ComponentName{…})` in entity's `init`.

### Adding a New Player State
1. Create state class in `src/player/player_states.lua` (or new file, required there).
2. Implement `enter`, `exit`, `update`, and any custom methods.
3. Add to `PlayerStates` table; reference in `Player.fsm` `stateClasses`.

### Adding a New Game State
1. Create class in `src/game_states.lua` (or new file) following `MenuState`/`InGameState` pattern.
2. Add to returned `GameStates` table.
3. Transition via `game:setGameState('NewStateName')`.

---

## 7. Validation & Testing

* **Headless Tests**: `./test.sh` (or `./test.sh tests/specific_test.lua`) — runs `tests/run.lua`; no LÖVE window. Add a test when practical for logic changes.
* **Gameplay Checks**: Targeted manual run, e.g. `love . debug drawphysics map=sandbox.lua`.
* **Flags** (parsed in `src/main.lua` / `Game:init`):
  * `debug` — starts lldebugger, sets `conf.debug`
  * `drawphysics` — physics debug drawing
  * `profile` — prints load profile in `InGameState:load`
  * `map=<file>` — skips menu, loads `res/map/<file>`
* **F12** — screenshot.

---

## 8. Build & Packaging

* `./build.sh` — interactive `makelove` packaging (targets: win32, win64, macos, appimage).
* **Note**: `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.

---

## 9. Key Files Quick Reference

| File | Purpose |
|------|---------|
| `main.lua` / `conf.lua` | Entrypoint & LÖVE config |
| `src/main.lua` | Global bootstrap, LÖVE callbacks |
| `src/game.lua` | Top-level Game object, state FSM |
| `src/game_states.lua` | Menu / InGame / GameOver states |
| `src/map.lua` | STI wrapper, entity loading, collision/ladders |
| `src/camera.lua` | Auto-zoom camera framing all players |
| `src/entity.lua` | Base entity + component lifecycle |
| `src/components/` | Reusable components (Collider, Sprite, StateMachine, Inventory, Pickup, Usable, …) |
| `src/entities/` | Map entity implementations (type → file) |
| `src/player/` | Player entity, movement states, lives, safe position |
| `src/physics/` | Swappable backends (bump, love) behind Collider/World |
| `src/ui/` | Slab menu UI, map list, lives HUD |
| `res/map/` | Tiled `.tmx` sources + exported `.lua` (STI loads `.lua` only) |
| `tests/` | Headless Lua tests (run via `./test.sh`) |
| `docs/adr/` | Architecture Decision Records |

---

## 10. ADR Index

* **ADR 0001** — Deterministic pushable motion & snap model (tile-perfect hole filling, pressure-plate seating)
* **ADR 0002** — Solution-first level generation with modular puzzle-rule library (guaranteed solvability by construction)

*(See `docs/adr/` for full text.)*

---

## 11. Gotchas

* CI workflows reference `./install.sh` — the script is actually `setup.sh`.
* `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.
* Controls: P1 arrows + right-shift (use); P2 WASD + Q; joystick axes + button 1.
* Map code in Tiled object properties (`object:exec`) is trusted — never feed it user input.