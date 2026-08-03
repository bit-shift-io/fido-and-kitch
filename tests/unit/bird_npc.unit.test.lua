-- Tests for Bird NPC entity

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

local BirdNPC = require('src.entities.npc_bird')

-- Mock Tiled object
local function createMockTiledObject(x, y)
    return {
        x = x,
        y = y,
        width = 16,
        height = 16,
        name = 'bird_npc',
        properties = {}
    }
end

test('BirdNPC entity creation: has correct components', function()
    local object = createMockTiledObject(100, 100)
    local bird = BirdNPC(object)
    
    assertEqual('bird_npc', bird.type)
    assertEqual('bird_npc', bird.name)
    assertTrue(bird.sprite ~= nil)
    assertTrue(bird.collider ~= nil)
    assertTrue(bird.followComponent ~= nil)
end)

test('BirdNPC entity: collider is sensor', function()
    local object = createMockTiledObject(100, 100)
    local bird = BirdNPC(object)
    
    assertTrue(bird.collider.isSensor)
end)

test('BirdNPC entity: has NPCFollowComponent with fly movement', function()
    local object = createMockTiledObject(100, 100)
    local bird = BirdNPC(object)
    
    assertEqual('fly', bird.followComponent.movementType)
    assertEqual(4, bird.followComponent.followDistance)
    assertEqual(120, bird.followComponent.maxSpeed)
end)

test('BirdNPC onSpawn sets follow target', function()
    local object = createMockTiledObject(100, 100)
    local bird = BirdNPC(object)
    
    bird:onSpawn(2)
    
    assertEqual(2, bird.followComponent.targetPlayerIndex)
end)

test('BirdNPC entity registered in entity factory', function()
    -- This test just verifies the module loads without error
    assertTrue(BirdNPC ~= nil)
end)

return true