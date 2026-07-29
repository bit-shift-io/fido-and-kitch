-- One-way tile crossing over a real gap: closed leaves the gap fully
-- exposed (no barrier -- approaching from the wrong side just means
-- falling in, like any other pit). Only the lead-in trigger tile (on the
-- arrival side, per crossingDirection) can break a closed bridge -- this is
-- what keeps the wrong side a real hazard, rather than a wide collider
-- grazing the deck's far edge pre-emptively solidifying the gap for it.
-- Once moving, either the trigger tile or the deck tile itself holds the
-- bridge down: it lowers while held and raises once it's not, reversing an
-- in-flight animation from the current frame if the hold state flips
-- mid-transition. No eligibility, no memory of past occupancy: held is
-- recomputed fresh every frame. See .scratch/drawbridge/ for the original
-- design and DECISIONS.md Q3/Q4 for why the old flag-based model could get
-- permanently stuck open.
local DrawbridgeSupport = require('src.entities.drawbridge.drawbridge_support')

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

	self.crossingDirection = (object.properties and object.properties.crossingDirection) or 'leftToRight'

	-- visual footprint only -- the deck and trigger colliders below stay one
	-- tile each; the bigger sprite is purely decorative bleed and must never
	-- be treated as a hint about what a player can stand on
	local spriteBoxWidth, spriteBoxHeight = DrawbridgeSupport.spriteBoxDimensions(object.width, object.height)

	self.sprite = self:addComponent(Sprite{
		image = 'res/img/entity_drawbridge.png',
		frames = 4,
		-- fast enough that the deck finishes lowering while the entity that
		-- triggered it (walking from the thin lead-in sensor flush against
		-- the gap) is still on or approaching the tile, not long after
		-- they've already crossed and left
		duration = 0.3,
		loop = false,
		playing = false,
		position = position,
		shape_arguments = {0, 0, spriteBoxWidth, spriteBoxHeight},
		facing = DrawbridgeSupport.spriteFacing(self.crossingDirection),
		finish = utils.func(self.onAnimationFinish, self),
	})

	-- solid walkable ground while open/opening/closing, absent while closed
	-- (closed leaves the gap fully exposed -- no barrier; the wrong side is
	-- a real hazard, not a wall)
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

	-- lead-in sensor on the arrival side, part of the continuous hold zone
	-- (see checkHeld) -- kept as a sensor purely so the zone still draws
	-- under drawphysics; its enter event no longer drives state directly.
	-- Thin and flush against the gap's edge (not a full tile out) so the
	-- deck visibly starts lowering only once the player is right at the
	-- edge -- reads as pushing the gate down, not tripping a remote sensor.
	self.triggerWidth = self.rect.width * 0.25
	local triggerOffsetX = DrawbridgeSupport.triggerOffsetX(self.crossingDirection, self.rect.width, self.triggerWidth)
	self.triggerCentre = position + Vector(triggerOffsetX, 0)
	self.trigger = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, self.triggerWidth, self.rect.height},
		body_type = 'static',
		sensor = true,
		position = self.triggerCentre,
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_drawbridge_open.wav',
			close = 'res/snd/entity_drawbridge_close.wav',
		}
	})
end

-- flip solidity to match the new state
function Drawbridge:setState(state)
	self.state = state
	self.deck:setSensor(not DrawbridgeSupport.isDeckSolid(state))
end

function Drawbridge:update(dt)
	Entity.update(self, dt)
	self:checkHeld()
end

-- comfortably taller than any standing entity, so an occupant resting on
-- the deck (feet at the tile's top edge, body extending upward) is caught
-- by the overlap query below, not just something inside the tile's own
-- physical depth
local OCCUPANCY_HEIGHT_MARGIN = 200

-- held is evaluated fresh every frame, separately, over the trigger tile
-- and the deck tile -- an entity that has triggered the bridge but not yet
-- reached the deck is still standing in the trigger tile, so it still
-- counts. This is what makes the model safe with no memory: there is no
-- flag left behind by a previous cycle for a later frame to trust. Kept as
-- two separate queries (not one merged bounding box) because only the
-- trigger may break a closed bridge -- see the file header.
function Drawbridge:checkHeld()
	local triggerBounds = {
		left = self.triggerCentre.x - self.triggerWidth / 2,
		right = self.triggerCentre.x + self.triggerWidth / 2,
		top = self.rect.y - OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}
	local deckBounds = {
		left = self.rect.x,
		right = self.rect.x + self.rect.width,
		top = self.rect.y - OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}
	local triggerHeld = DrawbridgeSupport.isHeld(world:queryOverlap(triggerBounds), self)
	local deckHeld = DrawbridgeSupport.isHeld(world:queryOverlap(deckBounds), self)

	local nextState = DrawbridgeSupport.nextStateOnHeldChange(self.state, triggerHeld, deckHeld)

	if nextState == self.state then
		return
	end

	if nextState == 'closing' then
		if self.state == 'opening' then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playReverse() -- fresh close from the fully-open end
		end
		self.sound:play('close')
	elseif nextState == 'opening' then
		if self.state == 'closing' then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playForward() -- fresh open from the fully-closed end
		end
		self.sound:play('open')
	end

	self:setState(nextState)
end

function Drawbridge:onAnimationFinish()
	self:setState(DrawbridgeSupport.nextStateOnAnimationFinish(self.state))
end

return Drawbridge
