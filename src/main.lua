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
--StateMachine = require('lib.lua-state-machine.statemachine')

utils = require('utils')
Func = require('func')

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

-- local includes only accessible to this file


local physics_draw = (arg[#arg] == "debug") and true



-- TODO world needs own class with collision stuff
--world = {} -- global for now so Collider componnent works easy TODO: clean up globals
-- map = {}

function love.load()
	if profile then
		profile.start()
	end

	-- files stored in game dir
	--function love.filesystem.isFused()
	--	return true
	--end
	--print(love.filesystem.isFused())

	world = World:new(0, 90.81, true)
	map = Map:new('res/map/sandbox.lua', world)

	camera = Camera(love.graphics.getWidth()/2,love.graphics.getHeight()/2, 1)

	-- spawn players
	local playerCount = 2
	local index = 1
	for li, layer in ipairs(map.map.layers) do -- todo: map.map changed with the new layout for some reason??
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects) do
				if object.type == 'spawn' then
					for i = 1, playerCount, 1 do
						local entity = Player({object=object, index=index})
						table.insert(layer.entities, entity)
						index = index + 1
					end
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

	--[[
	local tx = camera.x - (love.graphics.getWidth() / 2)
	local ty = camera.y - (love.graphics.getHeight() / 2)

	if tx < 0 then 
		tx = 0 
	end
	if tx > map.map.width  * map.map.tilewidth  - love.graphics.getWidth()  then
		tx = map.map.width  * map.map.tilewidth  - love.graphics.getWidth()  
	end
	if ty > map.map.height * map.map.tileheight - love.graphics.getHeight() then
		ty = map.map.height * map.map.tileheight - love.graphics.getHeight()
	end

	tx = math.floor(tx)
	ty = math.floor(ty)
	]]--

	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	local mw = map.map.width * map.map.tilewidth
	local mh = map.map.height * map.map.tileheight
	local sx = w / mw
	local sy = h / mh
	local s = math.min(sx, sy)

	-- todo: centre the map? why is there a black bar at the bottom?
	map.map:draw(0, 0, s, s)

	--[[
	camera:attach()
	map:draw()
	if physics_draw then
		world:draw()
	end
	camera:detach()
	]]--
end

function love.resize(w, h)
	--camera = Camera(w/2,h/2, 1)
	--map.map:resize(w, h)
end

function love.keypressed(k)
	if k == "escape" then
		love.event.push("quit")
	end
	if k == "f12" then
		print('prnt')
		love.filesystem.setIdentity("screenshot_example")
		local cwd = love.filesystem.getWorkingDirectory() .. "/" .. os.time() .. ".png"
		love.graphics.captureScreenshot(cwd)
	end
end

function love.textinput(t)
	--print(t)
	--console_toggle(t)
end


