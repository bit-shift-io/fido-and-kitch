-- One-way tile crossing over a real gap: closed leaves the gap fully
-- exposed (no barrier -- approaching from the wrong side just means
-- falling in, like any other pit). Only the lead-in trigger tile (on the
-- arrival side, per flipCrossing) can break a closed bridge -- this is
-- what keeps the wrong side a real hazard, rather than a wide collider
-- grazing the deck's far edge pre-emptively solidifying the gap for it.
-- Once moving, either the trigger tile or the deck tile itself holds the
-- bridge down: it lowers while held and raises once it's not, reversing an
-- in-flight animation from the current frame if the hold state flips
-- mid-transition. No eligibility, no memory of past occupancy: held is
-- recomputed fresh every frame (see DECISIONS.md Q3/Q4).
--
-- Single file, not the multi-file directory NOTES.md originally called
-- for: that split existed solely so the pure decision helpers below could
-- be required from tests/unit/, which cannot construct a Sprite/Collider-
-- composing entity headless. tests/support/headless_bootstrap.lua now
-- makes that construction possible directly (see NOTES.md), so the
-- helpers stay private locals here instead of a separate _support module.
-- See tests/unit/drawbridge_test.lua for the entity-level tests this
-- enables.

local Drawbridge = Class({ __includes = Entity })
local SpriteProps = require("src.entities.sprite_props")
local Geom = require("src.utils.geom")

-- centre-offset (from the bridge tile's own centre) for the arrival-side
-- trigger sensor, positioned flush against the gap's edge -- not a full
-- tile out -- so the deck visibly starts lowering only once the player is
-- right at the edge (reads as "pushing the gate down"), not by tripping a
-- remote sensor a whole tile away. flipCrossing flips the direction of
-- travel the bridge permits: a normal (non-flipped, left-to-right) bridge is
-- arrived at from the left, so the trigger sits to the left; a
-- flipCrossing=true bridge is arrived at from the right, so the trigger sits
-- to the right. A missing value falls back to non-flipped (left-to-right).
local function triggerOffsetX(flipCrossing, tileWidth, triggerWidth)
	local flushOffset = tileWidth / 2 + triggerWidth / 2
	if flipCrossing then
		return flushOffset
	end
	return -flushOffset
end

-- Maps flipCrossing to the sprite's mirror flag. The art is a tower
-- hinged on the left with the deck lowering rightward, so unmirrored ('right')
-- is exactly a left-to-right crossing; flipCrossing=true mirrors it. This is the
-- inverse of treating the flip as a facing value directly -- doing
-- that was the original bug (both shipped bridges drew the tower over the
-- gap). A missing value falls back to the non-flipped mapping.
local function spriteFacing(flipCrossing)
	if flipCrossing then
		return "left"
	end
	return "right"
end

-- The sprite fills the authored object's own rect, 1:1 -- like the
-- blocker. The drawbridge template is authored at the art size (64x64
-- against the 64px-wide drawbridge frames), so drawing at the object's own
-- size reproduces the editor placement exactly, with no bleed and no
-- stretch. (The old 2x box existed only because the template was a 32x32
-- object; once the art box is authored at the true size, 2x would distort.)
-- Purely visual: the deck and trigger colliders stay one tile each, sized
-- by the colliderWidth/colliderHeight template props -- see init.
local function spriteBoxDimensions(objectWidth, objectHeight)
	return objectWidth, objectHeight
end

local function isDeckSolid(state)
	return state ~= "closed"
end

-- Two zones, evaluated fresh every frame: triggerHeld (the lead-in tile on
-- the arrival side) and deckHeld (the bridge's own tile).
--
-- Only the trigger can break a CLOSED bridge -- deck overlap alone is not
-- enough. This is what keeps a wrong-side approach a real hazard: without
-- it, a wide collider grazing the far edge of the deck tile while still
-- standing on solid ground on the wrong side would pre-emptively solidify
-- the gap for it, regardless of flipCrossing. Every other transition
-- is driven by either zone once the bridge is already moving -- by the time
-- it's CLOSING, the deck is still solid, so an occupant there (having
-- crossed from the far side, or never having left) is a legitimate reason
-- to reopen, not a rescue.
local function nextStateOnHeldChange(state, triggerHeld, deckHeld)
	if state == "closed" then
		if triggerHeld then
			return "opening"
		end
		return state
	end

	if state == "closing" then
		if triggerHeld or deckHeld then
			return "opening"
		end
		return state
	end

	if state == "open" or state == "opening" then
		if not (triggerHeld or deckHeld) then
			return "closing"
		end
		return state
	end

	return state
end

local function nextStateOnAnimationFinish(state)
	if state == "opening" then
		return "open"
	end

	if state == "closing" then
		return "closed"
	end

	return state
end

-- true if any collider in the (combined trigger+deck) overlap set belongs
-- to an entity other than the drawbridge's own colliders (deck/trigger).
-- Anything counts -- players, enemies, pushed boxes -- there is no
-- entity-type eligibility, EXCEPT ladders: a ladder's collider is a static,
-- always-present sensor volume (its climbable air-space), not an occupant --
-- it overlaps a bridge's trigger/deck whether or not anyone is actually
-- climbing it. A drawbridge placed next to a ladder (a natural, common map
-- layout -- see fab2.tmj) would otherwise be permanently "held" open by the
-- ladder itself from the moment the map loads. A player actually standing in
-- that ladder is still detected via the player's own collider.
local function isHeld(overlaps, selfEntity)
	for _, collider in ipairs(overlaps) do
		local entity = collider.entity
		if entity and entity ~= selfEntity and not entity.isLadder then
			return true
		end
	end
	return false
end

function Drawbridge:init(object)
	Entity.init(self, object, "drawbridge")
	self.state = "closed"

	self.rect = Rect(object)

	self.flipCrossing = (object.properties and object.properties.flipCrossing) or nil

	self:buildSprite(object)
	self:buildDeckAndTrigger(object)
	self:buildSound()
	self:buildSwitch()
end

-- The object rect is the ART box (drawbridge.tj: 64x64); the sprite fills
-- it 1:1, centred on it, plus optional author-side `spriteOffsetX`/
-- `spriteOffsetY` (px, positive = right/down) that move only the art --
-- the colliders below never follow them.
function Drawbridge:buildSprite(object)
	local spriteBoxWidth, spriteBoxHeight = spriteBoxDimensions(object.width, object.height)
	local spriteOffsetX = tonumber(object.properties.spriteOffsetX) or 0
	local spriteOffsetY = tonumber(object.properties.spriteOffsetY) or 0
	local spritePosition = self.rect:centre()

	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = spritePosition + Vector(spriteOffsetX, spriteOffsetY)
	spriteProps.shape_arguments = { spriteBoxWidth, spriteBoxHeight }
	spriteProps.facing = spriteFacing(self.flipCrossing)
	spriteProps.finish = utils.bindSelf(self.onAnimationFinish, self)

	self.sprite = self:addComponent(Sprite(spriteProps))
end

-- The gameplay footprint is independent of the art box: the deck, trigger,
-- and occupancy geometry derive from the colliderWidth/colliderHeight
-- template props (drawbridge.tj: one tile each -- 32x32), anchored at the
-- object's own corner (plus optional colliderOffsetX/Y author nudges,
-- symmetric to the sprite offsets), so doubling the art box to the true
-- 64px frame -- or moving the art in the editor -- never drags the
-- colliders the author placed over the gap. Falling back to the object's
-- own size means a map that omits the props (or a headless test stub)
-- still gets a deck.
function Drawbridge:buildDeckAndTrigger(object)
	local colliderWidth = tonumber(object.properties.colliderWidth) or self.rect.width
	local colliderHeight = tonumber(object.properties.colliderHeight) or self.rect.height
	local colliderOffsetX = tonumber(object.properties.colliderOffsetX) or 0
	local colliderOffsetY = tonumber(object.properties.colliderOffsetY) or 0
	-- colliderOffsetX is authored for the non-flipped (left-to-right) pose,
	-- same as spriteFacing/triggerOffsetX -- flipCrossing mirrors the sprite
	-- about the art box's own centre, so the deck's footprint has to mirror
	-- with it (about the art box's width) or it lands a tile away from the
	-- gap the mirrored art is actually drawn over: a flipped bridge would
	-- solidify already-solid ground instead of the real gap, dropping anyone
	-- who steps onto the visible (mirrored) deck straight through.
	if self.flipCrossing then
		colliderOffsetX = self.rect.width - colliderWidth - colliderOffsetX
	end
	self.rect = Rect({
		x = self.rect.x + colliderOffsetX,
		y = self.rect.y + colliderOffsetY,
		width = colliderWidth,
		height = colliderHeight,
	})
	local shape_arguments = self.rect:colliderShapeArgs()
	local position = self.rect:centre()

	-- solid walkable ground while open/opening/closing, absent while closed
	-- (closed leaves the gap fully exposed -- no barrier; the wrong side is
	-- a real hazard, not a wall)
	self.deck = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = shape_arguments,
		body_type = "static",
		position = position,
		sensor = not isDeckSolid(self.state),
	}))
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
	local triggerOffset = triggerOffsetX(self.flipCrossing, self.rect.width, self.triggerWidth)
	self.triggerCentre = position + Vector(triggerOffset, 0)
	self.trigger = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = { self.triggerWidth, self.rect.height },
		body_type = "static",
		sensor = true,
		position = self.triggerCentre,
	}))
end

function Drawbridge:buildSound()
	self.sound = self:addComponent(Sound({
		sounds = {
			open = "res/snd/entity_drawbridge_open.wav",
			close = "res/snd/entity_drawbridge_close.wav",
		},
	}))
end

function Drawbridge:buildSwitch()
	-- A linked switch, once flicked ON, holds the bridge open and locks it
	-- there: with nobody holding it, it won't re-close, regardless of
	-- occupancy. Turning OFF only releases that lock -- it plays the close
	-- animation but hands control straight back to occupancy-driven
	-- checkHeld() (switchHeld returns to nil), rather than latching closed.
	-- This matters for a momentary pressure switch (unlike a deliberately
	-- toggled lever): its resting state is "off" the instant nobody's
	-- weight is on it, which is not a deliberate "lock this shut" action --
	-- the bridge's own contact trigger must still work afterward, or every
	-- switch-linked bridge permanently loses its walk-up trigger the first
	-- time the switch is ever touched. A nil initial value means no switch
	-- has acted yet, so the plain occupancy behaviour governs unless/until
	-- a switch turns it on.
	self.switchHeld = nil
	self:addComponent(Switchable({
		entity = self,
		onStateChange = function(enabled)
			if enabled then
				self.switchHeld = true
				if self.state == "open" or self.state == "opening" then
					return
				end
				if self.state == "closing" then
					self.sprite:reverseFromCurrent()
				else
					self.sprite:playForward()
				end
				self.sound:play("open")
				self:setState("opening")
			else
				self.switchHeld = nil
				if self.state == "closed" or self.state == "closing" then
					return
				end
				if self.state == "opening" then
					self.sprite:reverseFromCurrent()
				else
					self.sprite:playReverse()
				end
				self.sound:play("close")
				self:setState("closing")
			end
		end,
	}))
end

-- flip solidity to match the new state
function Drawbridge:setState(state)
	self.state = state
	self.deck:setSensor(not isDeckSolid(state))
end

function Drawbridge:update(dt)
	Entity.update(self, dt)
	-- while a switch holds the bridge (either direction), its state is
	-- latched -- don't let occupancy-driven checkHeld() override the switch
	if self.switchHeld == nil then
		self:checkHeld()
	end
end

-- comfortably taller than any standing entity, so an occupant resting on
-- the deck (feet at the tile's top edge, body extending upward) is caught
-- by the overlap query below, not just something inside the tile's own
-- physical depth

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
		top = self.rect.y - Geom.OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}
	local deckBounds = {
		left = self.rect.x,
		right = self.rect.x + self.rect.width,
		top = self.rect.y - Geom.OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}
	local triggerHeld = isHeld(world:queryOverlap(triggerBounds), self)
	local deckHeld = isHeld(world:queryOverlap(deckBounds), self)

	local nextState = nextStateOnHeldChange(self.state, triggerHeld, deckHeld)

	if nextState == self.state then
		return
	end

	if nextState == "closing" then
		if self.state == "opening" then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playReverse() -- fresh close from the fully-open end
		end
		self.sound:play("close")
	elseif nextState == "opening" then
		if self.state == "closing" then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playForward() -- fresh open from the fully-closed end
		end
		self.sound:play("open")
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
