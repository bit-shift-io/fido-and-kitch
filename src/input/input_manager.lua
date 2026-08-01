local Class = require('lib.hump.class')
local actionMap = require('src.input.action_map')

local InputManager = Class{}

-- Track joysticks that should be forced to non-gamepad mode
local forcedNonGamepad = {}

function InputManager:init()
  if love and love.joystick and love.joystick.loadGamepadMappings then
    print("[InputManager] Loading gamecontrollerdb.txt")
    local success, err = love.joystick.loadGamepadMappings('res/gamecontrollerdb.txt')
    print("[InputManager] loadGamepadMappings:", success, err)
  end
  self.players = {}
  self.actionState = {}
  self.prevActionState = {}
  for i = 1, 4 do self:ensurePlayer(i) end
  
  -- Handle already-connected joysticks (joystickadded doesn't fire for already-connected)
  if love and love.joystick then
    local joysticks = love.joystick.getJoysticks()
    print("[InputManager] Found", #joysticks, "already-connected joystick(s)")
    for _, js in ipairs(joysticks) do
      self:joystickadded(js)
    end
  end
end

-- Force a joystick to be treated as non-gamepad (for generic controllers with bad mappings)
function InputManager:forceNonGamepad(joystick)
  forcedNonGamepad[joystick] = true
  print("[InputManager] Forced non-gamepad mode for:", joystick:getName())
end

function InputManager:isForcedNonGamepad(joystick)
  return forcedNonGamepad[joystick] == true
end

function InputManager:ensurePlayer(idx)
  if not self.players[idx] then
    self.players[idx] = {joystick = nil, deadzone = 0.2, keyboardMap = actionMap.KEYBOARD_MAPS[idx] or {}}
  end
  if not self.actionState[idx] then self.actionState[idx] = {} end
  if not self.prevActionState[idx] then self.prevActionState[idx] = {} end
end

function InputManager:update(dt)
  self.prevActionState = {}
  for i, s in pairs(self.actionState) do
    self.prevActionState[i] = {}
    for a, v in pairs(s) do self.prevActionState[i][a] = v end
  end
  self.actionState = {}

  for i = 1, 4 do self:ensurePlayer(i) end

  for i, p in ipairs(self.players) do
    self.actionState[i] = {}

    local km = p.keyboardMap
    if love and love.keyboard then
      for action, key in pairs(km) do
        if love.keyboard.isDown(key) then self.actionState[i][action] = true end
      end
    end

    if p.joystick then
      self:pollGamepad(i, p)
    end
  end
end

function InputManager:pollGamepad(idx, player)
  local js = player.joystick
  if not js or not js:isConnected() then return end
  local dz = player.deadzone

  -- Always check raw axes first (works for both gamepad and generic joystick)
  local hx = js:getAxis(1) or 0
  local hy = js:getAxis(2) or 0
  
  -- If it's a gamepad, also check gamepad axes as fallback
  if js:isGamepad() then
    local gx = js:getGamepadAxis('leftx') or 0
    local gy = js:getGamepadAxis('lefty') or 0
    -- Use gamepad axes if they have meaningful values, otherwise use raw
    if gx ~= 0 or gy ~= 0 then
      hx, hy = gx, gy
    end
  end

  if hx < -dz then self.actionState[idx].left = true end
  if hx > dz then self.actionState[idx].right = true end
  if hy < -dz then self.actionState[idx].up = true end
  if hy > dz then self.actionState[idx].down = true end

  -- Check buttons: try gamepad buttons first, then raw button indices
  local isGamepad = js:isGamepad()
  local gamepadButtons = actionMap.GAMEPAD_BUTTONS
  local joystickButtons = actionMap.JOYSTICK_BUTTONS
  
  for action, _ in pairs({use=true, start=true, back=true}) do
    local isDown = false
    -- Try gamepad buttons
    if isGamepad then
      for _, btn in ipairs(gamepadButtons[action] or {}) do
        if js.isGamepadDown and js:isGamepadDown(btn) then
          isDown = true
          break
        end
      end
    end
    -- Fallback to raw button indices
    if not isDown then
      for _, btn in ipairs(joystickButtons[action] or {}) do
        if js:isDown(btn) then
          isDown = true
          break
        end
      end
    end
    if isDown then
      self.actionState[idx][action] = true
    end
  end
end

function InputManager:joystickadded(joystick)
  print("[InputManager] joystickadded:", joystick:getName(), "isGamepad:", joystick:isGamepad())
  for i = 1, 4 do
    if not self.players[i].joystick then
      self.players[i].joystick = joystick
      print("[InputManager] Assigned joystick to player", i)
      break
    end
  end
end

function InputManager:joystickremoved(joystick)
  print("[InputManager] joystickremoved:", joystick:getName())
  for i = 1, 4 do
    if self.players[i].joystick == joystick then
      self.players[i].joystick = nil
      break
    end
  end
end

function InputManager:isDown(idx, action)
  return self.actionState[idx] and self.actionState[idx][action] == true
end

function InputManager:wasPressed(idx, action)
  return (self.actionState[idx] and self.actionState[idx][action])
     and not (self.prevActionState[idx] and self.prevActionState[idx][action])
end

function InputManager:wasReleased(idx, action)
  return not (self.actionState[idx] and self.actionState[idx][action])
     and (self.prevActionState[idx] and self.prevActionState[idx][action])
end

function InputManager:setDeadzone(idx, dz)
  self:ensurePlayer(idx)
  self.players[idx].deadzone = dz
end

function InputManager:getAssignedJoystick(idx)
  self:ensurePlayer(idx)
  return self.players[idx].joystick
end

return InputManager