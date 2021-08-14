if arg[#arg] == "debug" then 
	require("lldebugger").start() 
elseif arg[#arg] == "profile" then
	profile = require('profile')
end

print(package.path)

-- includes
--require('lovedebug')


-- global includes to save having to include in other files!
utils = require('utils')

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
World = require('world')
Entity = require('entity')
Sprite = require('components.sprite')
Collider = require('components.collider')
Map = require('map')


-- local includes only accessible to this file


local physics_draw = (arg[#arg] == "debug") and false

local Player = require('player')

-- TODO world needs own class with collision stuff
--world = {} -- global for now so Collider componnent works easy TODO: clean up globals


function love.load()
	if profile then
		profile.start()
	end

	world = World:new(0, 90.81, true)
	map = Map:new('res/map/sandbox.lua', world)

	-- spawn players
	for li, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects) do
				if object.type == 'spawn' then
					local entity = Player(object)
					table.insert(layer.entities, entity)
				end
			end
		end
	end

	if profile then
		profile.stop()
		print('love.load profile:')
		print(profile.report(10))
	end
end

function love.update(dt)
	map:update(dt)
	world:update(dt)
end

function love.draw()
	map:draw()

	if physics_draw then
		world:draw()
	end
end


function love.keypressed(k)
	if k == "escape" then
		love.event.push("quit")
	end
end

function love.textinput(t)
	print(t)
	--console_toggle(t)
end


