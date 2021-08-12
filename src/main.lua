if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

print(package.path)

-- global includes to save having to include in other files!
vector = require('hump.vector')
Class = require('hump.class')
bf = require("breezefield")

Entity = require('entity')
Sprite = require('sprite')
Collider = require('collider')

-- local includes only accessible to this file
local newMap = require('map')
local Player = require('player')

-- TODO world needs own class with collision stuff
world = {} -- global for now so Collider componnent works easy TODO: clean up globals

function preSolve(a, b, coll)
    print(a:getUserData())
    print(b:getUserData())

end

function love.load()
    print("load start")

    world = bf.newWorld(0, 90.81, true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    map = newMap('res/maps/sandbox.lua', world._world)

    -- todo move to init
    map:createEntitiesFromObjectGroupLayers()
    map:createStaticPhysicsBodyBoundary()
    -- todo gone
    local groundLayer = map.map.layers['ground']
    if groundLayer then
        groundLayer:createStaticPhysicsBodies()
    end

	p = Player()
    
    print("load complete")
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