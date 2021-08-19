-- A physics body component
-- a Collider object, wrapping shape, body, and fixtue

local Collider = Class{}
--local set_funcs, lp, lg, COLLIDER_TYPES = unpack(require('utils'))

-- TODO: shape arguments includes position as first 2 values in the case or a circle
-- which we don't care about supplying, circle just needs a radius
-- so this needs some tweaking
function Collider:init(props)
	self.name = 'collider'

	if props.shape_arguments then
		world:newCollider(props.shape_type, props.shape_arguments, self)
	end
	--col.name = 'bfcollider'
	--Class.include(self, col) -- merge collider with this, this does not work!

	self.debug = props.debug or false
	self.sprite = props.sprite

	if self.sprite then
		function self:update(dt)
			self.sprite.position = self:getPositionV()
		end
	end

		--u = self.fixture:getUserData()
	--self.entity = 'test' -- done in entity

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
			self.postSolveFunc:call(other)
		end
	end

	if self.preSolveFunc then
		function self:preSolve(other)
			self.preSolveFunc:call(other)
		end
	end

	if self.enterFunc then
		function self:enter(other)
			self.enterFunc:call(other)
		end
	end

	if self.exitFunc then
		function self:exit(other)
			self.exitFunc:call(other)
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
	local shape = love.physics['new'..collider_type..'Shape'](unpack(shape_arguments))
	
	local fixture = love.physics.newFixture(self.body, shape, 1)
	fixture:setUserData(self)
end

function Collider:setPositionV(pos)
	self:setX(pos.x)
	self:setY(pos.y)
end

function Collider:getPositionV() 
	return Vector(self:getX(), self:getY())
end



--[[
function Collider:draw(alpha)
	if self.debug == false then
		return
	end

	love.graphics.setColor(0.9, 0.9, 0.0)
	local x = self:getX()
	local y = self:getY()
	local radius = self.getRadius(self)
	love.graphics.circle('fill', x, y, radius)
end
]]--

function Collider:draw_type()
	if self.collider_type == 'Edge' or self.collider_type == 'Chain' then
	   return 'line'
	end
	return self.collider_type:lower()
 end
 
 function Collider:__draw__()
	self._draw_type = self._draw_type or self:draw_type()
	local args
	if self._draw_type == 'line' then
	   args = {self:getSpatialIdentity()}
	else
	   args = {'line', self:getSpatialIdentity()}
	end
	love.graphics[self:draw_type()](unpack(args))
 end
 
 function Collider:draw()
	self:__draw__()
 end
 
 
 function Collider:destroy()
	self._world.colliders[self] = nil
	self.fixture:setUserData(nil)
	self.fixture:destroy()
	self.body:destroy()
 end
 
 function Collider:getSpatialIdentity()
	if self.collider_type == 'Circle' then
	   return self:getX(), self:getY(), self:getRadius()
	else
	   return self:getWorldPoints(self:getPoints())
	end
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
	return self.fixture:isSensor()
 end

return Collider