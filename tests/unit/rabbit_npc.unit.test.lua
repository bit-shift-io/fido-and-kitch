-- Tests for Rabbit NPC entity

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

-- Mock players for NPC following
_G.players = {}

local RabbitNPC = require('src.entities.rabbit_npc')

-- Mock Tiled object
local function createMockTiledObject(x, y)
    return {
        x = x,
        y = y,
        width = 16,
        height = 16,
        name = 'rabbit_npc',
        properties = {}
    }
end

test('RabbitNPC entity creation: has correct components', function()
    local object = createMockTiledObject(100, 100)
    local rabbit = RabbitNPC(object)
    
    assertEqual('rabbit_npc', rabbit.type)
    assertEqual('rabbit_npc', rabbit.name)
    assertTrue(rabbit.sprite ~= nil)
    assertTrue(rabbit.collider ~= nil)
    assertTrue(rabbit.followComponent ~= nil)
end)

test('RabbitNPC entity: collider is sensor', function()
    local object = createMockTiledObject(100, 100)
    local rabbit = RabbitNPC(object)
    
    assertTrue(rabbit.collider.isSensor)
end)

test('RabbitNPC entity: has NPCFollowComponent with hop movement', function()
    local object = createMockTiledObject(100, 100)
    local rabbit = RabbitNPC(object)
    
    assertEqual('hop', rabbit.followComponent.movementType)
    assertEqual(2, rabbit.followComponent.followDistance)
    assertEqual(80, rabbit.followComponent.maxSpeed)
end)

test('RabbitNPC onSpawn sets follow target', function()
    local object = createMockTiledObject(100, 100)
    local rabbit = RabbitNPC(object)
    
    rabbit:onSpawn(2)
    
    assertEqual(2, rabbit.followComponent.targetPlayerIndex)
end)

test('RabbitNPC entity registered in entity factory', function()
    -- This test just verifies the module loads without error
    assertTrue(RabbitNPC ~= nil)
end)

return true