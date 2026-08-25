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
--
-- Single file, not the multi-file directory NOTES.md originally called
-- for: that split existed solely so the pure decision helpers below could
-- be required from tests/unit/, which cannot construct a Sprite/Collider-
-- composing entity headless. tests/support/headless_bootstrap.lua now
-- makes that construction possible directly (see NOTES.md), so the
-- helpers stay private locals here instead of a separate _support module.
-- See tests/unit/drawbridge_test.lua for the entity-level tests this
-- enables.

local Drawbridge = Class{__includes = Entity}

-- centre-offset (from the bridge tile's own centre) for the arrival-side
-- trigger sensor, positioned flush against the gap's edge -- not a full
-- tile out -- so the deck visibly starts lowering only once the player is
-- right at the edge (reads as "pushing the gate down"), not by tripping a
-- remote sensor a whole tile away. crossingDirection names the direction of
-- travel the bridge permits: a leftToRight bridge is arrived at from the
-- left, so the trigger sits to the left; an unrecognised or missing value
-- falls back to leftToRight.
local function triggerOffsetX(crossingDirection, tileWidth, triggerWidth)
	local flushOffset = tileWidth / 2 + triggerWidth / 2
	if crossingDirection == 'rightToLeft' then
		return flushOffset
	end
	return -flushOffset
end

-- Maps crossingDirection to the sprite's mirror flag. The art is a tower
-- hinged on the left with the deck lowering rightward, so unmirrored ('right')
-- is exactly a left-to-right crossing; rightToLeft mirrors it. This is the
-- inverse of treating crossingDirection as a facing value directly -- doing
-- that was the original bug (both shipped bridges drew the tower over the
-- gap). An unrecognised or missing value falls back to leftToRight's mapping.
local function spriteFacing(crossingDirection)
	if crossingDirection == 'rightToLeft' then
		return 'left'
	end
	return 'right'
end

-- the sprite draws 2x the object's own tile dimensions, centred on the
-- object tile -- half a tile of bleed in every direction so the art can key
-- into the surrounding environment. Derived from the object's own size
-- rather than a hard-coded pixel value so it survives a tile-size change.
-- Purely visual: the deck and trigger colliders stay one tile each.
local function spriteBoxDimensions(objectWidth, objectHeight)
	return objectWidth * 2, objectHeight * 2
end

local function isDeckSolid(state)
	return state ~= 'closed'
end

-- Two zones, evaluated fresh every frame: triggerHeld (the lead-in tile on
-- the arrival side) and deckHeld (the bridge's own tile).
--
-- Only the trigger can break a CLOSED bridge -- deck overlap alone is not
-- enough. This is what keeps a wrong-side approach a real hazard: without
-- it, a wide collider grazing the far edge of the deck tile while still
-- standing on solid ground on the wrong side would pre-emptively solidify
-- the gap for it, regardless of crossingDirection. Every other transition
-- is driven by either zone once the bridge is already moving -- by the time
-- it's CLOSING, the deck is still solid, so an occupant there (having
-- crossed from the far side, or never having left) is a legitimate reason
-- to reopen, not a rescue.
local function nextStateOnHeldChange(state, triggerHeld, deckHeld)
	if state == 'closed' then
		if triggerHeld then
			return 'opening'
		end
		return state
	end

	if state == 'closing' then
		if triggerHeld or deckHeld then
			return 'opening'
		end
		return state
	end

	if state == 'open' or state == 'opening' then
		if not (triggerHeld or deckHeld) then
			return 'closing'
		end
		return state
	end

	return state
end

local function nextStateOnAnimationFinish(state)
	if state == 'opening' then
		return 'open'
	end

	if state == 'closing' then
		return 'closed'
	end

	return state
end

-- true if any collider in the (combined trigger+deck) overlap set belongs
-- to an entity other than the drawbridge's own colliders (deck/trigger).
-- Anything counts -- players, enemies, pushed boxes -- there is no
-- entity-type eligibility.
local function isHeld(overlaps, selfEntity)
	for _, collider in ipairs(overlaps) do
		if collider.entity and collider.entity ~= selfEntity then
			return true
		end
	end
	return false
end

function Drawbridge:init(object)
	Entity.init(self, object, 'drawbridge')
	self.state = 'closed'
	self.latchedOpen = false
	self.latchedOpen = false

	self.rect = Rect(object)
	local shape_arguments = self.rect:colliderShapeArgs()
	local position = self.rect:centre()

	self.crossingDirection = (object.properties and object.properties.crossingDirection) or 'leftToRight'

	-- visual footprint only -- the deck and trigger colliders below stay one
	-- tile each; the bigger sprite is purely decorative bleed and must never
	-- be treated as a hint about what a player can stand on
	local spriteBoxWidth, spriteBoxHeight = spriteBoxDimensions(object.width, object.height)

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
		shape_arguments = {spriteBoxWidth, spriteBoxHeight},
		facing = spriteFacing(self.crossingDirection),
		finish = utils.bindSelf(self.onAnimationFinish, self),
	})

	-- solid walkable ground while open/opening/closing, absent while closed
	-- (closed leaves the gap fully exposed -- no barrier; the wrong side is
	-- a real hazard, not a wall)
	self.deck = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		position = position,
		sensor = not isDeckSolid(self.state),
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
	local triggerOffset = triggerOffsetX(self.crossingDirection, self.rect.width, self.triggerWidth)
	self.triggerCentre = position + Vector(triggerOffset, 0)
	self.trigger = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {self.triggerWidth, self.rect.height},
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

	self:addComponent(Switchable{
		entity = self,
		onStateChange = function(enabled)
			self.latchedOpen = enabled
		end
	})
end

-- flip solidity to match the new state
function Drawbridge:setState(state)
	self.state = state
	self.deck:setSensor(not isDeckSolid(state))
end

function Drawbridge:update(dt)
	Entity.update(self, dt)
	if self.latchedOpen then
		if self.state ~= 'open' then
			self:setState('open')
		end
		return
	end
	self:checkHeld()
end

-- comfortably taller than any standing entity, so an occupant resting on
-- the deck (feet at the tile's top edge, body extending upward) is caught
-- by the overlap query below, not just something inside the tile's own
-- physical depth
local OCCUPANCY_HEIGHT_MARGIN = 32

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
	local triggerHeld = isHeld(world:queryOverlap(triggerBounds), self)
	local deckHeld = isHeld(world:queryOverlap(deckBounds), self)

	local nextState = nextStateOnHeldChange(self.state, triggerHeld, deckHeld)

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
	self:setState(nextStateOnAnimationFinish(self.state))
end

-- White-box seam for tests/unit/drawbridge_test.lua only: the pure decision
-- helpers above have no reason to be public API (nothing outside this file
-- calls them), but exposing them here keeps their fast, precise,
-- construction-free test coverage alongside the entity-level tests that
-- exercise the whole assembled Drawbridge (construction, real Sprite/
-- Collider/world wiring, checkHeld) via tests/support/headless_bootstrap.
-- Not for use by production code -- reach for the real entity there.
Drawbridge._internal = {
	triggerOffsetX = triggerOffsetX,
	spriteFacing = spriteFacing,
	spriteBoxDimensions = spriteBoxDimensions,
	isDeckSolid = isDeckSolid,
	nextStateOnHeldChange = nextStateOnHeldChange,
	nextStateOnAnimationFinish = nextStateOnAnimationFinish,
	isHeld = isHeld,
}

return Drawbridge
