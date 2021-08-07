if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

print(package.path)

local newMap = require('map')
local Player = require('player')

function love.load()
	p = Player()

    -- Prepare physics world with horizontal and vertical gravity
	world = love.physics.newWorld(0, 0)

    map = newMap('assets/maps/sandbox.lua', world)
    map:createEntitiesFromObjectGroupLayers()
    
    print("load complete")
end

function love.update(dt)
    map:update(dt)
	p:update(dt)
end

function love.draw()
    map:draw()
	p:draw()
end