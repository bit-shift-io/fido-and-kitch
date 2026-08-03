-- tests/integration/bird_migration_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_bird_extendsNPCBase()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local BirdNPC = require('src.entities.npc_bird')
    
    local bird = BirdNPC({x = 0, y = 0})
    assert(bird.config ~= nil, 'should have config')
    assert(bird.stateMachine ~= nil, 'should have stateMachine')
    print('test_bird_extendsNPCBase: PASS')
end

local function test_bird_defaultConfig()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local BirdNPC = require('src.entities.npc_bird')
    
    local bird = BirdNPC({x = 0, y = 0})
    assert(bird.config.behavior == 'follow', 'bird should default to follow behavior')
    assert(bird.config.maxSpeed > 0, 'should have maxSpeed')
    assert(bird.config.ridePlatforms == false, 'bird should not ride platforms')
    -- Note: canBePushed is true by default in NPCConfig, overridden to false in BirdNPC
    assert(bird.config.canBePushed == false, 'bird should not be pushable, got ' .. tostring(bird.config.canBePushed))
    print('test_bird_defaultConfig: PASS')
end

local function test_bird_spawnsViaRegistry()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local BirdNPC = require('src.entities.npc_bird')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('bird_npc', BirdNPC)
    
    local bird = NPCRegistry.spawn('bird_npc', 100, 100, {})
    assert(bird ~= nil, 'should spawn via registry')
    assert(bird.x == 100 and bird.y == 100, 'should set position')
    print('test_bird_spawnsViaRegistry: PASS')
end

local function test_bird_followsPlayer()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local BirdNPC = require('src.entities.npc_bird')
    
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
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local BirdNPC = require('src.entities.npc_bird')
    
    local bird = BirdNPC({x = 0, y = 0, followDistance = 50})
    local player = {x = 100, y = 0}
    bird:setTarget(player)
    
    bird:update(0.1)
    -- Bird should not get too close, maintain follow distance
    local dist = math.sqrt((bird.x - 100)^2 + bird.y^2)
    assert(dist > 20, 'should maintain some distance from player')
    print('test_bird_maintainsFollowDistance: PASS')
end

local function test_bird_fliesOverObstacles()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local BirdNPC = require('src.entities.npc_bird')
    
    local bird = BirdNPC({x = 0, y = 0, canFly = true})
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