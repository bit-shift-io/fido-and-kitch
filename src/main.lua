if arg[#arg] == "debug" then 
	require("lldebugger").start() 
elseif arg[#arg] == "profile" then
	profile = require('profile')
end

print(package.path)

-- includes
--require('lovedebug')


-- global includes to save having to include in other files!

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
World = require('world')
Entity = require('entity')
Sprite = require('sprite')
Collider = require('collider')

-- local includes only accessible to this file


local newMap = require('map')
local Player = require('player')

-- TODO world needs own class with collision stuff
--world = {} -- global for now so Collider componnent works easy TODO: clean up globals


function love.load()
	if profile then
		profile.start()
	end

	world = World:new(0, 90.81, true)

	map = newMap('res/map/sandbox.lua', world._world)

	p = Player()

	if profile then
		profile.stop()
		print('love.load profile:')
		print(profile.report(10))
	end
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


