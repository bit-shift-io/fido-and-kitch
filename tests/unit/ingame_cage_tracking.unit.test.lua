-- Tests for InGameState cage tracking and all_cages_unlocked event

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

local InGameState = require('src.states.ingame_state')

test('InGameState onCageUnlocked emits all_cages_unlocked when all cages unlocked', function()
    local allUnlockedReceived = false
    local allUnlockedData = nil
    EventBus.on('all_cages_unlocked', function(data)
        allUnlockedReceived = true
        allUnlockedData = data
    end)
    
    local state = InGameState()
    state.totalCages = 2
    state.unlockedCages = 0
    
    -- Simulate cage unlocked events
    state:onCageUnlocked({cage = {}, spawnType = 'bird', totalCages = 2, unlockedCount = 1})
    assertFalse(allUnlockedReceived)
    
    state:onCageUnlocked({cage = {}, spawnType = 'rabbit', totalCages = 2, unlockedCount = 2})
    assertTrue(allUnlockedReceived)
    assertTrue(allUnlockedData ~= nil)
    assertEqual(2, allUnlockedData.totalCages)
end)

test('InGameState onCageUnlocked handles zero cages', function()
    local allUnlockedReceived = false
    EventBus.on('all_cages_unlocked', function(data)
        allUnlockedReceived = true
    end)
    
    local state = InGameState()
    state.totalCages = 0
    state.unlockedCages = 0
    
    -- Should emit immediately when totalCages is 0
    -- Note: In real load(), this happens automatically
    state:onCageUnlocked({cage = {}, spawnType = 'bird', totalCages = 0, unlockedCount = 0})
    assertTrue(allUnlockedReceived)
end)

return true