
local MenuState = require('src.states.menu_state')
local InGameState = require('src.states.ingame_state')
local GameOverState = require('src.states.game_over_state')
local Map = require('src.map')
local Log = require('src.utils.log')

local Game = Class{}

function Game:init()
	self.fsm = StateMachine{
		stateClasses={
			MenuState = MenuState,
			InGameState = InGameState,
			GameOverState = GameOverState,
		},
		entity=self,
		currentState='MenuState'
	}

    -- Look for map=somemap and then load straight into that map
    local fn = function(e)
        return str.startsWith(e, 'map=')
    end
    local mapArg = tbl.find(conf.args, fn)
    if (mapArg) then
        local split = str.split(mapArg, '=')
        local mapName = split[2]
        local mapPath = Map.resolveMapFile('res/map/' .. mapName)
        self.fsm.currentState:startGame({map=mapPath})
    end
end

function Game:setGameState(name)
    local previous = self.fsm.currentState and self.fsm.currentState.name or 'none'
    Log.debug('game state: ' .. previous .. ' -> ' .. name)
    self.fsm:setState(name)

    -- The press that caused this transition is very likely still held (see
    -- InputManager:swallowEdges). Created after Game in main.lua, so absent
    -- for a map= launch argument handled during Game:init.
    if inputManager then
        inputManager:swallowEdges()
    end
end

function Game:load(props)
    self.fsm:load(props)
end

function Game:update(dt)
    if conf.ultraslow then
        dt = dt * 0.0001  -- 0.01% speed (ultra slow motion)
    elseif conf.slowmo then
        dt = dt * 0.1  -- 10% speed (slow motion)
    end
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
        Log.debug('screenshot')
        love.filesystem.setIdentity("screenshot_example")
        local cwd = love.filesystem.getWorkingDirectory() .. "/" .. os.time() .. ".png"
        love.graphics.captureScreenshot(cwd)
    end

    if k == "f1" then
        Log.debug('toggle debug')
		conf.drawphysics = not conf.drawphysics
	end

    if k == "f2" then
        Log.debug('toggle particle outlines')
        conf.draw_particles = not conf.draw_particles
    end

    if k == "f3" then
        Log.debug('toggle sprite outlines')
        conf.draw_sprite_outlines = not conf.draw_sprite_outlines
    end

    if k == "f4" then
        Log.debug('toggle grid overlay')
        conf.draw_grid = not conf.draw_grid
    end

    if k == "f5" then
        Log.debug('toggle slow motion')
        conf.slowmo = not conf.slowmo
    end

    if k == "f6" then
        Log.debug('toggle ultra slow motion')
        conf.ultraslow = not conf.ultraslow
    end

    if k == "f11" or (k == "return" and love.keyboard.isDown('lalt', 'ralt')) then
        Log.debug('toggle fullscreen')
        love.window.setFullscreen(not love.window.getFullscreen(), 'desktop')
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


return Game
