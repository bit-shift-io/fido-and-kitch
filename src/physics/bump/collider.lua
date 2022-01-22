-- A physics body component
-- a Collider object, wrapping shape, body, and fixtue

local Collider = Class{}
--local set_funcs, lp, lg, COLLIDER_TYPES = unpack(require('utils'))

-- TODO: shape arguments includes position as first 2 values in the case or a circle
-- which we don't care about supplying, circle just needs a radius
-- so this needs some tweaking
function Collider:init(props)
	self.type = 'collider'

	if props.shape_arguments then
		world:newCollider(props.shape_type, props.shape_arguments, self)
	end
	--col.name = 'bfcollider'
	--Class.include(self, col) -- merge collider with this, this does not work!

	self.debug = props.debug or false
	self.sprite = props.sprite

	if self.sprite then
		function self:update(dt)
			self.sprite:setPositionV(self:getPositionV())
		end
	end

	self:setLinearVelocity(0, 0)
	self:setSensor(false)
	self:setFixedRotation(false)

	if props.fixedRotation then
		self:setFixedRotation(true)
	end

	if props.sensor then 
		self:setSensor(true)
	end


	self.postSolveFunc = props.postSolve
	self.preSolveFunc = props.preSolve
	self.enterFunc = props.enter
	self.exitFunc = props.exit

	if self.postSolveFunc then
		function self:postSolve(other)
			self.postSolveFunc(other)
		end
	end

	if self.preSolveFunc then
		function self:preSolve(other)
			self.preSolveFunc(other)
		end
	end

	if self.enterFunc then
		function self:enter(other)
			self.enterFunc(other)
		end
	end

	if self.exitFunc then
		function self:exit(other)
			self.exitFunc(other)
		end
	end

	self.draw = Collider.collider_draw

	if (props.position) then
		self:setPositionV(props.position)
	end

	if props.body_type then
		self:setType(props.body_type)
	end
	--self.collider._collider = self
	--setmetatable(self.collider, bf.Collider)
end

function Collider:addShape(props)
	local collider_type = props.shape_type
	local shape_arguments = props.shape_arguments

	local args = unpack(shape_arguments)

	--local shape = love.physics['new'..collider_type..'Shape'](unpack(shape_arguments))
	--local fixture = love.physics.newFixture(self.body, shape, 1)
	--fixture:setUserData(self)
	return nil
end


function Collider:setPositionV(pos)
	self:setX(pos.x)
	self:setY(pos.y)
end


function Collider:getPositionV() 
	return Vector(self:getX(), self:getY())
end


function Collider:getBounds()
	local bounds = {}
	bounds.left = self.x
	bounds.right = self.x + self.width
	bounds.top = self.y
	bounds.bottom = self.y + self.height
	bounds.width = self.width
	bounds.height = self.height
	return bounds
end


function Collider:draw()
	love.graphics.rectangle('line', self.x, self.y, self.width, self.height)
end
 
 
function Collider:destroy()
	self._world.colliders[self] = nil
	self.fixture:setUserData(nil)
	self.fixture:destroy()
	self.body:destroy()
end
 


function Collider:collider_contacts()
	local contacts = self:getContacts()
	local colliders = {}
	for i, contact in ipairs(contacts) do
	   if contact:isTouching() then
	  local f1, f2 = contact:getFixtures()
	  if f1 == self.fixture then
		 colliders[#colliders+1] = f2:getUserData()
	  else
		 colliders[#colliders+1] = f1:getUserData()
	  end
	   end
	end
	return colliders
end


function Collider:isSensor()
	return self.sensor
end


function Collider:setSensor(sensor)
	self.sensor = sensor
end


function Collider:setFixedRotation(fixed)
	self.fixedRotation = fixed
end


function Collider:setX(x)
	self.x = x
end


function Collider:setY(y)
	self.y = y
end


function Collider:getX()
	return self.x 
end


function Collider:getY()
	return self.y
end


function Collider:setType(t)
	self.type = t
end


function Collider:setGroupIndex(g)
	self.groupIndex = g
end


function Collider:getLinearVelocity()
	return self.linearVelocityX, self.linearVelocityY
end


function Collider:setLinearVelocity(x, y)
	self.linearVelocityX = x
	self.linearVelocityY = y
end


function Collider:move(dt)
	local actualX, actualY, cols, len = self._world._world:move(self, (self.linearVelocityX * dt), (self.linearVelocityY * dt))
    self.x = actualX
    self.y = actualY

	if (len) then
		self:setLinearVelocity(0, 0)
	end
end


return Collider