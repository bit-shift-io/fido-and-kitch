if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

print(package.path)

-- includes
require('lovedebug')


-- global includes to save having to include in other files!

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
bf = require('breezefield')

Entity = require('entity')
Sprite = require('sprite')
Collider = require('collider')

-- local includes only accessible to this file

local profile = require('profile')
local newMap = require('map')
local Player = require('player')

-- TODO world needs own class with collision stuff
world = {} -- global for now so Collider componnent works easy TODO: clean up globals

function preSolve(a, b, coll)
	print(a:getUserData())
	print(b:getUserData())

end

function love.load()
	profile.start()
	print("load")

	world = bf.newWorld(0, 90.81, true)
	--world:setCallbacks(beginContact, endContact, preSolve, postSolve)

	map = newMap('res/map/sandbox.lua', world._world)

	p = Player()

	profile.stop()
	print(profile.report(10))
end

function love.update(dt)
	map:update(dt)
	world:update(dt)
	p:update(dt)
end

function love.draw()
	map:draw()
	world:draw()
	p:draw()
end


function love.keypressed(k)
	if k == "escape" then love.event.push("quit") end
end

function love.textinput(t)
	print(t)
	--console_toggle(t)
end


