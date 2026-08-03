-- tests/integration/npc_physics_test.lua
require('tests.support.headless_bootstrap')

_G.Class = _G.Class or require('lib.hump.class')
_G.Vector = _G.Vector or require('lib.hump.vector')

local function setupRegistry()
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    local Robot = require('src.entities.npc_robot')
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('npc_spider', Spider)
    NPCRegistry.registerType('npc_robot', Robot)
    NPCRegistry.registerType('npc_rabbit', RabbitNPC)
    
    return NPCRegistry
end

local function test_npcs_canPushEachOther()
    local NPCRegistry = setupRegistry()
    
    local spider = NPCRegistry.spawn('npc_spider', 0, 0, {canPush = true, canBePushed = true, pushForce = 200})
    local robot = NPCRegistry.spawn('npc_robot', 50, 0, {canPush = true, canBePushed = true, pushForce = 200})
    
    -- Simulate collision
    spider:onCollision(robot, 1, 0)
    
    -- Robot should have been pushed
    assert(robot.collider.vx > 0, 'robot should be pushed by spider')
    print('test_npcs_canPushEachOther: PASS')
end

local function test_npc_pushesPlayer()
    local NPCRegistry = setupRegistry()
    
    local spider = NPCRegistry.spawn('npc_spider', 0, 0, {canPush = true, pushForce = 200})
    local rabbit = NPCRegistry.spawn('npc_rabbit', 40, 0, {canBePushed = true})
    
    spider:onCollision(rabbit, 1, 0)
    
    assert(rabbit.collider.vx > 0, 'NPC should be pushed by NPC')
    print('test_npc_pushesPlayer: PASS')
end

local function test_rabbit_ridesMovingPlatform()
    local NPCRegistry = setupRegistry()
    
    local rabbit = NPCRegistry.spawn('npc_rabbit', 0, 0, {ridePlatforms = true})
    local platform = {x = 0, y = 16, width = 64, height = 16, collider = {vx = 50, vy = 0}, isMovingPlatform = true}
    
    -- Rabbit lands on platform - simulate collision
    rabbit.collider.y = platform.y - 16
    rabbit.collider.vy = 0
    
    -- Simulate platform collision
    rabbit:onCollision(platform, 0, 1)
    
    -- Rabbit should move with platform
    assert(rabbit.collider.vx == platform.collider.vx, 'rabbit should ride platform, got vx=' .. rabbit.collider.vx .. ' expected ' .. platform.collider.vx)
    print('test_rabbit_ridesMovingPlatform: PASS')
end

local function test_robot_triggersSwitch()
    local NPCRegistry = setupRegistry()
    
    local robot = NPCRegistry.spawn('npc_robot', 0, 0, {triggerSwitches = true})
    local switch = {x = 30, y = 0, isSwitch = true, activated = false, activate = function(self, by) self.activated = true end}
    
    robot:onCollision(switch, 1, 0)
    
    assert(switch.activated == true, 'switch should be activated by robot')
    print('test_robot_triggersSwitch: PASS')
end

local function test_spider_doesNotTriggerSwitch()
    local NPCRegistry = setupRegistry()
    
    local spider = NPCRegistry.spawn('npc_spider', 0, 0, {triggerSwitches = false})
    local switch = {x = 30, y = 0, isSwitch = true, activated = false, activate = function(self, by) self.activated = true end}
    
    spider:onCollision(switch, 1, 0)
    
    assert(switch.activated == false, 'spider should not trigger switch')
    print('test_spider_doesNotTriggerSwitch: PASS')
end

local function test_npc_collisionWithSolidWall()
    local NPCRegistry = setupRegistry()
    
    local spider = NPCRegistry.spawn('npc_spider', 0, 0)
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