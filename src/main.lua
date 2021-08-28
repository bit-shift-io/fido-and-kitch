if arg[#arg] == "debug" then 
	require("lldebugger").start() 
	print(package.path)
elseif arg[#arg] == "profile" then
	profile = require('profile')
end

-- includes
--require('lovedebug')

-- global includes to save having to include in other files!
Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
Camera = require('lib.hump.camera')
Tween = require('lib.tween.tween')
suit = require('lib.suit')

utils = require('utils')
Signal = require('signal')
World = require('world')
Entity = require('entity')
StateMachine = require('components.state_machine')
Sprite = require('components.sprite')
Path = require('components.path')
Timeline = require('components.timeline')
PathFollow = require('components.path_follow')
Collider = require('components.collider')
Pickup = require('components.pickup')
Inventory = require('components.inventory')
Usable = require('components.usable')
Map = require('map')
Player = require('player')
Game = require('game')

-- local includes only accessible to this file

function love.load()
	game = Game()
end

function love.update(dt)
	game:update(dt)
end

function love.draw()
	game:draw()
end

function love.resize(w, h)
	--camera = Camera(w/2,h/2, 1)
	--map.map:resize(w, h)
end

function love.keypressed(k)
	game:keypressed(k)
end

function love.textinput(t)
	game:textinput(t)
	--print(t)
	--console_toggle(t)
end


