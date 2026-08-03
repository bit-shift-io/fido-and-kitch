-- Tests for Cage spawn NPC and event emission

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
EventBus = require('src.utils.event_bus')

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

local Cage = require('src.entities.cage')

-- Mock Tiled object
local function createMockTiledObject(x, y, color, spawnType)
    return {
        x = x,
        y = y,
        width = 32,
        height = 32,
        name = 'cage',
        properties = {
            color = color or 'red',
            spawn_type = spawnType or 'bird'
        }
    }
end

-- Mock map object
local function createMockMap()
    return {
        loadEntity = function(self, entityName, layer, object)
            if entityName == 'bird_npc' then
                local BirdNPC = require('src.entities.npc_bird')
                return BirdNPC(object)
            elseif entityName == 'rabbit_npc' then
                local RabbitNPC = require('src.entities.npc_rabbit')
                return RabbitNPC(object)
            end
            return nil
        end
    }
end

test('Cage reads spawn_type property', function()
    local object = createMockTiledObject(100, 100, 'red', 'bird')
    local cage = Cage(object, createMockMap())
    
    assertEqual('bird', cage.spawnType)
end)

test('Cage defaults to bird when spawn_type missing', function()
    local object = createMockTiledObject(100, 100, 'red', nil)
    object.properties.spawn_type = nil
    local cage = Cage(object, createMockMap())
    
    assertEqual('bird', cage.spawnType)
end)

test('Cage reads rabbit spawn_type', function()
    local object = createMockTiledObject(100, 100, 'blue', 'rabbit')
    local cage = Cage(object, createMockMap())
    
    assertEqual('rabbit', cage.spawnType)
end)

test('Cage use spawns bird NPC and emits event', function()
    local map = createMockMap()
    local object = createMockTiledObject(100, 100, 'red', 'bird')
    local cage = Cage(object, map)
    cage.map = map
    cage.totalCages = 2
    cage.unlockedCount = 0
    
    local eventReceived = false
    local eventData = nil
    EventBus.on('cage_unlocked', function(data)
        eventReceived = true
        eventData = data
    end)
    
    local mockUser = {index = 1}
    cage:use(mockUser)
    
    assertTrue(eventReceived)
    assertTrue(eventData ~= nil)
    assertEqual('bird', eventData.spawnType)
    assertEqual(2, eventData.totalCages)
    assertEqual(1, eventData.unlockedCount)
    assertEqual(cage, eventData.cage)
end)

test('Cage use spawns rabbit NPC and emits event', function()
    local map = createMockMap()
    local object = createMockTiledObject(100, 100, 'blue', 'rabbit')
    local cage = Cage(object, map)
    cage.map = map
    cage.totalCages = 1
    cage.unlockedCount = 0
    
    local eventReceived = false
    local eventData = nil
    EventBus.on('cage_unlocked', function(data)
        eventReceived = true
        eventData = data
    end)
    
    local mockUser = {index = 2}
    cage:use(mockUser)
    
    assertTrue(eventReceived)
    assertTrue(eventData ~= nil)
    assertEqual('rabbit', eventData.spawnType)
    assertEqual(1, eventData.totalCages)
    assertEqual(1, eventData.unlockedCount)
end)

test('Cage increments unlockedCount on each use', function()
    local map = createMockMap()
    local object = createMockTiledObject(100, 100, 'red', 'bird')
    local cage = Cage(object, map)
    cage.map = map
    cage.totalCages = 2
    cage.unlockedCount = 0
    
    local unlockCounts = {}
    EventBus.on('cage_unlocked', function(data)
        table.insert(unlockCounts, data.unlockedCount)
    end)
    
    local mockUser = {index = 1}
    cage:use(mockUser)
    cage:use(mockUser) -- Second call (though in practice cage would be disabled)
    
    assertEqual(1, unlockCounts[1])
    assertEqual(2, unlockCounts[2])
end)

return true