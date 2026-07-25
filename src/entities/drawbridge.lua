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

	self.hasBeenOccupied = false

	self.rect = Rect(object)
	local shape_arguments = self.rect:colliderShapeArgs()
	local position = self.rect:centre()

	self.facing = (object.properties and object.properties.facing) or 'right'
	self.allowEnemies = (object.properties and object.properties.allowEnemies) or false

	self.sprite = self:addComponent(Sprite{
		image = 'res/img/default.png',
		frames = 1,
		-- fast enough that the deck finishes lowering while the entity that
		-- triggered it (walking from the lead-in sensor, one tile away) is
		-- still on or approaching the tile, not long after they've already
		-- crossed and left
		duration = 0.3,
		loop = false,
		playing = false,
		position = position,
		shape_arguments = shape_arguments,
		facing = self.facing,
		finish = utils.func(self.onAnimationFinish, self),
	})

	-- Solid while closed, blocks horizontal entry like a wall. Shaped taller
	-- than the tile itself (bottom flush with it, extending well above the
	-- walking surface) rather than reusing the tile's own flush-with-ground
	-- rect: two solid rects of the same height, both starting at the ground
	-- surface, resolve as a walkable step rather than a wall under this
	-- project's simple AABB collision, so a same-height barrier never
	-- actually stops a player approaching at normal standing height (found
	-- via the headed drawbridge scenario -- see DECISIONS.md in
	-- .scratch/headed-e2e-tests/).
	local barrierHeight = self.rect.height * 5
	local barrierPosition = Vector(position.x, (object.y + object.height) - barrierHeight / 2)
	self.barrier = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, self.rect.width, barrierHeight},
		body_type = 'static',
		position = barrierPosition,
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
	-- Player:queryOnGround()/GroundSupport treat a bare `entity == nil`
	-- collider as terrain; the deck belongs to this Drawbridge entity, so it
	-- needs an explicit opt-in to be recognised as ground a player can
	-- stand and walk on, or a crossing player gets stuck in FallState the
	-- instant they step onto it (found via the headed drawbridge scenario).
	self.deck.walkable = true

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

function Drawbridge:update(dt)
	Entity.update(self, dt)
	self:checkOccupancy()
end

-- comfortably taller than any standing entity, so an occupant resting on
-- the deck (feet at the tile's top edge, body extending upward) is caught
-- by the occupancy query below, not just something inside the tile's own
-- physical depth
local OCCUPANCY_HEIGHT_MARGIN = 200

-- occupancy is the safety net: it keeps the bridge open (or reopens a
-- close-in-progress) while anyone overlaps the tile's footprint, independent
-- of the trigger sensor, so an occupant is never dropped
function Drawbridge:checkOccupancy()
	local bounds = {
		left = self.rect.x,
		right = self.rect.x + self.rect.width,
		top = self.rect.y - OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}
	local overlaps = world:queryOverlap(bounds)
	local occupied = DrawbridgeSupport.hasOccupant(overlaps, self)

	if occupied then
		self.hasBeenOccupied = true
	end

	local nextState = DrawbridgeSupport.nextStateOnOccupancyChange(self.state, occupied, self.hasBeenOccupied)

	if nextState == self.state then
		return
	end

	if nextState == 'closing' then
		self.sprite:playReverse() -- fresh close from the fully-open end
		self.hasBeenOccupied = false -- reset for the next open cycle
	elseif nextState == 'opening' then
		self.sprite:reverseFromCurrent() -- reverse in place, no snap
	end

	self:setState(nextState)
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
