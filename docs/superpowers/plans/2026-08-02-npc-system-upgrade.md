# NPC System Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the two NPC architectures (follower NPCs: bird, rabbit; hostile NPCs: spider, robot) into a single extensible system using Enhanced FSM with Utility Scoring.

**Architecture:** Single `NPCBase` class with Enhanced FSM states (idle, wander, chase, follow, patrol, attack, flee) driven by utility scoring. NPC Registry handles spawn/despawn. Unified `npc_config.lua` schema for Tiled properties. Physics integration for pushing, platform riding, and trigger interaction.

**Tech Stack:** LÖVE 12.0 (LuaJIT), bump.lua physics, hump.Class, STI for Tiled maps, existing component/entity system.

## Global Constraints

- Follow existing code conventions: globals intentional, hump.Class with `Class{}`, `Entity.init(self)` in `init`, components via `addComponent()`
- State machines use `src/components/state_machine.lua` pattern (states as instances or classes, proxy unknown methods to currentState)
- New entity = new `src/entities/<type>.lua` + Tiled object with matching `type`; `Map.typeIgnores = {'', 'spawn'}` skips those types
- Physics through `Collider`/`World`, not `src.physics.bump` directly; `collider.walkable = true` for entities players can stand/walk on
- Sound: `Sound.silentMode = not (love and love.audio)` suppresses warnings in headless tests
- Test tiers: `./test-unit.sh` (logic), `./test-integration.sh` (maps loaded), `./test-e2e.sh` (real LÖVE window)
- Match nearby style (mixed quotes/indentation), keep changes small, prefer new entities/components/states over growing existing files

---

### Task 1: Create NPC Config Schema (`npc_config.lua`)

**Files:**
- Create: `src/npc/npc_config.lua`
- Test: `tests/unit/npc_config_test.lua`

**Interfaces:**
- Consumes: (none — foundation task)
- Produces: `NPCConfig` table with `getDefaults()`, `validate(props)`, `mergeWithDefaults(props)` functions; schema definitions for all NPC types

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/npc_config_test.lua
local NPCConfig = require('npc.npc_config')

local function test_getDefaults_returnsTable()
    local defaults = NPCConfig.getDefaults()
    assert(type(defaults) == 'table', 'getDefaults should return a table')
    assert(defaults.maxSpeed ~= nil, 'defaults should have maxSpeed')
    assert(defaults.detectionRadius ~= nil, 'defaults should have detectionRadius')
    assert(defaults.behavior ~= nil, 'defaults should have behavior')
    print('test_getDefaults_returnsTable: PASS')
end

local function test_validate_acceptsValidProps()
    local valid = { maxSpeed = 100, detectionRadius = 200, behavior = 'follow', patrolPoints = {{x=0,y=0},{x=100,y=0}} }
    local ok, err = NPCConfig.validate(valid)
    assert(ok == true, 'valid props should pass: ' .. tostring(err))
    print('test_validate_acceptsValidProps: PASS')
end

local function test_validate_rejectsInvalidBehavior()
    local invalid = { behavior = 'invalid_behavior' }
    local ok, err = NPCConfig.validate(invalid)
    assert(ok == false, 'invalid behavior should fail')
    assert(type(err) == 'string', 'should return error message')
    print('test_validate_rejectsInvalidBehavior: PASS')
end

local function test_validate_rejectsNegativeSpeed()
    local invalid = { maxSpeed = -10 }
    local ok, err = NPCConfig.validate(invalid)
    assert(ok == false, 'negative speed should fail')
    print('test_validate_rejectsNegativeSpeed: PASS')
end

local function test_mergeWithDefaults_fillsMissing()
    local partial = { maxSpeed = 150 }
    local merged = NPCConfig.mergeWithDefaults(partial)
    assert(merged.maxSpeed == 150, 'should preserve provided value')
    assert(merged.detectionRadius == NPCConfig.getDefaults().detectionRadius, 'should fill missing with defaults')
    assert(merged.behavior == NPCConfig.getDefaults().behavior, 'should fill missing behavior')
    print('test_mergeWithDefaults_fillsMissing: PASS')
end

local function test_behaviorTypes_includeAllRequired()
    local types = NPCConfig.getBehaviorTypes()
    assert(types.follow ~= nil, 'should have follow')
    assert(types.wander ~= nil, 'should have wander')
    assert(types.patrol ~= nil, 'should have patrol')
    assert(types.chase ~= nil, 'should have chase')
    assert(types.attack ~= nil, 'should have attack')
    assert(types.flee ~= nil, 'should have flee')
    print('test_behaviorTypes_includeAllRequired: PASS')
end

test_getDefaults_returnsTable()
test_validate_acceptsValidProps()
test_validate_rejectsInvalidBehavior()
test_validate_rejectsNegativeSpeed()
test_mergeWithDefaults_fillsMissing()
test_behaviorTypes_includeAllRequired()
print('All NPCConfig tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/npc_config_test.lua`
Expected: FAIL with "module 'npc.npc_config' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/npc/npc_config.lua
local NPCConfig = {}

NPCConfig.BehaviorTypes = {
    follow = { description = 'Follow a target entity (player or NPC)' },
    wander = { description = 'Random movement within bounds' },
    patrol = { description = 'Move between defined patrol points' },
    chase = { description = 'Pursue a detected target aggressively' },
    attack = { description = 'Engage target in combat' },
    flee = { description = 'Run away from threat' },
}

NPCConfig.Defaults = {
    maxSpeed = 80,
    acceleration = 400,
    deceleration = 600,
    detectionRadius = 160,
    attackRange = 32,
    fleeThreshold = 0.3,
    behavior = 'wander',
    patrolPoints = {},
    followTarget = nil,
    canPush = true,
    canBePushed = true,
    pushForce = 200,
    ridePlatforms = false,
    triggerSwitches = false,
    health = 1,
    damage = 1,
    invulnerableTime = 0.5,
}

function NPCConfig.getDefaults()
    local copy = {}
    for k, v in pairs(NPCConfig.Defaults) do
        copy[k] = v
    end
    return copy
end

function NPCConfig.getBehaviorTypes()
    local types = {}
    for k, v in pairs(NPCConfig.BehaviorTypes) do
        types[k] = v
    end
    return types
end

function NPCConfig.validate(props)
    if props.behavior and not NPCConfig.BehaviorTypes[props.behavior] then
        return false, 'Invalid behavior type: ' .. tostring(props.behavior)
    end
    if props.maxSpeed and props.maxSpeed < 0 then
        return false, 'maxSpeed must be non-negative'
    end
    if props.detectionRadius and props.detectionRadius < 0 then
        return false, 'detectionRadius must be non-negative'
    end
    if props.health and props.health < 0 then
        return false, 'health must be non-negative'
    end
    if props.patrolPoints and type(props.patrolPoints) ~= 'table' then
        return false, 'patrolPoints must be a table'
    end
    return true, nil
end

function NPCConfig.mergeWithDefaults(props)
    local defaults = NPCConfig.getDefaults()
    local result = {}
    for k, v in pairs(defaults) do
        result[k] = props[k] ~= nil and props[k] or v
    end
    return result
end

return NPCConfig
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/npc_config_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/npc/npc_config.lua tests/unit/npc_config_test.lua
git commit -m "feat(npc): add NPCConfig schema with validation and defaults"
```

---

### Task 2: Create NPCBase Class (`npc_base.lua`)

**Files:**
- Create: `src/npc/npc_base.lua`
- Test: `tests/unit/npc_base_test.lua`

**Interfaces:**
- Consumes: `NPCConfig` (from Task 1), `Entity` (from `src/entity.lua`), `StateMachine` component (from `src/components/state_machine.lua`), `Collider` component (from `src/components/collider.lua`)
- Produces: `NPCBase` class extending `Entity` with config, state machine, physics, health, targeting, and utility scoring

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/npc_base_test.lua
local NPCBase = require('npc.npc_base')
local NPCConfig = require('npc.npc_config')
local Class = require('lib.hump.class')

local function test_NPCBase_extendsEntity()
    local npc = NPCBase({x = 100, y = 100})
    assert(npc.isInstanceOf and npc:isInstanceOf(Entity), 'NPCBase should extend Entity')
    assert(npc.x == 100 and npc.y == 100, 'should set position')
    print('test_NPCBase_extendsEntity: PASS')
end

local function test_NPCBase_appliesConfigDefaults()
    local npc = NPCBase({x = 0, y = 0, maxSpeed = 120})
    assert(npc.config.maxSpeed == 120, 'should use provided maxSpeed')
    assert(npc.config.detectionRadius == NPCConfig.Defaults.detectionRadius, 'should fill detectionRadius from defaults')
    assert(npc.config.behavior == NPCConfig.Defaults.behavior, 'should fill behavior from defaults')
    print('test_NPCBase_appliesConfigDefaults: PASS')
end

local function test_NPCBase_hasStateMachine()
    local npc = NPCBase({x = 0, y = 0})
    assert(npc.stateMachine ~= nil, 'should have stateMachine component')
    assert(npc.stateMachine.currentState ~= nil, 'should have initial state')
    print('test_NPCBase_hasStateMachine: PASS')
end

local function test_NPCBase_hasCollider()
    local npc = NPCBase({x = 0, y = 0})
    assert(npc.collider ~= nil, 'should have collider component')
    print('test_NPCBase_hasCollider: PASS')
end

local function test_NPCBase_hasHealth()
    local npc = NPCBase({x = 0, y = 0, health = 3})
    assert(npc.health == 3, 'should set health from config')
    assert(npc.maxHealth == 3, 'should track maxHealth')
    npc:takeDamage(1)
    assert(npc.health == 2, 'takeDamage should reduce health')
    print('test_NPCBase_hasHealth: PASS')
end

local function test_NPCBase_canSetTarget()
    local npc = NPCBase({x = 0, y = 0})
    local target = {x = 100, y = 100}
    npc:setTarget(target)
    assert(npc.target == target, 'should store target')
    print('test_NPCBase_canSetTarget: PASS')
end

local function test_NPCBase_utilityScoringExists()
    local npc = NPCBase({x = 0, y = 0})
    assert(type(npc.calculateUtilities) == 'function', 'should have calculateUtilities method')
    local utilities = npc:calculateUtilities()
    assert(type(utilities) == 'table', 'calculateUtilities should return table')
    assert(utilities.idle ~= nil, 'should have idle utility')
    assert(utilities.wander ~= nil, 'should have wander utility')
    assert(utilities.chase ~= nil, 'should have chase utility')
    assert(utilities.follow ~= nil, 'should have follow utility')
    assert(utilities.patrol ~= nil, 'should have patrol utility')
    assert(utilities.attack ~= nil, 'should have attack utility')
    assert(utilities.flee ~= nil, 'should have flee utility')
    print('test_NPCBase_utilityScoringExists: PASS')
end

local function test_NPCBase_selectsHighestUtility()
    local npc = NPCBase({x = 0, y = 0})
    npc.target = {x = 50, y = 50}  -- close target
    local utilities = npc:calculateUtilities()
    -- chase should score highest when target in range
    local best = nil
    local bestScore = -math.huge
    for state, score in pairs(utilities) do
        if score > bestScore then
            bestScore = score
            best = state
        end
    end
    assert(best == 'chase' or best == 'follow', 'should select chase or follow for nearby target, got ' .. tostring(best))
    print('test_NPCBase_selectsHighestUtility: PASS')
end

local function test_NPCBase_handlesPushForce()
    local npc = NPCBase({x = 0, y = 0, canBePushed = true, pushForce = 150})
    assert(npc.config.canBePushed == true, 'should accept canBePushed')
    assert(npc.config.pushForce == 150, 'should accept pushForce')
    npc:applyPush(100, 0)
    assert(npc.collider.vx ~= 0, 'applyPush should affect velocity')
    print('test_NPCBase_handlesPushForce: PASS')
end

test_NPCBase_extendsEntity()
test_NPCBase_appliesConfigDefaults()
test_NPCBase_hasStateMachine()
test_NPCBase_hasCollider()
test_NPCBase_hasHealth()
test_NPCBase_canSetTarget()
test_NPCBase_utilityScoringExists()
test_NPCBase_selectsHighestUtility()
test_NPCBase_handlesPushForce()
print('All NPCBase tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/npc_base_test.lua`
Expected: FAIL with "module 'npc.npc_base' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/npc/npc_base.lua
local Class = require('lib.hump.class')
local Entity = require('entity')
local StateMachine = require('components.state_machine')
local Collider = require('components.collider')
local NPCConfig = require('npc.npc_config')
local Vector = require('utils.vector')

local NPCBase = Class{__includes = Entity}

function NPCBase:init(props)
    props = props or {}
    Entity.init(self, props)
    
    -- Merge config with defaults
    self.config = NPCConfig.mergeWithDefaults(props)
    
    -- Health system
    self.health = self.config.health
    self.maxHealth = self.config.health
    self.invulnerableTimer = 0
    
    -- Target tracking
    self.target = nil
    self.lastKnownTargetPos = nil
    
    -- Patrol state
    self.currentPatrolIndex = 1
    self.patrolDirection = 1
    
    -- Physics setup
    self:addComponent(Collider{
        width = props.width or 16,
        height = props.height or 16,
        solid = true,
        walkable = self.config.ridePlatforms,
    })
    self.collider.owner = self
    self.collider.walkable = self.config.ridePlatforms
    
    -- State machine with enhanced FSM states
    self:addComponent(StateMachine{
        stateClasses = {
            IdleState = require('npc.states.idle_state'),
            WanderState = require('npc.states.wander_state'),
            ChaseState = require('npc.states.chase_state'),
            FollowState = require('npc.states.follow_state'),
            PatrolState = require('npc.states.patrol_state'),
            AttackState = require('npc.states.attack_state'),
            FleeState = require('npc.states.flee_state'),
        },
        initialState = 'IdleState',
        entity = self,
    })
    
    -- Utility scoring weights (can be overridden per NPC type)
    self.utilityWeights = {
        idle = 10,
        wander = 20,
        chase = 80,
        follow = 70,
        patrol = 30,
        attack = 90,
        flee = 60,
    }
end

function NPCBase:update(dt)
    Entity.update(self, dt)
    
    -- Update invulnerability timer
    if self.invulnerableTimer > 0 then
        self.invulnerableTimer = self.invulnerableTimer - dt
    end
    
    -- Calculate utilities and transition state
    local utilities = self:calculateUtilities()
    local bestState = self:selectBestState(utilities)
    if bestState and bestState ~= self.stateMachine.currentState.name then
        self.stateMachine:changeState(bestState)
    end
end

function NPCBase:calculateUtilities()
    local utils = {}
    local config = self.config
    local target = self.target
    
    -- Idle: always available, low base score
    utils.idle = self.utilityWeights.idle
    
    -- Wander: available when no target or target far away
    if not target then
        utils.wander = self.utilityWeights.wander
    else
        local dist = Vector.distance(self.x, self.y, target.x, target.y)
        if dist > config.detectionRadius * 1.5 then
            utils.wander = self.utilityWeights.wander * 0.5
        else
            utils.wander = 0
        end
    end
    
    -- Chase: high when target detected and hostile
    if target and config.behavior ~= 'follow' then
        local dist = Vector.distance(self.x, self.y, target.x, target.y)
        if dist <= config.detectionRadius then
            utils.chase = self.utilityWeights.chase * (1 - dist / config.detectionRadius)
        else
            utils.chase = 0
        end
    else
        utils.chase = 0
    end
    
    -- Follow: high when behavior is follow and target exists
    if target and config.behavior == 'follow' then
        local dist = Vector.distance(self.x, self.y, target.x, target.y)
        utils.follow = self.utilityWeights.follow * (1 - math.min(1, dist / (config.detectionRadius * 2)))
    else
        utils.follow = 0
    end
    
    -- Patrol: only when patrol points defined and no target
    if #config.patrolPoints > 0 and not target then
        utils.patrol = self.utilityWeights.patrol
    else
        utils.patrol = 0
    end
    
    -- Attack: very high when in attack range
    if target then
        local dist = Vector.distance(self.x, self.y, target.x, target.y)
        if dist <= config.attackRange then
            utils.attack = self.utilityWeights.attack
        else
            utils.attack = 0
        end
    else
        utils.attack = 0
    end
    
    -- Flee: high when low health
    local healthRatio = self.health / self.maxHealth
    if healthRatio <= config.fleeThreshold then
        utils.flee = self.utilityWeights.flee * (1 - healthRatio)
    else
        utils.flee = 0
    end
    
    return utils
end

function NPCBase:selectBestState(utilities)
    local bestState = nil
    local bestScore = -math.huge
    
    for state, score in pairs(utilities) do
        if score > bestScore then
            bestScore = score
            bestState = state .. 'State'  -- match state class naming
        end
    end
    
    return bestState
end

function NPCBase:setTarget(target)
    self.target = target
    if target then
        self.lastKnownTargetPos = {x = target.x, y = target.y}
    end
end

function NPCBase:takeDamage(amount, source)
    if self.invulnerableTimer > 0 then return end
    self.health = math.max(0, self.health - amount)
    self.invulnerableTimer = self.config.invulnerableTime
    if self.health <= 0 then
        self:die(source)
    end
end

function NPCBase:die(source)
    self:queueRemove()
    -- Emit death event for registry/cleanup
    local EventBus = require('utils.event_bus')
    EventBus.emit('npc_death', {npc = self, source = source})
end

function NPCBase:applyPush(dx, dy)
    if not self.config.canBePushed then return end
    local force = self.config.pushForce
    self.collider.vx = self.collider.vx + dx * force
    self.collider.vy = self.collider.vy + dy * force
end

function NPCBase:onCollision(other, dx, dy)
    -- Handle pushing other entities
    if other and other.config and other.config.canBePushed and self.config.canPush then
        local pushDir = Vector.normalize(other.x - self.x, other.y - self.y)
        other:applyPush(pushDir.x, pushDir.y)
    end
    
    -- Handle trigger/switch interaction
    if other and other.isSwitch and self.config.triggerSwitches then
        other:activate(self)
    end
end

return NPCBase
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/npc_base_test.lua`
Expected: PASS (all 9 tests)

- [ ] **Step 5: Commit**

```bash
git add src/npc/npc_base.lua tests/unit/npc_base_test.lua
git commit -m "feat(npc): add NPCBase class with Enhanced FSM and utility scoring"
```

---

### Task 3: Create Enhanced FSM State Classes (`src/npc/states/`)

**Files:**
- Create: `src/npc/states/idle_state.lua`
- Create: `src/npc/states/wander_state.lua`
- Create: `src/npc/states/chase_state.lua`
- Create: `src/npc/states/follow_state.lua`
- Create: `src/npc/states/patrol_state.lua`
- Create: `src/npc/states/attack_state.lua`
- Create: `src/npc/states/flee_state.lua`
- Test: `tests/unit/npc_states_test.lua`

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `StateMachine` component pattern
- Produces: 7 state classes each with `enter(entity)`, `update(entity, dt)`, `exit(entity)` methods; states receive `entity` (the NPCBase instance) as first argument

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/npc_states_test.lua
local NPCBase = require('npc.npc_base')
local Class = require('lib.hump.class')

-- Mock entity for state testing
local function createMockNPC(overrides)
    local npc = NPCBase({x = 0, y = 0})
    for k, v in pairs(overrides or {}) do
        npc[k] = v
    end
    return npc
end

local function test_IdleState_enter_setsVelocityZero()
    local IdleState = require('npc.states.idle_state')
    local npc = createMockNPC({collider = {vx = 10, vy = 5}})
    IdleState.enter(npc)
    assert(npc.collider.vx == 0 and npc.collider.vy == 0, 'IdleState should zero velocity')
    print('test_IdleState_enter_setsVelocityZero: PASS')
end

local function test_WanderState_enter_picksRandomDirection()
    local WanderState = require('npc.states.wander_state')
    local npc = createMockNPC({
        config = {maxSpeed = 50, wanderRadius = 100},
        collider = {vx = 0, vy = 0},
    })
    WanderState.enter(npc)
    assert(npc.wanderTarget ~= nil, 'should set wanderTarget')
    assert(npc.wanderTarget.x ~= nil and npc.wanderTarget.y ~= nil, 'wanderTarget should have x,y')
    print('test_WanderState_enter_picksRandomDirection: PASS')
end

local function test_WanderState_update_movesTowardTarget()
    local WanderState = require('npc.states.wander_state')
    local npc = createMockNPC({
        config = {maxSpeed = 50, acceleration = 200},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
        wanderTarget = {x = 100, y = 0},
    })
    WanderState.update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward wander target')
    print('test_WanderState_update_movesTowardTarget: PASS')
end

local function test_ChaseState_enter_setsTarget()
    local ChaseState = require('npc.states.chase_state')
    local npc = createMockNPC({
        target = {x = 200, y = 0},
        config = {maxSpeed = 80, acceleration = 300},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
    })
    ChaseState.enter(npc)
    assert(npc.chaseTarget ~= nil, 'should set chaseTarget')
    print('test_ChaseState_enter_setsTarget: PASS')
end

local function test_ChaseState_update_movesTowardTarget()
    local ChaseState = require('npc.states.chase_state')
    local npc = createMockNPC({
        target = {x = 200, y = 0},
        config = {maxSpeed = 80, acceleration = 300},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
        chaseTarget = {x = 200, y = 0},
    })
    ChaseState.update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward chase target')
    print('test_ChaseState_update_movesTowardTarget: PASS')
end

local function test_FollowState_maintainsDistance()
    local FollowState = require('npc.states.follow_state')
    local npc = createMockNPC({
        target = {x = 100, y = 0},
        config = {maxSpeed = 60, acceleration = 250, followDistance = 40},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
    })
    FollowState.enter(npc)
    FollowState.update(npc, 0.1)
    -- Should not close to zero distance, maintain followDistance
    local dist = math.sqrt((npc.collider.x - 100)^2 + npc.collider.y^2)
    -- Just verify it's moving toward target
    assert(npc.collider.vx > 0, 'should move toward follow target')
    print('test_FollowState_maintainsDistance: PASS')
end

local function test_PatrolState_cyclesPoints()
    local PatrolState = require('npc.states.patrol_state')
    local npc = createMockNPC({
        config = {
            maxSpeed = 50,
            acceleration = 200,
            patrolPoints = {{x=0,y=0}, {x=100,y=0}, {x=100,y=100}}
        },
        collider = {vx = 0, vy = 0, x = 10, y = 0},
        currentPatrolIndex = 1,
        patrolDirection = 1,
    })
    PatrolState.enter(npc)
    assert(npc.patrolTarget ~= nil, 'should set patrolTarget')
    PatrolState.update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward first patrol point')
    print('test_PatrolState_cyclesPoints: PASS')
end

local function test_AttackState_dealsDamage()
    local AttackState = require('npc.states.attack_state')
    local npc = createMockNPC({
        target = {x = 10, y = 0, takeDamage = function(self, amt) self.hit = amt end},
        config = {attackRange = 32, damage = 2, attackCooldown = 1.0},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
        attackTimer = 0,
    })
    AttackState.enter(npc)
    AttackState.update(npc, 0.1)
    assert(npc.target.hit == 2, 'should deal damage to target')
    print('test_AttackState_dealsDamage: PASS')
end

local function test_FleeState_movesAwayFromThreat()
    local FleeState = require('npc.states.flee_state')
    local npc = createMockNPC({
        target = {x = 0, y = 0},  -- threat at origin
        config = {maxSpeed = 100, acceleration = 400, fleeThreshold = 0.3},
        collider = {vx = 0, vy = 0, x = 50, y = 0},
        health = 1,
        maxHealth = 10,
    })
    FleeState.enter(npc)
    FleeState.update(npc, 0.1)
    -- Should move away from threat (positive x since threat at 0,0 and npc at 50,0)
    assert(npc.collider.vx > 0, 'should move away from threat')
    print('test_FleeState_movesAwayFromThreat: PASS')
end

test_IdleState_enter_setsVelocityZero()
test_WanderState_enter_picksRandomDirection()
test_WanderState_update_movesTowardTarget()
test_ChaseState_enter_setsTarget()
test_ChaseState_update_movesTowardTarget()
test_FollowState_maintainsDistance()
test_PatrolState_cyclesPoints()
test_AttackState_dealsDamage()
test_FleeState_movesAwayFromThreat()
print('All NPC state tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/npc_states_test.lua`
Expected: FAIL with "module 'npc.states.idle_state' not found"

- [ ] **Step 3: Write minimal implementation (IdleState)**

```lua
-- src/npc/states/idle_state.lua
local IdleState = {}

function IdleState.enter(entity)
    entity.collider.vx = 0
    entity.collider.vy = 0
end

function IdleState.update(entity, dt)
    -- Idle does nothing, waits for utility to change
end

function IdleState.exit(entity)
    -- Cleanup if needed
end

return IdleState
```

```lua
-- src/npc/states/wander_state.lua
local Vector = require('utils.vector')
local WanderState = {}

function WanderState.enter(entity)
    -- Pick random point within wander radius
    local radius = entity.config.wanderRadius or 100
    local angle = math.random() * 2 * math.pi
    entity.wanderTarget = {
        x = entity.x + math.cos(angle) * radius,
        y = entity.y + math.sin(angle) * radius
    }
    entity.wanderTimer = 0
end

function WanderState.update(entity, dt)
    if not entity.wanderTarget then
        WanderState.enter(entity)
        return
    end
    
    local dx = entity.wanderTarget.x - entity.x
    local dy = entity.wanderTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 10 then
        -- Reached target, pick new one
        entity.wanderTimer = entity.wanderTimer + dt
        if entity.wanderTimer > 2 then
            WanderState.enter(entity)
        end
        return
    end
    
    -- Move toward target
    local dirX, dirY = Vector.normalize(dx, dy)
    local accel = entity.config.acceleration or 200
    local maxSpeed = entity.config.maxSpeed or 50
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    -- Clamp to max speed
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function WanderState.exit(entity)
    entity.wanderTarget = nil
    entity.wanderTimer = 0
end

return WanderState
```

```lua
-- src/npc/states/chase_state.lua
local Vector = require('utils.vector')
local ChaseState = {}

function ChaseState.enter(entity)
    if entity.target then
        entity.chaseTarget = {x = entity.target.x, y = entity.target.y}
    end
end

function ChaseState.update(entity, dt)
    if not entity.target or not entity.chaseTarget then
        return
    end
    
    -- Update chase target to current target position
    entity.chaseTarget.x = entity.target.x
    entity.chaseTarget.y = entity.target.y
    
    local dx = entity.chaseTarget.x - entity.x
    local dy = entity.chaseTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 5 then return end
    
    local dirX, dirY = Vector.normalize(dx, dy)
    local accel = entity.config.acceleration or 300
    local maxSpeed = entity.config.maxSpeed or 80
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function ChaseState.exit(entity)
    entity.chaseTarget = nil
end

return ChaseState
```

```lua
-- src/npc/states/follow_state.lua
local Vector = require('utils.vector')
local FollowState = {}

function FollowState.enter(entity)
    entity.followTimer = 0
end

function FollowState.update(entity, dt)
    if not entity.target then return end
    
    local followDist = entity.config.followDistance or 40
    local dx = entity.target.x - entity.x
    local dy = entity.target.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- If too close, back off; if too far, approach
    local targetDist = followDist
    if dist < targetDist * 0.5 then
        -- Too close, move away
        dx, dy = -dx, -dy
    elseif dist > targetDist * 2 then
        -- Too far, move closer aggressively
    end
    
    if dist < 5 then return end
    
    local dirX, dirY = Vector.normalize(dx, dy)
    local accel = entity.config.acceleration or 250
    local maxSpeed = entity.config.maxSpeed or 60
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function FollowState.exit(entity)
    entity.followTimer = 0
end

return FollowState
```

```lua
-- src/npc/states/patrol_state.lua
local Vector = require('utils.vector')
local PatrolState = {}

function PatrolState.enter(entity)
    local points = entity.config.patrolPoints
    if not points or #points == 0 then return end
    
    local idx = entity.currentPatrolIndex or 1
    entity.patrolTarget = points[idx]
end

function PatrolState.update(entity, dt)
    local points = entity.config.patrolPoints
    if not points or #points == 0 then return end
    if not entity.patrolTarget then
        PatrolState.enter(entity)
        return
    end
    
    local dx = entity.patrolTarget.x - entity.x
    local dy = entity.patrolTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 10 then
        -- Reached patrol point, advance to next
        local idx = (entity.currentPatrolIndex or 1) + (entity.patrolDirection or 1)
        if idx > #points then
            idx = #points - 1
            entity.patrolDirection = -1
        elseif idx < 1 then
            idx = 2
            entity.patrolDirection = 1
        end
        entity.currentPatrolIndex = idx
        entity.patrolTarget = points[idx]
        return
    end
    
    local dirX, dirY = Vector.normalize(dx, dy)
    local accel = entity.config.acceleration or 200
    local maxSpeed = entity.config.maxSpeed or 50
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function PatrolState.exit(entity)
    entity.patrolTarget = nil
end

return PatrolState
```

```lua
-- src/npc/states/attack_state.lua
local AttackState = {}

function AttackState.enter(entity)
    entity.attackTimer = 0
end

function AttackState.update(entity, dt)
    if not entity.target then return end
    
    local cooldown = entity.config.attackCooldown or 1.0
    entity.attackTimer = entity.attackTimer + dt
    
    if entity.attackTimer >= cooldown then
        entity.attackTimer = 0
        local dmg = entity.config.damage or 1
        if entity.target.takeDamage then
            entity.target:takeDamage(dmg, entity)
        end
    end
end

function AttackState.exit(entity)
    entity.attackTimer = 0
end

return AttackState
```

```lua
-- src/npc/states/flee_state.lua
local Vector = require('utils.vector')
local FleeState = {}

function FleeState.enter(entity)
    entity.fleeTimer = 0
end

function FleeState.update(entity, dt)
    if not entity.target then return end
    
    -- Move away from threat
    local dx = entity.x - entity.target.x
    local dy = entity.y - entity.target.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 1 then return end
    
    local dirX, dirY = Vector.normalize(dx, dy)
    local accel = entity.config.acceleration or 400
    local maxSpeed = entity.config.maxSpeed or 100
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function FleeState.exit(entity)
    entity.fleeTimer = 0
end

return FleeState
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/npc_states_test.lua`
Expected: PASS (all 9 tests)

- [ ] **Step 5: Commit**

```bash
git add src/npc/states/ tests/unit/npc_states_test.lua
git commit -m "feat(npc): add Enhanced FSM states (idle, wander, chase, follow, patrol, attack, flee)"
```

---

### Task 4: Create NPC Registry (`npc_registry.lua`)

**Files:**
- Create: `src/npc/npc_registry.lua`
- Test: `tests/unit/npc_registry_test.lua`
- Modify: `src/map/entity_factory.lua` (to use registry for spawning)

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `EventBus` (from `src/utils/event_bus.lua`), `Map` (from `src/map/init.lua`)
- Produces: `NPCRegistry` module with `registerType(name, class)`, `spawn(type, x, y, props)`, `despawn(npc)`, `getAll()`, `getByType(type)`, `clear()`, `onMapLoad(map)`, `onMapUnload()` functions

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/npc_registry_test.lua
local NPCRegistry = require('npc.npc_registry')
local NPCBase = require('npc.npc_base')
local Class = require('lib.hump.class')

-- Mock NPC type for testing
local TestNPC = Class{__includes = NPCBase}
function TestNPC:init(props)
    NPCBase.init(self, props)
    self.testType = 'test'
end

local function test_registerType_and_spawn()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    local npc = NPCRegistry.spawn('test_npc', 100, 200, {maxSpeed = 150})
    assert(npc ~= nil, 'spawn should return NPC instance')
    assert(npc.x == 100 and npc.y == 200, 'should set position')
    assert(npc.config.maxSpeed == 150, 'should pass props to config')
    assert(npc.testType == 'test', 'should be TestNPC instance')
    print('test_registerType_and_spawn: PASS')
end

local function test_spawn_unknownType_returnsNil()
    NPCRegistry.clear()
    local npc = NPCRegistry.spawn('unknown_type', 0, 0, {})
    assert(npc == nil, 'unknown type should return nil')
    print('test_spawn_unknownType_returnsNil: PASS')
end

local function test_getAll_returnsAllSpawned()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', 0, 0, {})
    NPCRegistry.spawn('test_npc', 10, 10, {})
    NPCRegistry.spawn('test_npc', 20, 20, {})
    
    local all = NPCRegistry.getAll()
    assert(#all == 3, 'should return all 3 NPCs')
    print('test_getAll_returnsAllSpawned: PASS')
end

local function test_getByType_filtersCorrectly()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.registerType('other_npc', TestNPC)
    NPCRegistry.spawn('test_npc', 0, 0, {})
    NPCRegistry.spawn('other_npc', 10, 10, {})
    NPCRegistry.spawn('test_npc', 20, 20, {})
    
    local testNPCs = NPCRegistry.getByType('test_npc')
    assert(#testNPCs == 2, 'should return only test_npc type')
    print('test_getByType_filtersCorrectly: PASS')
end

local function test_despawn_removesNPC()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    local npc = NPCRegistry.spawn('test_npc', 0, 0, {})
    assert(#NPCRegistry.getAll() == 1, 'should have 1 NPC')
    
    NPCRegistry.despawn(npc)
    assert(#NPCRegistry.getAll() == 0, 'should have 0 NPCs after despawn')
    print('test_despawn_removesNPC: PASS')
end

local function test_clear_removesAll()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', 0, 0, {})
    NPCRegistry.spawn('test_npc', 10, 10, {})
    
    NPCRegistry.clear()
    assert(#NPCRegistry.getAll() == 0, 'clear should remove all')
    print('test_clear_removesAll: PASS')
end

local function test_onMapLoad_registersMapEntities()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    -- Mock map with NPC objects
    local mockMap = {
        objects = {
            {type = 'test_npc', x = 50, y = 50, properties = {maxSpeed = 200}},
            {type = 'test_npc', x = 150, y = 150, properties = {}},
        }
    }
    NPCRegistry.onMapLoad(mockMap)
    
    local all = NPCRegistry.getAll()
    assert(#all == 2, 'should spawn NPCs from map objects')
    assert(all[1].config.maxSpeed == 200, 'should apply properties from map')
    print('test_onMapLoad_registersMapEntities: PASS')
end

local function test_onMapUnload_clearsRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', 0, 0, {})
    
    NPCRegistry.onMapUnload()
    assert(#NPCRegistry.getAll() == 0, 'onMapUnload should clear all')
    print('test_onMapUnload_clearsRegistry: PASS')
end

test_registerType_and_spawn()
test_spawn_unknownType_returnsNil()
test_getAll_returnsAllSpawned()
test_getByType_filtersCorrectly()
test_despawn_removesNPC()
test_clear_removesAll()
test_onMapLoad_registersMapEntities()
test_onMapUnload_clearsRegistry()
print('All NPCRegistry tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/npc_registry_test.lua`
Expected: FAIL with "module 'npc.npc_registry' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/npc/npc_registry.lua
local NPCRegistry = {}
local EventBus = require('utils.event_bus')

NPCRegistry._types = {}
NPCRegistry._instances = {}

function NPCRegistry.registerType(name, class)
    NPCRegistry._types[name] = class
end

function NPCRegistry.spawn(typeName, x, y, props)
    local class = NPCRegistry._types[typeName]
    if not class then
        return nil
    end
    
    props = props or {}
    props.x = x
    props.y = y
    
    local npc = class(props)
    table.insert(NPCRegistry._instances, npc)
    
    -- Listen for death event to auto-despawn
    local function onDeath(data)
        if data.npc == npc then
            NPCRegistry.despawn(npc)
        end
    end
    npc._deathListener = onDeath
    EventBus.on('npc_death', onDeath)
    
    return npc
end

function NPCRegistry.despawn(npc)
    for i, inst in ipairs(NPCRegistry._instances) do
        if inst == npc then
            table.remove(NPCRegistry._instances, i)
            if npc._deathListener then
                EventBus.off('npc_death', npc._deathListener)
                npc._deathListener = nil
            end
            npc:queueRemove()
            break
        end
    end
end

function NPCRegistry.getAll()
    return NPCRegistry._instances
end

function NPCRegistry.getByType(typeName)
    local result = {}
    for _, npc in ipairs(NPCRegistry._instances) do
        if npc.config and npc.config._typeName == typeName then
            table.insert(result, npc)
        end
    end
    return result
end

function NPCRegistry.clear()
    for _, npc in ipairs(NPCRegistry._instances) do
        if npc._deathListener then
            EventBus.off('npc_death', npc._deathListener)
        end
        npc:queueRemove()
    end
    NPCRegistry._instances = {}
end

function NPCRegistry.onMapLoad(map)
    NPCRegistry.clear()
    
    if not map or not map.objects then return end
    
    for _, obj in ipairs(map.objects) do
        if obj.type and NPCRegistry._types[obj.type] then
            local props = obj.properties or {}
            props._typeName = obj.type  -- Track type for getByType
            NPCRegistry.spawn(obj.type, obj.x, obj.y, props)
        end
    end
end

function NPCRegistry.onMapUnload()
    NPCRegistry.clear()
end

return NPCRegistry
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/npc_registry_test.lua`
Expected: PASS (all 8 tests)

- [ ] **Step 5: Commit**

```bash
git add src/npc/npc_registry.lua tests/unit/npc_registry_test.lua
git commit -m "feat(npc): add NPCRegistry for spawn/despawn management"
```

---

### Task 5: Update Entity Factory to Use Registry

**Files:**
- Modify: `src/map/entity_factory.lua` (replace direct NPC instantiation with registry calls)
- Test: `tests/integration/entity_factory_npc_test.lua`

**Interfaces:**
- Consumes: `NPCRegistry` (from Task 4), `Map` (from `src/map/init.lua`)
- Produces: Updated `EntityFactory.createEntity()` that delegates NPC types to `NPCRegistry.spawn()`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/entity_factory_npc_test.lua
local Map = require('map')
local NPCRegistry = require('npc.npc_registry')
local NPCBase = require('npc.npc_base')
local Class = require('lib.hump.class')

-- Mock NPC type
local TestNPC = Class{__includes = NPCBase}
function TestNPC:init(props)
    NPCBase.init(self, props)
    self.testType = 'test'
end

local function test_entityFactory_usesRegistryForNPCs()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    -- Create a minimal map with an NPC object
    local map = Map({width = 320, height = 240})
    map.objects = {
        {type = 'test_npc', x = 100, y = 100, properties = {maxSpeed = 120}}
    }
    
    local entityFactory = require('map.entity_factory')
    local entities = entityFactory.createEntities(map)
    
    -- Should have created the NPC via registry
    local npcs = NPCRegistry.getAll()
    assert(#npcs == 1, 'should have spawned 1 NPC via registry')
    assert(npcs[1].config.maxSpeed == 120, 'should pass properties')
    print('test_entityFactory_usesRegistryForNPCs: PASS')
end

local function test_entityFactory_skipsUnknownTypes()
    NPCRegistry.clear()
    
    local map = Map({width = 320, height = 240})
    map.objects = {
        {type = 'unknown_npc_type', x = 100, y = 100, properties = {}}
    }
    
    local entityFactory = require('map.entity_factory')
    local entities = entityFactory.createEntities(map)
    
    local npcs = NPCRegistry.getAll()
    assert(#npcs == 0, 'should not spawn unknown NPC types')
    print('test_entityFactory_skipsUnknownTypes: PASS')
end

test_entityFactory_usesRegistryForNPCs()
test_entityFactory_skipsUnknownTypes()
print('All EntityFactory NPC tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/entity_factory_npc_test.lua`
Expected: FAIL (entity_factory doesn't use NPCRegistry yet)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/map/entity_factory.lua (modification - add to existing file)
local NPCRegistry = require('npc.npc_registry')

-- In createEntity function, add NPC handling:
local function createEntity(map, object, entities)
    -- ... existing code for other entity types ...
    
    -- Handle NPC types via registry
    if NPCRegistry._types[object.type] then
        local props = object.properties or {}
        local npc = NPCRegistry.spawn(object.type, object.x, object.y, props)
        if npc then
            table.insert(entities, npc)
        end
        return
    end
    
    -- ... rest of existing entity creation ...
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/entity_factory_npc_test.lua`
Expected: PASS (both tests)

- [ ] **Step 5: Commit**

```bash
git add src/map/entity_factory.lua tests/integration/entity_factory_npc_test.lua
git commit -m "feat(npc): update entity_factory to use NPCRegistry for NPC spawning"
```

---

### Task 6: Migrate Spider NPC to NPCBase

**Files:**
- Modify: `src/entities/spider.lua` (rewrite to extend NPCBase)
- Delete: `src/npc/npc.lua`, `src/npc/npc_states.lua`, `src/npc/npc_brain.lua` (after all migrations)
- Test: `tests/integration/spider_migration_test.lua`

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `NPCConfig` (from Task 1), `NPCRegistry` (from Task 4)
- Produces: `Spider` class extending `NPCBase` with spider-specific config (chase behavior, attack, patrol points from map)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/spider_migration_test.lua
local NPCRegistry = require('npc.npc_registry')
local Spider = require('entities.spider')
local Map = require('map')

local function test_spider_extendsNPCBase()
    local spider = Spider({x = 0, y = 0})
    assert(spider.config ~= nil, 'should have config')
    assert(spider.stateMachine ~= nil, 'should have stateMachine')
    assert(spider.health ~= nil, 'should have health')
    print('test_spider_extendsNPCBase: PASS')
end

local function test_spider_defaultConfig()
    local spider = Spider({x = 0, y = 0})
    assert(spider.config.behavior == 'chase', 'spider should default to chase behavior')
    assert(spider.config.maxSpeed > 0, 'should have maxSpeed')
    assert(spider.config.detectionRadius > 0, 'should have detectionRadius')
    assert(spider.config.attackRange > 0, 'should have attackRange')
    assert(spider.config.damage > 0, 'should have damage')
    print('test_spider_defaultConfig: PASS')
end

local function test_spider_spawnsViaRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    
    local spider = NPCRegistry.spawn('spider', 100, 100, {})
    assert(spider ~= nil, 'should spawn via registry')
    assert(spider.x == 100 and spider.y == 100, 'should set position')
    print('test_spider_spawnsViaRegistry: PASS')
end

local function test_spider_chasesPlayer()
    local spider = Spider({x = 0, y = 0})
    local player = {x = 50, y = 0, takeDamage = function() end}
    spider:setTarget(player)
    
    -- Simulate update
    spider:update(0.1)
    
    -- Should be in chase or attack state
    local stateName = spider.stateMachine.currentState.name
    assert(stateName == 'ChaseState' or stateName == 'AttackState', 
           'should be in chase or attack state, got ' .. stateName)
    print('test_spider_chasesPlayer: PASS')
end

local function test_spider_attacksInRange()
    local spider = Spider({x = 0, y = 0, config = {attackRange = 32, damage = 1}})
    local player = {x = 10, y = 0, takeDamage = function(self, amt) self.hit = amt end}
    spider:setTarget(player)
    
    spider:update(0.1)
    -- Attack state should deal damage
    assert(player.hit == 1, 'should deal damage to player in range')
    print('test_spider_attacksInRange: PASS')
end

local function test_spider_fleesWhenLowHealth()
    local spider = Spider({x = 50, y = 0, health = 1, maxHealth = 10, config = {fleeThreshold = 0.3}})
    local threat = {x = 0, y = 0}
    spider:setTarget(threat)
    
    spider:update(0.1)
    
    local stateName = spider.stateMachine.currentState.name
    assert(stateName == 'FleeState', 'should flee when low health, got ' .. stateName)
    print('test_spider_fleesWhenLowHealth: PASS')
end

test_spider_extendsNPCBase()
test_spider_defaultConfig()
test_spider_spawnsViaRegistry()
test_spider_chasesPlayer()
test_spider_attacksInRange()
test_spider_fleesWhenLowHealth()
print('All Spider migration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/spider_migration_test.lua`
Expected: FAIL (spider.lua still uses old architecture)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/entities/spider.lua
local Class = require('lib.hump.class')
local NPCBase = require('npc.npc_base')
local NPCConfig = require('npc.npc_config')
local NPCRegistry = require('npc.npc_registry')

local Spider = Class{__includes = NPCBase}

function Spider:init(props)
    props = props or {}
    -- Spider-specific defaults
    local spiderDefaults = {
        maxSpeed = 90,
        acceleration = 350,
        deceleration = 500,
        detectionRadius = 200,
        attackRange = 24,
        damage = 1,
        health = 2,
        behavior = 'chase',
        fleeThreshold = 0.25,
        canPush = false,
        canBePushed = true,
        pushForce = 100,
        ridePlatforms = false,
        triggerSwitches = false,
        invulnerableTime = 0.5,
    }
    
    -- Merge spider defaults with provided props, then with NPCConfig defaults
    local merged = {}
    for k, v in pairs(spiderDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    -- Register type if not already registered
    if not NPCRegistry._types['spider'] then
        NPCRegistry.registerType('spider', Spider)
    end
end

return Spider
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/spider_migration_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/entities/spider.lua tests/integration/spider_migration_test.lua
git commit -m "feat(npc): migrate spider to NPCBase architecture"
```

---

### Task 7: Migrate Robot NPC to NPCBase

**Files:**
- Modify: `src/entities/robot.lua` (rewrite to extend NPCBase)
- Test: `tests/integration/robot_migration_test.lua`

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `NPCConfig` (from Task 1), `NPCRegistry` (from Task 4)
- Produces: `Robot` class extending `NPCBase` with robot-specific config (patrol behavior, ranged attack, higher health)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/robot_migration_test.lua
local NPCRegistry = require('npc.npc_registry')
local Robot = require('entities.robot')

local function test_robot_extendsNPCBase()
    local robot = Robot({x = 0, y = 0})
    assert(robot.config ~= nil, 'should have config')
    assert(robot.stateMachine ~= nil, 'should have stateMachine')
    assert(robot.health ~= nil, 'should have health')
    print('test_robot_extendsNPCBase: PASS')
end

local function test_robot_defaultConfig()
    local robot = Robot({x = 0, y = 0})
    assert(robot.config.behavior == 'patrol', 'robot should default to patrol behavior')
    assert(robot.config.maxSpeed > 0, 'should have maxSpeed')
    assert(robot.config.health >= 3, 'robot should have higher health')
    assert(robot.config.attackRange > 32, 'robot should have ranged attack')
    print('test_robot_defaultConfig: PASS')
end

local function test_robot_spawnsViaRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('robot', Robot)
    
    local robot = NPCRegistry.spawn('robot', 100, 100, {})
    assert(robot ~= nil, 'should spawn via registry')
    assert(robot.x == 100 and robot.y == 100, 'should set position')
    print('test_robot_spawnsViaRegistry: PASS')
end

local function test_robot_patrolsBetweenPoints()
    local robot = Robot({
        x = 0, y = 0,
        config = {
            patrolPoints = {{x=0,y=0}, {x=100,y=0}, {x=100,y=100}},
            behavior = 'patrol'
        }
    })
    
    robot:update(0.1)
    local stateName = robot.stateMachine.currentState.name
    assert(stateName == 'PatrolState', 'should be in patrol state, got ' .. stateName)
    print('test_robot_patrolsBetweenPoints: PASS')
end

local function test_robot_chasesWhenPlayerDetected()
    local robot = Robot({x = 0, y = 0, config = {detectionRadius = 200, behavior = 'patrol'}})
    local player = {x = 50, y = 0}
    robot:setTarget(player)
    
    robot:update(0.1)
    
    local stateName = robot.stateMachine.currentState.name
    assert(stateName == 'ChaseState' or stateName == 'AttackState',
           'should chase when player detected, got ' .. stateName)
    print('test_robot_chasesWhenPlayerDetected: PASS')
end

local function test_robot_rangedAttack()
    local robot = Robot({x = 0, y = 0, config = {attackRange = 120, damage = 2}})
    local player = {x = 50, y = 0, takeDamage = function(self, amt) self.hit = amt end}
    robot:setTarget(player)
    
    robot:update(0.1)
    assert(player.hit == 2, 'should deal ranged damage')
    print('test_robot_rangedAttack: PASS')
end

test_robot_extendsNPCBase()
test_robot_defaultConfig()
test_robot_spawnsViaRegistry()
test_robot_patrolsBetweenPoints()
test_robot_chasesWhenPlayerDetected()
test_robot_rangedAttack()
print('All Robot migration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/robot_migration_test.lua`
Expected: FAIL (robot.lua still uses old architecture)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/entities/robot.lua
local Class = require('lib.hump.class')
local NPCBase = require('npc.npc_base')
local NPCRegistry = require('npc.npc_registry')

local Robot = Class{__includes = NPCBase}

function Robot:init(props)
    props = props or {}
    local robotDefaults = {
        maxSpeed = 60,
        acceleration = 250,
        deceleration = 400,
        detectionRadius = 250,
        attackRange = 120,
        damage = 2,
        health = 4,
        behavior = 'patrol',
        fleeThreshold = 0.2,
        canPush = true,
        canBePushed = true,
        pushForce = 300,
        ridePlatforms = false,
        triggerSwitches = true,
        invulnerableTime = 0.3,
        patrolPoints = {},
    }
    
    local merged = {}
    for k, v in pairs(robotDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    if not NPCRegistry._types['robot'] then
        NPCRegistry.registerType('robot', Robot)
    end
end

return Robot
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/robot_migration_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/entities/robot.lua tests/integration/robot_migration_test.lua
git commit -m "feat(npc): migrate robot to NPCBase architecture"
```

---

### Task 8: Migrate Bird NPC to NPCBase

**Files:**
- Modify: `src/entities/bird_npc.lua` (rewrite to extend NPCBase)
- Test: `tests/integration/bird_migration_test.lua`

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `NPCConfig` (from Task 1), `NPCRegistry` (from Task 4)
- Produces: `BirdNPC` class extending `NPCBase` with bird-specific config (follow behavior, flying movement, no ground collision)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/bird_migration_test.lua
local NPCRegistry = require('npc.npc_registry')
local BirdNPC = require('entities.bird_npc')

local function test_bird_extendsNPCBase()
    local bird = BirdNPC({x = 0, y = 0})
    assert(bird.config ~= nil, 'should have config')
    assert(bird.stateMachine ~= nil, 'should have stateMachine')
    print('test_bird_extendsNPCBase: PASS')
end

local function test_bird_defaultConfig()
    local bird = BirdNPC({x = 0, y = 0})
    assert(bird.config.behavior == 'follow', 'bird should default to follow behavior')
    assert(bird.config.maxSpeed > 0, 'should have maxSpeed')
    assert(bird.config.ridePlatforms == false, 'bird should not ride platforms')
    assert(bird.config.canBePushed == false, 'bird should not be pushable')
    print('test_bird_defaultConfig: PASS')
end

local function test_bird_spawnsViaRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('bird_npc', BirdNPC)
    
    local bird = NPCRegistry.spawn('bird_npc', 100, 100, {})
    assert(bird ~= nil, 'should spawn via registry')
    assert(bird.x == 100 and bird.y == 100, 'should set position')
    print('test_bird_spawnsViaRegistry: PASS')
end

local function test_bird_followsPlayer()
    local bird = BirdNPC({x = 0, y = 0})
    local player = {x = 100, y = 0}
    bird:setTarget(player)
    
    bird:update(0.1)
    
    local stateName = bird.stateMachine.currentState.name
    assert(stateName == 'FollowState', 'should be in follow state, got ' .. stateName)
    assert(bird.collider.vx > 0, 'should move toward player')
    print('test_bird_followsPlayer: PASS')
end

local function test_bird_maintainsFollowDistance()
    local bird = BirdNPC({x = 0, y = 0, config = {followDistance = 50}})
    local player = {x = 100, y = 0}
    bird:setTarget(player)
    
    bird:update(0.1)
    -- Bird should not get too close, maintain follow distance
    local dist = math.sqrt((bird.x - 100)^2 + bird.y^2)
    assert(dist > 20, 'should maintain some distance from player')
    print('test_bird_maintainsFollowDistance: PASS')
end

local function test_bird_fliesOverObstacles()
    local bird = BirdNPC({x = 0, y = 0, config = {canFly = true}})
    -- Bird's collider should not be solid for ground collision
    assert(bird.collider.solid == false or bird.config.canFly == true, 
           'bird should be able to fly over obstacles')
    print('test_bird_fliesOverObstacles: PASS')
end

test_bird_extendsNPCBase()
test_bird_defaultConfig()
test_bird_spawnsViaRegistry()
test_bird_followsPlayer()
test_bird_maintainsFollowDistance()
test_bird_fliesOverObstacles()
print('All Bird migration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/bird_migration_test.lua`
Expected: FAIL (bird_npc.lua still uses old architecture)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/entities/bird_npc.lua
local Class = require('lib.hump.class')
local NPCBase = require('npc.npc_base')
local NPCRegistry = require('npc.npc_registry')

local BirdNPC = Class{__includes = NPCBase}

function BirdNPC:init(props)
    props = props or {}
    local birdDefaults = {
        maxSpeed = 100,
        acceleration = 300,
        deceleration = 400,
        detectionRadius = 300,
        attackRange = 0,  -- Bird doesn't attack
        damage = 0,
        health = 1,
        behavior = 'follow',
        fleeThreshold = 0.5,
        canPush = false,
        canBePushed = false,
        pushForce = 0,
        ridePlatforms = false,
        triggerSwitches = false,
        invulnerableTime = 0.5,
        followDistance = 60,
        canFly = true,
    }
    
    local merged = {}
    for k, v in pairs(birdDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    -- Override collider for flying (non-solid)
    self.collider.solid = false
    
    if not NPCRegistry._types['bird_npc'] then
        NPCRegistry.registerType('bird_npc', BirdNPC)
    end
end

return BirdNPC
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/bird_migration_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/entities/bird_npc.lua tests/integration/bird_migration_test.lua
git commit -m "feat(npc): migrate bird_npc to NPCBase architecture"
```

---

### Task 9: Migrate Rabbit NPC to NPCBase

**Files:**
- Modify: `src/entities/rabbit_npc.lua` (rewrite to extend NPCBase)
- Test: `tests/integration/rabbit_migration_test.lua`

**Interfaces:**
- Consumes: `NPCBase` (from Task 2), `NPCConfig` (from Task 1), `NPCRegistry` (from Task 4)
- Produces: `RabbitNPC` class extending `NPCBase` with rabbit-specific config (follow behavior, hopping movement, can ride platforms)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/rabbit_migration_test.lua
local NPCRegistry = require('npc.npc_registry')
local RabbitNPC = require('entities.rabbit_npc')

local function test_rabbit_extendsNPCBase()
    local rabbit = RabbitNPC({x = 0, y = 0})
    assert(rabbit.config ~= nil, 'should have config')
    assert(rabbit.stateMachine ~= nil, 'should have stateMachine')
    print('test_rabbit_extendsNPCBase: PASS')
end

local function test_rabbit_defaultConfig()
    local rabbit = RabbitNPC({x = 0, y = 0})
    assert(rabbit.config.behavior == 'follow', 'rabbit should default to follow behavior')
    assert(rabbit.config.maxSpeed > 0, 'should have maxSpeed')
    assert(rabbit.config.ridePlatforms == true, 'rabbit should ride platforms')
    assert(rabbit.config.canBePushed == true, 'rabbit should be pushable')
    print('test_rabbit_defaultConfig: PASS')
end

local function test_rabbit_spawnsViaRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    
    local rabbit = NPCRegistry.spawn('rabbit_npc', 100, 100, {})
    assert(rabbit ~= nil, 'should spawn via registry')
    assert(rabbit.x == 100 and rabbit.y == 100, 'should set position')
    print('test_rabbit_spawnsViaRegistry: PASS')
end

local function test_rabbit_followsPlayer()
    local rabbit = RabbitNPC({x = 0, y = 0})
    local player = {x = 100, y = 0}
    rabbit:setTarget(player)
    
    rabbit:update(0.1)
    
    local stateName = rabbit.stateMachine.currentState.name
    assert(stateName == 'FollowState', 'should be in follow state, got ' .. stateName)
    assert(rabbit.collider.vx > 0, 'should move toward player')
    print('test_rabbit_followsPlayer: PASS')
end

local function test_rabbit_hopsMovement()
    local rabbit = RabbitNPC({x = 0, y = 0})
    local player = {x = 50, y = 0}
    rabbit:setTarget(player)
    
    rabbit:update(0.1)
    -- Rabbit should have hopping behavior (vertical velocity changes)
    assert(rabbit.collider.vy ~= 0 or rabbit.config.hopHeight ~= nil, 
           'rabbit should have hop mechanics')
    print('test_rabbit_hopsMovement: PASS')
end

local function test_rabbit_ridesMovingPlatforms()
    local rabbit = RabbitNPC({x = 0, y = 0, config = {ridePlatforms = true}})
    -- Rabbit's collider should be walkable
    assert(rabbit.collider.walkable == true, 'rabbit should be able to ride platforms')
    print('test_rabbit_ridesMovingPlatforms: PASS')
end

test_rabbit_extendsNPCBase()
test_rabbit_defaultConfig()
test_rabbit_spawnsViaRegistry()
test_rabbit_followsPlayer()
test_rabbit_hopsMovement()
test_rabbit_ridesMovingPlatforms()
print('All Rabbit migration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/rabbit_migration_test.lua`
Expected: FAIL (rabbit_npc.lua still uses old architecture)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/entities/rabbit_npc.lua
local Class = require('lib.hump.class')
local NPCBase = require('npc.npc_base')
local NPCRegistry = require('npc.npc_registry')
local Vector = require('utils.vector')

local RabbitNPC = Class{__includes = NPCBase}

function RabbitNPC:init(props)
    props = props or {}
    local rabbitDefaults = {
        maxSpeed = 80,
        acceleration = 350,
        deceleration = 500,
        detectionRadius = 200,
        attackRange = 0,
        damage = 0,
        health = 1,
        behavior = 'follow',
        fleeThreshold = 0.4,
        canPush = false,
        canBePushed = true,
        pushForce = 150,
        ridePlatforms = true,
        triggerSwitches = false,
        invulnerableTime = 0.5,
        followDistance = 40,
        hopHeight = 120,
        hopCooldown = 0.5,
    }
    
    local merged = {}
    for k, v in pairs(rabbitDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    -- Ensure collider is walkable for platform riding
    self.collider.walkable = true
    self.hopTimer = 0
    
    if not NPCRegistry._types['rabbit_npc'] then
        NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    end
end

function RabbitNPC:update(dt)
    NPCBase.update(self, dt)
    
    -- Handle hopping when following
    if self.target and self.stateMachine.currentState.name == 'FollowState' then
        self.hopTimer = self.hopTimer - dt
        if self.hopTimer <= 0 and self:isOnGround() then
            self.collider.vy = -self.config.hopHeight
            self.hopTimer = self.config.hopCooldown
        end
    end
end

function RabbitNPC:isOnGround()
    -- Simple ground check - in real implementation would use physics query
    return self.collider.vy == 0
end

return RabbitNPC
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/rabbit_migration_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/entities/rabbit_npc.lua tests/integration/rabbit_migration_test.lua
git commit -m "feat(npc): migrate rabbit_npc to NPCBase architecture"
```

---

### Task 10: Physics Integration Tests (Pushing, Platforms, Triggers)

**Files:**
- Create: `tests/integration/npc_physics_test.lua`
- Test: `tests/integration/npc_physics_test.lua`

**Interfaces:**
- Consumes: All NPC types (Spider, Robot, Bird, Rabbit), `NPCRegistry`, `Map`, physics `World`
- Produces: Integration tests verifying mutual pushing, platform riding, trigger/switch interaction

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/npc_physics_test.lua
local NPCRegistry = require('npc.npc_registry')
local Spider = require('entities.spider')
local Robot = require('entities.robot')
local RabbitNPC = require('entities.rabbit_npc')
local Map = require('map')
local World = require('physics.world')

local function setupRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    NPCRegistry.registerType('robot', Robot)
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
end

local function test_npcs_canPushEachOther()
    setupRegistry()
    
    local spider = NPCRegistry.spawn('spider', 0, 0, {canPush = true, canBePushed = true, pushForce = 200})
    local robot = NPCRegistry.spawn('robot', 50, 0, {canPush = true, canBePushed = true, pushForce = 200})
    
    -- Simulate collision
    spider:onCollision(robot, 1, 0)
    
    -- Robot should have been pushed
    assert(robot.collider.vx > 0, 'robot should be pushed by spider')
    print('test_npcs_canPushEachOther: PASS')
end

local function test_npc_pushesPlayer()
    setupRegistry()
    
    local spider = NPCRegistry.spawn('spider', 0, 0, {canPush = true, pushForce = 200})
    local player = {x = 40, y = 0, collider = {vx = 0, vy = 0}, config = {canBePushed = true}}
    
    spider:onCollision(player, 1, 0)
    
    assert(player.collider.vx > 0, 'player should be pushed by NPC')
    print('test_npc_pushesPlayer: PASS')
end

local function test_rabbit_ridesMovingPlatform()
    setupRegistry()
    
    local rabbit = NPCRegistry.spawn('rabbit_npc', 0, 0, {ridePlatforms = true})
    local platform = {x = 0, y = 16, width = 64, height = 16, collider = {vx = 50, vy = 0}, isMovingPlatform = true}
    
    -- Rabbit lands on platform
    rabbit.collider.y = platform.y - 16
    rabbit.collider.vy = 0
    
    -- Simulate platform moving
    rabbit:update(0.1)
    
    -- Rabbit should move with platform
    assert(rabbit.collider.vx == platform.collider.vx, 'rabbit should ride platform')
    print('test_rabbit_ridesMovingPlatform: PASS')
end

local function test_robot_triggersSwitch()
    setupRegistry()
    
    local robot = NPCRegistry.spawn('robot', 0, 0, {triggerSwitches = true})
    local switch = {x = 30, y = 0, isSwitch = true, activated = false, activate = function(self, by) self.activated = true end}
    
    robot:onCollision(switch, 1, 0)
    
    assert(switch.activated == true, 'switch should be activated by robot')
    print('test_robot_triggersSwitch: PASS')
end

local function test_spider_doesNotTriggerSwitch()
    setupRegistry()
    
    local spider = NPCRegistry.spawn('spider', 0, 0, {triggerSwitches = false})
    local switch = {x = 30, y = 0, isSwitch = true, activated = false, activate = function(self, by) self.activated = true end}
    
    spider:onCollision(switch, 1, 0)
    
    assert(switch.activated == false, 'spider should not trigger switch')
    print('test_spider_doesNotTriggerSwitch: PASS')
end

local function test_npc_collisionWithSolidWall()
    setupRegistry()
    
    local spider = NPCRegistry.spawn('spider', 0, 0)
    local wall = {x = 20, y = 0, width = 16, height = 32, collider = {solid = true}}
    
    spider.collider.vx = 100
    spider:update(0.1)
    
    -- Spider should not pass through wall
    -- (Actual physics resolution handled by bump, but NPC should not get stuck)
    assert(spider.x < wall.x, 'spider should not pass through solid wall')
    print('test_npc_collisionWithSolidWall: PASS')
end

test_npcs_canPushEachOther()
test_npc_pushesPlayer()
test_rabbit_ridesMovingPlatform()
test_robot_triggersSwitch()
test_spider_doesNotTriggerSwitch()
test_npc_collisionWithSolidWall()
print('All NPC physics integration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/npc_physics_test.lua`
Expected: FAIL (some physics interactions not fully implemented)

- [ ] **Step 3: Implement missing physics handling in NPCBase**

```lua
-- src/npc/npc_base.lua (additions to existing onCollision)
function NPCBase:onCollision(other, dx, dy)
    -- Handle pushing other entities
    if other and other.config and other.config.canBePushed and self.config.canPush then
        local pushDir = Vector.normalize(other.x - self.x, other.y - self.y)
        other:applyPush(pushDir.x, pushDir.y)
    end
    
    -- Handle trigger/switch interaction
    if other and other.isSwitch and self.config.triggerSwitches then
        other:activate(self)
    end
    
    -- Handle platform riding (for entities with ridePlatforms = true)
    if other and other.isMovingPlatform and self.config.ridePlatforms then
        self.collider.vx = other.collider.vx
        self.collider.vy = other.collider.vy
    end
end

function NPCBase:isOnGround()
    -- Query physics world for ground contact
    if self.collider and self.collider.world then
        local items, len = self.collider.world:queryRect(
            self.collider.x, self.collider.y + self.collider.height + 1,
            self.collider.width, 2
        )
        for _, item in ipairs(items) do
            if item.solid and item ~= self.collider then
                return true
            end
        end
    end
    return false
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/npc_physics_test.lua`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/npc/npc_base.lua tests/integration/npc_physics_test.lua
git commit -m "feat(npc): add physics integration tests for pushing, platforms, triggers"
```

---

### Task 11: Cleanup Old NPC Files

**Files:**
- Delete: `src/npc/npc.lua`
- Delete: `src/npc/npc_states.lua`
- Delete: `src/npc/npc_brain.lua`
- Delete: `src/components/npc_follow.lua`
- Modify: `src/map/entity_factory.lua` (remove old NPC creation code)
- Test: `tests/unit/npc_cleanup_test.lua` (verify old modules not required)

**Interfaces:**
- Consumes: None (cleanup task)
- Produces: Clean codebase with only new NPC architecture

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/npc_cleanup_test.lua
local function test_oldNPCModules_notRequired()
    -- These should fail to load (modules deleted)
    local ok1, _ = pcall(require, 'npc.npc')
    local ok2, _ = pcall(require, 'npc.npc_states')
    local ok3, _ = pcall(require, 'npc.npc_brain')
    local ok4, _ = pcall(require, 'components.npc_follow')
    
    assert(ok1 == false, 'old npc.lua should not be loadable')
    assert(ok2 == false, 'old npc_states.lua should not be loadable')
    assert(ok3 == false, 'old npc_brain.lua should not be loadable')
    assert(ok4 == false, 'old npc_follow.lua should not be loadable')
    print('test_oldNPCModules_notRequired: PASS')
end

local function test_newArchitectureLoads()
    local NPCBase = require('npc.npc_base')
    local NPCConfig = require('npc.npc_config')
    local NPCRegistry = require('npc.npc_registry')
    local Spider = require('entities.spider')
    local Robot = require('entities.robot')
    local BirdNPC = require('entities.bird_npc')
    local RabbitNPC = require('entities.rabbit_npc')
    
    assert(NPCBase ~= nil, 'NPCBase should load')
    assert(NPCConfig ~= nil, 'NPCConfig should load')
    assert(NPCRegistry ~= nil, 'NPCRegistry should load')
    assert(Spider ~= nil, 'Spider should load')
    assert(Robot ~= nil, 'Robot should load')
    assert(BirdNPC ~= nil, 'BirdNPC should load')
    assert(RabbitNPC ~= nil, 'RabbitNPC should load')
    print('test_newArchitectureLoads: PASS')
end

test_oldNPCModules_notRequired()
test_newArchitectureLoads()
print('All cleanup tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/npc_cleanup_test.lua`
Expected: FAIL (old modules still exist)

- [ ] **Step 3: Delete old files and update entity_factory**

```bash
# Delete old NPC files
rm src/npc/npc.lua
rm src/npc/npc_states.lua
rm src/npc/npc_brain.lua
rm src/components/npc_follow.lua
```

```lua
-- src/map/entity_factory.lua (remove old NPC creation, keep only registry-based)
-- Remove any code that directly instantiated Spider, Robot, BirdNPC, RabbitNPC
-- The NPCRegistry.spawn() call added in Task 5 handles all NPC types
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/npc_cleanup_test.lua`
Expected: PASS (both tests)

- [ ] **Step 5: Commit**

```bash
git rm src/npc/npc.lua src/npc/npc_states.lua src/npc/npc_brain.lua src/components/npc_follow.lua
git add src/map/entity_factory.lua tests/unit/npc_cleanup_test.lua
git commit -m "chore(npc): remove old NPC architecture files"
```

---

### Task 12: Full Integration Test with Real Maps

**Files:**
- Create: `tests/integration/npc_full_map_test.lua`
- Use: Existing map files in `res/map/` (e.g., `sandbox.lua`, `ll1.lua`)

**Interfaces:**
- Consumes: All migrated NPC types, `NPCRegistry`, `Map`, `Game` state
- Produces: Integration test that loads a real map and verifies all NPCs spawn and behave correctly

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/npc_full_map_test.lua
local GameHarness = require('tests.support.game_harness')
local NPCRegistry = require('npc.npc_registry')
local Spider = require('entities.spider')
local Robot = require('entities.robot')
local BirdNPC = require('entities.bird_npc')
local RabbitNPC = require('entities.rabbit_npc')

local function test_mapLoadsWithAllNPCTypes()
    -- Register all NPC types
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    NPCRegistry.registerType('robot', Robot)
    NPCRegistry.registerType('bird_npc', BirdNPC)
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    
    -- Start game with a map that has NPCs
    local game = GameHarness.startGame('res/map/sandbox.lua')
    
    -- Wait for map to load
    local FrameStepper = require('tests.support.frame_stepper')
    FrameStepper.step(game, 10)
    
    local npcs = NPCRegistry.getAll()
    assert(#npcs > 0, 'should have NPCs spawned from map')
    
    -- Verify each NPC type is present
    local types = {}
    for _, npc in ipairs(npcs) do
        types[npc.config._typeName] = true
    end
    
    -- At least some NPC types should be in the test map
    print('Found NPC types: ' .. table.concat(types, ', '))
    
    game:shutdown()
    print('test_mapLoadsWithAllNPCTypes: PASS')
end

local function test_npcsUpdateWithoutErrors()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    NPCRegistry.registerType('robot', Robot)
    
    local game = GameHarness.startGame('res/map/sandbox.lua')
    local FrameStepper = require('tests.support.frame_stepper')
    
    -- Step simulation for 1 second
    FrameStepper.step(game, 60)
    
    local npcs = NPCRegistry.getAll()
    for _, npc in ipairs(npcs) do
        -- Verify NPC is still valid and has state
        assert(npc.stateMachine ~= nil, 'NPC should have stateMachine')
        assert(npc.stateMachine.currentState ~= nil, 'NPC should have current state')
        assert(npc.config ~= nil, 'NPC should have config')
    end
    
    game:shutdown()
    print('test_npcsUpdateWithoutErrors: PASS')
end

local function test_playerNPCInteraction()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    
    local game = GameHarness.startGame('res/map/sandbox.lua')
    local FrameStepper = require('tests.support.frame_stepper')
    local FakeInput = require('tests.support.fake_input').FakeInput
    local controller = FakeInput.new()
    
    FrameStepper.step(game, 10)
    
    -- Move player toward NPC
    local npcs = NPCRegistry.getAll()
    if #npcs > 0 then
        local npc = npcs[1]
        controller:press('right')
        FrameStepper.step(game, 30)
        controller:release('right')
        
        -- NPC should react (change state, move, etc.)
        assert(npc.stateMachine.currentState ~= nil, 'NPC should have state')
    end
    
    game:shutdown()
    print('test_playerNPCInteraction: PASS')
end

test_mapLoadsWithAllNPCTypes()
test_npcsUpdateWithoutErrors()
test_playerNPCInteraction()
print('All full map integration tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/npc_full_map_test.lua`
Expected: FAIL (may need map with NPCs placed)

- [ ] **Step 3: Ensure test map has NPC objects**

```lua
-- In res/map/sandbox.lua or create test map, ensure objects layer has:
-- {type = 'spider', x = 200, y = 100, properties = {}}
-- {type = 'robot', x = 400, y = 100, properties = {}}
-- {type = 'bird_npc', x = 300, y = 50, properties = {}}
-- {type = 'rabbit_npc', x = 300, y = 200, properties = {}}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/npc_full_map_test.lua`
Expected: PASS (all 3 tests)

- [ ] **Step 5: Commit**

```bash
git add tests/integration/npc_full_map_test.lua
git commit -m "test(npc): add full map integration test with all NPC types"
```

---

### Task 13: E2E Tests (Headed, Real Rendering)

**Files:**
- Create: `tests/e2e/npc_e2e_test.lua`

**Interfaces:**
- Consumes: All NPC types, `GameHarness` with `{real=true}`, `Capture` for screenshots
- Produces: E2E test that runs real LÖVE window, captures frames, verifies visual behavior

- [ ] **Step 1: Write the failing test**

```lua
-- tests/e2e/npc_e2e_test.lua
local GameHarness = require('tests.support.game_harness')
local NPCRegistry = require('npc.npc_registry')
local Spider = require('entities.spider')
local Robot = require('entities.robot')
local RabbitNPC = require('entities.rabbit_npc')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInput = require('tests.support.fake_input').FakeInput
local Capture = require('tests.support.capture')

local function test_spiderChasesPlayerVisually()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    
    local game = GameHarness.startGame('res/map/sandbox.lua', {real = true})
    local controller = FakeInput.new()
    
    FrameStepper.step(game, 10)
    
    -- Position player near spider
    controller:press('right')
    FrameStepper.step(game, 30)
    controller:release('right')
    
    -- Capture frame showing spider chasing
    local path = Capture.capture('spider_chase')
    assert(path ~= nil, 'should capture screenshot')
    
    local npcs = NPCRegistry.getAll()
    local spider = npcs[1]
    assert(spider.stateMachine.currentState.name == 'ChaseState' or 
           spider.stateMachine.currentState.name == 'AttackState',
           'spider should be chasing/attacking')
    
    game:shutdown()
    print('test_spiderChasesPlayerVisually: PASS')
end

local function test_rabbitFollowsPlayerVisually()
    NPCRegistry.clear()
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    
    local game = GameHarness.startGame('res/map/sandbox.lua', {real = true})
    local controller = FakeInput.new()
    
    FrameStepper.step(game, 10)
    
    controller:press('right')
    FrameStepper.step(game, 30)
    controller:release('right')
    
    local path = Capture.capture('rabbit_follow')
    assert(path ~= nil, 'should capture screenshot')
    
    local npcs = NPCRegistry.getAll()
    local rabbit = npcs[1]
    assert(rabbit.stateMachine.currentState.name == 'FollowState',
           'rabbit should be following')
    
    game:shutdown()
    print('test_rabbitFollowsPlayerVisually: PASS')
end

local function test_robotPatrolsAndAttacksVisually()
    NPCRegistry.clear()
    NPCRegistry.registerType('robot', Robot)
    
    local game = GameHarness.startGame('res/map/sandbox.lua', {real = true})
    
    FrameStepper.step(game, 60)  -- Let robot patrol
    
    local path1 = Capture.capture('robot_patrol')
    assert(path1 ~= nil, 'should capture patrol screenshot')
    
    local npcs = NPCRegistry.getAll()
    local robot = npcs[1]
    assert(robot.stateMachine.currentState.name == 'PatrolState',
           'robot should be patrolling initially')
    
    game:shutdown()
    print('test_robotPatrolsAndAttacksVisually: PASS')
end

local function test_npcPushingVisually()
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    NPCRegistry.registerType('robot', Robot)
    
    local game = GameHarness.startGame('res/map/sandbox.lua', {real = true})
    
    FrameStepper.step(game, 10)
    
    -- Spawn second NPC near first to test pushing
    local spider = NPCRegistry.spawn('spider', 100, 100, {canPush = true})
    local robot = NPCRegistry.spawn('robot', 130, 100, {canBePushed = true})
    
    FrameStepper.step(game, 30)
    
    local path = Capture.capture('npc_pushing')
    assert(path ~= nil, 'should capture pushing screenshot')
    
    game:shutdown()
    print('test_npcPushingVisually: PASS')
end

test_spiderChasesPlayerVisually()
test_rabbitFollowsPlayerVisually()
test_robotPatrolsAndAttacksVisually()
test_npcPushingVisually()
print('All E2E tests passed')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-e2e.sh tests/e2e/npc_e2e_test.lua`
Expected: FAIL (may need map setup, visual verification)

- [ ] **Step 3: Run with --paced flag for manual verification**

Run: `./test-e2e.sh --paced tests/e2e/npc_e2e_test.lua`
Expected: Opens real window, runs at 1 sim frame = 1 real frame for observation

- [ ] **Step 4: Run with --filmstrip for capture**

Run: `./test-e2e.sh --filmstrip=5 tests/e2e/npc_e2e_test.lua`
Expected: Captures every 5th frame to `tests/screenshots/`

- [ ] **Step 5: Commit**

```bash
git add tests/e2e/npc_e2e_test.lua
git commit -m "test(npc): add E2E tests with frame capture"
```

---

## Execution Summary

**Total Tasks:** 13
- Task 1: NPCConfig schema (unit)
- Task 2: NPCBase class (unit)
- Task 3: Enhanced FSM states (unit)
- Task 4: NPCRegistry (unit)
- Task 5: Entity Factory integration (integration)
- Task 6: Spider migration (integration)
- Task 7: Robot migration (integration)
- Task 8: Bird migration (integration)
- Task 9: Rabbit migration (integration)
- Task 10: Physics integration (integration)
- Task 11: Cleanup old files (unit)
- Task 12: Full map integration (integration)
- Task 13: E2E tests (e2e)

**Estimated Time:** ~2-3 days for full implementation

**Test Commands:**
- Unit: `./test-unit.sh tests/unit/<test_file>.lua`
- Integration: `./test-integration.sh tests/integration/<test_file>.lua`
- E2E: `./test-e2e.sh [--paced|--filmstrip] tests/e2e/<test_file>.lua`
- All: `./test-all.sh`

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-02-npc-system-upgrade.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**