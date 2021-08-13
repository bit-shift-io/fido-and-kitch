local Player = Class{__includes = Entity}

function Player:init(object)
	Entity.init(self)
	self.name = 'player'
	character = 'dog';
	position = Vector(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

	self.sprite = self:addComponent(Sprite{
		frames=string.format('res/img/%s/Idle (${i}).png', character),
		frameCount=10, 
		duration=1.0, 
		scale=Vector(0.1, 0.1), 
		position=position})
	self.object = object
	self.speed = 100;

	-- TODO: make a rectangle
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		postSolve=self.contact, 
		sprite=self.sprite, 
		position=Vector(325, 325)})
	self.collider:setFixedRotation(true)
end

function Player:contact(other)
	print('player has made contact with something!')
end

function Player:update(dt)
	Entity.update(self, dt)
	local x = self.collider:getX()
	local y = self.collider:getY()
	local delta = self.speed * dt

	if love.keyboard.isDown("right") then
		self.collider:setPosition(Vector(x + delta, y))
	end
	if love.keyboard.isDown("left") then
	   self.collider:setPosition(Vector(x - delta, y))
	end
	if love.keyboard.isDown("up") then
		self.collider:setLinearVelocity(0, -100)
	end
	if love.keyboard.isDown("down") then
		self.collider:setLinearVelocity(0, 100)
	end
end

return Player