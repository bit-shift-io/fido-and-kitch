-- Two tiers of coverage for src/entities/destructible_tile.lua, mirroring
-- tests/unit/laser_switch_test.lua's split:
--
-- 1. Entity-level: constructs a real DestructibleTile -- real Sprite, real
--    Collider, a real bump World -- confirming it is solid and matches its
--    authored object rect. There is no decision-helper tier (unlike
--    laser_switch's acceptsDirection): a destructible tile is purely
--    reactive, nothing here decides anything per frame.
-- 2. End-to-end against a real Laser (also entity-level, no fixture/Map
--    needed -- Laser only reaches for `self.map:getPixelSize()`, stubbed
--    below): a fully-on beam queues the tile's destruction, a warming beam
--    does not. This is the same generic gate src/entities/laser.lua
--    already applies to a boulder (see tests/integration/
--    laser_blocking_test.lua's boulder case) -- src/entities/
--    laser_beam_resolver.lua's isDestructible(entity) is the one thing this
--    slice actually changed, so these tests exercise it through the real
--    classification + the real (unchanged) Laser:update gate, rather than
--    re-testing the gate itself.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')

local DestructibleTile = require('src.entities.destructible_tile')
local Laser = require('src.entities.laser')

local function makeTile(x, y)
	return DestructibleTile({
		x = x, y = y, width = 32, height = 32,
		properties = {},
	})
end

-- Laser only reaches for map:getPixelSize() (to compute the far endpoint
-- when nothing stops the beam first) -- a bare stub stands in fine, no
-- real Map/World-registered tileset needed.
local fakeMap = {getPixelSize = function() return 1000, 1000 end}

local function makeLaser(direction)
	return Laser({
		x = 0, y = 32, width = 32, height = 32,
		properties = {direction = direction, enabled = true},
	}, fakeMap)
end

--
-- Part 1: entity-level construction
--

test('constructs headless with a real Sprite/Collider/World stack, solid, matching its object rect', function()
	HeadlessBootstrap.resetWorld()
	local tile = makeTile(300, 132)

	assertEqual('destructible_tile', tile.type)
	assertFalse(tile.collider:isSensor(), 'a destructible tile must be solid so it blocks the beam like any other opaque prop')
	assertEqual(32, tile.rect.width)
	assertEqual(32, tile.rect.height)
end)

--
-- Part 2: a real Laser's beam hitting a real DestructibleTile
--

test('a warming beam does not destroy a destructible tile in its path', function()
	HeadlessBootstrap.resetWorld()
	local laser = makeLaser('right')
	-- Same row as the laser's own firing height (laser rect: y=0..32,
	-- centre y=16 -- see src/entities/laser.lua's firingEdgePoint).
	local tile = makeTile(300, 32)

	laser:update(1 / 60) -- first frame: still warming, nowhere near POWER_DURATION (0.3s)

	assertFalse(laser:isFullyOn())
	assertTrue(tile.destroy_flag == nil, 'expected a warming beam to leave the tile intact')
end)

test('a fully-on beam destroys a destructible tile in its path', function()
	HeadlessBootstrap.resetWorld()
	local laser = makeLaser('right')
	local tile = makeTile(300, 32)

	-- Step well past POWER_DURATION (0.3s = 18 frames at 1/60) to reach the
	-- held 'on' state. tile:update ticks alongside laser:update, mirroring
	-- how the real map ticks every entity every frame -- this bare unit
	-- test has no map to do that for it.
	for _ = 1, 25 do
		laser:update(1 / 60)
		tile:update(1 / 60)
	end

	assertTrue(laser:isFullyOn(), 'expected the laser to have reached full power')
	assertTrue(laser.beamHitEntity == tile, 'expected the beam to stop at the tile on contact')
	assertTrue(tile.destroy_flag == nil, 'expected the tile to stay intact for DESTROY_DELAY of continuous contact before breaking')

	-- The tile only actually destroys once the fully-on beam has kept
	-- touching it continuously for DESTROY_DELAY (0.5s = 30 frames at 1/60)
	-- via its BeamContactDelay component -- comfortably clear that here.
	-- Both laser:update (marks contact) and tile:update (accumulates the
	-- component's elapsed timer) need ticking each frame, mirroring how the
	-- real map ticks every entity every frame -- this bare unit test has no
	-- map to do that for it.
	for _ = 1, 30 do
		laser:update(1 / 60)
		tile:update(1 / 60)
	end

	assertTrue(tile.destroy_flag, 'expected a fully-on beam held for DESTROY_DELAY to queue the tile for destruction')
end)

test('a fully-on beam that stops touching the tile before DESTROY_DELAY elapses never destroys it', function()
	HeadlessBootstrap.resetWorld()
	local laser = makeLaser('right')
	local tile = makeTile(300, 32)

	-- Reach fully-on and accumulate some (but not all) of DESTROY_DELAY's
	-- worth of continuous contact.
	for _ = 1, 25 do
		laser:update(1 / 60)
		tile:update(1 / 60)
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to have reached full power')
	assertTrue(laser.beamHitEntity == tile, 'expected the beam to stop at the tile on contact')
	assertTrue(tile.beamContactDelay.elapsed > 0, 'expected some contact time to have accumulated before the interruption')

	-- Power the laser off before DESTROY_DELAY elapses -- contact stops, so
	-- the component's elapsed timer resets instead of reaching the tile.
	laser:getComponent(Switchable):switch({state = 'off'})

	for _ = 1, 30 do
		laser:update(1 / 60)
		tile:update(1 / 60)
	end

	assertTrue(tile.destroy_flag == nil, 'expected interrupted beam contact to leave the tile intact')
	assertEqual(0, tile.beamContactDelay.elapsed, 'expected the contact timer to reset once contact stopped')
end)
