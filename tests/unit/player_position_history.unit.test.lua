-- Tests for Player position history (breadcrumb trail)

-- Bootstrap globals like integration tests do
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

-- Mock player object (like from Tiled)
local function createMockPlayerObject(x, y)
    return {
        x = x,
        y = y,
        width = 50,
        height = 50,
        name = 'spawn',
        properties = {}
    }
end

local Player = require('src.player.player')

test('Player initializes with empty position history', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    assertEqual('table', type(player.positionHistory))
    assertEqual(0, #player.positionHistory)
    assertEqual(120, player.maxPositionHistory)
    assertEqual(0, player.gameTime)
end)

test('Player records position each update', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016) -- ~60fps
    
    assertEqual(1, #player.positionHistory)
    local entry = player.positionHistory[1]
    assertTrue(entry.x ~= nil)
    assertTrue(entry.y ~= nil)
    assertTrue(entry.t ~= nil)
    assertTrue(entry.t > 0)
end)

test('Player position history records correct positions', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016)
    local firstX = player.positionHistory[1].x
    
    player:update(0.016)
    local secondX = player.positionHistory[2].x
    
    -- Position should be recorded
    assertEqual(2, #player.positionHistory)
end)

test('Player position history caps at max length', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    player.maxPositionHistory = 5 -- Set small for testing
    
    for i = 1, 10 do
        player:update(0.016)
    end
    
    assertEqual(5, #player.positionHistory)
    -- Should have the last 5 entries
    assertEqual(player.gameTime, player.positionHistory[5].t)
end)

test('Player getPositionHistory returns ordered copy', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016)
    player:update(0.016)
    
    local history = player:getPositionHistory()
    
    assertEqual(2, #history)
    -- Should be a copy, not the same table
    assertTrue(player.positionHistory ~= history)
    assertTrue(player.positionHistory[1] ~= history[1])
    -- But values should be equal
    assertEqual(player.positionHistory[1].x, history[1].x)
    assertEqual(player.positionHistory[1].y, history[1].y)
    assertEqual(player.positionHistory[1].t, history[1].t)
end)

test('Player getPositionHistory prevents external mutation', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016)
    
    local history = player:getPositionHistory()
    history[1].x = 999 -- Try to mutate
    
    -- Original should be unchanged
    assertTrue(player.positionHistory[1].x ~= 999)
end)

test('Player position history timestamps use game time accumulator', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016)
    local t1 = player.positionHistory[1].t
    
    player:update(0.016)
    local t2 = player.positionHistory[2].t
    
    -- Timestamps should increment by dt
    assertNear(0.016, t2 - t1, 0.001)
end)

test('Player position history records collider position', function()
    local object = createMockPlayerObject(100, 100)
    local player = Player{object = object, index = 1}
    
    player:update(0.016)
    
    local entry = player.positionHistory[1]
    -- Should record collider center position
    assertEqual(player.collider:getX(), entry.x)
    assertEqual(player.collider:getY(), entry.y)
end)

return true