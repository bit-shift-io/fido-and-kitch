
local GameStates = require('src.game_states')

local Game = Class{}

function Game:init()
	self.fsm = StateMachine{
		stateClasses=GameStates,
		entity=self,
		currentState='MenuState'
	}
    
    -- Look for map=somemap.lua and then load straight into that map
    local fn = function(e) 
        return str.startsWith(e, 'map=')
    end
    local mapArg = tbl.find(conf.args, fn)
    if (mapArg) then
        local split = str.split(mapArg, '=')
        local mapName = split[2]
        self.fsm.currentState:startGame({map='res/map/'..mapName})
    end
end

function Game:setGameState(name)
    self.fsm:setState(name)
end

function Game:load(props)
    self.fsm:load(props)
end

function Game:update(dt)
    self.fsm:update(dt)
end

function Game:draw()
    self.fsm:draw()
end

function Game:resize(w, h)
	self.fsm:resize(w, h)
end

function Game:textinput(t)
    --suit.textinput(t)
    self.fsm:textinput(t)
end

function Game:keypressed(k)
    --suit.keypressed(key)
    
    if k == "f12" then
		print('prnt')
		love.filesystem.setIdentity("screenshot_example")
		local cwd = love.filesystem.getWorkingDirectory() .. "/" .. os.time() .. ".png"
		love.graphics.captureScreenshot(cwd)
	end

    self.fsm:keypressed(k)
end

function Game:gamepadpressed(joystick, button)
	self.fsm:gamepadpressed(joystick, button)
end

function Game:joystickpressed(joystick, button)
	self.fsm:joystickpressed(joystick, button)
end

function Game:mousepressed(x, y, button)
	self.fsm:mousepressed(x, y, button)
end

function Game:touchpressed(id, x, y)
	self.fsm:touchpressed(id, x, y)
end

function Game:endGame()
    print("end the game peeps!")
    self:setGameState('MenuState')
end


return Game