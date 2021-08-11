local Player = Class{__includes = Entity}

function Player:init(object)
	Entity.init(self)

	position = vector(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

    self.sprite = self:addComponent(Sprite{frames='res/images/cat/Idle (${i}).png', frameCount=10, duration=1.0, scale=vector(0.1, 0.1), position=position})
	self.object = object

	-- TODO: make a rectangle
    self.collider = self:addComponent(Collider{
        shape_type='circle', 
        shape_arguments={0, 0, 15}, 
        postSolve=Player.contact, 
        sprite=self.sprite, 
        position=vector(325, 325)})
	self.collider:setRestitution(0.8)
end

function Player:contact(other)
    print('player has made contact with something!')
end

function Player:update(dt)
    Entity.update(self, dt)

	if love.keyboard.isDown("right") then
        self.collider:applyForce(400, 0)
    elseif love.keyboard.isDown("left") then
        self.collider:applyForce(-400, 0)
    elseif love.keyboard.isDown("up") then
        self.collider:setPosition(vector(325, 325))
        self.collider:setLinearVelocity(0, 0) 
    elseif love.keyboard.isDown("down") then
        self.collider:applyForce(0, 600)
    end
end

return Player