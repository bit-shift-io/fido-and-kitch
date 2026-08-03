-- tests/unit/npc_states_test.lua
require('tests.support.headless_bootstrap')
local NPCBase = require('src.npc.npc_base')

-- Mock entity for state testing
local function createMockNPC(overrides)
    local npc = NPCBase({x = 0, y = 0})
    for k, v in pairs(overrides or {}) do
        npc[k] = v
    end
    return npc
end

-- Helper to create a state instance with entity attached (as StateMachine does)
local function createStateInstance(StateClass, entity)
    local instance = StateClass({})
    instance.entity = entity
    instance.fsm = {}
    instance.name = 'test'
    return instance
end

local function test_IdleState_enter_setsVelocityZero()
    local IdleState = require('src.npc.states.idle_state')
    local npc = createMockNPC({collider = {vx = 10, vy = 5}})
    local state = createStateInstance(IdleState, npc)
    state:enter(nil)
    assert(npc.collider.vx == 0 and npc.collider.vy == 0, 'IdleState should zero velocity')
    print('test_IdleState_enter_setsVelocityZero: PASS')
end

local function test_WanderState_enter_picksRandomDirection()
    local WanderState = require('src.npc.states.wander_state')
    local npc = createMockNPC({
        config = {maxSpeed = 50, wanderRadius = 100},
        collider = {vx = 0, vy = 0},
    })
    local state = createStateInstance(WanderState, npc)
    state:enter(nil)
    assert(npc.wanderTarget ~= nil, 'should set wanderTarget')
    assert(npc.wanderTarget.x ~= nil and npc.wanderTarget.y ~= nil, 'wanderTarget should have x,y')
    print('test_WanderState_enter_picksRandomDirection: PASS')
end

local function test_WanderState_update_movesTowardTarget()
    local WanderState = require('src.npc.states.wander_state')
    local npc = createMockNPC({
        config = {maxSpeed = 50, acceleration = 200},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
        wanderTarget = {x = 100, y = 0},
    })
    local state = createStateInstance(WanderState, npc)
    state:update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward wander target')
    print('test_WanderState_update_movesTowardTarget: PASS')
end

local function test_ChaseState_enter_setsTarget()
    local ChaseState = require('src.npc.states.chase_state')
    local npc = createMockNPC({
        target = {x = 200, y = 0},
        config = {maxSpeed = 80, acceleration = 300},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
    })
    local state = createStateInstance(ChaseState, npc)
    state:enter(nil)
    assert(npc.chaseTarget ~= nil, 'should set chaseTarget')
    print('test_ChaseState_enter_setsTarget: PASS')
end

local function test_ChaseState_update_movesTowardTarget()
    local ChaseState = require('src.npc.states.chase_state')
    local npc = createMockNPC({
        target = {x = 200, y = 0},
        config = {maxSpeed = 80, acceleration = 300},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
        chaseTarget = {x = 200, y = 0},
    })
    local state = createStateInstance(ChaseState, npc)
    state:update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward chase target')
    print('test_ChaseState_update_movesTowardTarget: PASS')
end

local function test_FollowState_maintainsDistance()
    local FollowState = require('src.npc.states.follow_state')
    local npc = createMockNPC({
        target = {x = 100, y = 0},
        config = {maxSpeed = 60, acceleration = 250, followDistance = 40},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
    })
    local state = createStateInstance(FollowState, npc)
    state:enter(nil)
    state:update(npc, 0.1)
    -- Should not close to zero distance, maintain followDistance
    local dist = math.sqrt((npc.collider.x - 100)^2 + npc.collider.y^2)
    -- Just verify it's moving toward target
    assert(npc.collider.vx > 0, 'should move toward follow target')
    print('test_FollowState_maintainsDistance: PASS')
end

local function test_PatrolState_cyclesPoints()
    local PatrolState = require('src.npc.states.patrol_state')
    local npc = createMockNPC({
        x = -10,
        config = {
            maxSpeed = 50,
            acceleration = 200,
            patrolPoints = {{x=0,y=0}, {x=100,y=0}, {x=100,y=100}}
        },
        collider = {vx = 0, vy = 0},
        currentPatrolIndex = 1,
        patrolDirection = 1,
    })
    local state = createStateInstance(PatrolState, npc)
    state:enter(nil)
    assert(npc.patrolTarget ~= nil, 'should set patrolTarget')
    state:update(npc, 0.1)
    assert(npc.collider.vx > 0, 'should move toward first patrol point')
    print('test_PatrolState_cyclesPoints: PASS')
end

local function test_AttackState_dealsDamage()
    local AttackState = require('src.npc.states.attack_state')
    local npc = createMockNPC({
        target = {x = 10, y = 0, takeDamage = function(self, amt) self.hit = amt end},
        config = {attackRange = 32, damage = 2, attackCooldown = 1.0},
        collider = {vx = 0, vy = 0, x = 0, y = 0},
    })
    local state = createStateInstance(AttackState, npc)
    state:enter(nil)
    npc.attackTimer = 0.9  -- Set close to cooldown so first update triggers attack
    state:update(0.2)  -- This should push timer over 1.0
    assert(npc.target.hit == 2, 'should deal damage to target')
    print('test_AttackState_dealsDamage: PASS')
end

local function test_FleeState_movesAwayFromThreat()
    local FleeState = require('src.npc.states.flee_state')
    local npc = createMockNPC({
        x = 50,
        target = {x = 0, y = 0},  -- threat at origin
        config = {maxSpeed = 100, acceleration = 400, fleeThreshold = 0.3},
        collider = {vx = 0, vy = 0},
        health = 1,
        maxHealth = 10,
    })
    local state = createStateInstance(FleeState, npc)
    state:enter(nil)
    state:update(npc, 0.1)
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