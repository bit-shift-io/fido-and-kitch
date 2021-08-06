if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

package.path = package.path .. ';hump/?.lua'
print(package.path)

local newAnimation = require('animation')
local newMap = require('map')
local newPlayer = require('player')

function love.load()
	p = newPlayer()

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