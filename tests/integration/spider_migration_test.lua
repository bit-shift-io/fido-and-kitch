-- tests/integration/spider_migration_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_spider_extendsNPCBase()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Spider = require('src.entities.npc_spider')
    
    local spider = Spider({x = 0, y = 0})
    assert(spider.config ~= nil, 'should have config')
    assert(spider.stateMachine ~= nil, 'should have stateMachine')
    assert(spider.health ~= nil, 'should have health')
    print('test_spider_extendsNPCBase: PASS')
end

local function test_spider_defaultConfig()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Spider = require('src.entities.npc_spider')
    
    local spider = Spider({x = 0, y = 0})
    assert(spider.config.behavior == 'chase', 'spider should default to chase behavior')
    assert(spider.config.maxSpeed > 0, 'should have maxSpeed')
    assert(spider.config.detectionRadius > 0, 'should have detectionRadius')
    assert(spider.config.attackRange > 0, 'should have attackRange')
    assert(spider.config.damage > 0, 'should have damage')
    print('test_spider_defaultConfig: PASS')
end

local function test_spider_spawnsViaRegistry()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('spider', Spider)
    
    local spider = NPCRegistry.spawn('spider', 100, 100, {})
    assert(spider ~= nil, 'should spawn via registry')
    assert(spider.x == 100 and spider.y == 100, 'should set position')
    print('test_spider_spawnsViaRegistry: PASS')
end

local function test_spider_chasesPlayer()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Spider = require('src.entities.npc_spider')
    
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
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Spider = require('src.entities.npc_spider')
    
    -- Pass properties directly, not nested in config table
    local spider = Spider({x = 0, y = 0, attackRange = 32, damage = 1, attackCooldown = 1.0})
    local player = {x = 10, y = 0, takeDamage = function(self, amt) self.hit = amt end}
    spider:setTarget(player)
    
    spider.attackTimer = 0.9  -- Set close to cooldown so first update triggers attack
    print("DEBUG: before update, attackTimer = " .. spider.attackTimer)
    spider:update(0.2)
    print("DEBUG: after update, attackTimer = " .. spider.attackTimer)
    print("DEBUG: spider state = " .. spider.stateMachine.currentState.name)
    -- Attack state should deal damage
    assert(player.hit == 1, 'should deal damage to player in range, got ' .. tostring(player.hit))
    print('test_spider_attacksInRange: PASS')
end

local function test_spider_fleesWhenLowHealth()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local Spider = require('src.entities.npc_spider')
    
    -- Target far away so chase utility is 0, flee utility wins
    -- Pass health=10 (maxHealth), then set health=1 to get healthRatio = 0.1
    local spider = Spider({x = 50, y = 0, health = 10, config = {fleeThreshold = 0.3}})
    spider.health = 1  -- Override to low health after init
    spider.maxHealth = 10  -- Ensure maxHealth is correct
    local threat = {x = 500, y = 0}  -- Far outside detection radius
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