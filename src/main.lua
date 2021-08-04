if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

print(package.path)

local newAnimation = require('animation')
local newMap = require('map')

platform = {}
player = {}

function love.load()
	platform.width = love.graphics.getWidth()
	platform.height = love.graphics.getHeight()

	platform.x = 0
	platform.y = platform.height / 2

	player.x = love.graphics.getWidth() / 2
	player.y = love.graphics.getHeight() / 2

	player.speed = 200

	player.img = love.graphics.newImage('assets/images/cat/Idle (1).png')

	player.ground = player.y
	
	player.y_velocity = 0

	player.jump_height = -300
	player.gravity = -500

    frames = {
        love.graphics.newImage('assets/images/cat/Idle (1).png'),
        love.graphics.newImage('assets/images/cat/Idle (2).png'),
        love.graphics.newImage('assets/images/cat/Idle (3).png')
    }
    a = newAnimation(frames, 1.0)

    -- Prepare physics world with horizontal and vertical gravity
	world = love.physics.newWorld(0, 0)

    map = newMap('assets/maps/sandbox.lua', world)
    print("load complete")
end

function love.update(dt)
    map:update(dt)
	a:update(dt)

	if love.keyboard.isDown('d') then
		if player.x < (love.graphics.getWidth() - player.img:getWidth()) then
			player.x = player.x + (player.speed * dt)
		end
	elseif love.keyboard.isDown('a') then
		if player.x > 0 then 
			player.x = player.x - (player.speed * dt)
		end
	end

	if love.keyboard.isDown('space') then
		if player.y_velocity == 0 then
			player.y_velocity = player.jump_height
		end
	end

	if player.y_velocity ~= 0 then
		player.y = player.y + player.y_velocity * dt
		player.y_velocity = player.y_velocity - player.gravity * dt
	end

	if player.y > player.ground then
		player.y_velocity = 0
    	player.y = player.ground
	end
end

function love.draw()
    map:draw()

	love.graphics.draw(player.img, player.x, player.y, 0, 0.1, 0.1, 0, 32)

    a:draw()
end