-- tests/integration/robot_migration_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_robot_extendsNPCBase()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Robot = require('src.entities.robot')
    
    local robot = Robot({x = 0, y = 0})
    assert(robot.config ~= nil, 'should have config')
    assert(robot.stateMachine ~= nil, 'should have stateMachine')
    assert(robot.health ~= nil, 'should have health')
    print('test_robot_extendsNPCBase: PASS')
end

local function test_robot_defaultConfig()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Robot = require('src.entities.robot')
    
    local robot = Robot({x = 0, y = 0})
    assert(robot.config.behavior == 'patrol', 'robot should default to patrol behavior')
    assert(robot.config.maxSpeed > 0, 'should have maxSpeed')
    assert(robot.config.health >= 3, 'robot should have higher health')
    assert(robot.config.attackRange > 32, 'robot should have ranged attack')
    print('test_robot_defaultConfig: PASS')
end

local function test_robot_spawnsViaRegistry()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local Robot = require('src.entities.robot')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('robot', Robot)
    
    local robot = NPCRegistry.spawn('robot', 100, 100, {})
    assert(robot ~= nil, 'should spawn via registry')
    assert(robot.x == 100 and robot.y == 100, 'should set position')
    print('test_robot_spawnsViaRegistry: PASS')
end

local function test_robot_patrolsBetweenPoints()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Robot = require('src.entities.robot')
    
    local robot = Robot({
        x = 0, y = 0,
        patrolPoints = {{x=0,y=0}, {x=100,y=0}, {x=100,y=100}},
        behavior = 'patrol'
    })
    
    robot:update(0.1)
    local stateName = robot.stateMachine.currentState.name
    assert(stateName == 'PatrolState', 'should be in patrol state, got ' .. stateName)
    print('test_robot_patrolsBetweenPoints: PASS')
end

local function test_robot_chasesWhenPlayerDetected()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Robot = require('src.entities.robot')
    
    local robot = Robot({x = 0, y = 0, detectionRadius = 200, behavior = 'patrol'})
    local player = {x = 50, y = 0}
    robot:setTarget(player)
    
    robot:update(0.1)
    
    local stateName = robot.stateMachine.currentState.name
    assert(stateName == 'ChaseState' or stateName == 'AttackState',
           'should chase when player detected, got ' .. stateName)
    print('test_robot_chasesWhenPlayerDetected: PASS')
end

local function test_robot_rangedAttack()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Robot = require('src.entities.robot')
    
    local robot = Robot({x = 0, y = 0, attackRange = 120, damage = 2, attackCooldown = 1.0})
    local player = {x = 50, y = 0, takeDamage = function(self, amt) self.hit = amt end}
    robot:setTarget(player)
    
    robot.attackTimer = 0.9
    robot:update(0.2)
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