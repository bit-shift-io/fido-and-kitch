-- Pure module: resolves a laser beam's full raycast chain for a single
-- frame -- one straight segment per mirror bounce -- into an ordered list
-- of segments plus the entities killed/destroyed along the way.
--
-- Deliberately carries no World/Collider/Map knowledge (ADR 0006: a beam is
-- an instant raycast chain, recomputed fresh every frame -- never a
-- stateful travelling projectile) -- it takes a plain
-- `querySegmentFn(x1, y1, x2, y2)` double shaped like
-- World:querySegmentWithCoords's result (a nearest-first array of
-- `{entity=?, sensor=?, x1=, y1=, ...}` hits), so this module is fully
-- unit-testable without a real physics backend. It also takes a plain
-- `farEndpointFn(x, y, direction) -> x2, y2` double (a pure function of a
-- point + direction, no World/Map needed) instead of a fixed far endpoint,
-- because recursing through a mirror means computing a NEW far endpoint
-- after every bounce, in whatever new direction the mirror redirected into
-- -- see src/entities/laser.lua for the real closure it passes (over its
-- own farEndpoint local + self.map:getPixelSize()).
--
-- Classification, per the feature's cross-cutting constraints:
--   * a sensor collider is transparent to the beam -- it neither stops it
--     nor counts as a kill/destroy, so the scan just continues past it
--   * a player (`entity.type == 'player'`) or enemy (`entity.isEnemy`) is
--     fatal-and-continue: recorded in `killed`, and the scan keeps going
--     past it looking for the next hit
--   * a boulder (`entity.type == 'boulder'`) OR a destructible_tile
--     (`entity.type == 'destructible_tile'`) is destroyed-and-stop:
--     recorded in `destroyed`, AND treated as this segment's stop point
--     (x/y/hitEntity land on it) -- unlike a fatal hit, the scan does not
--     continue past it THIS frame. The entity is still physically present
--     until the caller (Laser:update) queues its destruction and the map's
--     entity-list update actually removes it, so next frame's fresh
--     re-cast is what reaches further, not this one (see
--     src/entities/laser.lua and the shared destroy-on-hit hook in
--     src/entities/boulder.lua / src/entities/destructible_tile.lua --
--     one classification branch here covers both, deliberately not two
--     parallel ones)
--   * a mirror (`entity.type == 'mirror'`) redirects the beam when the
--     incoming direction is one of its (current) two connected directions
--     -- see entity:redirect(incomingDirection) on src/entities/mirror.lua,
--     which owns all orientation/direction-pair knowledge so this module
--     never needs to know what the 4 orientation values mean. A new
--     segment is cast from the mirror's hit point in the outgoing
--     direction, up to MAX_BOUNCES times total; past the cap the beam
--     simply stops at that mirror (absorbed), guarding against an
--     infinite two-mirror ping-pong loop. When the incoming direction is
--     NOT one of the mirror's two connected directions, entity:redirect
--     returns nil and the mirror is opaque, same as any other obstacle.
--   * a laser_switch (`entity.type == 'laser_switch'`) is ALREADY opaque via
--     its own solid (non-sensor) collider -- this branch exists only to
--     record a valid-direction hit for activation purposes, via
--     entity:acceptsDirection(incomingDirection) (src/entities/
--     laser_switch.lua owns what "valid direction" means, mirroring the
--     mirror's :redirect delegation). A true result records the entity into
--     `activated`; either way the segment still stops here exactly like the
--     plain "anything else non-sensor" case below -- a laser_switch hit from
--     the WRONG direction is simply never added to `activated`, and falls
--     through with no other special handling.
--   * anything else non-sensor is the beam's opaque stop point -- terrain,
--     pushable props (push_box), locked/opening blockers, solid drawbridge
--     decks, moving-platform colliders all fall here by default, since
--     each already toggles its own collider's `sensor` state correctly for
--     its own reasons -- no per-entity-type resolver logic needed beyond
--     the boulder/mirror cases above
--   * nothing solid found before this segment's far endpoint: the beam
--     reaches that endpoint (the map bounds in the segment's direction),
--     with no stop entity
local LaserBeamResolver = {}

-- Hard cap on mirror bounces per beam, checked as a segment count (not a
-- mirror-visited-set) -- a two-mirror ping-pong loop must terminate on this
-- cap, not attempt cycle detection. Generous enough for any real level's
-- mirror chain, small enough to guarantee termination within one frame.
local MAX_BOUNCES = 8

local function isFatal(entity)
	return entity ~= nil and (entity.type == 'player' or entity.isEnemy == true)
end

local function isDestructible(entity)
	return entity ~= nil and (entity.type == 'boulder' or entity.type == 'destructible_tile')
end

local function isMirror(entity)
	return entity ~= nil and entity.type == 'mirror'
end

local function isLaserSwitch(entity)
	return entity ~= nil and entity.type == 'laser_switch'
end

-- Casts one straight segment from (x1, y1) in `direction`, recursing into a
-- new segment when it bounces off a mirror. `bounceCount` is how many
-- mirror bounces have already happened before this segment (0 for the
-- emitter's own first segment). `pivotEntity` is the mirror this segment's
-- OWN origin point was pivoted through (nil for the emitter's first
-- segment) -- see below for why it must be skipped, not just any other hit.
-- Appends exactly one entry to `segments` for this segment (from its start
-- to wherever it stops), and inserts directly into the shared
-- `killed`/`destroyed` arrays as it scans.
-- Returns {x, y, hitEntity} for this segment's own stop point.
local function castSegment(x1, y1, direction, farEndpointFn, querySegmentFn, bounceCount, segments, killed, destroyed, activated, pivotEntity)
	local x2, y2 = farEndpointFn(x1, y1, direction)
	local hits = querySegmentFn(x1, y1, x2, y2) or {}

	for _, hit in ipairs(hits) do
		-- A segment bounced off a mirror originates from THAT mirror's own
		-- centre (see the isMirror branch below), which sits INSIDE its own
		-- collider -- so the very next raycast, starting from a point its
		-- own bounding box contains, immediately re-touches that same
		-- mirror at (near) zero distance. Left unfiltered this burns through
		-- the whole bounce cap redirecting off the same mirror in place,
		-- never actually travelling. Skipping just this one entity (not
		-- every hit) still lets a beam legitimately re-cross a DIFFERENT
		-- mirror, or even loop back through this same one from outside its
		-- bounds later in a larger chain.
		if not (pivotEntity ~= nil and hit.entity == pivotEntity) and not hit.sensor then
			local entity = hit.entity

			if isFatal(entity) then
				table.insert(killed, entity)
			elseif isDestructible(entity) then
				table.insert(destroyed, entity)
				table.insert(segments, {x1 = x1, y1 = y1, x2 = hit.x1, y2 = hit.y1})
				return {x = hit.x1, y = hit.y1, hitEntity = entity}
			elseif isMirror(entity) then
				-- Bounce through the mirror's own centre, not the raw
				-- raycast entry point on its collider's edge. The entry
				-- point is wherever the incoming segment happens to cross
				-- the mirror's bounding box -- for a beam travelling
				-- straight up that's the mirror's TOP edge, half a tile
				-- above its centre, never its centre itself. Redirecting
				-- from there would send every subsequent segment travelling
				-- off the tile-grid line the rest of the beam (and every
				-- other mirror) is aligned to, so a second bounce could
				-- miss a correctly-placed mirror entirely. A mirror always
				-- redirects through its own middle, so pivoting there is
				-- what keeps the whole chain grid-aligned. Falls back to
				-- the raw hit point for a fake/test double with no
				-- getPosition, which the resolver still tolerates.
				local pivotX, pivotY = hit.x1, hit.y1
				if entity.getPosition then
					pivotX, pivotY = entity:getPosition()
				end

				table.insert(segments, {x1 = x1, y1 = y1, x2 = pivotX, y2 = pivotY})

				local outgoing = entity.redirect and entity:redirect(direction)
				if outgoing == nil then
					-- Not one of this mirror's two connected directions:
					-- opaque, same as any other obstacle.
					return {x = pivotX, y = pivotY, hitEntity = entity}
				end

				if bounceCount >= MAX_BOUNCES then
					-- Bounce cap reached: stop here, treated as absorbed.
					return {x = pivotX, y = pivotY, hitEntity = entity}
				end

				return castSegment(pivotX, pivotY, outgoing, farEndpointFn, querySegmentFn,
					bounceCount + 1, segments, killed, destroyed, activated, entity)
			elseif isLaserSwitch(entity) then
				table.insert(segments, {x1 = x1, y1 = y1, x2 = hit.x1, y2 = hit.y1})

				if entity.acceptsDirection and entity:acceptsDirection(direction) then
					table.insert(activated, entity)
				end

				return {x = hit.x1, y = hit.y1, hitEntity = entity}
			else
				table.insert(segments, {x1 = x1, y1 = y1, x2 = hit.x1, y2 = hit.y1})
				return {x = hit.x1, y = hit.y1, hitEntity = entity}
			end
		end
	end

	table.insert(segments, {x1 = x1, y1 = y1, x2 = x2, y2 = y2})
	return {x = x2, y = y2, hitEntity = nil}
end

-- x1, y1: beam origin (the emitter's firing edge).
-- direction: the beam's initial travel direction ('up'/'down'/'left'/
--            'right').
-- farEndpointFn(x, y, direction): pure function returning the far endpoint
--            to cast toward from (x, y) in `direction` (e.g. the map bound
--            in that direction) -- called fresh for every segment, since a
--            bounce changes both the origin and the direction.
-- querySegmentFn(x1, y1, x2, y2): returns a nearest-first array of hits,
--            each shaped like a World:querySegmentWithCoords entry.
--
-- Returns {x, y, hitEntity, killed, destroyed, segments}:
--   * x, y: the FINAL segment's resolved hit point (the stop point, or its
--     far endpoint if none)
--   * hitEntity: the entity that stopped the FINAL segment, or nil if it
--     reached its far endpoint
--   * killed: array of every player/enemy entity the beam passed through,
--     across every segment
--   * destroyed: array of every boulder/destructible_tile the beam hit
--     this frame, across every segment (0 or 1 -- either is always its
--     segment's stop point, so nothing past it can also be recorded)
--   * activated: array of every laser_switch the beam hit THIS frame from
--     its own accepted direction (0 or 1 -- a laser_switch is always its
--     segment's stop point, being solid, so nothing past it can also be
--     recorded). A laser_switch hit from the wrong direction is NOT
--     included here, even though it still stopped the beam.
--   * segments: ordered array of every straight segment cast this frame,
--     from the emitter outward, each {x1, y1, x2, y2} -- for rendering the
--     whole bent path
function LaserBeamResolver.resolve(x1, y1, direction, farEndpointFn, querySegmentFn)
	local segments = {}
	local killed = {}
	local destroyed = {}
	local activated = {}

	local final = castSegment(x1, y1, direction, farEndpointFn, querySegmentFn, 0, segments, killed, destroyed, activated)

	return {
		x = final.x,
		y = final.y,
		hitEntity = final.hitEntity,
		killed = killed,
		destroyed = destroyed,
		activated = activated,
		segments = segments,
	}
end

-- White-box seam for tests/unit/laser_beam_resolver_test.lua only.
LaserBeamResolver._internal = {
	isFatal = isFatal,
	isDestructible = isDestructible,
	isMirror = isMirror,
	isLaserSwitch = isLaserSwitch,
	maxBounces = MAX_BOUNCES,
}

return LaserBeamResolver
