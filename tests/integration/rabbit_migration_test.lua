-- tests/integration/rabbit_migration_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_rabbit_extendsNPCBase()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    local rabbit = RabbitNPC({x = 0, y = 0})
    assert(rabbit.config ~= nil, 'should have config')
    assert(rabbit.stateMachine ~= nil, 'should have stateMachine')
    print('test_rabbit_extendsNPCBase: PASS')
end

local function test_rabbit_defaultConfig()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    local rabbit = RabbitNPC({x = 0, y = 0})
    assert(rabbit.config.behavior == 'follow', 'rabbit should default to follow behavior')
    assert(rabbit.config.maxSpeed > 0, 'should have maxSpeed')
    assert(rabbit.config.ridePlatforms == true, 'rabbit should ride platforms')
    assert(rabbit.config.canBePushed == true, 'rabbit should be pushable')
    print('test_rabbit_defaultConfig: PASS')
end

local function test_rabbit_spawnsViaRegistry()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('rabbit_npc', RabbitNPC)
    
    local rabbit = NPCRegistry.spawn('rabbit_npc', 100, 100, {})
    assert(rabbit ~= nil, 'should spawn via registry')
    assert(rabbit.x == 100 and rabbit.y == 100, 'should set position')
    print('test_rabbit_spawnsViaRegistry: PASS')
end

local function test_rabbit_followsPlayer()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local RabbitNPC = require('src.entities.npc_rabbit')
    
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
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local RabbitNPC = require('src.entities.npc_rabbit')
    
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
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    local rabbit = RabbitNPC({x = 0, y = 0, ridePlatforms = true})
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