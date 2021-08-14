local Player = Class{__includes = Entity}

function Player:init(object)
	Entity.init(self)
	self.name = 'player'
	character = 'dog';
	position = Vector(object.x + 16, object.y - 16)

	self.sprite = self:addComponent(Sprite{
		frames=string.format('res/img/%s/Idle (${i}).png', character),
		frameCount=10, 
		duration=1.0, 
		scale=Vector(0.1, 0.1), 
		position=position})
	self.object = object
	self.speed = 100;

	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		postSolve=self.contact,
		sprite=self.sprite,
		position=position,
		entity=self,
		fixedRotation=true
	})

	self.inventory = self:addComponent(Inventory{})
end

function Player:contact(other)
	--print('player has made contact with something!')
end


function Player:checkForUsables()
	print('TODO:e pressed, check for usables!');
	local shape = self.collider
	-- todo: player world position 
	local colls = world:queryRectangleArea(0,0,30,30)
	for _, collider in ipairs(colls) do
		if (collider.isSensor) then
			-- todo: find the entity which the sensor belongs too
			print('ping!')
		end
	end
end

function Player:update(dt)
	Entity.update(self, dt)
	local x = self.collider:getX()
	local y = self.collider:getY()
	local delta = self.speed * dt

	local eDownLast = self.eDown
	self.eDown = love.keyboard.isDown("e")
	if self.eDown == true and eDownLast == false then
		self:checkForUsables()
	end

	if love.keyboard.isDown("right") then
		self.collider:setPositionV(Vector(x + delta, y))
	end
	if love.keyboard.isDown("left") then
	   self.collider:setPositionV(Vector(x - delta, y))
	end
	if love.keyboard.isDown("up") then
		self.collider:setLinearVelocity(0, -100)
	end
	if love.keyboard.isDown("down") then
		self.collider:setLinearVelocity(0, 100)
	end
end

function Player:pickup(pickup)
	local entity = pickup.entity
	print('player picked up a ' .. pickup.itemName)
	self.inventory:addItems(pickup.itemName, pickup.itemCount)
	entity:queue_destroy()
end

return Player