-- Laser emitter core: casts a single straight beam every frame from its
-- mounted firing edge in a fixed `direction`, and classifies what it hits
-- via the pure src/entities/laser_beam_resolver.lua module.
--
-- ADR 0006: the beam is an instant raycast, recomputed fresh every frame --
-- never a stateful travelling projectile -- so there is no beam state
-- carried between frames beyond the emitter's own on/off Switchable.
--
-- On/off input: exactly one, an optional `target`-following Switchable this
-- entity itself OWNS (DECISIONS.md, confirmed) -- mirrors
-- src/entities/blocker.lua's wiring. Spawn on/off = the initial Switchable
-- `enabled` value, read from the Tiled `enabled` property (default true);
-- no `target` wired to this laser elsewhere (a lever switch/pressure_switch/
-- timer_switch pointing its own `target` at this laser's object id) means
-- switchEnabled never changes from that spawn value.
--
-- Slice 04 (this slice) layers a Reversible-timeline-driven power state
-- machine on top: off -> warming (playing forward) -> on (held at the
-- timeline's last frame) -> cooling (reverseFromCurrent) -> off. Mirrors
-- src/entities/drawbridge.lua/blocker.lua's "recomputed fresh every frame,
-- no memory" discipline -- switchEnabled is the single live input, and
-- powerState is derived from it plus the timeline's own finish signal,
-- never stored as a separate flag that could drift.
--
-- Only 'on' (the held final frame) gates kill/block/destroy/activate --
-- see Laser:isFullyOn(), the single seam every later slice's interaction
-- code should read instead of re-deriving it from raw state strings. Both
-- 'warming' and 'cooling' are harmless but still visually/audibly present
-- (beamStart/beamEnd/beamHitEntity are still resolved every frame in every
-- state but 'off', for rendering -- ADR 0006: the beam is an instant
-- raycast, recomputed fresh every frame, regardless of power state).
--
-- The beam's art is res/img/fx/fx_laser_beam.png, a horizontally-tiling
-- energy strip, drawn as one scrolling-UV quad spanning the beam's current
-- length by src/fx/laser_beam.lua -- the beam samples the texture wrapped,
-- so the same pattern repeats along the beam and slides continuously as the
-- texture animates (no discrete copies, so nothing can pop in or out at a
-- tile boundary) -- this entity advances the scroll phase every update.
-- POWER_FRAMES below stays a small authored Lua table of {width, color} --
-- driven by a bare Timeline (not a full Sprite/animation component, since
-- the texture scrolls rather than switching frames) via
-- Timeline:getFrameIndex -- and src/fx/laser_beam.lua draws the texture
-- squished onto whichever frame's width the timeline currently indexes into.
-- This satisfies "no separate width/color computation" (the acceptance
-- criterion is about not procedurally lerping, not about requiring a real
-- texture): the renderer never computes a width or a colour itself, it only
-- reads frame.width/frame.color.
--
-- Visual head/tail animation (slice 05): the beam's visible extent is a
-- single scalar `beamExtent` (world px along the resolved polyline from
-- the emitter). The head grows at `LaserBeam.SCROLL_SPEED` px/s toward the
-- full resolved length; when the resolved path changes (mirror flip) the
-- previous path is retained as `beamPathState` and drains from its TAIL
-- (the mirror end, which stops getting laser energy) toward its HEAD (the
-- old far end), which stays put until the last moment, at 0 length then
-- destroyed. The new reflected beam grows head-first from the mirror at
-- the same speed. While the path is stable, the beam holds at full
-- length. Power-off triggers the same tail-drain on the current visible
-- beam, even after the instant raycast stops.
local LaserBeamResolver = require("src.entities.laser_beam_resolver")
local LaserBeam = require("src.fx.laser_beam")
local SpriteProps = require("src.entities.sprite_props")

local Laser = Class({ __includes = Entity })

-- Thin red -> full ~half-tile white-hot-core/red-edge, authored directly as
-- data (see file header) -- frame 1 is the thin red beam the acceptance
-- criteria describe, the last frame is the fully "on" full-power look.
-- Widths are in px; 16px is half of the game's 32px tile.
local POWER_FRAMES = {
	{ width = 2, color = { 0.9, 0.1, 0.1 } },
	{ width = 5, color = { 1, 0.25, 0.15 } },
	{ width = 9, color = { 1, 0.45, 0.2 } },
	{ width = 13, color = { 1, 0.7, 0.4 } },
	{ width = 16, color = { 1, 0.95, 0.85 } },
}

-- Symmetric telegraph: warming plays this many seconds forward before
-- holding at 'on'; cooling reverses over the same duration. A single
-- shared duration keeps reverseFromCurrent's flip-in-place exact -- an
-- interruption partway through one direction resumes at the same speed
-- going the other way, never snapping.
local POWER_DURATION = 0.3

-- The whole power state model, as one pure function of the live input --
-- the linked switch's reading -- recomputed fresh every frame, mirroring
-- src/entities/blocker.lua's nextState. No memory here on purpose.
local function nextState(state, enabled)
	if state == "off" then
		if enabled then
			return "warming"
		end
		return state
	end

	if state == "warming" then
		if enabled then
			return state
		end
		return "cooling"
	end

	if state == "on" then
		if enabled then
			return state
		end
		return "cooling"
	end

	-- cooling
	if enabled then
		return "warming"
	end
	return state
end

-- Driven by the timeline's finish signal (fires at both the forward-end and
-- the reverse-start, src/components/timeline.lua) -- mirrors
-- src/entities/drawbridge.lua's nextStateOnAnimationFinish.
local function nextStateOnAnimationFinish(state)
	if state == "warming" then
		return "on"
	end
	if state == "cooling" then
		return "off"
	end
	return state
end

local function isFullyOn(state)
	return state == "on"
end

-- World px of a single segment. Pure math so it stays unit-testable.
local function segmentLength(seg)
	local dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
	return math.sqrt(dx * dx + dy * dy)
end

-- Total world px of a path (ordered segments). Pure math so it stays
-- unit-testable.
local function pathLength(segments)
	local total = 0
	for _, seg in ipairs(segments) do
		total = total + segmentLength(seg)
	end
	return total
end

-- The point on the emitter's own rect the beam departs from -- one edge per
-- direction, e.g. a floor-mounted laser (direction='up') fires from its TOP
-- edge, not its centre, so the beam visibly leaves the fixture rather than
-- punching out through its middle.
local function firingEdgePoint(rect, direction)
	local centreX = rect.x + rect.width * 0.5
	local centreY = rect.y + rect.height * 0.5
	if direction == "up" then
		return centreX, rect.y
	elseif direction == "down" then
		return centreX, rect.y + rect.height
	elseif direction == "left" then
		return rect.x, centreY
	end
	return rect.x + rect.width, centreY -- 'right'
end

-- The far endpoint to cast toward: straight out to the map bounds in
-- `direction`, so a beam that hits nothing still terminates at the map edge
-- instead of casting to infinity.
local function farEndpoint(startX, startY, direction, mapWidth, mapHeight)
	if direction == "up" then
		return startX, 0
	elseif direction == "down" then
		return startX, mapHeight
	elseif direction == "left" then
		return 0, startY
	end
	return mapWidth, startY -- 'right'
end

function Laser:init(object, map)
	Entity.init(self, object, "laser")

	self.direction = (object.properties and object.properties.direction) or "up"
	self.map = map

	-- Bottom-anchored, like every other gid-template entity (switch, key,
	-- blocker, ...): object.y is the mount's BOTTOM edge, so the rect's top
	-- sits one height above it (Rect.centreOfMapObject's convention, applied
	-- unconditionally the same way src/entities/switch.lua and
	-- src/entities/blocker.lua do rather than branching on object.gid --
	-- fixture-authored instances have no gid at all but are still authored
	-- bottom-anchored, matching a real Tiled placement).
	local topLeftY = object.y - object.height
	self.rect = Rect({ x = object.x, y = topLeftY, width = object.width, height = object.height })
	local position = self.rect:centre()

	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = self.rect:colliderShapeArgs()
	self.sprite = self:addComponent(Sprite(spriteProps))

	-- A sensor: the emitter's own mount is a small fixture, not something the
	-- beam itself should be blocked by (the beam is resolved separately,
	-- straight through World:querySegmentWithCoords below, filtered to
	-- exclude this very collider), nor something solid a player could
	-- incorrectly stand on or collide with.
	self.collider = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = "static",
		sensor = true,
		position = position,
	}))

	-- Spawn on/off state = the initial Switchable.enabled value. The
	-- callback only records the reading -- update() recomputes what the
	-- beam does fresh every frame from switchEnabled, the same discipline
	-- src/entities/blocker.lua follows.
	local spawnEnabled = true
	if object.properties and object.properties.enabled ~= nil then
		spawnEnabled = object.properties.enabled
	end
	self.switchEnabled = spawnEnabled
	self:addComponent(Switchable({
		entity = self,
		enabled = spawnEnabled,
		onStateChange = function(enabled)
			self.switchEnabled = enabled
		end,
	}))

	self.beamStart = Vector(0, 0)
	self.beamEnd = Vector(0, 0)
	self.beamHitEntity = nil
	-- Ordered {x1,y1,x2,y2} segments for the whole resolved (possibly
	-- mirror-bounced) path this frame, from the emitter outward -- see
	-- Laser:draw and src/fx/laser_beam.lua's drawSegments.
	self.beamSegments = {}

	-- Visual length animation: three-part model.
	--   * baseExtent: distance from emitter along the shared prefix (emitter
	--     to mirror). Grows at SCROLL_SPEED until it reaches the mirror
	--     distance, then holds.
	--   * oldReflectedExtent: length of the old reflected beam (beyond the
	--     mirror) that retracts toward 0 at SCROLL_SPEED.
	--   * newReflectedExtent: length of the new reflected beam (beyond the
	--     mirror) that grows from 0 at SCROLL_SPEED toward its full length.
	-- When the path is stable (no mirror flip), we treat the whole beam as
	-- a single extent growing from the emitter (baseExtent = total length,
	-- reflected extents = 0).
	self.baseExtent = 0
	self.oldReflectedExtent = 0
	self.newReflectedExtent = 0
	self.baseSegments = nil        -- shared prefix segments (emitter -> mirror)
	self.oldReflectedSegments = nil
	self.newReflectedSegments = nil
	-- World length from the emitter to the mirror (the shared prefix),
	-- captured for the duration of a split (drain+growth). It is FIXED
	-- geometry from the mirror flip -- while the old beam drains, the
	-- mirror's position along the beam never changes -- so it must be
	-- stored, never recomputed from baseSegments: baseSegments is
	-- REPLACED by the full merged path when the new beam reaches its
	-- collision, and deriving the mirror offset from it would jump the
	-- still-draining old beam's UV window by the new reflected length.
	self.splitMirrorDist = 0
	self.prevPathHash = nil
	self.beamScrollPhase = 0

	-- Power state always starts 'off' regardless of spawnEnabled -- a
	-- laser authored enabled=true begins warming on its very first
	-- update rather than snapping straight to a held 'on' frame, so
	-- every laser (spawn-enabled or switch-enabled) goes through the
	-- same telegraph. See the file header for why this stays a bare
	-- Timeline rather than a full Sprite.
	self.powerState = "off"
	self.powerTimeline = Timeline({
		duration = POWER_DURATION,
		finish = utils.bindSelf(self.onPowerAnimationFinish, self),
	})

	self.sound = self:addComponent(Sound({
		sounds = {
			powerup = "res/snd/entity_laser_powerup.wav",
			powerdown = "res/snd/entity_laser_powerdown.wav",
		},
	}))
end

-- The single gate every interaction (kill/block/destroy/activate) reads --
-- not raw state strings. Only the held final frame is "full power".
function Laser:isFullyOn()
	return isFullyOn(self.powerState)
end

function Laser:onPowerAnimationFinish()
	self.powerState = nextStateOnAnimationFinish(self.powerState)
end

-- Recomputed fresh every frame from switchEnabled (never stored as a second
-- source of truth) -- mirrors src/entities/blocker.lua/drawbridge.lua.
-- Drives the timeline's direction on every transition edge, reversing in
-- place (not snapping) when interrupted mid-flight, and plays the power
-- sound exactly once per edge.
function Laser:updatePowerState()
	local next = nextState(self.powerState, self.switchEnabled)
	if next == self.powerState then
		return
	end

	if next == "warming" then
		if self.powerState == "cooling" then
			self.powerTimeline:reverseFromCurrent()
		else
			self.powerTimeline:playForward()
		end
		self.sound:play("powerup")
	elseif next == "cooling" then
		if self.powerState == "warming" then
			self.powerTimeline:reverseFromCurrent()
		else
			self.powerTimeline:playReverse()
		end
		self.sound:play("powerdown")
	end

	self.powerState = next
end

function Laser:currentPowerFrame()
	return POWER_FRAMES[self.powerTimeline:getFrameIndex(#POWER_FRAMES)]
end

-- Advances the visual length animation by `dt`.
-- When the resolved path changes (mirror flip), the old reflected
-- beam (beyond the mirror) drains from its tail -- the mirror end,
-- which no longer receives laser energy -- toward its old head, which
-- stays put until 0 length, then is destroyed. The new reflected beam
-- grows from the mirror outward at SCROLL_SPEED until its full resolved
-- length. The incident segment (emitter -> mirror) stays at the mirror
-- distance. While the path is stable, the beam simply grows from the
-- emitter to full length (baseExtent) and holds.
-- Simple path hash for change detection.
function Laser.pathHash(segments)
	local parts = {}
	for _, seg in ipairs(segments) do
		parts[#parts + 1] = string.format("%.6f,%.6f,%.6f,%.6f", seg.x1, seg.y1, seg.x2, seg.y2)
	end
	return table.concat(parts, "|")
end

function Laser:reconstructOldPath()
	if self.baseSegments and self.oldReflectedSegments then
		local out = {}
		for _, seg in ipairs(self.baseSegments) do table.insert(out, seg) end
		for _, seg in ipairs(self.oldReflectedSegments) do table.insert(out, seg) end
		return out
	end
	return self.beamSegments
end

function Laser:reconstructNewPath()
	if self.baseSegments and self.newReflectedSegments then
		local out = {}
		for _, seg in ipairs(self.baseSegments) do table.insert(out, seg) end
		for _, seg in ipairs(self.newReflectedSegments) do table.insert(out, seg) end
		return out
	end
	return self.beamSegments
end

function Laser:advanceBeamAnimation(dt, resolvedSegments)
	local prevHash = self.prevPathHash
	local curHash = Laser.pathHash(resolvedSegments)
	local changed = (prevHash ~= nil and prevHash ~= curHash)

	if changed then
		-- Path changed (mirror flip). Compute the shared prefix length
		-- (distance from emitter to mirror) and fix it for the whole
		-- split: the mirror point along the beam is constant geometry,
		-- and baseSegments may be replaced mid-drain by the merged path
		-- (see draw()), so the mirror offset must not be re-derived from
		-- it later.
		local oldPath = self.baseSegments and self.baseSegments or self.beamSegments
		local commonPrefixLen = LaserBeam.commonPrefixLength(oldPath, resolvedSegments)
		self.splitMirrorDist = commonPrefixLen

		-- Split both paths into shared prefix (base) and reflected suffixes.
		self.baseSegments = LaserBeam.clipSegmentsToLength(oldPath, commonPrefixLen)
		self.oldReflectedSegments = LaserBeam.suffixBeyond(oldPath, commonPrefixLen)
		self.newReflectedSegments = LaserBeam.suffixBeyond(resolvedSegments, commonPrefixLen)

		-- The incident part stays at the mirror distance (clamp baseExtent).
		local baseLen = pathLength(self.baseSegments)
		if self.baseExtent > baseLen then
			self.baseExtent = baseLen
		end

		-- Old reflected part: its current visible length is whatever was
		-- visible beyond the mirror. If we don't have it, assume full old
		-- reflected length.
		local oldReflectedTotal = pathLength(self.oldReflectedSegments)
		if self.oldReflectedExtent == 0 then
			self.oldReflectedExtent = oldReflectedTotal
		end

		-- New reflected part starts at the mirror (length 0) and will grow.
		self.newReflectedExtent = 0
		self.prevPathHash = curHash
	else
		-- Path is stable. Ensure baseSegments is set so the beam is drawn
		-- even before any path change occurs (e.g. on the first frame).
		if not self.baseSegments then
			self.baseSegments = resolvedSegments
			self.prevPathHash = curHash
		end
	end

	-- Update the resolved segments for drawing and collision.
	self.beamSegments = resolvedSegments

	-- Advance each part at SCROLL_SPEED.
	-- Base (emitter -> mirror): grow toward mirror distance, then hold.
	local baseLen = pathLength(self.baseSegments or resolvedSegments)
	if self.baseExtent < baseLen then
		self.baseExtent = math.min(baseLen, self.baseExtent + LaserBeam.SCROLL_SPEED * dt)
	end

	-- Old reflected: retract toward 0.
	if self.oldReflectedExtent > 0 then
		self.oldReflectedExtent = math.max(0, self.oldReflectedExtent - LaserBeam.SCROLL_SPEED * dt)
		if self.oldReflectedExtent <= 0 then
			self.oldReflectedSegments = nil
		end
	end

	-- New reflected: grow toward its full length.
	if self.newReflectedSegments then
		local newReflectedTotal = pathLength(self.newReflectedSegments)
		if self.newReflectedExtent < newReflectedTotal then
			self.newReflectedExtent = math.min(newReflectedTotal, self.newReflectedExtent + LaserBeam.SCROLL_SPEED * dt)
		end
		-- Once fully grown, merge into base and clear reflected.
		-- After setting baseSegments to the full resolved path, recompute
		-- baseExtent to match so the visible head doesn't jump back to the
		-- mirror distance on the next frame.  baseLen (computed above from
		-- the OLD baseSegments) equals only the mirror prefix; using it
		-- as-is would set baseExtent to the prefix length while draw()
		-- draws the full merged path, visibly shrinking the beam for one
		-- frame before it re-grows.
		if self.newReflectedExtent >= newReflectedTotal then
			self.baseSegments = resolvedSegments
			self.baseExtent = pathLength(resolvedSegments)
			self.newReflectedSegments = nil
			self.newReflectedExtent = 0
		end
	end
end

function Laser:update(dt)
	Entity.update(self, dt)

	self.beamScrollPhase = self.beamScrollPhase + dt
	self.powerTimeline:update(dt)
	self:updatePowerState()

	if self.powerState == "off" then
		self.beamHitEntity = nil
		-- Retract everything toward the emitter at SCROLL_SPEED.
		self:advanceBeamAnimation(dt, {})
		return
	end

	local startX, startY = firingEdgePoint(self.rect, self.direction)

	-- Never let the beam hit its own mount collider.
	local ownCollider = self.collider
	local function filter(item)
		return item ~= ownCollider
	end

	local function querySegmentFn(x1, y1, x2, y2)
		return world:querySegmentWithCoords(x1, y1, x2, y2, filter)
	end

	-- Pure function of a point + direction, no World/Map needed by the
	-- resolver itself (ADR 0006) -- it recomputes this fresh for every
	-- segment, including after a mirror bounce changes the direction.
	local function farEndpointFn(x, y, direction)
		local mapWidth, mapHeight = self.map:getPixelSize()
		return farEndpoint(x, y, direction, mapWidth, mapHeight)
	end

	local result = LaserBeamResolver.resolve(startX, startY, self.direction, farEndpointFn, querySegmentFn)

	self.beamStart.x, self.beamStart.y = startX, startY
	self.beamEnd.x, self.beamEnd.y = result.x, result.y
	self.beamHitEntity = result.hitEntity

	-- Visual length animation: the beam's visible front travels at the
	-- same speed as the texture scroll. When the resolved path changes
	-- (a mirror flip), the tail of the old beam -- the mirror end, which
	-- stops getting laser energy -- drains toward its old head at
	-- SCROLL_SPEED, the head staying put until the last moment, then is
	-- destroyed, while the head of the new beam grows from the mirror at
	-- SCROLL_SPEED until it reaches its full resolved length. The
	-- instant raycast above stays unchanged (ADR 0006: fresh every
	-- frame, no stateful travelling projectile) -- the animation is
	-- purely visual.
	self:advanceBeamAnimation(dt, result.segments)

	-- Kill zones normally kill via an overlap query for isKillZone; a
	-- raycast beam has no such overlap to query, so the resolved hit's
	-- entity is killed directly through the same :die() method a kill zone
	-- would have called. Only acted on while fully 'on' -- warming/cooling
	-- still resolve the beam every frame (for rendering) but never kill/
	-- block/destroy/activate.
	if self:isFullyOn() then
		for _, killedEntity in ipairs(result.killed) do
			if killedEntity.die then
				killedEntity:die("laser")
			end
		end

		-- Boulder/destructible-tile destruction is gated on sustained contact,
		-- not immediate on first touch: each isDestructible entity carries a
		-- BeamContactDelay component, and markContact() here just records
		-- "still touched this frame" -- the component's own update(dt) is
		-- what accumulates elapsed time and calls queueDestroy() once the
		-- delay is reached. queueDestroy() is NOT instant/synchronous even
		-- then -- it flags the entity, and the map's entity-list update loop
		-- is what actually removes it and calls :destroy() -- so a boulder
		-- hit this frame is still physically present (still in the bump
		-- world) until that later pass runs. This is why the beam's own
		-- resolved segment for THIS frame still stops at the boulder
		-- (LaserBeamResolver treats it as the stop point); the beam only
		-- reaches further on the next frame's fresh re-cast, once the
		-- boulder is actually gone.
		for _, destroyedEntity in ipairs(result.destroyed) do
			destroyedEntity.beamContactDelay:markContact()
		end

		-- A laser_switch decides its own active/inactive state fresh every
		-- frame (src/entities/laser_switch.lua) from whether it was validly
		-- hit THIS frame -- it never rays-casts itself, so this is the only
		-- way it finds out.
		for _, activatedEntity in ipairs(result.activated) do
			if activatedEntity.receiveValidHit then
				activatedEntity:receiveValidHit()
			end
		end
	end
end

function Laser:draw()
	Entity.draw(self)

	-- During 'off' with nothing drawn, nothing to draw.
	if self.powerState == "off" and self.baseExtent <= 0 and
	   self.oldReflectedExtent <= 0 and self.newReflectedExtent <= 0 then
		return
	end

	local frame = self:currentPowerFrame()
	local phase = self.beamScrollPhase

	-- Base segment (emitter -> mirror): draw up to baseExtent. The base
	-- starts the beam's UV ribbon at 0.
	if self.baseSegments and self.baseExtent > 0 then
		local clipped = LaserBeam.clipSegmentsToLength(self.baseSegments, self.baseExtent)
		if #clipped > 0 then
			LaserBeam.drawSegments(clipped, frame, phase)
		end
	end

	-- The new reflected part starts at the mirror (a fixed world point in
	-- the base chain), so its UV window continues from the top of the base
	-- -- the mirror's world length along the beam. Without this offset the
	-- reflected section's phase is wrong relative to the base the whole
	-- time it draws, and worse: the moment it merges into a single base
	-- chain (the new beam reaching its collision point), every texel on the
	-- reflected section -- including the head -- shifts by the mirror
	-- distance in one frame. That was the stutter/extra-texture at the head
	-- when the new beam lands.
	--
	-- The mirror offset is splitMirrorDist, the mirror's fixed world length
	-- captured when the split began -- NEVER re-derived from
	-- pathLength(baseSegments). At the merge baseSegments is swapped for
	-- the full merged path (mirror + new reflection), and deriving the
	-- offset from it would shift the still-draining old beam's window by
	-- the new reflected length in one frame: the old-beam skip when the
	-- new beam hits its collision. splitMirrorDist is geometry, not state:
	-- the mirror point along the beam does not move while the old beam
	-- drains, so it is stored once at the flip.
	local mirrorOffset = self.splitMirrorDist

	-- Old reflected segment (beyond the mirror in OLD direction): the old
	-- beam is no longer fed past the mirror, so it drains from its TAIL
	-- (the mirror end) toward its HEAD (the old far end), which stays put
	-- until the last moment. Drawn as the head-anchored trailing suffix of
	-- the old path (suffixToLength), never a front truncation -- clipping
	-- from the mirror would pull the old head backward, which a laser never
	-- does.
	--
	-- The UV window here must NOT start at the mirror: the drawn suffix's
	-- first segment is partial, sliced at the drain front, and that front
	-- advances every frame. Anchoring the window at the mirror makes the
	-- whole lit portion read texels as if it started at the mirror --
	-- an offset error equal to the drained distance -- which grows at the
	-- drain speed (the texture appears to scroll faster) and, because
	-- drawSegments re-accumulates the partial first segment's actual
	-- length, audibly/visibly re-anchors when the front crosses a segment
	-- joint (the jump). Anchoring at the drain front -- mirror distance
	-- plus the drained length -- keeps every texel mapped to its true
	-- world position along the beam, so the scroll runs at exactly the
	-- normal SCROLL_SPEED with no re-anchor anywhere. This also gives
	-- power-off the same true mapping: there the whole old beam drains as
	-- one "old" polyline starting at the emitter, and with an empty base
	-- this resolves to just the drained distance from the emitter.
	if self.oldReflectedSegments and self.oldReflectedExtent > 0 then
		local oldTotal = pathLength(self.oldReflectedSegments)
		local drained = oldTotal - self.oldReflectedExtent
		local oldOffset = mirrorOffset + drained
		local lit = LaserBeam.suffixToLength(self.oldReflectedSegments, self.oldReflectedExtent)
		if #lit > 0 then
			LaserBeam.drawSegments(lit, frame, phase, oldOffset)
		end
	end

	-- New reflected segment (beyond mirror in new direction): draw up to newReflectedExtent.
	if self.newReflectedSegments and self.newReflectedExtent > 0 then
		local clipped = LaserBeam.clipSegmentsToLength(self.newReflectedSegments, self.newReflectedExtent)
		if #clipped > 0 then
			LaserBeam.drawSegments(clipped, frame, phase, mirrorOffset)
		end
	end
end

Laser._internal = {
	firingEdgePoint = firingEdgePoint,
	farEndpoint = farEndpoint,
	nextState = nextState,
	nextStateOnAnimationFinish = nextStateOnAnimationFinish,
	isFullyOn = isFullyOn,
	powerFrames = POWER_FRAMES,
	powerDuration = POWER_DURATION,
	segmentLength = segmentLength,
	pathLength = pathLength,
	pathHash = Laser.pathHash,
}

return Laser