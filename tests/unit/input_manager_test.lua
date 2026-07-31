package.path = '../../?.lua;../../?/init.lua;' .. package.path
local InputManager = require('src.input.input_manager')

-- Mock love for headless tests
love = love or {}
love.joystick = love.joystick or {}
love.keyboard = love.keyboard or {}
love.joystick.loadGamepadMappings = love.joystick.loadGamepadMappings or function() end
love.keyboard.isDown = love.keyboard.isDown or function() return false end

test('input_manager_basic', function()
  local im = InputManager()
  im:update(1/60)
  -- No joysticks, keyboard not pressed
  assertFalse(im:isDown(1, 'left'))
  assertFalse(im:wasPressed(1, 'left'))
end)

test('input_manager_keyboard_p1', function()
  local im = InputManager()
  love.keyboard.isDown = function(key) return key == 'left' end
  im:update(1/60)
  assertTrue(im:isDown(1, 'left'))
  assertTrue(im:wasPressed(1, 'left'))
  love.keyboard.isDown = function(key) return false end
  im:update(1/60)
  assertFalse(im:isDown(1, 'left'))
  assertTrue(im:wasReleased(1, 'left'))
end)

test('input_manager_keyboard_p2', function()
  local im = InputManager()
  love.keyboard.isDown = function(key) return key == 'a' end
  im:update(1/60)
  assertTrue(im:isDown(2, 'left'))
  assertTrue(im:wasPressed(2, 'left'))
end)

test('input_manager_gamepad_axes', function()
  local im = InputManager()
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function(self, axis)
      if axis == 'leftx' then return 0.5 end
      if axis == 'lefty' then return -0.5 end
      return 0
    end,
    isGamepadDown = function() return false end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  im:update(1/60)
  assertTrue(im:isDown(1, 'right'))
  assertTrue(im:isDown(1, 'up'))
  assertFalse(im:isDown(1, 'left'))
  assertFalse(im:isDown(1, 'down'))
end)

test('input_manager_gamepad_deadzone', function()
  local im = InputManager()
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function(self, axis)
      if axis == 'leftx' then return 0.1 end -- below default deadzone 0.2
      return 0
    end,
    isGamepadDown = function() return false end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  im:update(1/60)
  assertFalse(im:isDown(1, 'right'))
  assertFalse(im:isDown(1, 'left'))
end)

test('input_manager_gamepad_buttons', function()
  local im = InputManager()
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function() return 0 end,
    isGamepadDown = function(self, btn) return btn == 'a' end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  im:update(1/60)
  assertTrue(im:isDown(1, 'use'))
end)

test('input_manager_hotplug_add', function()
  local im = InputManager()
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function() return 0 end,
    isGamepadDown = function() return false end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  assertEqual(fakeJs, im.players[1].joystick)
end)

test('input_manager_hotplug_remove', function()
  local im = InputManager()
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function() return 0 end,
    isGamepadDown = function() return false end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  im:joystickremoved(fakeJs)
  assertFalse(im.players[1].joystick)
end)

test('input_manager_deadzone_config', function()
  local im = InputManager()
  im:setDeadzone(1, 0.5)
  local fakeJs = {
    isGamepad = function() return true end,
    getGamepadAxis = function(self, axis)
      if axis == 'leftx' then return 0.3 end
      return 0
    end,
    isGamepadDown = function() return false end,
    isDown = function() return false end,
    isConnected = function() return true end,
  }
  im:joystickadded(fakeJs)
  im:update(1/60)
  assertFalse(im:isDown(1, 'right')) -- 0.3 < 0.5 deadzone
  im:setDeadzone(1, 0.2)
  im:update(1/60)
  assertTrue(im:isDown(1, 'right')) -- 0.3 > 0.2 deadzone
end)