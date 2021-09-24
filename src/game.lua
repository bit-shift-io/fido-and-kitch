
local GameStates = require('src.game_states')

local Game = Class{}

function Game:init(props)
	self.fsm = StateMachine{
		stateClasses=GameStates,
		entity=self,
		currentState='MenuState'
	}

    
    -- when debugging for now we just want to get straight into the game!
    --[[
    if arg[#arg] == "debug" then 
        self:setGameState('InGameState')
        self:load()
	end
    ]]--
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

function Game:endGame()
    print("end the game peeps!")
    self:setGameState('MenuState')
end


return Game