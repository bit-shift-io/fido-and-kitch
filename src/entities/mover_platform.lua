-- A rideable moving platform that travels a path defined in Tiled and carries
-- standing players with it. Route comes from a `path` (polyline) object
-- referenced by property, linear constant-speed point-to-point motion,
-- `endBehavior='pingpong'|'loop'`, a `pause` at every path point, delta-carry
-- of players standing on top, one-way top-only collision (jump/up-through),
-- and switch start/stop. See docs/adr/ -- the grilled decisions live in
-- NOTES.md.

local MoverPlatform = Class{__includes = Entity}

-- Feet-in-top-band tolerance for rider detection, in px. Must be >= the
-- platform's worst per-frame rise (speed * dt): at default 100px/s and 60fps
-- that's ~1.7px, so 8 gives comfortable headroom without swallowing anything
-- near the deck. A supported rider has feet sitting on the deck, so the band
-- reaching the full LAND_TOL below the top keeps the player the colFilterFn
-- deems landable inside the carry band too -- the two tolerances never
-- disagree about who is standing on the platform.
local RIDER_TOL = 8

-- How far (px) a player's feet may sit below the platform top and still be
-- treated as landing/standing on it for collision (see the colFilterFn
-- installed in init). Feet more than this below the top means the player is
-- under the deck -- jump up-through, and the platform's sides never block a
-- grounded walker (an intentional simplification of the one-way rule; see
-- NOTES.md).
local LAND_TOL = 6

-- Absolute waypoints: STI re-anchors a polyline object's points in place on
-- load (adding the object's own x/y to each vertex, lib/sti/init.lua
-- convertObjectShapesToPolygons), so the points the entity resolves off the
-- map object are already absolute -- jump_pad's use of polyline[1] as an
-- absolute launch origin depends on the same contract. Pure and
-- headless-safe -- no World, no I/O -- so the whole path model can be
-- unit-tested via MoverPlatform._internal without constructing anything.
local function polylineWaypoints(pathObject)
	local waypoints = {}
	for i, point in ipairs(pathObject.polyline or {}) do
		waypoints[i] = Vector(point.x, point.y)
	end
	return waypoints
end

-- The polyline a map maker draws is the DECK line: the waypoints mark where
-- the platform's TOP riding surface travels, so it lines up with the floor
-- heights (and other path layers) drawn in Tiled and the author never has to
-- do the half-height mental math. The collider (and sprite) are centred on
-- the stepper position, so the route hangs half the platform's height BELOW
-- the drawn line -- applyDeckOffset shifts each waypoint down by halfHeight
-- to turn the authored deck line into real collider-centre waypoints.
-- Returns NEW vectors; the input waypoints are not mutated. Pure and
-- headless-safe like the other path helpers.
local function applyDeckOffset(waypoints, halfHeight)
	local shifted = {}
	for i, waypoint in ipairs(waypoints) do
		shifted[i] = Vector(waypoint.x, waypoint.y + halfHeight)
	end
	return shifted
end

-- The route as a cyclic list of directed legs. pingpong reflects the
-- waypoint list so the ends are ordinary nodes in the cycle (arrive at last
-- waypoint, pause, then carry on down the reflected leg -- reversing
-- direction happens by construction, not special-cased). loop appends one
-- wrap-back leg from the last waypoint to the first, closing the ring.
-- Each leg names its from/to (as Vectors) and pixel length. Zero-length
-- legs (duplicate adjacent points) are dropped -- a coincident pair can't
-- be travelled and would otherwise be a divide-by-zero/never-terminate
-- hazard in advance().
local function buildLegs(waypoints, endBehavior)
	local legs = {}
	local count = #waypoints
	if count < 2 then
		return legs
	end

	local function pushLeg(from, to)
		local length = from:dist(to)
		if length > 0 then
			legs[#legs + 1] = { from = from, to = to, length = length }
		end
	end

	if endBehavior == 'loop' then
		for i = 1, count - 1 do
			pushLeg(waypoints[i], waypoints[i + 1])
		end
		pushLeg(waypoints[count], waypoints[1])
	else
		for i = 1, count - 1 do
			pushLeg(waypoints[i], waypoints[i + 1])
		end
		for i = count, 2, -1 do
			pushLeg(waypoints[i], waypoints[i - 1])
		end
	end
	return legs
end

-- A stepper is the running state of one platform's motion: the leg cycle,
-- the current position, how far into the current leg it has travelled, and
-- how much node-hold remains. `pause` is in seconds and `speed` in px/s;
-- the hold is pre-converted to a pixel-equivalent (pause * speed) so
-- advance() can consume it straight against the pixel distances the caller
-- steps by -- a 1s hold at 100px/s swallows 100px of advance before moving.
local function newStepper(waypoints, endBehavior, pause, speed)
	local legs = buildLegs(waypoints, endBehavior)
	local first = legs[1]
	return {
		legs = legs,
		endBehavior = endBehavior,
		pause = pause,
		speed = speed,
		pauseRemaining = 0,
		pauseDistance = (pause or 0) * (speed or 100),
		legIndex = 1,
		distInLeg = 0,
		-- a degenerate path (single waypoint, or all points coincident) has
		-- no legs: the platform simply holds at the one point it was placed
		pos = first and Vector(first.from.x, first.from.y) or (waypoints[1] or Vector(0, 0)),
	}
end

-- Advance the stepper by `distance` pixels. A node-hold (pause at every
-- path node, including both ends) is consumed first; only once it's spent
-- does the platform move on. Returns the new position (mutating stepper.pos
-- in place, so update() can diff newPos vs the pre-advance pos for the
-- exact rider-carry delta). Constant linear point-to-point speed: no easing,
-- no bezier -- a deliberately simple model (the Path/PathFollow bezier
-- machinery was considered and rejected; see NOTES.md).
local function advance(stepper, distance)
	if #stepper.legs == 0 then
		return stepper.pos
	end

	local remaining = distance

	while remaining > 0 do
		-- a node-hold queued by a previous arrival (pause at every node,
		-- including both ends) must be consumed before any further motion
		if stepper.pauseRemaining > 0 then
			if remaining > stepper.pauseRemaining then
				remaining = remaining - stepper.pauseRemaining
				stepper.pauseRemaining = 0
			else
				stepper.pauseRemaining = stepper.pauseRemaining - remaining
				remaining = 0
			end
			if remaining <= 0 then
				break
			end
		end

		local leg = stepper.legs[stepper.legIndex]
		local legNeed = leg.length - stepper.distInLeg

		if remaining < legNeed then
			-- mid-leg: still plenty of leg left this advance
			stepper.distInLeg = stepper.distInLeg + remaining
			local t = stepper.distInLeg / leg.length
			stepper.pos = leg.from + (leg.to - leg.from) * t
			remaining = 0
		else
			-- reach the node at this leg's end (or overshoot into the next)
			remaining = remaining - legNeed
			stepper.legIndex = stepper.legIndex % #stepper.legs + 1
			stepper.distInLeg = 0

			-- immediately owning the next leg's start pins the platform
			-- EXACTLY to the node, even on a pure overshoot -- no drift past
			-- the waypoint when advance spans a whole leg
			local nextLeg = stepper.legs[stepper.legIndex]
			stepper.pos = Vector(nextLeg.from.x, nextLeg.from.y)

			-- a hold at every node, incl. both ends of the path; the next
			-- loop iteration (or the caller's next advance) eats it first
			stepper.pauseRemaining = stepper.pauseDistance
		end
	end

	return stepper.pos
end

function MoverPlatform:init(object, map)
	Entity.init(self, object, 'mover_platform')

	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)

	self.sprite = self:addComponent(Sprite{
		image = 'res/img/entity_mover_platform.png',
		frames = 1,
		shape_arguments = shape_arguments,
	})

	-- solid, walkable ground (platforms carry standing players); manually
	-- moved each update() along the path -- a static body so gravity/motion
	-- never applies to it
	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		sprite = self.sprite,
		position = position,
		sensor = false,
	})
	-- Player:queryOnGround()/GroundSupport treat a bare `entity == nil`
	-- collider as terrain; this collider belongs to a MoverPlatform entity,
	-- so it needs an explicit opt-in to be recognised as ground a player can
	-- stand and walk on, or a rider gets stuck in FallState the instant they
	-- step onto it.
	self.collider.walkable = true

	-- One-way top-only collision: the colFilterFn decides per-pair whether
	-- the deck is solid. A player whose feet (other.y + other.height) sit
	-- more than LAND_TOL below the platform top is under the deck -> 'cross'
	-- (jump up-through, pass the sides); any player at the deck is 'slide'
	-- (land, stand, and be held). Any other collider returns nil -> the
	-- global World.colFilter defaults apply unchanged.
	local platCollider = self.collider
	local function platformColFilter(a, b)
		local other = (a == platCollider) and b or a
		local entity = other.entity
		if entity and entity.type == 'player' then
			local feet = other.y + other.height
			if feet > platCollider.y + LAND_TOL then
				return 'cross'
			end
			return 'slide'
		end
		return nil
	end
	self.collider:setColFilterFn(platformColFilter)

	-- props, with the defaults settled in NOTES.md
	self.speed = tonumber(object.properties.speed) or 100
	self.endBehavior = object.properties.endBehavior or 'pingpong'
	self.pause = tonumber(object.properties.pause) or 0
	self.enabled = true
	if object.properties.enabled ~= nil and object.properties.enabled ~= true then
		self.enabled = false
	end
	self.running = self.enabled

	if map and object.properties and object.properties.path then
		self.pathObject = map:getObjectById(object.properties.path.id)
	end

	if self.pathObject then
		local waypoints = polylineWaypoints(self.pathObject)
		-- the drawn polyline is the deck line (where the surface rides):
		-- shift the route down by half the platform height so the stepper's
		-- positions are collider-centre positions, and the deck top lands
		-- exactly on the authored waypoints
		self.waypoints = applyDeckOffset(waypoints, object.height / 2)
		self.stepper = newStepper(self.waypoints, self.endBehavior, self.pause, self.speed)
		self.prevPos = Vector(self.stepper.pos.x, self.stepper.pos.y)
		-- the route owns the platform's resting place: start parked exactly
		-- on the first (deck-line) waypoint, not the template anchor (they
		-- may differ)
		self.collider:setPositionV(self.stepper.pos)
	end

	self:addComponent(Switchable{
		entity = self,
		onStateChange = function(enabled)
			self.running = enabled
		end
	})
end

-- Advance the platform along its path and carry any standing riders by the
-- exact per-frame delta. Ordering is already correct: InGameState:update runs
-- map:update(dt) (ingame_state.lua:198) BEFORE world:update(dt) (line 199),
-- so the platform moves first and then nudges riders, and bump's own move()
-- of the player never fights the carry. When switched off, the platform
-- stops in place and simply tracks its current position; re-enabling resumes
-- from wherever it stopped (the stepper's distInLeg was preserved).
function MoverPlatform:update(dt)
	Entity.update(self, dt)

	if not self.stepper then
		-- no `path` property => stationary scenery; nothing to move
		return
	end

	if not self.running then
		self.prevPos = self.collider:getPositionV()
		return
	end

	local prevPos = self.prevPos or self.collider:getPositionV()
	local newPos = advance(self.stepper, self.speed * dt)
	local delta = newPos - prevPos

	self.collider:setPositionV(newPos)
	self.prevPos = newPos

	self:carryRiders(delta)
end

-- Delta-carry: every player whose feet are in the platform's top band and
-- overlapping horizontally (queryOverlap already restricts to colliders
-- intersecting the platform rect) is nudged by the exact platform delta -- no
-- slip, no eased follow. Feet below the top edge (mid-body riders are
-- impossible, but a player jumping up from below would pass the query before
-- crossing) are NOT carried.
function MoverPlatform:carryRiders(delta)
	if not world then
		return
	end
	if delta.x == 0 and delta.y == 0 then
		return
	end

	local bounds = self.collider:getBounds()
	local platTop = bounds.top

	-- The query rect must reach into the feet band, or a rider resting flush
	-- on top (player bottom == platTop, the exact rest pose bump leaves) would
	-- fail bump's strict rect-vs-rect intersection and never be found. Grow
	-- the top/bottom by RIDER_TOL so every candidate the feet-band check could
	-- accept is caught; the left/right edges stay the platform's own, so a
	-- player standing off the edge overlaps the query but fails the horizontal
	-- overlap against the real bounds below -- it only carries when it can
	-- actually push them.
	local query = {
		left = bounds.left,
		right = bounds.right,
		top = bounds.top - RIDER_TOL,
		bottom = bounds.bottom + RIDER_TOL,
	}
	local overlap = world:queryOverlap(query)

	for _, collider in ipairs(overlap) do
		local entity = collider.entity
		if entity and entity.type == 'player' then
			local feet = collider.y + collider.height
			local onTop = feet >= platTop - RIDER_TOL and feet <= platTop + RIDER_TOL
			-- horizontal overlap is not implied by the grown query: a player
			-- off the platform's edge passes the vertical band but not this
			local horizOverlap = collider.x < bounds.right and collider.x + collider.width > bounds.left
			if onTop and horizOverlap then
				collider:setPositionV(collider:getPositionV() + delta)
			end
		end
	end
end

-- White-box seam for tests/unit/ only: the pure path helpers above have no
-- reason to be public API (nothing outside this file calls them), but
-- exposing them here keeps their fast, precise, construction-free unit
-- coverage alongside the entity-level tests that exercise the whole
-- assembled MoverPlatform via tests/support/headless_bootstrap. Not for use
-- by production code -- reach for the real entity there.
MoverPlatform._internal = {
	polylineWaypoints = polylineWaypoints,
	applyDeckOffset = applyDeckOffset,
	buildLegs = buildLegs,
	newStepper = newStepper,
	advance = advance,
	RIDER_TOL = RIDER_TOL,
	LAND_TOL = LAND_TOL,
}

return MoverPlatform