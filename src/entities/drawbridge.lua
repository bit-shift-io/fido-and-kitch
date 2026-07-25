-- One-way tile crossing over a real gap: closed blocks like a wall, an
-- eligible entity approaching from the correct (facing) side lowers it into
-- solid ground, and it stays open while occupied before raising again.
-- See .scratch/drawbridge/ for the full design.
local DrawbridgeSupport = require('src.entities.drawbridge_support')

local Drawbridge = Class{__includes = Entity}

function Drawbridge:init(object)
	Entity.init(self)
	self.type = 'drawbridge'
	self.object = object
	self.name = object.name
	self.state = 'closed'

	self.rect = Rect(object)
	local shape_arguments = self.rect:colliderShapeArgs()
	local position = self.rect:centre()

	self.facing = (object.properties and object.properties.facing) or 'right'
	self.allowEnemies = (object.properties and object.properties.allowEnemies) or false

	self.sprite = self:addComponent(Sprite{
		image = 'res/img/default.png',
		frames = 1,
		duration = 1.0,
		loop = false,
		playing = false,
		position = position,
		shape_arguments = shape_arguments,
		facing = self.facing,
		finish = utils.func(self.onAnimationFinish, self),
	})

	-- solid while closed, blocks horizontal entry like a wall
	self.barrier = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		position = position,
		sensor = not DrawbridgeSupport.isBarrierPresent(self.state),
	})

	-- solid walkable ground while open/opening/closing, absent while closed
	self.deck = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		position = position,
		sensor = not DrawbridgeSupport.isDeckSolid(self.state),
	})

	-- always-present sensor on the correct (facing) side; overlap by an
	-- eligible entity starts (or reverses back into) the open transition
	local triggerOffset = Vector(DrawbridgeSupport.triggerOffsetX(self.facing, self.rect.width), 0)
	self.trigger = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		sensor = true,
		position = position + triggerOffset,
		enter = utils.func(self.onTriggerEnter, self),
	})
end

-- flip solidity to match the new state and remember it
function Drawbridge:setState(state)
	self.state = state
	self.barrier:setSensor(not DrawbridgeSupport.isBarrierPresent(state))
	self.deck:setSensor(not DrawbridgeSupport.isDeckSolid(state))
end

function Drawbridge:onTriggerEnter(other)
	local entityType = other.entity and other.entity.type
	local nextState = DrawbridgeSupport.nextStateOnTrigger(self.state, entityType, self.allowEnemies)

	if nextState == self.state then
		return
	end

	if self.state == 'closing' then
		self.sprite:reverseFromCurrent() -- reverse in place, no snap
	else
		self.sprite:playForward()
	end

	self:setState(nextState)
end

function Drawbridge:onAnimationFinish()
	self:setState(DrawbridgeSupport.nextStateOnAnimationFinish(self.state))
end

return Drawbridge
