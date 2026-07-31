# NPC Sprite Rendering Fix + Idle/Walk Animations + Rename

**Date:** 2026-07-31  
**Scope:** Incremental improvement to existing enemy system

---

## Problem Statement

1. **Sprites don't render at correct positions** — The `Enemy` base class creates a `Collider` without passing the `sprite` reference, so the collider's internal `update(dt)` never calls `sprite:setPositionV()`. Sprites stay at (0,0).

2. **Placeholder rectangle drawn over sprites** — `Enemy:draw()` draws a colored quad that would override sprites if called.

3. **No animation states** — Enemies use a single static frame (`frames=1`) with no idle/walk transitions.

4. **Naming inconsistency** — The `bird` entity doesn't use the `Enemy` base class, and future friendly NPCs are planned. The directory/module name `enemy` is misleading.

---

## Solution Overview

Rename `src/enemy/` → `src/npc/`, fix sprite positioning in the base class, add idle/walk animation states driven by the existing FSM, and update derived classes (spider, robot) to use the base class animations.

---

## Detailed Design

### 1. Directory & File Rename

```
src/enemy/                    →  src/npc/
├── enemy.lua                 →  npc.lua
├── enemy_states.lua          →  npc_states.lua
├── enemy_brain.lua           →  npc_brain.lua
└── web.lua                   →  web.lua (unchanged, spider-specific)
```

- Class: `Enemy` → `NPC`
- Module paths: `src.enemy.*` → `src.npc.*`
- All imports in `spider.lua`, `robot.lua`, tests, and any other files updated

### 2. NPC Base Class (`src/npc/npc.lua`)

**Changes to `NPC:init()`:**

```lua
function NPC:init(object, props)
    -- ... existing setup (speed, bans, wander, stun, color, etc.) ...

    -- Create animations StateMachine with idle/walk states
    local shape_args = {0, 0, object.width, object.height}
    local idle_image = props.idleImage or 'res/img/enemy_spider.png'
    local walk_image = props.walkImage or idle_image  -- fallback to idle for now

    local animations = {
        idle = Sprite{
            image = idle_image,
            frames = 1,
            duration = 1.0,
            loop = false,
            shape_arguments = shape_args,
        },
        walk = Sprite{
            image = walk_image,
            frames = 1,
            duration = 1.0,
            loop = false,
            shape_arguments = shape_args,
        },
    }

    self.animations = self:addComponent(StateMachine{
        states = animations,
        entity = self,
        currentState = 'idle',
    })

    -- Pass animations to Collider for automatic position sync
    self.collider = self:addComponent(Collider{
        shape_type = 'rectangle',
        shape_arguments = shape_args,
        body_type = 'dynamic',
        position = position,
        fixedRotation = true,
        sprite = self.animations,  -- KEY FIX: position syncs automatically
    })
    -- ... rest of existing collider setup ...
end
```

**Remove `NPC:draw()` entirely** — `Entity.draw()` will call `animations:draw()` via component iteration.

**Keep `NPC:update(dt)`** — calls `Entity.update()`, ticks bans, checks for stomp (unchanged).

### 3. NPC States (`src/npc/npc_states.lua`)

**`ChaseState:update()` drives animation:**

```lua
function ChaseState:update(dt)
    local npc = self.entity

    if npc.fsm:tryTransition('ClimbState') then
        return
    end

    local target = npc:findTarget()
    local v_x, v_y = npc.collider:getLinearVelocity()

    if target == nil then
        npc.fsm:setState('WanderState')
        npc.animations:setState('idle')
        return
    end

    local npcX = npc.collider:getX()
    local targetX = target.collider:getX()
    local decision = NPCBrain.decideHorizontalMovement(npcX, targetX, npc.speed, npc.alignThreshold)
    npc.collider:setLinearVelocity(decision.velocityX, v_y)

    -- Drive animation from movement decision
    if decision.velocityX ~= 0 then
        npc.animations:setState('walk')
        -- Face movement direction
        local facing = decision.velocityX > 0 and 'right' or 'left'
        if npc.animations.currentState.setFacing then
            npc.animations.currentState:setFacing(facing)
        end
    else
        npc.animations:setState('idle')
    end
end
```

**`WanderState:update()` drives animation similarly:**

```lua
function WanderState:update(dt)
    local npc = self.entity

    if npc:findTarget() ~= nil then
        npc.fsm:setState('ChaseState')
        return
    end

    local v_x, v_y = npc.collider:getLinearVelocity()
    local npcX = npc.collider:getX()
    local decision = NPCBrain.decideWander(
        {direction = npc.wanderDirection},
        npcX,
        npc.homeX,
        npc.speed,
        npc.wanderRange,
        dt
    )
    npc.wanderDirection = decision.direction
    npc.collider:setLinearVelocity(decision.velocityX, v_y)

    if decision.velocityX ~= 0 then
        npc.animations:setState('walk')
        local facing = decision.velocityX > 0 and 'right' or 'left'
        if npc.animations.currentState.setFacing then
            npc.animations.currentState:setFacing(facing)
        end
    else
        npc.animations:setState('idle')
    end
end
```

**`ClimbState:update()` → `idle`** (climb animation can be added later):
```lua
function ClimbState:update(dt)
    -- ... existing climb logic ...
    npc.animations:setState('idle')
end
```

**`StunnedState:update()` → `idle`:**
```lua
function StunnedState:update(dt)
    -- ... existing stun timer logic ...
    npc.animations:setState('idle')
end
```

### 4. Derived Classes

#### `src/entities/spider.lua`
```lua
local NPC = require('src.npc.npc')
local NPCBrain = require('src.npc.npc_brain')
-- Sprite no longer needed here

local Spider = Class{__includes = NPC}

function Spider:init(object)
    NPC.init(self, object, {
        color = {0.15, 0.15, 0.15, 1},
        idleImage = 'res/img/enemy_spider.png',
        -- walkImage = 'res/img/enemy_spider_walk.png'  -- future
    })
    self.type = 'spider'
    self.wrapDuration = (object.properties and object.properties.wrapDuration) or DEFAULT_WRAP_DURATION
end

function Spider:draw()
    Entity.draw(self)  -- renders animations
end

function Spider:update(dt)
    NPC.update(self, dt)
    -- ... wrap logic unchanged ...
end
```

#### `src/entities/robot.lua`
```lua
local NPC = require('src.npc.npc')
local NPCBrain = require('src.npc.npc_brain')

local Robot = Class{__includes = NPC}

function Robot:init(object)
    NPC.init(self, object, {
        color = {0.55, 0.55, 0.6, 1},
        idleImage = 'res/img/enemy_blob.png',
        -- walkImage = 'res/img/enemy_blob_walk.png'  -- future
    })
    self.type = 'robot'
    self.shoveSpeed = (object.properties and object.properties.shoveSpeed) or DEFAULT_SHOVE_SPEED
    self.chaseBanTime = (object.properties and object.properties.chaseBanTime) or DEFAULT_CHASE_BAN_TIME
    self.chaseTimer = {target = nil, elapsed = 0}
end

function Robot:draw()
    Entity.draw(self)
end

function Robot:update(dt)
    NPC.update(self, dt)
    -- ... shove/chase-ban logic unchanged ...
end
```

### 5. Assets

- **Spider:** `res/img/enemy_spider.png` → used for `idle` (1 frame). Future: add `enemy_spider_walk.png` for walk frames.
- **Robot:** `res/img/enemy_blob.png` → used for `idle` (1 frame). Future: add `enemy_blob_walk.png` for walk frames.
- No new art required for this increment.

---

## Acceptance Criteria

1. **Sprites render at correct positions** — Spider and robot sprites appear centered on their colliders, not at (0,0).
2. **No placeholder rectangles** — No colored quads drawn over sprites.
3. **Idle animation** — When stationary (aligned with target or at wander edge), `idle` sprite shows.
4. **Walk animation** — When moving horizontally, `walk` sprite shows (currently same image, structured for future frames).
5. **Facing direction** — Sprites flip horizontally when moving left vs right.
6. **All existing behavior preserved** — Spider wrap, robot shove, chase bans, stomp stun, ladder climbing, wandering all work identically.
7. **Renamed imports work** — `require('src.npc.npc')`, `require('src.npc.npc_states')`, `require('src.npc.npc_brain')` resolve correctly.
8. **Tests pass** — Unit tests for `npc_brain` pass; integration tests for spider/robot behavior pass.

---

## Out of Scope

- New sprite sheets / multi-frame animations
- Patrol paths, idle pauses, edge detection
- Friendly NPC types (bird refactor, new critters)
- Bird entity changes (already separate)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Collider `sprite` position sync breaks existing physics | Verified in `bump/collider.lua:26-28` — only updates sprite position, no physics changes |
| Animation StateMachine conflicts with FSM | Separate components: `animations` (visual) vs `fsm` (behavior), same as player |
| Derived class `draw()` overrides base | Both spider/robot already call `Entity.draw(self)` — will render animations |
| Rename breaks external references | Grep for `src.enemy` before/after; update all found imports |

---

## Testing Strategy

1. **Unit:** `tests/unit/npc_brain_test.lua` (renamed from `enemy_brain_test.lua`) — all existing tests pass
2. **Integration:** `tests/integration/` — add spider/robot spawn + move tests if not present
3. **E2E:** Visual verification — run game, observe sprites on colliders, facing flips, idle/walk states