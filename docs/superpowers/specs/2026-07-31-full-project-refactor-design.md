# Full Project Refactor: Modular Architecture for Fido & Kitch

**Date:** 2026-07-31  
**Scope:** Complete codebase reorganization for modularity, extensibility, and AI agent support

---

## Problem Statement

The codebase has grown several monolithic files that violate single responsibility:

| File | Lines | Issues |
|------|-------|--------|
| `src/entity.lua` | 78 | O(N) component lookups, no lifecycle hooks |
| `src/map.lua` | 460 | STI wrapper + entity factory + collision builder + parallax renderer |
| `src/game_states.lua` | 463 | 3 game states mixed; dead `suit` UI code |
| `src/player/player.lua` | 375 | God class: movement, sensors, death, inventory, animation all coupled |
| `src/input/input_manager.lua` | 187 | Duplicate `isForcedNonGamepad` methods |

Missing infrastructure:
- No texture/asset cache (entities reload images on spawn)
- No global event bus (tight `deathSignal` coupling)
- IPC missing: `LOAD_MAP`, `TAKE_SCREENSHOT`, `GET_TILE_GRID`, `SPAWN_ENTITY`, `STEP_FRAMES`

Approved NPC work (from `2026-07-31-npc-sprite-fix-and-rename-design.md`):
- Rename `src/enemy/` → `src/npc/`
- Fix sprite positioning, add idle/walk animations to base class

---

## Design Overview

### Guiding Principles
1. **Minimal & modular** — each file has single responsibility
2. **Preserve conventions** — globals intentional, flat entity structure, OCS pattern
3. **Test-driven** — every phase verified by existing test tiers
4. **AI agent ready** — extended IPC, event bus for decoupled hooks

---

## Phase 1: Entity/Component Core (`src/entity.lua`)

### Changes
- Add `componentsByType` map for O(1) `getComponent(type)`
- Add lifecycle hooks: `onAttach(entity)`, `onDetach()`, `onDestroy()`
- Keep `components` array for ordered update/draw iteration
- Fallback linear search for `utils.instanceOf` queries (legacy support)

### API
```lua
Entity:addComponent(component, name?)  -- name optional, used as key
Entity:getComponent(typeOrName)         -- O(1) via componentsByType
Entity:removeComponent(nameOrType)
Entity:update(dt)                       -- calls component:update(dt)
Entity:draw()                           -- calls component:draw()
Entity:destroy()                        -- calls component:onDestroy()
```

### Verification
- `./test-unit.sh` passes
- New test: `tests/unit/entity_lifecycle_test.lua`

---

## Phase 2: Map System (`src/map/` → 4 modules)

### Module Breakdown
| Module | Responsibility |
|--------|----------------|
| `init.lua` | Map class, STI loading, public API, background map |
| `entity_factory.lua` | Tiled object → runtime entity (`loadEntity`, `createEntitiesFromObjectGroupLayers`) |
| `collision_builder.lua` | Static bodies (tile/object layers), ladder sensors, map boundaries |
| `parallax_renderer.lua` | Background image layers, parallax math, screen-space draw |

### Key Changes
- Remove all dead/commented code (lines 90-112, 130-137, 227-234 in current `map.lua`)
- `Map:new()` delegates to factory/builder modules
- `Map:draw2()` delegates to `parallax_renderer`

### Verification
- `./test-integration.sh` — all 73 tests pass (0 golden failures)
- `tests/integration/tmx_golden_test.lua` passes

---

## Phase 3: Game States + Player Decoupling

### 3.1 Game States (`src/states/`)
| File | Responsibility |
|------|----------------|
| `menu_state.lua` | MapList, input handling, start game |
| `ingame_state.lua` | Level runtime, lives HUD, death handling, camera easing |
| `game_over_state.lua` | Restart/Menu options |

- Remove all dead `suit` UI commented code
- Update `src/game.lua` to require from `src.states`

### 3.2 Player (`src/player/`)
| Module | Responsibility |
|--------|----------------|
| `player.lua` | Bootstrap: components, signals, animation FSM, movement FSM |
| `player_sensors.lua` | `queryKillZone`, `queryLadder`, `queryLadderBelow`, `queryOnGround`, `queryFullySupported` |
| `player_movement.lua` | Horizontal movement math, jump/climb velocity, bounce, edge cases |
| `player_states.lua` | FSM states (WalkIdle, Fall, Ladder, Dead, Wrapped) — unchanged |
| `safe_position.lua` | Safe position tracking — unchanged |
| `ground_support.lua` | `isFullySupported` — unchanged |

### Verification
- `./test-integration.sh` passes
- `./test-e2e.sh` passes (visual physics checks)

---

## Phase 4: Input + Infrastructure

### 4.1 Input Manager Cleanup
- Remove duplicate `isForcedNonGamepad` (lines 175-181)
- Ensure all states use `InputManager:wasPressed(idx, action)` uniformly

### 4.2 Asset Manager (`src/utils/asset_manager.lua`)
```lua
local AssetManager = { textures = {} }
function AssetManager.getImage(path)
    if not AssetManager.textures[path] then
        AssetManager.textures[path] = love.graphics.newImage(path)
    end
    return AssetManager.textures[path]
end
```
- Entities use `AssetManager.getImage()` instead of `love.graphics.newImage()`

### 4.3 Event Bus (`src/utils/event_bus.lua`)
```lua
local EventBus = { signals = {} }
function EventBus.emit(name, ...) ... end
function EventBus.on(name, fn) ... end
function EventBus.off(name, fn) ... end
```
- Global signals: `player_died`, `item_collected`, `objective_unlocked`, `level_complete`
- Replace direct `deathSignal:connect()` with `EventBus.on('player_died', ...)`

### 4.4 Extended IPC (`src/ipc/command_handlers.lua`, `game_api.lua`)
| Command | Args | Response |
|---------|------|----------|
| `LOAD_MAP` | `<map_name>` | `OK: Loaded <map>` |
| `TAKE_SCREENSHOT` | `[filename]` | `OK: Screenshot saved to ...` |
| `GET_TILE_GRID` | — | JSON: 2D matrix (0=empty, 1=solid, 2=ladder, 3=killzone) |
| `SPAWN_ENTITY` | `<type> <x> <y> [props_json]` | `OK: Spawned <type> at x,y` |
| `STEP_FRAMES` | `<count>` | `OK: Stepped N frames` |

- Update `.opencode/tools/fido-kitch-ipc.ts` with new tools

### Verification
- `./test-all.sh` — all 3 tiers green
- Manual IPC test: `./run.sh ipc map=sandbox` + new commands

---

## Phase 5: NPC System (from approved design)

### 5.1 Rename `src/enemy/` → `src/npc/`
```
src/enemy/                    →  src/npc/
├── enemy.lua                 →  npc.lua
├── enemy_states.lua          →  npc_states.lua
├── enemy_brain.lua           →  npc_brain.lua
└── web.lua                   →  web.lua (unchanged)
```
- Class: `Enemy` → `NPC`
- Module paths: `src.enemy.*` → `src.npc.*`

### 5.2 NPC Base Class (`src/npc/npc.lua`)
- Pass `sprite=self.animations` to Collider for position sync
- Add idle/walk animation StateMachine
- Remove `NPC:draw()` — `Entity.draw()` renders animations

### 5.3 NPC States (`src/npc/npc_states.lua`)
- Drive `animations:setState('idle'/'walk')` in Chase/Wander/Climb/Stunned
- Face movement direction via `setFacing()`

### 5.4 Derived Classes
- `spider.lua`, `robot.lua` inherit from `NPC`
- Call `Entity.draw(self)` in `draw()`
- Pass `idleImage` prop (future: `walkImage`)

### 5.5 Update All Imports
- Grep `src.enemy` → `src.npc` across codebase + tests

### Verification
- `./test-integration.sh` passes
- Visual check: sprites on colliders, facing flips, idle/walk states

---

## File Structure After Refactor

```
src/
├── main.lua                 # unchanged (globals bootstrap)
├── game.lua                 # updated: require states from src.states/
├── entity.lua               # +componentsByType, +lifecycle hooks
├── camera.lua               # unchanged
├── world.lua                # unchanged (backend proxy)
├── map.lua                  # → src/map/init.lua (thin wrapper)
├── map/
│   ├── init.lua             # Map class, STI load, background
│   ├── entity_factory.lua   # object layer → entities
│   ├── collision_builder.lua # static bodies, ladders, boundaries
│   ├── parallax_renderer.lua # background parallax draw
│   ├── tmx.lua              # unchanged
│   └── tmx_template.lua     # unchanged
├── states/
│   ├── menu_state.lua
│   ├── ingame_state.lua
│   └── game_over_state.lua
├── player/
│   ├── player.lua           # thin bootstrap
│   ├── player_sensors.lua   # NEW: all spatial queries
│   ├── player_movement.lua  # NEW: movement math
│   ├── player_states.lua    # unchanged
│   ├── safe_position.lua    # unchanged
│   └── ground_support.lua   # unchanged
├── npc/                     # RENAMED from enemy/
│   ├── npc.lua              # base class with animations
│   ├── npc_states.lua       # animation-driven states
│   ├── npc_brain.lua        # unchanged
│   └── web.lua              # unchanged
├── components/
│   ├── collider.lua         # unchanged
│   ├── state_machine.lua    # unchanged
│   └── ...                  # unchanged
├── input/
│   ├── input_manager.lua    # deduped
│   └── action_map.lua       # unchanged
├── ipc/
│   ├── init.lua             # unchanged
│   ├── server.lua           # unchanged
│   ├── command_handlers.lua # +5 new commands
│   └── game_api.lua         # +helpers for new commands
└── utils/
    ├── asset_manager.lua    # NEW: texture cache
    ├── event_bus.lua        # NEW: global signals
    └── ...                  # unchanged
```

---

## Verification Matrix

| Phase | Command | Must Pass |
|-------|---------|-----------|
| 1 | `./test-unit.sh` | All unit tests |
| 2 | `./test-integration.sh` | All 73 integration tests (0 golden failures) |
| 3 | `./test-integration.sh` + `./test-e2e.sh` | Integration + E2E |
| 4 | `./test-all.sh` | All 3 tiers green |
| 5 | `./test-integration.sh` + visual | Integration + sprite rendering |

---

## Invariants Maintained

1. **Globals intentional** — `world`, `map`, `camera`, `game`, `conf`, `utils`, `Vector`, `Class`, `Tween`, `Slab`, `Entity`, `Map`, `Player`, `Game` remain globals
2. **Flat entity structure** — new entities in `src/entities/<type>.lua`; subdirs only when >1 file (ADR 0003)
3. **Deterministic physics** — tile-snap and pushable semantics preserved (ADR 0001)
4. **Trusted map code** — `object:exec` snippets remain trusted
5. **OCS pattern** — entities own components; no pure ECS migration

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Map golden tests break during split | Run `./test-integration.sh` after each module extraction; fix before proceeding |
| Player sensor extraction changes physics | E2E tests catch landing/ladder/climb regressions |
| IPC command handlers need game context | `game_api.lua` already has `game` reference; extend carefully |
| EventBus replaces direct signals | Migrate incrementally; keep `deathSignal` during transition |
| AssetManager breaks headless tests | `AssetManager.getImage` guards `love.graphics` existence |

---

## Out of Scope

- New sprite sheets / multi-frame animations (NPC walk frames)
- Patrol paths, idle pauses, edge detection for NPCs
- Friendly NPC types (bird refactor, new critters)
- Procedural levels, story entity, particle effects
- Game GUI overhaul

---

## Next Step

Upon approval: invoke `writing-plans` skill to create detailed implementation plan with task breakdown per phase.