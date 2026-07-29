-- Shared behaviour for props a player can shove horizontally (push_box,
-- boulder). Polls the world each frame for who is leaning on the prop and
-- what is resting on it, hands those facts to the pure decisions in
-- pushable_support.lua, and drives the resulting horizontal velocity.
--
-- Deliberately world-polling rather than contact-driven: nothing has to be
-- added to Player at all (no push probe, no per-frame bookkeeping), which
-- keeps the mechanic entirely inside the prop -- the same "recompute fresh
-- every frame, keep no memory" approach src/entities/drawbridge uses for its
-- hold state. Entities update before physics (InGameState:update calls
-- map:update then world:update), so a velocity set here is applied by the
-- physics step later in the same frame.
--
-- Vertical motion is left entirely to gravity: this component only ever
-- writes the horizontal component, so a prop that walks off a ledge falls
-- straight down (ADR 0001) instead of arcing.
local GroundSupport = require('src.player.ground_support')
local PushableSupport = require('src.components.pushable.pushable_support')

local Pushable = Class{}

-- how far beyond a face to look for a pusher. Small: a player has to be
-- genuinely against the prop, not merely near it.
local PROBE_DEPTH = 2
-- inset from the prop's own top and bottom edges, so the terrain it is
-- resting on (and anything directly above) never reads as a side pusher
local FACE_INSET = 6
-- tall enough that an entity standing on the prop -- feet on its top edge,
-- body extending upward out of the prop's own depth -- is caught by the
-- on-top query, mirroring the drawbridge's occupancy margin
local ON_TOP_HEIGHT = 200

function Pushable:init(props)
	self.type = 'pushable'
	self.collider = props.collider
	-- 'slide' (a push box) moves only while actively pushed; 'roll' (a boulder)
	-- carries on under its own momentum after the shove ends
	self.mode = props.mode or 'slide'
	self.rollVelocity = 0
	self.allowPushWhenStoodOn = props.allowPushWhenStoodOn or false
	-- the prop's resting collision group, handed back to the collider whenever
	-- it settles; while falling it borrows the players' group instead
	self.groupIndex = props.collider.groupIndex
end

-- entities (not raw terrain) overlapping a strip just outside one face
function Pushable:queryFace(bounds, side)
	local probe
	if side == 'left' then
		probe = {left = bounds.left - PROBE_DEPTH, right = bounds.left}
	else
		probe = {left = bounds.right, right = bounds.right + PROBE_DEPTH}
	end
	probe.top = bounds.top + FACE_INSET
	probe.bottom = bounds.bottom - FACE_INSET

	return world:queryOverlap(probe)
end

-- Players pressed against either face, described as the plain intent tables
-- PushableSupport.pushDirection consumes. Only players push -- a prop shoved
-- into another prop stops rather than shunting it along (no prop trains).
function Pushable:findPushers(bounds)
	local pushers = {}

	for _, side in ipairs({'left', 'right'}) do
		for _, collider in ipairs(self:queryFace(bounds, side)) do
			local entity = collider.entity
			if entity and entity.type == 'player' then
				table.insert(pushers, {
					centreX = entity.collider:getX(),
					grounded = entity:queryOnGround(),
					holdingLeft = entity:isDown('left'),
					holdingRight = entity:isDown('right'),
					speed = entity.speed,
				})
			end
		end
	end

	return pushers
end

-- what is resting on the prop right now, as the flags isPushableNow consumes
function Pushable:findOnTop(bounds)
	local probe = {
		left = bounds.left + FACE_INSET,
		right = bounds.right - FACE_INSET,
		top = bounds.top - ON_TOP_HEIGHT,
		bottom = bounds.top,
	}

	local playerOnTop, pushableOnTop = false, false

	for _, collider in ipairs(world:queryOverlap(probe)) do
		local entity = collider.entity
		if entity and entity ~= self.entity then
			if entity.type == 'player' then
				playerOnTop = true
			elseif entity.isPushable then
				pushableOnTop = true
			end
		end
	end

	return playerOnTop, pushableOnTop
end

-- ADR 0001: support is decided by what is under the prop's CENTRE-x alone,
-- not by how much of its footprint still overlaps a ledge. That is what makes
-- the drop deterministic -- the prop rests wherever it was left while its
-- centre is over ground, and the moment the centre crosses onto an
-- unsupported tile it commits to falling into that tile.
function Pushable:hasSupportUnderCentre(bounds)
	return GroundSupport.hasGroundAt(world, self.collider:getX(), bounds.bottom + 4, bounds.bottom + 5)
end

-- Where an overlapping pressure plate wants this prop seated, or nil if there
-- is no plate under it (or it is too far off-centre to seat). The plate owns
-- the tolerance and publishes the seat position, so the prop never has to know
-- what counts as "on" a plate.
function Pushable:seatOnPlate(bounds)
	for _, collider in ipairs(world:queryOverlap(bounds)) do
		local entity = collider.entity
		if entity and entity.isPressurePlate then
			local seatCentreX = entity:seatCentreX(self.collider:getX())
			if seatCentreX then
				return seatCentreX
			end
		end
	end

	return nil
end

function Pushable:update(dt)
	local bounds = self.collider:getBounds()
	local resolvedVelocityX, velocityY = self.collider:getLinearVelocity()
	-- gravity is cancelled the frame a prop lands, so any vertical velocity
	-- left over from the physics step means it is still falling
	local airborne = PushableSupport.isAirborne(velocityY)
	local supported = self:hasSupportUnderCentre(bounds)

	local direction, speed = 0, 0

	if supported and not airborne then
		local playerOnTop, pushableOnTop = self:findOnTop(bounds)
		local pushable = PushableSupport.isPushableNow({
			airborne = airborne,
			playerOnTop = playerOnTop,
			pushableOnTop = pushableOnTop,
			allowPushWhenStoodOn = self.allowPushWhenStoodOn,
		})

		if pushable then
			local pushers = self:findPushers(bounds)
			local centreX = self.collider:getX()
			direction = PushableSupport.pushDirection(pushers, centreX)
			speed = PushableSupport.pushSpeed(pushers, centreX, direction)
		end
	end

	-- In roll mode the prop keeps its own momentum once shoved; in slide mode
	-- there is no momentum to keep, so the velocity is purely the live push.
	local velocityX = direction * speed
	if self.mode == 'roll' then
		self.rollVelocity = PushableSupport.nextRollVelocity({
			currentRoll = self.rollVelocity,
			pushVelocity = velocityX,
			resolvedVelocityX = resolvedVelocityX,
			falling = not supported or airborne,
		})
		velocityX = self.rollVelocity
	end

	local state = {supported = supported, airborne = airborne, moving = velocityX ~= 0}
	self.collider:setType(PushableSupport.bodyTypeFor(state))
	self.collider:setGroupIndex(PushableSupport.groupIndexFor(state, self.groupIndex))

	-- The plate-seating forcing event (ADR 0001), fired on push-RELEASE rather
	-- than during motion: a prop that has come to a stop within a plate's
	-- tolerance settles onto the plate tile's centre. Gating it on "not moving"
	-- is what keeps it from fighting the player -- mid-push the prop always has
	-- a velocity, so the snap can only land once they have let go. Idempotent
	-- once seated, since the seat position is then the prop's own centre.
	if supported and not airborne and velocityX == 0 then
		local seatCentreX = self:seatOnPlate(bounds)
		if seatCentreX then
			self.collider:setX(seatCentreX)
		end
	end

	if not supported then
		-- The forcing event (ADR 0001): nothing under the centre, so align to
		-- the tile being dropped into and fall straight down. Alignment is
		-- what makes a one-tile hole fill flush instead of leaving the prop
		-- wedged off-centre wherever momentum happened to leave it.
		--
		-- Re-applied every frame of the fall, which is harmless: once aligned
		-- the snap target is the prop's own current x, so it is idempotent.
		self.collider:setX(PushableSupport.snapTargetX(self.collider:getX(), map.tilewidth))
	end

	-- rewritten every frame, including to zero: a sliding prop stops the
	-- instant the player stops, releases, or turns away, with no deceleration
	-- to carry it past where they stopped pushing, and neither mode can be
	-- steered mid-fall
	self.collider:setLinearVelocity(velocityX, velocityY)
end

return Pushable
