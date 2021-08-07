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

world = {} -- global for now so Collider componnent works easy TODO: clean up globals

function love.load()
    print("load start")

	p = Player()

    world = bf.newWorld(0, 90.81, true)

    --ground = bf.Collider.new(world, "Polygon",
	--			    {0, 550, 650, 550 , 650, 650, 0, 650})
    --ground:setType("static")

    ball = bf.Collider.new(world, "Circle", 325, 325, 20)
    ball:setRestitution(0.8) -- any function of shape/body/fixture works
    --block1 = bf.Collider.new(world, "Polygon", {150, 375, 250, 375,
	--				       250, 425, 150, 425})

    map = newMap('assets/maps/sandbox.lua', world._world)
    map:createEntitiesFromObjectGroupLayers()
    map:createStaticPhysicsBodyBoundary()
    
    print("load complete")
end

function love.update(dt)
    map:update(dt)
    world:update(dt)
	p:update(dt)

    if love.keyboard.isDown("right") then
        ball:applyForce(400, 0)
    elseif love.keyboard.isDown("left") then
        ball:applyForce(-400, 0)
    elseif love.keyboard.isDown("up") then
        ball:setPosition(325, 325)
        ball:setLinearVelocity(0, 0) 
    elseif love.keyboard.isDown("down") then
        ball:applyForce(0, 600)
    end
end

function love.draw()
    map:draw()
    world:draw()
	p:draw()
end