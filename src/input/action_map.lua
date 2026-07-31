local KEYBOARD_MAPS = {
  [1] = {left='left', right='right', up='up', down='down', use='rshift', start='escape', back='tab'},
  [2] = {left='a', right='d', up='w', down='s', use='q', start='escape', back='tab'},
}

local GAMEPAD_BUTTONS = {
  use = {'a', 'b'},
  start = {'start'},
  back = {'back', 'guide'},
}

-- Generic joystick button indices (for non-gamepad joysticks)
local JOYSTICK_BUTTONS = {
  use = {1, 2},      -- Button 1 (A), Button 2 (B)
  start = {10},      -- Button 10 (Start)
  back = {9, 13},    -- Button 9 (Back/Select), Button 13 (Guide/Home)
}

local GAMEPAD_AXES = {
  left = 'leftx',
  up = 'lefty',
}

return {KEYBOARD_MAPS = KEYBOARD_MAPS, GAMEPAD_BUTTONS = GAMEPAD_BUTTONS, JOYSTICK_BUTTONS = JOYSTICK_BUTTONS, GAMEPAD_AXES = GAMEPAD_AXES}