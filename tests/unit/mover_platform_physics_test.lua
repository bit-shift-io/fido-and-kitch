-- Behavioural physics tests for src/entities/mover_platform.lua: a headless
-- bump world (tests/support/headless_bootstrap) with a real constructed
-- MoverPlatform, a dynamic player collider, and the one-way colFilterFn --
-- jump up-through from below, landing/standing on the deck, exact-delta
-- rider carry, halted-platform rider support, and a regression check that
-- non-platform collision pairs still use the existing World.colFilter
-- defaults.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')

local MoverPlatform = require('src.entities.mover_platform')
local PlayerSensors = require('src.player.player_sensors')
local World = require('src.physics.bump.world')

-- A Tiled path object whose waypoints are already absolute (STI re-anchors
-- them in place): the first waypoint (100,100) is the DECK line -- the
-- platform rests with its collider centre 16px (half of 32) below it at
-- (100,116), so the 128x32 rect sits at top=100, bottom=132, left=36,
-- right=164 -- then travels to (300,100) on the +x leg.
local pathHandler = {
	id = 1,
	x = 100,
	y = 100,
	polyline = {
		{ x = 100, y = 100 },
		{ x = 300, y = 100 },
	},
}

local map = {
	getObjectById = function(_, id)
		return pathHandler
	end,
}

local function makePlatform(overrides)
	local props = {
		path = { id = 1 },
		speed = 100,
		endBehavior = 'pingpong',
		pause = 0,
	}
	for k, v in pairs(overrides or {}) do
		props[k] = v
	end
	return MoverPlatform({
		x = 0, y = 0, width = 128, height = 32,
		properties = props,
	}, map)
end

-- A bare dynamic player collider: 50x50 (matching src/player/player.lua),
-- tagged so the platform's colFilterFn and rider checks recognise it, and
-- given the real player's groupIndex (-1) so the default World.colFilter
-- rules behave exactly as they do in-game (terrain colliders stay nil).
local function makePlayer(centerX, centerY)
	local c = Collider{
		shape_type = 'rectangle',
		shape_arguments = { 50, 50 },
	}
	c.entity = { type = 'player' }
	c:setGroupIndex(-1)
	c:setPositionV(Vector(centerX, centerY))
	return c
end

local function feet(c)
	return c.y + c.height
end

-- A plain static slab as a contrasting solid: a player rising from below
-- should be stopped at its bottom face (proves the platform's pass-through is
-- its own one-way 'cross' rule, not a blanket 'everything crosses' leniency).
-- 50px tall with its bottom face at y=100: a 60px rise would land feet at 90
-- through the slab if the pair were cross-compatible, so a stop at 100 is the
-- signature of a genuine slide block.
local function makeSolidSlab()
	local c = Collider{
		shape_type = 'rectangle',
		shape_arguments = { 400, 50 },
		body_type = 'static',
	}
	c:setPositionV(Vector(200, 75)) -- top=50, bottom=100
	return c
end

--
-- one-way top-only collision
--

test('a player collider below the platform jumps straight up through it', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 90) -- feet = 115, clearly inside the pass-through zone (deck top 100)
	player:setGravityScale(0)
	player:setLinearVelocity(0, -2000)

	-- 20px of upward travel in one frame must cross the whole deck (top 100)
	player:worldUpdate(0.01)
	assertTrue(feet(player) < 100, 'player should have passed through to above the deck, feet=' .. feet(player))
	assertTrue(feet(player) > 80, 'player should be just above the deck, not miles clear')

	-- and keep rising, no longer blocked by the (now above) platform
	player:worldUpdate(0.01)
	assertTrue(feet(player) < 100, 'player should keep rising clear of the deck')
end)

test('a player below a plain solid is stopped (contrast: the pass-through is one-way, not global)', function()
	world = HeadlessBootstrap.resetWorld()
	makeSolidSlab() -- static slab, bottom face at y=100
	local player = makePlayer(100, 125) -- feet = 150, flush under the slab
	player:setGravityScale(0)
	player:setLinearVelocity(0, -2000)

	player:worldUpdate(0.03) -- a cross-compatible pair would rise 60px (feet to 90)
	assertNear(150, feet(player), 0.01, 'the solid slab should block any rise into it (feet stays at first contact)')
end)

test('falling onto the top lands and stands (ground query true)', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 40) -- feet = 65, above the deck, falling
	player:setLinearVelocity(0, 300)

	for _ = 1, 30 do
		player:worldUpdate(1 / 60)
	end

	assertNear(100, feet(player), 0.01, 'player should be resting on the deck')
	assertTrue(PlayerSensors.queryOnGround(world, player), 'a landed rider must report ground')
end)

--
-- rider delta-carry
--

test('a standing rider is carried by exactly the platform delta', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 75) -- resting on the deck (feet = 100 = top)

	local platBefore = p.collider:getPositionV()
	local playerBefore = player:getPositionV()

	p:update(0.5) -- speed 100 * 0.5s = 50px right

	local platAfter = p.collider:getPositionV()
	local playerAfter = player:getPositionV()
	local delta = platAfter - platBefore

	assertNear(50, delta.x, 0.001)
	assertNear(0, delta.y, 0.001)
	assertNear(playerBefore.x + delta.x, playerAfter.x, 0.001, 'rider should move with the platform')
	assertNear(playerBefore.y + delta.y, playerAfter.y, 0.001)
	assertNear(100, feet(player), 0.001, 'rider should stay flush on the deck while carried')
end)

test('a player whose feet are far below the deck is not carried', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 200) -- feet = 225, well under the platform

	p:update(0.5)

	assertNear(100, player:getPositionV().x, 0.001, 'deep-below player must not be dragged')
	assertNear(200, player:getPositionV().y, 0.001)
end)

test('a player standing fully off the platform edge is not dragged onto it', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	-- standing on terrain at deck height (feet = 100) well right of the path:
	-- the platform slides 50px right (to [86,214]) but never reaches the
	-- player at x=[275,325]
	local player = makePlayer(300, 75)

	p:update(0.5)

	assertNear(300, player:getPositionV().x, 0.001, 'off-path player must not be pulled onto the deck')
	assertNear(75, player:getPositionV().y, 0.001)
end)

--
-- halted platform
--

test('when the platform halts, the rider stays supported and the platform is still', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 75) -- feet = 100, flush on the deck top

	p:update(0.1) -- carry the rider 10px right first
	assertNear(110, p.collider:getPositionV().x, 0.001)
	assertNear(110, player:getPositionV().x, 0.001)

	p:getComponent(Switchable):switch({ state = 'off' }, nil)
	assertFalse(p.running, 'switch should stop the platform')

	local platPos = p.collider:getPositionV()

	for _ = 1, 30 do
		p:update(1 / 60)
		player:worldUpdate(1 / 60)
	end

	assertNear(platPos.x, p.collider:getPositionV().x, 0.001, 'halting platform must not move')
	assertNear(platPos.y, p.collider:getPositionV().y, 0.001)
	assertNear(platPos.x, player:getPositionV().x, 0.001, 'rider should keep their spot over the deck')
	assertNear(platPos.y - 16, feet(player), 0.001, 'rider should stay supported (feet on deck)')
	assertTrue(PlayerSensors.queryOnGround(world, player), 'rider should still report ground')
end)

--
-- regression: non-platform pairs keep the existing colFilter defaults
--

test('existing player vs plain-entity collision behaviour is unchanged', function()
	world = HeadlessBootstrap.resetWorld()
	local p = makePlatform()
	local player = makePlayer(100, 59)

	local terrain = Collider{ shape_arguments = { 50, 50 } }
	assertEqual('slide', World.colFilter(player, terrain), 'player vs plain terrain stays solid')

	terrain.entity = { type = 'entity' }
	assertEqual('cross', World.colFilter(player, terrain), 'player vs plain entity still passes through')

	local box = Collider{ shape_arguments = { 32, 32 } }
	box.entity = { type = 'pushable' }
	box:setGroupIndex(50) -- real pushables carry a non-nil groupIndex (PushableSupport)
	-- the platform's colFilterFn returns nil for non-players, so the default
	-- rules decide: pushables are solid against the platform
	assertEqual('slide', World.colFilter(box, p.collider), 'platform vs non-player falls through to defaults')
end)
