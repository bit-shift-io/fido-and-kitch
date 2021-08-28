
local GameStates = require('game_states')

local Game = Class{}

function Game:init(props)
	self.fsm = StateMachine{
		stateClasses=GameStates,
		entity=self,
		currentState='MenuState'
	}

    -- when debbugging for now we just want to get straight into the game!
    if arg[#arg] == "debug" then 
        self:setGameState('InGameState')
        self:load();
	end
end

function Game:setGameState(name)
    self.fsm:setState(name)
end

function Game:load()
    self.fsm:load()
end

function Game:update(dt)
    self.fsm:update(dt)
end

function Game:draw()
    self.fsm:draw()
end

function Game:keypressed(k)
    if k == "f12" then
		print('prnt')
		love.filesystem.setIdentity("screenshot_example")
		local cwd = love.filesystem.getWorkingDirectory() .. "/" .. os.time() .. ".png"
		love.graphics.captureScreenshot(cwd)
	end

    self.fsm:keypressed(k)
end

function Game:endGame()
    print("end the game peeps!")
    self:setGameState('MenuState')
end


return Game