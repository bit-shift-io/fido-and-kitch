local newAnimation = require('animation')
local vector = require('vector')

local Player   = {}
Player.__index = Player

local function newPlayer(object)
    frames = {
        love.graphics.newImage('assets/images/cat/Idle (1).png'),
        love.graphics.newImage('assets/images/cat/Idle (2).png'),
        love.graphics.newImage('assets/images/cat/Idle (3).png')
    }

    a = newAnimation{frames=frames, duration=1.0}
    a.scale = vector(0.1, 0.1)
    a.position = vector(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

    return setmetatable({
        object = object,
        animation = a,

        ground = a.position.y,
        speed = 200,
	    y_velocity = 0,
	    jump_height = -300,
	    gravity = -500
      },
      Player
    )
end

function Player:update(dt)
    self.animation:update(dt)

    local position = self.animation.position
    if love.keyboard.isDown('d') then
		--if position.x < (love.graphics.getWidth() - player.img:getWidth()) then
			position.x = position.x + (self.speed * dt)
		--end
	elseif love.keyboard.isDown('a') then
		if position.x > 0 then 
			position.x = position.x - (self.speed * dt)
		end
	end

	if love.keyboard.isDown('space') then
		if self.y_velocity == 0 then
			self.y_velocity = self.jump_height
		end
	end

	if self.y_velocity ~= 0 then
		position.y = position.y + self.y_velocity * dt
		self.y_velocity = self.y_velocity - self.gravity * dt
	end

	if position.y > self.ground then
		self.y_velocity = 0
    	position.y = self.ground
	end
end

function Player:draw()
    self.animation:draw()
end

return newPlayer