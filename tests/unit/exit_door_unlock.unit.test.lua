-- Tests for Exit Door unlock via all_cages_unlocked event

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

local ExitDoor = require('src.entities.exit_door')

-- Mock Tiled object for exit door
local function createMockExitDoorObject(x, y)
    return {
        x = x,
        y = y,
        width = 32,
        height = 64,
        name = 'exit_door',
        type = 'exit_door',
        properties = {
            actor_count = 0
        }
    }
end

test('ExitDoor initializes with usable disabled', function()
    local object = createMockExitDoorObject(400, 300)
    local door = ExitDoor(object)
    
    assertEqual('exit_door', door.type)
    assertFalse(door.usable.enabled)
    assertEqual('closed', door.state)
    assertFalse(door.cagesUnlocked)
end)

test('ExitDoor enables usable when all_cages_unlocked event received', function()
    local object = createMockExitDoorObject(400, 300)
    local door = ExitDoor(object)
    
    -- Initially not usable
    assertFalse(door.usable.enabled)
    assertFalse(door.cagesUnlocked)
    
    -- Emit the event
    EventBus.emit('all_cages_unlocked', {totalCages = 2})
    
    -- Should now be unlocked
    assertTrue(door.cagesUnlocked)
    assertEqual('open', door.desiredState)
end)

test('ExitDoor cleans up event listener on destroy', function()
    local object = createMockExitDoorObject(400, 300)
    local door = ExitDoor(object)
    
    -- Verify handler exists
    assertTrue(door.allCagesUnlockedHandler ~= nil)
    
    -- Destroy the door
    door:destroy()
    
    -- Emit event - should not cause errors
    local success, err = pcall(function()
        EventBus.emit('all_cages_unlocked', {totalCages = 2})
    end)
    
    print("success = " .. tostring(success) .. ", err = " .. tostring(err))
    
    -- Test passes if no error thrown
    assertTrue(success, "EventBus.emit should not throw after destroy: " .. tostring(err))
end)

return true