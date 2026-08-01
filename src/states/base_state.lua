-- Shared no-op input/lifecycle handlers for game.fsm's states (MenuState,
-- InGameState, GameOverState). Game:keypressed/gamepadpressed/mousepressed/
-- touchpressed/textinput/resize all forward unconditionally to
-- self.fsm.currentState, so every state needs an implementation of each
-- callback even when it has nothing to do with it. A state that cares about
-- a given callback overrides it after __includes = BaseState -- the same
-- override-by-copy mechanism Entity/component mixins already use
-- throughout the codebase (see lib/hump/class.lua's `include`).
local BaseState = Class{}

function BaseState:gamepadpressed(joystick, button)
end

function BaseState:joystickpressed(joystick, button)
end

function BaseState:mousepressed(x, y, button)
end

function BaseState:touchpressed(id, x, y)
end

function BaseState:textinput(t)
end

function BaseState:resize(w, h)
end

return BaseState
