# ARCHITECTURE.md — System Architecture & Codebase Map (Fido & Kitch)

> **Purpose:** This document provides a structural map, architectural guidelines, and module breakdown for both human developers and AI assistants. Keep this file updated as key modules, traits, or data flows evolve.

---

## 1. Executive Overview

**Project Goal:** A LÖVE 2D (v12.0) puzzle-platformer with local couch co-op: two players (dog and cat) solve bite-sized levels built in Tiled. Written in LuaJIT-style Lua.

### Key Technology Stack
* **Runtime:** LÖVE 12.0 (LuaJIT)
* **Physics Backend:** `bump.lua` (AABB) behind `Collider`/`World`
* **UI:** Slab (immediate-mode UI) for menus/HUD
* **Class System:** hump.class
* **Tweening:** hump.tween
* **Vector Math:** hump.vector
* **Map Loader:** STI (Simple Tiled Implementation) — loads maps; `.tmj` sources are parsed directly (via `src/map/tmj.lua`) then fed to STI
* **Tiled Map Editor:** `.tmj` sources in `res/map/`; external templates (`.tj`) and tilesets (`.tsj`) in `res/entities/`
* **Testing:** Headless Lua tests in `tests/` (run via `./test-unit.sh`)

---

## 2. Directory & Module Hierarchy

```text
.
├── main.lua              # LÖVE entrypoint (loads src/main.lua)
├── conf.lua              # LÖVE config
├── ARCHITECTURE.md       # This file
├── AGENTS.md             # AI agent guidelines, commands, conventions
├── CONTEXT.md            # Glossary of domain terms (camera, framing targets, etc.)
├── setup.sh              # Installs LÖVE + fetches Lua deps into lib/
├── run.sh                # Runs the game (prefers bin/love.AppImage)
├── test-unit.sh           # Fast headless Lua unit tests (no LÖVE window)
├── test-integration.sh    # Headless real-stack tests (maps loaded through a love.* mock)
├── test-e2e.sh            # Headed tests: real LÖVE, real window, frame capture
├── test-all.sh            # Runs all three tiers
├── build.sh              # Interactive makelove packaging (win32/win64/macos/appimage)
├── lib/                  # Vendored Lua deps (bump, Slab, tween, hump, sti, etc.)
├── src/
│   ├── main.lua          # Bootstraps globals (conf, utils, Vector, Class, Camera, Tween, Slab, World, Entity, Map, Player, Game, …) and LÖVE callbacks
│   ├── game.lua          # Top-level Game object; FSM over game states
│   ├── states/           # MenuState, InGameState, GameOverState (FSM states, one file per state)
│   ├── map.lua           # Thins STI wrapper; delegates to src/map/init.lua
│   ├── camera.lua        # Shared auto-zoom camera framing all players
│   ├── entity.lua        # Base Entity with component lifecycle
│   ├── world.lua         # Collider/World physics API backed by bump
│   ├── map/              # Map system (init, entity_factory, collision_builder, ladder_merger, parallax_renderer, tmj, tj_template, tj_tileset, map_parallax)
│   ├── components/       # Reusable components (Collider, Sprite, StateMachine, Inventory, Pickup, Usable, Switchable, Variable, Flash, Timeline, Path, PathFollow, Sound, Tint, UsableSparkle, Pushable, SpeedStreak)
│   ├── entities/         # Map entity implementations; Tiled object `type` must match filename (key → src/entities/key.lua); sprite art comes from the entity's template via src/entities/sprite_props.lua (SpriteProps.fromObject)
│   ├── player/           # Player entity + subsystems (states/, movement, sensors, lives, safe-position)
│   ├── npc/              # NPC base, config, locomotion, registry, states/
│   ├── ipc/              # TCP IPC server + command handlers (OpenCode control layer)
│   ├── physics/          # bump backend behind Collider/World
│   ├── emitters/         # Low-level emitter engines (sprite_emitter, mesh_ribbon_emitter)
│   ├── fx/               # One-shot particle effect presets
│   ├── ui/               # Slab menu UI, map list, lives HUD, overlays
│   └── utils/            # str, tbl, utils, rect, signal, json, log, profile, settings, event_bus, asset_manager, physics_tolerance
├── res/
│   ├── map/              # Tiled .tmj sources (run directly; exported .lua maps are legacy)
│   ├── bg/               # Parallax background presets (image-layer .tmj)
│   ├── entities/           # Tiled object templates (.tj) and tilesets (.tsj)
│   ├── img/              # Textures
│   ├── snd/              # Sound effects
│   └── fnt/              # Fonts
└── tests/                # Headless unit/integration + headed e2e tests (see tests/README.md)
```

---

## 3. Core Subsystems & Module Breakdown

### 3.1 Core & Entrypoint (`src/main.lua`, `conf.lua`)
* **`main.lua`**: Loads all globals (`conf`, `utils`, `Vector`, `Class`, `Camera`, `Tween`, `Slab`, `World`, `Entity`, `Map`, `Player`, `Game`, …), parses CLI flags (`debug`, `drawphysics`, `profile`, `map=<file>`), creates `Game()` in `love.load`.
* **`conf.lua`**: LÖVE config (window, modules, save identity).

### 3.2 Game Object & State Machine (`src/game.lua`, `src/states/`)
* **`Game`**: Holds a `StateMachine` (`stateClasses = GameStates`, `entity = self`, `currentState = 'MenuState'`). Delegates all LÖVE callbacks (`update`, `draw`, `keypressed`, …) to `self.fsm`.
* **States** (`src/states/`, one file per state):
  * **`MenuState`**: Slab-based map list (`MapList`), handles keyboard/gamepad/mouse/touch to start a map or quit.
  * **`InGameState`**: Loads map via `Map:new()`, creates `World`, `AutoCamera`, spawns 2 `Player` entities at `spawn` objects, manages shared lives pool (`Lives`), handles player death/respawn/game-over, camera framing.
  *   **`GameOverState`**: Simple menu (Restart / Main Menu) with keyboard/gamepad/mouse/touch input.

### 3.3 Map & Entity Loading (`src/map/`)
* Wraps **STI**; `.tmj` maps are parsed directly via `src/map/tmj.lua` (then fed to `sti(data, {"box2d"})`) and proxied via `utils.proxyClass`.
* **Object Layers → Entities**: Iterates object layers; for each object with `type` not in `typeIgnores = {'', 'spawn'}`, `require('src.entities.' .. type)(object)` and inserts into `layer.entities`.
* **Ladders**: Authored as per-rung template objects (each 32px gid tile, bottom-anchored: `object.y` is the rung's bottom edge). `entity_factory.lua` runs `ladder_merger.lua` per layer to group rungs by column + vertical contiguity into one logical ladder rect, flagging the lowest rung as the family lead. `src/entities/ladder.lua` builds the merged collider/sprite stack on the lead rung; upper rungs are thin aliases. `Ladder:switch` hides (`off`) / restores (`on`) the ladder while keeping its grown size.
* **Layer Update/Draw**: Injects `update(dt)` and `draw()` onto each object layer to iterate its entities.
* **Collision**: Reads layer property `collision=true` to create static physics bodies from ground/tile layers.
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
  * **`Collider`**: Physics body wrapper (delegates to the bump backend via `src/physics/bump/collider.lua`).
  * **`Sprite`**: Animated sprite sheets (frame count, duration, loop, offset, facing).
  *   **`StateMachine`**: Generic FSM; accepts `states` (instances) or `stateClasses` (instantiated & wired to `entity`); unknown method calls proxy to `currentState`.
  * **`Inventory`**: Simple item count map (`addItems`, `hasItem`, `removeItem`).
  * **`Pickup`**: Marks entity as collectible (`itemName`, `itemCount`); player `Inventory` picks up on contact.
  * **`Usable`**: Interaction target (`canUse(player)`, `use(player)`).
  * **`UsableSparkle`**: Gentle sparkles hovering over a usable while a player is in range (auto-attached by `Usable`).
  * **`Switchable`**: gate an entity on/off driven by a linked switch's state (`:switch(switch, user)`, `enabled` default true).
  * **`Variable`**: Named value storage for map-triggered logic.
  * **`Flash`**: Timed visibility toggling (spawn/respawn blink).
  * **`Sound`**: Plays sound effects via the Sound manager.
  * **`Tint`**: Color tint applied to a sprite.
  * **`Pushable`**: Mark an entity as pushable (moves with push logic).
  * **`SpeedStreak`**: Motion-stretch sprite effect.
  * **`Timeline` / `Path` / `PathFollow`**: Scripted movement along waypoints.

### 3.6 Player (`src/player/`)
* **`Player`** (`player.lua`): Extends `Entity`; two instances (index 1 = dog/arrows+RShift, index 2 = cat/WASD+Q + gamepad).
*   **Components**: `Collider` (kinematic, fixed rotation), `StateMachine` (animation states: idle/walk/fall/climb), `StateMachine` (movement states: `WalkIdleState`, `LadderState`, `FallState`, `DeadState`), `Inventory`, `SafePosition`.
*   **Input**: `isDown(action)` maps actions to keys/gamepad per player index.
*   **Safe Position**: Tracks last fully-supported ground position for respawn (`SafePosition` module).
*   **Death/Respawn**: `die(deathType)` → `DeadState` → flash → `resolveDeath()` signals `InGameState` → `respawn()` teleports to safe position + spawn flash.

### 3.7 Physics (`src/physics/`)
* **`World`**: Thin wrapper over the bump world; `newCollider`, `update(dt)`, `draw()`, `queryRectangleArea`, `queryBounds`.
* **`Collider`**: Unified API (`setPosition`, `getBounds`, `setType`, `setSensor`, `setGroupIndex`, callbacks: `enter`, `exit`, `preSolve`, `postSolve`).
* **Bump Backend** (`src/physics/bump/`): `bump.lua` world; emulates Box2D-ish semantics (slide response, sensor cross, group-index filtering, kinematic cross). The Box2D/love backend was removed for implementing too little of the Collider contract to actually run the game; re-add it as a real, fully-implemented backend if ever needed.

### 3.8 Map Entities (`src/entities/`)
* **Convention**: New entity = new file `src/entities/<type>.lua` + Tiled object with matching `type`.
* **Sprite data**: art (frames, duration, loop, playing, scaleX/scaleY) is authored in `res/entities/<type>.tj` and merged into the object at load; the sprite `image` comes from the template's inline tileset tile (`tilesetImage`, injected into `object.properties.image` by both `tmj.lua parseObject` and `entity_factory:_mergeTemplateProps`). Entities read the merged props via `src/entities/sprite_props.lua` (`SpriteProps.fromObject(object)`), keeping sprite bodies free of art literals. `entity_factory` auto-applies a template's defaults to template-less runtime-mock objects (replicator spawns, cage NPCs, IPC spawns).
* **Examples**: `key`, `cage`, `switch`, `exit_door`, `ladder`, `kill_zone`, `jump_pad`, `teleport`, `bird`, `coin`, `variable`, `story`.
* **`story`**: invisible trigger; shows a screen-space typewriter speech bubble on `use` (see CONTEXT.md 'Story entity').
* **Map Hooks**: Tiled object properties may contain Lua snippets (`onUse`, `onTrigger`, etc.) executed via `object:exec`.

### 3.9 UI (`src/ui/`)
* **`MapList`**: Slab-based scrollable map selector.
* **`LivesHud`**: Draws heart squares top-center from `Lives` count.

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
            → Tmj.parse (.tmj) → STI loads map
            → createEntities() → annotateLadders (merge per-rung objects) → require('src.entities.<type>') for each object
            → createStaticPhysicsBodies (collision layers)
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

6. **Physics**: Go through `Collider`/`World`, not `src.physics.bump` directly, unless the task is backend-specific. The bump backend emulates Box2D-ish semantics (slide response, sensor cross, group-index filtering, kinematic cross).

7. **Match Nearby Style**: Quotes, indentation — it's mixed. Keep changes small; prefer new entities/components/states over growing `src/states/`.

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
1. Create class in `src/states/<name>_state.lua` (one file per state) following `MenuState`/`InGameState` pattern.
2. Add to returned `GameStates` table.
3. Transition via `game:setGameState('NewStateName')`.

---

## 7. Validation & Testing

* **Headless Tests**: `./test-unit.sh` (or `./test-unit.sh tests/unit/specific_test.lua`) — runs `tests/unit/run.lua`; no LÖVE window. `./test-integration.sh` runs the real stack through a love mock; `./test-e2e.sh` runs with a real window and frame capture. Add a test when practical for logic changes.
* **Gameplay Checks**: Targeted manual run, e.g. `love . debug drawphysics map=sandbox`.
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
| `src/game.lua` | Top-level Game object, state FSM (wires `src/states/` stateClasses) |
| `src/map.lua` | Thin STI wrapper, delegates to `src/map/init.lua` |
| `src/map/init.lua` | Map class: STI/JSON loading, entities, collisions, boundaries |
| `src/map/tmj.lua` | JSON map parser (the only loader), resolves `.tj` templates / `.tsj` tilesets, path-normalises `file`-typed props (`format_path`) |
| `src/map/entity_factory.lua` | Tiled object → runtime entity instantiation, ladder annotation |
| `src/map/ladder_merger.lua` | Pure per-rung → merged ladder rect grouping |
| `src/map/collision_builder.lua` | Static bodies from collision layers + map boundaries |
| `src/entities/ladder.lua` | Per-rung ladder entity (lead builds merged rect, aliases, switch on/off) |
| `src/camera.lua` | Auto-zoom camera framing all players |
| `src/entity.lua` | Base entity + component lifecycle |
| `src/components/` | Reusable components (Collider, Sprite, StateMachine, Inventory, Pickup, Usable, …) |
| `src/entities/` | Map entity implementations (type → file) |
| `src/player/` | Player entity, movement states, lives, safe position |
| `src/physics/` | bump backend behind Collider/World |
| `src/ui/` | Slab menu UI, map list, lives HUD |
| `res/map/` | Tiled `.tmj` sources (run directly) |
| `tests/` | Three-tier: `tests/unit` + `tests/integration` (via `./test-unit.sh`/`./test-integration.sh`), `tests/e2e` |
| `NOTES.md` | Design decisions & grill notes (former ADRs) |

---

## 10. Decision Index

* **Snap alignment** — Deterministic pushable motion & snap model (tile-perfect hole filling, pressure-plate seating)
* **Level generation** — Solution-first level generation with modular puzzle-rule library (guaranteed solvability by construction)

*(See `NOTES.md` for decisions; older ADRs were consolidated there.)*

---

## 11. Gotchas

* `makelove.toml` `love_files` uses shallow globs (`./src/*`, `./res/*`); verify nested files are included if touching packaging.
* Controls: P1 arrows + right-shift (use); P2 WASD + Q; joystick axes + button 1.
* Map code in Tiled object properties (`object:exec`) is trusted — never feed it user input.