-- Pure unit tests for src/entities/laser_beam_resolver.lua, driven with fake
-- querySegmentFn/farEndpointFn doubles -- no World/Collider construction
-- needed (see the module header for why it stays pure).
local LaserBeamResolver = require('src.entities.laser_beam_resolver')

local START_X, START_Y = 100, 100
local DIRECTION = 'up' -- e.g. a floor-mounted laser firing 'up'

-- A straight-line far endpoint: 'up' goes to y=0, 'down'/'left'/'right'
-- extend far enough that no fixture obstacle sits past it. Mirrors what
-- src/entities/laser.lua's real farEndpoint/self.map:getPixelSize()
-- closure would produce, but as a plain pure function for these tests.
local function fakeFarEndpoint(x, y, direction)
	if direction == 'up' then
		return x, 0
	elseif direction == 'down' then
		return x, 1000
	elseif direction == 'left' then
		return 0, y
	end
	return 1000, y -- 'right'
end

test('beam reaches the far endpoint when the segment hits nothing', function()
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(START_X, result.x)
	assertEqual(0, result.y)
	assertTrue(result.hitEntity == nil, 'expected no stop entity when nothing was hit')
	assertEqual(0, #result.killed)
	assertEqual(1, #result.segments, 'expected exactly one segment for a straight unbounced beam')
end)

test('beam stops at the first opaque (non-sensor, non-fatal) hit', function()
	local wallEntity = {type = 'entity'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = wallEntity, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(100, result.x)
	assertEqual(40, result.y)
	assertTrue(result.hitEntity == wallEntity, 'expected the wall entity to be the stop entity')
	assertEqual(0, #result.killed)
end)

test('beam passes through a player hit and continues to the next opaque hit', function()
	local player = {type = 'player'}
	local wallEntity = {type = 'entity'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = player, sensor = false, x1 = 100, y1 = 70},
			{entity = wallEntity, sensor = false, x1 = 100, y1 = 20},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(100, result.x)
	assertEqual(20, result.y, 'expected the beam to stop at the wall, past the player')
	assertTrue(result.hitEntity == wallEntity)
	assertEqual(1, #result.killed)
	assertTrue(result.killed[1] == player, 'expected the player to be recorded as killed')
end)

test('beam passes through an enemy hit the same way it passes through a player', function()
	local enemy = {type = 'entity', isEnemy = true}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = enemy, sensor = false, x1 = 100, y1 = 70},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(START_X, result.x)
	assertEqual(0, result.y, 'expected the beam to reach the far endpoint, past the enemy')
	assertTrue(result.hitEntity == nil)
	assertEqual(1, #result.killed)
	assertTrue(result.killed[1] == enemy)
end)

test('beam ignores sensor colliders entirely -- neither stopped nor killed', function()
	local sensorEntity = {type = 'entity'}
	local wallEntity = {type = 'entity'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = sensorEntity, sensor = true, x1 = 100, y1 = 70},
			{entity = wallEntity, sensor = false, x1 = 100, y1 = 20},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == wallEntity)
	assertEqual(0, #result.killed)
end)

test('beam stops at a hit with no owning entity (plain terrain)', function()
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = nil, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(40, result.y)
	assertTrue(result.hitEntity == nil)
end)

-- Slice 05: generalization of "any non-sensor collider blocks" -- these
-- entity types need no new resolver logic, they should already pass against
-- the existing isFatal-only opaque-stop branch. One representative hit per
-- type, each already carrying `sensor = false` (its own toggle for its own
-- reasons -- open/closed, raised/lowered, moving/parked), proves the default
-- "anything else non-sensor is opaque" rule already covers them.
test('beam stops (opaque) at a solid push_box', function()
	local pushBox = {type = 'push_box'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = pushBox, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == pushBox, 'expected the push_box to stop the beam')
	assertEqual(0, #result.killed)
	assertEqual(0, #result.destroyed)
end)

test('beam stops (opaque) at a locked/opening blocker', function()
	local blocker = {type = 'blocker'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = blocker, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == blocker, 'expected the blocker to stop the beam')
	assertEqual(0, #result.destroyed)
end)

test('beam stops (opaque) at a solid drawbridge deck', function()
	local drawbridge = {type = 'drawbridge'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = drawbridge, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == drawbridge, 'expected the solid deck to stop the beam')
	assertEqual(0, #result.destroyed)
end)

test('beam stops (opaque) at a solid moving-platform collider', function()
	local platform = {type = 'mover_platform'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = platform, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == platform, 'expected the platform to stop the beam')
	assertEqual(0, #result.destroyed)
end)

-- The one genuinely new case slice 05 added: a boulder is destroyed AND
-- treated as this call's stop point -- unlike a fatal player/enemy hit, the
-- scan does not continue scanning past it looking for a further hit.
test('beam destroys a boulder on contact and stops there (does not continue past it)', function()
	local boulder = {type = 'boulder'}
	local wallEntity = {type = 'entity'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = boulder, sensor = false, x1 = 100, y1 = 70},
			{entity = wallEntity, sensor = false, x1 = 100, y1 = 20},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(100, result.x)
	assertEqual(70, result.y, 'expected the beam to stop at the boulder, not the wall past it')
	assertTrue(result.hitEntity == boulder, 'expected the boulder to be the stop entity for this call')
	assertEqual(0, #result.killed)
	assertEqual(1, #result.destroyed)
	assertTrue(result.destroyed[1] == boulder, 'expected the boulder to be recorded as destroyed')
end)

test('LaserBeamResolver._internal.isDestructible identifies boulders and destructible tiles', function()
	local isDestructible = LaserBeamResolver._internal.isDestructible
	assertTrue(isDestructible({type = 'boulder'}))
	assertTrue(isDestructible({type = 'destructible_tile'}))
	assertFalse(isDestructible({type = 'push_box'}))
	assertFalse(isDestructible(nil))
end)

--
-- Slice 07: laser_switch activation
--

test('LaserBeamResolver._internal.isLaserSwitch identifies only laser_switches', function()
	local isLaserSwitch = LaserBeamResolver._internal.isLaserSwitch
	assertTrue(isLaserSwitch({type = 'laser_switch'}))
	assertFalse(isLaserSwitch({type = 'push_box'}))
	assertFalse(isLaserSwitch(nil))
end)

test('beam stops (opaque) at a laser_switch hit from its accepted direction, and records it as activated', function()
	local switchEntity = {
		type = 'laser_switch',
		acceptsDirection = function(self, incomingDirection)
			assertEqual('up', incomingDirection)
			return true
		end,
	}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = switchEntity, sensor = false, x1 = 100, y1 = 40},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == switchEntity, 'expected the switch to stop the beam, same as any other solid obstacle')
	assertEqual(1, #result.activated)
	assertTrue(result.activated[1] == switchEntity)
end)

test('beam still stops (opaque) at a laser_switch hit from the WRONG direction, but does not record it as activated', function()
	local switchEntity = {
		type = 'laser_switch',
		acceptsDirection = function(self, incomingDirection)
			return false
		end,
	}
	local wallEntity = {type = 'entity'}
	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = switchEntity, sensor = false, x1 = 100, y1 = 40},
			{entity = wallEntity, sensor = false, x1 = 100, y1 = 20},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == switchEntity, 'expected the switch to still stop the beam even though it did not activate')
	assertEqual(0, #result.activated, 'expected a wrongly-directed hit to never be recorded as activated')
end)

--
-- Slice 06: mirror bounce recursion
--

test('LaserBeamResolver._internal.isMirror identifies only mirrors', function()
	local isMirror = LaserBeamResolver._internal.isMirror
	assertTrue(isMirror({type = 'mirror'}))
	assertFalse(isMirror({type = 'push_box'}))
	assertFalse(isMirror(nil))
end)

-- A single bounce: the beam travels 'up' into a mirror connected to
-- up/right, redirects 'right', and reaches a target placed to the right.
test('a beam bounced off one mirror reaches a target the straight beam could never reach', function()
	local mirror = {
		type = 'mirror',
		redirect = function(self, incomingDirection)
			assertEqual('up', incomingDirection, 'expected the beam to arrive travelling up')
			return 'right'
		end,
	}
	local target = {type = 'entity'}

	local function fakeQuerySegment(x1, y1, x2, y2)
		if y1 == START_Y and x1 == START_X and y2 == 0 then
			-- first segment: straight up, hits the mirror at (100, 50)
			return {
				{entity = mirror, sensor = false, x1 = 100, y1 = 50},
			}
		end
		if x1 == 100 and y1 == 50 and x2 == 1000 then
			-- second segment: bounced right from the mirror, hits the target
			return {
				{entity = target, sensor = false, x1 = 300, y1 = 50},
			}
		end
		return {}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(300, result.x)
	assertEqual(50, result.y)
	assertTrue(result.hitEntity == target, 'expected the beam to reach the target after bouncing')
	assertEqual(2, #result.segments, 'expected two segments: emitter->mirror and mirror->target')
	assertEqual(100, result.segments[1].x1)
	assertEqual(100, result.segments[1].y1)
	assertEqual(100, result.segments[1].x2)
	assertEqual(50, result.segments[1].y2)
	assertEqual(100, result.segments[2].x1)
	assertEqual(50, result.segments[2].y1)
	assertEqual(300, result.segments[2].x2)
	assertEqual(50, result.segments[2].y2)
end)

-- A beam arriving from a direction the mirror does NOT connect: entity:
-- redirect returns nil, and the mirror is opaque -- blocked, same as any
-- other obstacle, never reaching whatever might be behind it.
test('a beam hitting a wrongly-facing mirror is blocked at the mirror, not redirected', function()
	local mirror = {
		type = 'mirror',
		redirect = function(self, incomingDirection)
			return nil -- 'up' is not one of this mirror's two connected directions
		end,
	}

	local function fakeQuerySegment(x1, y1, x2, y2)
		return {
			{entity = mirror, sensor = false, x1 = 100, y1 = 50},
		}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertEqual(100, result.x)
	assertEqual(50, result.y)
	assertTrue(result.hitEntity == mirror, 'expected the mirror itself to be the stop entity')
	assertEqual(1, #result.segments, 'expected only the one segment up to the blocking mirror')
end)

-- A two-mirror chain: up -> right off mirror A, then right -> down off
-- mirror B, reaching a target below.
test('a beam bounces through a two-mirror chain to reach its target', function()
	local mirrorA = {
		type = 'mirror',
		redirect = function(self, incomingDirection)
			if incomingDirection == 'up' then return 'right' end
			return nil
		end,
	}
	local mirrorB = {
		type = 'mirror',
		redirect = function(self, incomingDirection)
			if incomingDirection == 'right' then return 'down' end
			return nil
		end,
	}
	local target = {type = 'entity'}

	local function fakeQuerySegment(x1, y1, x2, y2)
		if x1 == START_X and y1 == START_Y then
			return {{entity = mirrorA, sensor = false, x1 = 100, y1 = 50}}
		end
		if x1 == 100 and y1 == 50 and x2 == 1000 then
			return {{entity = mirrorB, sensor = false, x1 = 200, y1 = 50}}
		end
		if x1 == 200 and y1 == 50 and y2 == 1000 then
			return {{entity = target, sensor = false, x1 = 200, y1 = 300}}
		end
		return {}
	end

	local result = LaserBeamResolver.resolve(START_X, START_Y, DIRECTION, fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == target, 'expected the beam to chain through both mirrors to the target')
	assertEqual(200, result.x)
	assertEqual(300, result.y)
	assertEqual(3, #result.segments, 'expected three segments across the two-mirror chain')
end)

-- The bounce cap: a looping mirror pair must not hang or crash -- the beam
-- terminates once MAX_BOUNCES is reached, absorbed at whichever mirror it
-- was about to bounce off next.
test('a looping mirror pair terminates at the bounce cap instead of recursing forever', function()
	local mirrorA, mirrorB
	mirrorA = {
		type = 'mirror',
		redirect = function(self, incomingDirection) return 'right' end,
	}
	mirrorB = {
		type = 'mirror',
		redirect = function(self, incomingDirection) return 'left' end,
	}

	local function fakeQuerySegment(x1, y1, x2, y2)
		-- Ping-pong forever between two fixed points: A at x=100, B at
		-- x=200, regardless of direction -- a deliberate infinite loop if
		-- nothing capped it.
		if x2 > x1 then
			return {{entity = mirrorB, sensor = false, x1 = 200, y1 = 100}}
		else
			return {{entity = mirrorA, sensor = false, x1 = 100, y1 = 100}}
		end
	end

	local result = LaserBeamResolver.resolve(100, 100, 'right', fakeFarEndpoint, fakeQuerySegment)

	assertTrue(result.hitEntity == mirrorA or result.hitEntity == mirrorB,
		'expected the beam to stop, absorbed, at whichever mirror it hit at the cap')
	local maxBounces = LaserBeamResolver._internal.maxBounces
	assertEqual(maxBounces + 1, #result.segments,
		'expected exactly maxBounces + 1 segments before the beam gives up')
end)
