tbl = require('src.utils.tbl')

if tbl.findIndexEq(arg, 'debug') then 
	require("lldebugger").start()
end

if tbl.findIndexEq(arg, 'profile') then
	profile = require('src.profile')
end

-- includes
--require('lovedebug')

-- global includes to save having to include in other files!
conf = require('conf')
str = require('src.utils.str')
utils = require('src.utils.utils')

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
Camera = require('lib.hump.camera')
Tween = require('lib.tween.tween')
--suit = require('lib.suit')
--urutora = require('lib.urutora')
Slab = require('lib.Slab')

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
Map = require('src.map')
Player = require('src.player')
Game = require('src.game')


-- local includes only accessible to this file

function love.load(args)
	conf.args = args
	Slab.Initialize(args)
	--u = urutora:new()
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


