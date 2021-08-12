-- A physics body component

local Collider = Class{__includes = bf.Collider}

-- TODO: shape arguments includes position as first 2 values in the case or a circle
-- which we don't care about supplying, circle just needs a radius
-- so this needs some tweaking
function Collider:init(props)
	if props.shape_arguments then
		col = bf.Collider.new(props.world or world, props.shape_type, unpack(props.shape_arguments))
	else
		col = bf.Collider.new(props.world or world, props.shape_type or 'unknown')
	end

	Class.include(self, col) -- merge collider with this

	self.debug = props.debug or false
	self.sprite = props.sprite

	if props.postSolve then
		self.postSolve = props.postSolve
	end

	if props.preSolve then
		self.preSolve = props.preSolve
	end

	if props.enter then
		self.enter = props.enter
	end

	if props.exit then
		self.exit = props.exit
	end

	self.draw = Collider.collider_draw

	if (props.position) then
		self:setPosition(props.position)
	end

	if props.body_type then
		self:setType(props.body_type)
	end
	--self.collider._collider = self
	--setmetatable(self.collider, Collider)
end

function Collider:addShape(props)
	local collider_type = props.shape_type
	local shape_arguments = props.shape_arguments
	local shape = love.physics['new'..collider_type..'Shape'](unpack(shape_arguments))
	
	local fixture = love.physics.newFixture(self.body, shape, 1)
	fixture:setUserData(self)
end

function Collider:setPosition(pos)
	self:setX(pos.x)
	self:setY(pos.y)
end

function Collider:getPosition() 
	return Vector(self:getX(), self:getY())
end

function Collider:update(dt)
	-- move sprite to where the body is
	if self.sprite then
		self.sprite.position = self:getPosition()
	end
end

function Collider:collider_draw(alpha)
	if self.debug == false then
		return
	end

	love.graphics.setColor(0.9, 0.9, 0.0)
	local x = self:getX()
	local y = self:getY()
	local radius = self.getRadius(self)
	love.graphics.circle('fill', x, y, radius)
end

return Collider