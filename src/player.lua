local Player = Class{__includes = Entity}

function Player:init(object)
	Entity.init(self)

	position = vector(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

    self.sprite = self:addComponent(Sprite{frames='assets/images/cat/Idle (${i}).png', frameCount=10, duration=1.0, scale=vector(0.1, 0.1), position=position})
	self.object = object
	self.ground = position.y
	self.speed = 200
	self.y_velocity = 0
	self.jump_height = -300
	self.gravity = -500
end

function Player:update(dt)
    Entity.update(self, dt)

    local position = self.sprite.position
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

return Player