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
-- No real sprite-sheet art exists for the beam (see res/img/entity_laser_
-- beam.png -- deliberately NOT created, per this slice's Gotchas: nothing
-- in this codebase can author real binary image data, and
-- src/entities/pressure_switch.lua already establishes the precedent of a
-- placeholder drawn straight from data rather than a loaded image). Instead
-- POWER_FRAMES below is a small authored Lua table of {width, color} --
-- driven by a bare Timeline (not a full Sprite/animation component, since
-- there is no image to cut into quads) via Timeline:getFrameIndex -- and
-- src/fx/laser_beam.lua draws a solid-colour stretched rectangle sized from
-- whichever frame the timeline currently indexes into. This satisfies "no
-- separate width/color computation" (the acceptance criterion is about not
-- procedurally lerping, not about requiring a real texture): the renderer
-- never computes a width or a colour itself, it only reads frame.width/
-- frame.color.
local LaserBeamResolver = require('src.entities.laser_beam_resolver')
local LaserBeam = require('src.fx.laser_beam')
local SpriteProps = require('src.entities.sprite_props')

local Laser = Class{__includes = Entity}

-- Thin red -> full ~half-tile white-hot-core/red-edge, authored directly as
-- data (see file header) -- frame 1 is the thin red beam the acceptance
-- criteria describe, the last frame is the fully "on" full-power look.
-- Widths are in px; 16px is half of the game's 32px tile.
local POWER_FRAMES = {
	{width = 2, color = {0.9, 0.1, 0.1}},
	{width = 5, color = {1, 0.25, 0.15}},
	{width = 9, color = {1, 0.45, 0.2}},
	{width = 13, color = {1, 0.7, 0.4}},
	{width = 16, color = {1, 0.95, 0.85}},
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
	if state == 'off' then
		if enabled then
			return 'warming'
		end
		return state
	end

	if state == 'warming' then
		if enabled then
			return state
		end
		return 'cooling'
	end

	if state == 'on' then
		if enabled then
			return state
		end
		return 'cooling'
	end

	-- cooling
	if enabled then
		return 'warming'
	end
	return state
end

-- Driven by the timeline's finish signal (fires at both the forward-end and
-- the reverse-start, src/components/timeline.lua) -- mirrors
-- src/entities/drawbridge.lua's nextStateOnAnimationFinish.
local function nextStateOnAnimationFinish(state)
	if state == 'warming' then
		return 'on'
	end
	if state == 'cooling' then
		return 'off'
	end
	return state
end

local function isFullyOn(state)
	return state == 'on'
end

-- The point on the emitter's own rect the beam departs from -- one edge per
-- direction, e.g. a floor-mounted laser (direction='up') fires from its TOP
-- edge, not its centre, so the beam visibly leaves the fixture rather than
-- punching out through its middle.
local function firingEdgePoint(rect, direction)
	local centreX = rect.x + rect.width * 0.5
	local centreY = rect.y + rect.height * 0.5
	if direction == 'up' then
		return centreX, rect.y
	elseif direction == 'down' then
		return centreX, rect.y + rect.height
	elseif direction == 'left' then
		return rect.x, centreY
	end
	return rect.x + rect.width, centreY -- 'right'
end

-- The far endpoint to cast toward: straight out to the map bounds in
-- `direction`, so a beam that hits nothing still terminates at the map edge
-- instead of casting to infinity.
local function farEndpoint(startX, startY, direction, mapWidth, mapHeight)
	if direction == 'up' then
		return startX, 0
	elseif direction == 'down' then
		return startX, mapHeight
	elseif direction == 'left' then
		return 0, startY
	end
	return mapWidth, startY -- 'right'
end

function Laser:init(object, map)
	Entity.init(self, object, 'laser')

	self.direction = (object.properties and object.properties.direction) or 'up'
	self.map = map

	-- Bottom-anchored, like every other gid-template entity (switch, key,
	-- blocker, ...): object.y is the mount's BOTTOM edge, so the rect's top
	-- sits one height above it (Rect.centreOfMapObject's convention, applied
	-- unconditionally the same way src/entities/switch.lua and
	-- src/entities/blocker.lua do rather than branching on object.gid --
	-- fixture-authored instances have no gid at all but are still authored
	-- bottom-anchored, matching a real Tiled placement).
	local topLeftY = object.y - object.height
	self.rect = Rect{x = object.x, y = topLeftY, width = object.width, height = object.height}
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
	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = 'static',
		sensor = true,
		position = position,
	})

	-- Spawn on/off state = the initial Switchable.enabled value. The
	-- callback only records the reading -- update() recomputes what the
	-- beam does fresh every frame from switchEnabled, the same discipline
	-- src/entities/blocker.lua follows.
	local spawnEnabled = true
	if object.properties and object.properties.enabled ~= nil then
		spawnEnabled = object.properties.enabled
	end
	self.switchEnabled = spawnEnabled
	self:addComponent(Switchable{
		entity = self,
		enabled = spawnEnabled,
		onStateChange = function(enabled)
			self.switchEnabled = enabled
		end
	})

	self.beamStart = Vector(0, 0)
	self.beamEnd = Vector(0, 0)
	self.beamHitEntity = nil
	-- Ordered {x1,y1,x2,y2} segments for the whole resolved (possibly
	-- mirror-bounced) path this frame, from the emitter outward -- see
	-- Laser:draw and src/fx/laser_beam.lua's drawSegments.
	self.beamSegments = {}

	-- Power state always starts 'off' regardless of spawnEnabled -- a
	-- laser authored enabled=true begins warming on its very first
	-- update rather than snapping straight to a held 'on' frame, so
	-- every laser (spawn-enabled or switch-enabled) goes through the
	-- same telegraph. See the file header for why this stays a bare
	-- Timeline rather than a full Sprite.
	self.powerState = 'off'
	self.powerTimeline = Timeline{
		duration = POWER_DURATION,
		finish = utils.bindSelf(self.onPowerAnimationFinish, self),
	}

	self.sound = self:addComponent(Sound{
		sounds = {
			powerup = 'res/snd/entity_laser_powerup.wav',
			powerdown = 'res/snd/entity_laser_powerdown.wav',
		}
	})
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

	if next == 'warming' then
		if self.powerState == 'cooling' then
			self.powerTimeline:reverseFromCurrent()
		else
			self.powerTimeline:playForward()
		end
		self.sound:play('powerup')
	elseif next == 'cooling' then
		if self.powerState == 'warming' then
			self.powerTimeline:reverseFromCurrent()
		else
			self.powerTimeline:playReverse()
		end
		self.sound:play('powerdown')
	end

	self.powerState = next
end

function Laser:currentPowerFrame()
	return POWER_FRAMES[self.powerTimeline:getFrameIndex(#POWER_FRAMES)]
end

function Laser:update(dt)
	Entity.update(self, dt)

	self.powerTimeline:update(dt)
	self:updatePowerState()

	if self.powerState == 'off' then
		self.beamHitEntity = nil
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
	self.beamSegments = result.segments

	-- Kill zones normally kill via an overlap query for isKillZone; a
	-- raycast beam has no such overlap to query, so the resolved hit's
	-- entity is killed directly through the same :die() method a kill zone
	-- would have called. Only acted on while fully 'on' -- warming/cooling
	-- still resolve the beam every frame (for rendering) but never kill/
	-- block/destroy/activate.
	if self:isFullyOn() then
		for _, killedEntity in ipairs(result.killed) do
			if killedEntity.die then
				killedEntity:die('laser')
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

	if self.powerState == 'off' then
		return
	end

	LaserBeam.drawSegments(self.beamSegments, self:currentPowerFrame())
end

-- White-box seam for tests/unit/laser_state_test.lua and a future
-- laser_test.lua; not for use by production code.
Laser._internal = {
	firingEdgePoint = firingEdgePoint,
	farEndpoint = farEndpoint,
	nextState = nextState,
	nextStateOnAnimationFinish = nextStateOnAnimationFinish,
	isFullyOn = isFullyOn,
	powerFrames = POWER_FRAMES,
	powerDuration = POWER_DURATION,
}

return Laser
