-- End-to-end coverage for src/entities/destructible_tile.lua, mirroring
-- tests/integration/laser_blocking_test.lua's boulder case (the closest
-- existing precedent: a fully-on beam destroys a solid obstacle and
-- reaches further afterward) -- real Game/Map/World/Entity stack, one
-- fixture (tests/fixtures/laser_destructible_tile_room.tmj) with a laser
-- aimed down a corridor blocked by a destructible tile, with a plain solid
-- blocker further along the same row standing in for "whatever is behind
-- it" -- proving the beam actually opens a path through, not just that the
-- tile itself is gone.
--
-- The unit-level split (a fully-on beam destroys, a warming beam does not)
-- is covered by tests/unit/destructible_tile_test.lua against a real Laser
-- + real DestructibleTile with no fixture/Map needed; this file is the one
-- that proves the real bump-World collider wiring and the map's own
-- entity-list removal pass actually deliver that behaviour end-to-end.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_destructible_tile_room.tmj'

test('a full-power beam destroys a destructible tile blocking a corridor and reaches the wall behind it', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_tile')
	local tile = Queries.findEntityByName(map, 'tile_target')
	local wallBehind = Queries.findEntityByName(map, 'wall_behind')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_tile')
	assertTrue(tile ~= nil, 'expected the fixture to load tile_target')
	assertTrue(wallBehind ~= nil, 'expected the fixture to load wall_behind')

	-- Step one frame at a time up to the laser's first fully-on frame,
	-- mirroring the boulder test's own reasoning: the resolver already
	-- reports the tile as the beam's stop point while warming, but it is
	-- only actually queueDestroy()'d once isFullyOn() gates that loop
	-- (src/entities/laser.lua).
	local frames = 0
	while not laser:isFullyOn() and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to reach full power within 40 frames')

	assertTrue(laser.beamHitEntity == tile, 'expected the beam to stop at the destructible tile on contact')
	assertTrue(laser.beamHitEntity ~= wallBehind, 'expected the wall behind to still be unreached while the tile blocks the corridor')

	-- The tile only actually queues its own destruction once a fully-on beam
	-- has touched it continuously for DESTROY_DELAY (0.5s = 30 frames at
	-- 1/60, src/entities/destructible_tile.lua's BeamContactDelay wiring) --
	-- step comfortably past that, then a further handful of frames since
	-- queueDestroy() is not instant (src/entity.lua) and the map's own
	-- entity-list update pass is what actually removes the tile.
	FrameStepper.step(game, 35)

	assertTrue(Queries.findEntityByName(map, 'tile_target') == nil,
		'expected the destructible tile to have been removed from the map after its destroy was queued')
	assertTrue(laser.beamHitEntity == wallBehind,
		'expected the beam to now reach past the destroyed tile and stop at the wall behind it')
end)
