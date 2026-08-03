-- tests/unit/npc_base_test.lua
require('tests.support.headless_bootstrap')
local NPCBase = require('src.npc.npc_base')
local NPCConfig = require('src.npc.npc_config')
local Entity = require('src.entity')

local function test_NPCBase_extendsEntity()
    local npc = NPCBase({x = 100, y = 100})
    -- Check that NPCBase extends Entity by verifying it has Entity methods
    assert(type(npc.update) == 'function', 'should have update method from Entity')
    assert(type(npc.addComponent) == 'function', 'should have addComponent method from Entity')
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