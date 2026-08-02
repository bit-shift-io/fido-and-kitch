-- Tests for NPC Teleport/Blink on player respawn or excessive distance

package.path = './?/init.lua;' .. package.path

local LoveMock = require('tests.support.love_mock')
love = LoveMock.new()

tbl = require('src.utils.tbl')
str = require('src.utils.str')
utils = require('src.utils.utils')
conf = require('conf')
love.conf({graphics = {}, window = {}, modules = {}, audio = {}})
conf.args = {}
conf.t = {physics = 'bump'}

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
Tween = require('lib.tween.tween')

Rect = require('src.utils.rect')
Signal = require('src.utils.signal')
World = require('src.world')
Entity = require('src.entity')
StateMachine = require('src.components.state_machine')
Sprite = require('src.components.sprite')
Path = require('src.components.path')
Timeline = require('src.components.timeline')
PathFollow = require('src.components.path_follow')
Collider = require('src.components.collider')
Pickup = require('src.components.pickup')
Inventory = require('src.components.inventory')
Usable = require('src.components.usable')
Variable = require('src.components.variable')
Sound = require('src.components.sound')
InputManager = require('src.input.input_manager')

-- Reset world for test
world = World:new(0, 0, true)

-- Mock input manager
_G.inputManager = {
    isDown = function() return false end,
    wasPressed = function() return false end,
    update = function() end
}

-- Mock players
_G.players = {}

local NPCFollowComponent = require('src.components.npc_follow')

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

-- Mock player
local MockPlayer = Class{}
function MockPlayer:init(index, x, y)
    self.index = index
    self.x = x
    self.y = y
    self.dead = false
    self.positionHistory = {{x = x, y = y, t = 1}}
    self.safePosition = {x = x, y = y}
    
    local entityRef = self
    self.collider = {
        getX = function() return entityRef.x end,
        getY = function() return entityRef.y end,
        getBounds = function() 
            return {left = entityRef.x - 10, top = entityRef.y - 15, width = 20, height = 30, bottom = entityRef.y + 15}
        end,
        setPosition = function(_, x, y) entityRef.x = x; entityRef.y = y end
    }
end
function MockPlayer:isDead() return self.dead end
function MockPlayer:getPositionHistory() return self.positionHistory end

function MockPlayer:new(index, x, y)
    return MockPlayer(index, x, y)
end

test('NPC teleports when distance exceeds threshold', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    
    -- Should have teleported to player (distance > 50*32 = 1600)
    assertTrue(entity.x > 1900 and entity.x < 2100, 'NPC should teleport to player')
end)

test('NPC teleport triggers blink animation', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    
    -- Alpha should be 0 after teleport (blink starts)
    assertEqual(0, entity.alpha)
end)

test('NPC teleport has cooldown', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    local firstTeleportX = entity.x
    
    -- Move player far away again
    _G.players[1].x = 4000
    component:update(1.5) -- Advance time past cooldown
    
    -- Should have teleported again after cooldown expired
    assertTrue(entity.x > 3900 and entity.x < 4100, 'NPC should teleport again after cooldown')
end)

test('NPC does not teleport during cooldown', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    local firstTeleportX = entity.x
    
    -- Move player far away again immediately
    _G.players[1].x = 4000
    component:update(0.1) -- Still within cooldown
    
    -- Should NOT have teleported to player (would be ~4000), but may move slightly due to follow behavior
    assertTrue(entity.x < 3000, 'NPC should not teleport to player during cooldown')
    assertTrue(entity.x > firstTeleportX, 'NPC may move slightly toward player due to follow behavior')
end)

test('NPC teleports to player on respawn', function()
    _G.players = {MockPlayer:new(1, 500, 500)}
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly'})
    component.targetPlayerIndex = 1
    
    component:onPlayerRespawn(1)
    
    assertTrue(entity.x > 490 and entity.x < 510, 'NPC should teleport to respawned player')
    assertTrue(entity.y > 490 and entity.y < 510, 'NPC should teleport to respawned player')
    assertEqual(0, entity.alpha, 'Blink should trigger on respawn')
end)

test('NPC does not teleport to dead player', function()
    _G.players = {MockPlayer:new(1, 2000, 100)}
    _G.players[1].dead = true
    
    local entity = MockNPCEntity:new(100, 100)
    local component = NPCFollowComponent(entity, {movementType = 'fly', teleportDistance = 50})
    
    component:update(0.1)
    
    -- Should not teleport to dead player
    assertEqual(100, entity.x, 'NPC should not teleport to dead player')
end)

return true