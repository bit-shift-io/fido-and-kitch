-- End-to-end coverage for the optional `chainBreak` cascade on
-- src/entities/destructible_tile.lua, using a real Game/Map/World/Entity
-- stack (tests/fixtures/laser_destructible_chain_room.tmj), mirroring
-- tests/integration/laser_destructible_tile_test.lua's own "step to
-- fully-on, then step the removal pass" shape but for a multi-hop chain
-- rather than a single tile.
--
-- Fixture layout (32px tiles, tile-grid coordinates in brackets):
--   laser_tile (x=0,y=32) fires right along row y=32, the ONLY row any
--   cascade-related fixture object sits in -- every neighbor below is on a
--   different row so the beam itself can never reach it directly, only the
--   cascade timer can (otherwise a tile sitting further along the beam's own
--   path would get destroyed by the beam continuing through, not by the
--   chain, and the test would prove nothing about the cascade).
--
--   tile_chain_a (x=288,y=32) [9,0] -- the only tile actually hit by the
--   beam, chainBreak enabled.
--
--   A plus-shape around it, one arm per case this slice cares about:
--     tile_cross_north (x=288,y=0) [9,-1] -- orthogonal to A, no chainBreak
--       of its own: force-destroyed in A's cascade hop, never propagates.
--     tile_diagonal_untouched (x=256,y=0) [8,-1] -- diagonal to A (and only
--       orthogonal to tile_cross_north, which never cascades since it has no
--       chainBreak) -- must never be touched.
--     tile_chain_b (x=288,y=64) [9,1] -- orthogonal to A, chainBreak
--       enabled: force-destroyed in A's cascade hop, then schedules its OWN
--       cascade for its own neighbors purely by going through the same
--       destroy() override a second time.
--     tile_chain_c_capped (x=288,y=96) [9,2] -- orthogonal to B, force-
--       destroyed in B's cascade hop, no chainBreak of its own: must never
--       propagate further.
--     tile_beyond_capped (x=288,y=128) [9,3] -- orthogonal to C; must
--       survive since C never schedules a cascade.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_destructible_chain_room.tmj'

test('a chainBreak tile destroyed by a beam cascades hop-by-hop through the chain, sparing diagonals and stopping at a capped tile', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_tile')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_tile')
	assertTrue(Queries.findEntityByName(map, 'tile_chain_a') ~= nil, 'expected the fixture to load tile_chain_a')
	assertTrue(Queries.findEntityByName(map, 'tile_chain_b') ~= nil, 'expected the fixture to load tile_chain_b')
	assertTrue(Queries.findEntityByName(map, 'tile_chain_c_capped') ~= nil, 'expected the fixture to load tile_chain_c_capped')
	assertTrue(Queries.findEntityByName(map, 'tile_beyond_capped') ~= nil, 'expected the fixture to load tile_beyond_capped')
	assertTrue(Queries.findEntityByName(map, 'tile_cross_north') ~= nil, 'expected the fixture to load tile_cross_north')
	assertTrue(Queries.findEntityByName(map, 'tile_diagonal_untouched') ~= nil, 'expected the fixture to load tile_diagonal_untouched')

	-- Step to the laser's first fully-on frame (mirrors
	-- laser_destructible_tile_test.lua's own reasoning).
	local frames = 0
	while not laser:isFullyOn() and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to reach full power within 40 frames')

	-- tile_chain_a only actually queues its own destruction once the fully-on
	-- beam has touched it continuously for DESTROY_DELAY (0.5s = 30 frames at
	-- 1/60, src/entities/destructible_tile.lua's BeamContactDelay wiring);
	-- queueDestroy() is then not instant -- the map's own entity-list update
	-- pass is what actually calls tile_chain_a:destroy(), which is what
	-- schedules its cascade timer. Step one frame at a time (rather than a
	-- fixed batch) so the "short of the ~0.1s delay" check right below starts
	-- counting from the exact frame the cascade timer was actually
	-- registered on, not from some arbitrary later point. Cap raised to
	-- comfortably clear DESTROY_DELAY plus the removal pass.
	frames = 0
	while Queries.findEntityByName(map, 'tile_chain_a') ~= nil and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(Queries.findEntityByName(map, 'tile_chain_a') == nil,
		'expected the directly-hit chainBreak tile to have been destroyed')

	-- The delay must be observable: well short of CHAIN_DELAY (0.5s = 30
	-- frames; 3 frames =~ 0.05s since the destroy above), none of the cascade
	-- neighbors have been force-destroyed yet.
	FrameStepper.step(game, 3)
	assertTrue(Queries.findEntityByName(map, 'tile_chain_b') ~= nil,
		'expected the first-hop neighbor to still be intact before the ~0.5s delay elapses')
	assertTrue(Queries.findEntityByName(map, 'tile_cross_north') ~= nil,
		'expected the cross neighbor to still be intact before the ~0.5s delay elapses')

	-- Comfortably past the ~0.5s (30-frame) delay plus the map's own removal
	-- pass for the neighbors it force-destroys.
	FrameStepper.step(game, 35)
	assertTrue(Queries.findEntityByName(map, 'tile_chain_b') == nil,
		'expected the orthogonal chainBreak neighbor to have been force-destroyed by tile_chain_a\'s cascade')
	assertTrue(Queries.findEntityByName(map, 'tile_cross_north') == nil,
		'expected the orthogonal non-chainBreak neighbor to have been force-destroyed too -- force-destroy ignores its own setting')
	assertTrue(Queries.findEntityByName(map, 'tile_diagonal_untouched') ~= nil,
		'expected the diagonal tile to never be affected')

	-- tile_chain_b was itself chainBreak-enabled, so being force-destroyed
	-- schedules its OWN cascade timer for its OWN neighbors -- no special
	-- recursion code, just the same destroy() override firing again. Give
	-- that second ~0.5s hop the same comfortable margin.
	FrameStepper.step(game, 35)
	assertTrue(Queries.findEntityByName(map, 'tile_chain_c_capped') == nil,
		'expected the second-hop neighbor to have been force-destroyed by tile_chain_b\'s own cascade')

	-- tile_chain_c_capped has no chainBreak of its own, so its destruction
	-- must never schedule a third hop -- give it the same generous window a
	-- real third hop would have needed, and confirm nothing past it moved.
	FrameStepper.step(game, 35)
	assertTrue(Queries.findEntityByName(map, 'tile_beyond_capped') ~= nil,
		'expected the tile beyond the capped tile to survive, isolated from anything past it')
	assertTrue(Queries.findEntityByName(map, 'tile_diagonal_untouched') ~= nil,
		'expected the diagonal tile to still be untouched at the end')
end)
