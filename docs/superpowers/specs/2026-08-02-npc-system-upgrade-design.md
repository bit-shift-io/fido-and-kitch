# NPC System Upgrade Design

**Status:** Approved
**Date:** 2026-08-02

## Overview

Unify the two separate NPC architectures (follower NPCs: bird, rabbit; hostile NPCs: spider, robot) into a single, extensible system built on an Enhanced FSM with Utility Scoring. Add shared infrastructure for spawning, events, and physics interactions.

---

## 1. Architecture

### 1.1 Unified Base Class: `NPCBase`

Single base class at `src/npc/npc_base.lua` replacing:
- `src/npc/npc.lua` (hostile base)
- `src/components/npc_follow.lua` (follower component)

**Responsibilities:**
- Component composition: `Collider`, `Sprite/Animations`, `StateMachine`
- Physics: gravity, world collision, player sensor collision
- Config: unified Tiled property schema
- Lifecycle: spawn, despawn, respawn, death

### 1.2 Enhanced FSM with Utility Scoring

Current FSM → Enhanced FSM at `src/npc/npc_states_enhanced.lua`:

```lua
-- Each state provides:
State = {
  utility = function(entity, dt) -> number (0-1),  -- score for this state
  canEnter = function(entity) -> boolean,          -- hard gate
  enter = function(entity),                        -- setup
  exit = function(entity),                         -- cleanup
  update = function(entity, dt)                    -- behavior
}
```

**State Selection:**
- Each frame: evaluate `utility()` for all valid states (`canEnter == true`)
- Pick highest score; hysteresis threshold (0.1) prevents oscillation
- Fallback: `IdleState` (utility = 0.01)

**States:**
| State | Purpose | Utility Factors |
|-------|---------|-----------------|
| `IdleState` | Stand still | Low baseline |
| `WanderState` | Patrol home range | Distance from home, no targets |
| `ChaseState` | Pursue target | Target distance, visibility, ban timer |
| `ClimbState` | Use ladders | Vertical delta to target, ladder presence |
| `FollowState` | Follow player (ex-followers) | Follow distance, target player index |
| `FleeState` | Run from threat | Threat proximity, health |
| `StunnedState` | Stunned | Timer > 0 |
| `DeadState` | Dead/respawning | Is dead |

### 1.3 NPC Types via Composition

New NPC types = `NPCBase` + config + optional custom states:

```lua
-- BirdNPC (follower)
local BirdNPC = Class{__includes = NPCBase}
function BirdNPC:init(object)
  NPCBase.init(self, object, {
    movementType = 'fly',
    followDistance = 4,
    maxSpeed = 120,
    gravityScale = 0,
    states = {FollowState, IdleState, FleeState, StunnedState, DeadState}
  })
end

-- Robot (hostile)
local Robot = Class{__includes = NPCBase}
function Robot:init(object)
  NPCBase.init(self, object, {
    movementType = 'walk',
    chaseRange = 8,
    wanderRange = 60,
    shoveSpeed = 40,
    states = {ChaseState, WanderState, ClimbState, IdleState, StunnedState, DeadState}
  })
end
```

---

## 2. Physics Interactions

### 2.1 Mutual Pushing/Shoving
- Mass-based pushing: `Collider.mass` property (default: 1)
- `NPCBase:applyShove(other, force)` — symmetric for NPC↔NPC, NPC↔Player
- Robot's `shoveSpeed` → config `shoveForce`

### 2.2 World Interaction
- **Platforms**: NPCs ride moving platforms (collider velocity sync)
- **Pressure switches**: NPC weight triggers switches (`collider.walkable = true` for NPCs)
- **Drawbridges**: NPCs fall through when open, walk when closed
- **Edges**: NPCs detect ledges via `queryLadderBelow` / raycast, turn around or fall

### 2.3 Sensor/Trigger Interaction
- Kill zones: `PlayerSensors.queryKillZone` works on any entity with collider
- Ladders: `queryLadder`/`queryLadderBelow` work on NPCs
- Teleporters: Trigger on NPC overlap

---

## 3. Shared Infrastructure

### 3.1 NPC Registry (`src/npc/npc_registry.lua`)

```lua
NPCRegistry = {
  -- Spawn/despawn
  spawn = function(type, x, y, props) -> entity
  despawn = function(entity)
  despawnAll = function()

  -- Queries
  getAll = function() -> entities[]
  getNearby = function(x, y, radius) -> entities[]
  getByType = function(type) -> entities[]

  -- Pooling (optional, for performance)
  acquire = function(type) -> entity
  release = function(entity)
}
```

- Central point for dynamic spawning (spawners, events)
- Tracks all live NPCs for debugging, save/load
- Integrates with `Entity.queueRemove()` / `queueDestroy()`

### 3.2 Event-Driven Lifecycle

Events emitted via `EventBus`:
| Event | Payload |
|-------|---------|
| `npc_spawned` | `{entity, type, x, y}` |
| `npc_despawned` | `{entity, type}` |
| `npc_state_changed` | `{entity, oldState, newState}` |
| `npc_died` | `{entity, type, deathType, killer}` |
| `npc_respawned` | `{entity, type}` |

Consumers: quest system, achievements, audio, UI, level logic.

### 3.3 Unified Tiled Property Schema

Standard properties (all optional, with defaults in `NPCConfig`):

```lua
NPCConfig = {
  -- Movement
  speed = 70,
  maxSpeed = 120,
  gravityScale = 1,
  movementType = 'walk',  -- 'walk', 'fly', 'hop', 'swim'
  
  -- Behavior ranges (in tiles)
  chaseRange = 8,
  wanderRange = 60,
  followDistance = 4,
  fleeRange = 6,
  
  -- Physics
  mass = 1,
  canClimb = true,
  canSwim = false,
  pushable = true,
  
  -- Combat
  health = 1,
  stunDuration = 10,
  shoveForce = 40,
  chaseBanTime = 10,
  
  -- Visuals
  idleImage = 'res/img/npc_spider.png',
  walkImage = nil,  -- defaults to idleImage
  color = {1, 1, 1, 1},
  
  -- State config
  states = nil,  -- custom state list (class refs)
}
```

---

## 4. Migration Plan

### 4.1 Deprecate Files
| Old File | Replacement |
|----------|-------------|
| `src/npc/npc.lua` | `src/npc/npc_base.lua` |
| `src/npc/npc_states.lua` | `src/npc/npc_states_enhanced.lua` |
| `src/components/npc_follow.lua` | `FollowState` in enhanced states |

### 4.2 Migrate Existing NPCs

**BirdNPC** (`src/entities/bird_npc.lua`):
- Inherit `NPCBase`
- Config: `movementType='fly'`, `gravityScale=0`, `followDistance=4`, `maxSpeed=120`
- States: `FollowState`, `IdleState`, `FleeState`, `StunnedState`, `DeadState`

**RabbitNPC** (`src/entities/rabbit_npc.lua`):
- Inherit `NPCBase`
- Config: `movementType='hop'`, `gravityScale=1`, `followDistance=2`, `maxSpeed=80`
- States: `FollowState`, `IdleState`, `FleeState`, `StunnedState`, `DeadState`

**Spider** (`src/entities/spider.lua`):
- Inherit `NPCBase` (already does via `NPC`)
- Add `wrap` custom state or keep custom logic in `update()`
- Config: `movementType='walk'`, `canClimb=true`, `chaseRange=8`

**Robot** (`src/entities/robot.lua`):
- Inherit `NPCBase` (already does via `NPC`)
- Config: `shoveForce=40`, `chaseBanTime=10`
- States: `ChaseState`, `WanderState`, `ClimbState`, `IdleState`, `StunnedState`, `DeadState`

### 4.3 New NPC Types (Examples)
- `PatrolNPC`: Waypoint-following (new `PatrolState`)
- `TurretNPC`: Stationary, shoots projectiles (`TurretState`)
- `BossNPC`: Multi-phase, custom states

---

## 5. Testing Strategy

### 5.1 Unit Tests (`tests/unit/npc/`)
- `npc_base_test.lua`: Construction, config, component wiring
- `npc_states_enhanced_test.lua`: Utility scoring, transitions, hysteresis
- `npc_registry_test.lua`: Spawn, despawn, queries, pooling
- `npc_config_test.lua`: Schema validation, defaults

### 5.2 Integration Tests (`tests/integration/npc/`)
- `physics_interactions_test.lua`: Pushing, platforms, switches, sensors
- `follower_behavior_test.lua`: Follow, flee, teleport
- `hostile_behavior_test.lua`: Chase, wander, climb, stomp stun
- `spawn_despawn_test.lua`: Dynamic spawn, registry tracking

### 5.3 E2E Tests (`tests/e2e/npc/`)
- Visual verification of NPC behaviors
- Multi-NPC scenarios (separation, flocking)
- Player-NPC combat flow

---

## 6. Consequences

### Positive
- Single NPC architecture to learn/maintain
- New NPC types in ~50 lines (config + optional custom state)
- Dynamic spawning enables procedural content, spawners
- Event-driven lifecycle integrates with game systems
- Physics interactions consistent across all NPCs

### Costs
- Migration effort for 4 existing NPC types
- Enhanced FSM adds utility evaluation per frame (negligible)
- Registry adds global state (mitigated: single module, testable)

### Risks
- Utility scoring tuning: may need iteration per NPC type
- Follower "orbit" behavior → `FollowState` must replicate current feel
- Physics edge cases: NPC-on-NPC stacking, platform sync

---

## 7. Rollback Plan

If issues arise:
1. Keep old files during transition (feature flag: `conf.useNewNPC = true`)
2. Run both systems in parallel for comparison
3. Revert `conf.useNewNPC = false` to restore old behavior

---

## 8. Future Extensions (Out of Scope)

- Behavior trees for complex NPCs
- NPC-NPC communication (flocking, formations)
- Scripting/moddable behaviors via Lua files
- Navmesh/pathfinding for complex geometry
- Save/load NPC state for checkpoints
