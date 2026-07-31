-- tests/unit/player_input_test.lua
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
Map = require('src.map')
AutoCamera = require('src.camera')
Player = require('src.player.player')
inputManager = require('src.input.input_manager')

-- Mock inputManager.isDown
local originalIsDown = inputManager.isDown

test('player delegates isDown to inputManager for player 1', function()
  local player = Player({index=1, x=0, y=0, object={x=0, y=0}})
  local called = false
  inputManager.isDown = function(idx, action)
    called = {idx=idx, action=action}
    return true
  end
  local result = player:isDown('left')
  assertEqual(called.idx, 1)
  assertEqual(called.action, 'left')
  assertTrue(result)
  inputManager.isDown = originalIsDown
end)

test('player delegates isDown to inputManager for player 2', function()
  local player = Player({index=2, x=0, y=0, object={x=0, y=0}})
  local called = false
  inputManager.isDown = function(idx, action)
    called = {idx=idx, action=action}
    return false
  end
  local result = player:isDown('right')
  assertEqual(called.idx, 2)
  assertEqual(called.action, 'right')
  assertFalse(result)
  inputManager.isDown = originalIsDown
end)