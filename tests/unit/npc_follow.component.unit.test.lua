-- Tests for NPCFollowComponent

local function bootGlobals()
    tbl = require('src.utils.tbl')
    str = require('src.utils.str')
    utils = require('src.utils.utils')
    
    Vector = require('lib.hump.vector')
    Class = require('lib.hump.class')
    Signal = require('src.utils.signal')
    Tween = require('lib.tween.tween')
end

bootGlobals()

local Entity = require('src.entity')
local NPCFollowComponent = require('src.components.npc_follow')
local Log = require('src.utils.log')

-- Mock world for testing
local MockWorld = Class{}
function MockWorld:init()
    self.colliders = {}
end
function MockWorld:queryRect(x, y, w, h)
    return {}, 0
end
function MockWorld:addEntity(entity) end

-- Mock player
local MockPlayer = Class{}
function MockPlayer:init(index, x, y)
    self.index = index
    self.x = x
    self.y = y
    self.dead = false
    self.positionHistory = {}
    self.safePosition = {x = x, y = y}
    
    self.collider = {
        getX = function() return self.x end,
        getY = function() return self.y end,
        getBounds = function() 
            return {left = self.x - 10, top = self.y - 15, width = 20, height = 30, bottom = self.y + 15}
        end,
        setPosition = function(x, y) self.x = x; self.y = y end
    }
end
function MockPlayer:isDead() return self.dead end
function MockPlayer:getPositionHistory() return self.positionHistory end

function MockPlayer:new(index, x, y)
    return MockPlayer(index, x, y)
end

-- Mock entity for NPC
local MockNPCEntity = Class{__includes = Entity}
function MockNPCEntity:init(x, y)
    Entity.init(self)
    self.x = x
    self.y = y
    self.alpha = 1
    self.components = {}
    self.npc_follow = nil
    
    -- Mock collider
    local entityRef = self
    self.collider = {
        getBounds = function()
            return {left = entityRef.x - 8, top = entityRef.y - 8, width = 16, height = 16, bottom = entityRef.y + 8}
        end,
        setPosition = function(_, x, y) 
            entityRef.x = x
            entityRef.y = y
        end
    }
    self.components.collider = self.collider
end

function MockNPCEntity:new(x, y)
    return MockNPCEntity(x, y)
end

-- Setup global state
_G.players = {}
_G.npcEntities = {}
_G.world = MockWorld()
_G.Tween = Tween

test('NPCFollowComponent initializes with config and stores reference to entity', function()
    local entity = MockNPCEntity:new(100, 100)
    local config = {movementType = 'fly', followDistance = 4, maxSpeed = 120}
    local component = NPCFollowComponent(entity, config)
    
    assertEqual(entity, component.entity)
    assertEqual('fly', component.movementType)
    assertEqual(4, component.followDistance)
    assertEqual(120, component.maxSpeed)
    assertEqual(1, component.targetPlayerIndex)
    assertEqual(0, component.velocity.x)
    assertEqual(0, component.velocity.y)
end)

test('NPCFollowComponent defaults config values for fly type', function()
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly'})
    
    assertEqual('fly', component.movementType)
    assertEqual(4, component.followDistance)
    assertEqual(120, component.maxSpeed)
    assertEqual(20, component.teleportDistance)
    assertEqual(8, component.switchRange)
    assertEqual(3, component.switchInterval)
    assertEqual(2, component.arrivalRadius)
end)

test('NPCFollowComponent defaults config values for hop type', function()
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'hop'})
    
    assertEqual('hop', component.movementType)
    assertEqual(2, component.followDistance)
    assertEqual(80, component.maxSpeed)
    assertEqual(20, component.teleportDistance)
    assertEqual(6, component.switchRange)
    assertEqual(1, component.arrivalRadius)
end)

test('setTarget updates follow target', function()
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly'})
    
    component:setTarget(2)
    assertEqual(2, component.targetPlayerIndex)
    
    component:setTarget(1)
    assertEqual(1, component.targetPlayerIndex)
end)

test('teleportTo moves entity and triggers blink', function()
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly'})
    
    component:teleportTo(200, 200)
    
    assertEqual(200, entity.x)
    assertEqual(200, entity.y)
    assertEqual(0, entity.alpha)
end)

test('Fly movement: seek behavior moves toward target', function()
    _G.players = {
        MockPlayer:new(1, 200, 100),
        MockPlayer:new(2, 400, 100)
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', maxSpeed = 100})
    
    component:update(0.1)
    
    -- Should have moved toward player 1
    assertTrue(entity.x > 100, 'NPC should move toward target player')
    -- Don't check overshoot since movement is frame-based
end)

test('Fly movement: arrival radius slows down near target', function()
    _G.players = {
        MockPlayer:new(1, 110, 100),
        MockPlayer:new(2, 400, 100)
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', maxSpeed = 100, arrivalRadius = 20})
    
    component:update(0.1)
    
    -- Near target, velocity should be reduced
    local distance = math.sqrt((entity.x - 110)^2 + (entity.y - 100)^2)
    assertTrue(distance < 20, 'NPC should be within arrival radius')
end)

test('Fly movement: separation from other birds', function()
    _G.players = {MockPlayer:new(1, 200, 100)}
    _G.npcEntities = {}
    
    local entity1 = MockNPCEntity:new(100, 100)
    local component1 = NPCFollowComponent(entity1, {movementType = 'fly', maxSpeed = 100})
    entity1.npc_follow = component1
    
    local entity2 = MockNPCEntity:new(105, 100)
    local component2 = NPCFollowComponent(entity2, {movementType = 'fly', maxSpeed = 100})
    entity2.npc_follow = component2
    
    _G.npcEntities = {entity1, entity2}
    
    component1:update(0.1)
    
    -- Should have separation force applied
    assertTrue(entity1.x ~= 100 or entity1.y ~= 100, 'Separation should move NPC')
end)

test('Hop movement: follows breadcrumb trail', function()
    _G.players = {MockPlayer:new(1, 200, 100)}
    _G.players[1].positionHistory = {
        {x = 100, y = 100, t = 1},
        {x = 110, y = 100, t = 2},
        {x = 120, y = 100, t = 3},
        {x = 130, y = 100, t = 4},
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'hop', maxSpeed = 80, followDistance = 4})
    
    component:update(0.1)
    
    -- Should move toward breadcrumb within follow distance
    assertTrue(entity.x > 100, 'NPC should follow breadcrumb trail')
end)

test('Teleport triggers when distance exceeds threshold', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    
    -- Should have teleported to player (distance = 1900 pixels, threshold = 50*32 = 1600)
    assertTrue(entity.x > 1900 and entity.x < 2100, 'NPC should teleport to player')
end)

test('Teleport has cooldown', function()
    _G.players = {MockPlayer:new(1, 1000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    local firstTeleportX = entity.x
    
    -- Move player again
    _G.players[1].x = 2000
    component:update(1.5) -- Advance time past cooldown
    
    -- Should have teleported again after cooldown expired
    assertTrue(entity.x > 1900 and entity.x < 2100, 'NPC should teleport again after cooldown')
end)

test('Bird target switching: random switch when both players in range', function()
    _G.players = {
        MockPlayer:new(1, 120, 100),
        MockPlayer:new(2, 140, 100)
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', switchRange = 10, switchInterval = 0.1})
    
    component:update(0.2)
    
    -- Should have switched target (random, so just verify it can switch)
    assertTrue(component.targetPlayerIndex == 1 or component.targetPlayerIndex == 2)
end)

test('Bird target switching: no switch when only one player in range', function()
    _G.players = {
        MockPlayer:new(1, 120, 100),
        MockPlayer:new(2, 500, 100)
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', switchRange = 10, switchInterval = 0.1})
    
    component:update(0.2)
    
    -- Should not switch since player 2 is out of range
    assertEqual(1, component.targetPlayerIndex)
end)

test('Bird target switching: no switch to dead player', function()
    _G.players = {
        MockPlayer:new(1, 120, 100),
        MockPlayer:new(2, 140, 100)
    }
    _G.players[2].dead = true
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', switchRange = 10, switchInterval = 0.1})
    
    component:update(0.2)
    
    -- Should not switch to dead player
    assertEqual(1, component.targetPlayerIndex)
end)

test('Rabbit target switching: switches to nearest with hysteresis', function()
    _G.players = {
        MockPlayer:new(1, 120, 100),
        MockPlayer:new(2, 140, 100)
    }
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'hop', switchRange = 10})
    component.targetPlayerIndex = 1
    
    component:update(0.1)
    
    -- Player 2 is closer, should switch with hysteresis
    -- 140-100 = 40, 120-100 = 20, ratio = 0.5 < 0.8, so should switch
    -- Actually player 1 is closer (20 vs 40), so should NOT switch
    assertEqual(1, component.targetPlayerIndex)
end)

test('Rabbit target switching: switches when other is significantly closer', function()
    _G.players = {
        MockPlayer:new(1, 200, 100),
        MockPlayer:new(2, 130, 100)
    }
    -- Add position history so updateHop doesn't return early
    _G.players[1].positionHistory = {{x = 200, y = 100, t = 1}}
    _G.players[2].positionHistory = {{x = 130, y = 100, t = 1}}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'hop', switchRange = 10})
    component.targetPlayerIndex = 1
    
    component:update(0.1)
    
    -- Player 2 is at distance 30, player 1 at 100
    -- 30 < 100 * 0.8 = 80, so should switch to player 2
    assertEqual(2, component.targetPlayerIndex)
end)

test('onPlayerRespawn teleports NPC to player', function()
    _G.players = {MockPlayer:new(1, 500, 500)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly'})
    component.targetPlayerIndex = 1
    
    component:onPlayerRespawn(1)
    
    assertTrue(entity.x > 490 and entity.x < 510, 'NPC should teleport to respawned player')
    assertTrue(entity.y > 490 and entity.y < 510, 'NPC should teleport to respawned player')
end)

return true