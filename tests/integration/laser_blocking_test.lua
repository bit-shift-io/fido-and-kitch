-- Beam blocking & destruction, driven through the real Game/Map/World/Entity
-- stack. See tests/unit/laser_beam_resolver_test.lua for the pure
-- hit-classification coverage this file doesn't repeat; this file covers
-- what only real physics/entity wiring can answer -- does a real push_box/
-- blocker/drawbridge/mover_platform/boulder collider actually stop (or, for
-- the boulder, get destroyed by) a real laser beam.
--
-- One fixture (tests/fixtures/laser_blocking_room.tmj) with one laser per
-- obstacle, each on its own horizontal row far enough apart vertically that
-- no beam can reach a row that isn't its own.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_blocking_room.tmj'

-- Comfortably past the laser's own power-up telegraph (POWER_DURATION =
-- 0.3s = 18 frames, src/entities/laser.lua) so the beam has had at least one
-- fully-on frame to resolve/act by the time each assertion runs.
local SETTLE_FRAMES = 25

test('a full-power beam stops (opaque) at a solid pushable prop', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_pushbox')
	local box = Queries.findEntityByName(map, 'box_target')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_pushbox')
	assertTrue(box ~= nil, 'expected the fixture to load box_target')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn(), 'expected the laser to have reached full power')
	assertTrue(laser.beamHitEntity == box, 'expected the beam to stop at the push_box')
end)

test('a full-power beam stops (opaque) at a locked (closed) blocker', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_blocker_closed')
	local blocker = Queries.findEntityByName(map, 'blocker_closed')
	assertTrue(blocker ~= nil, 'expected the fixture to load blocker_closed')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertEqual('closed', blocker.state)
	assertTrue(laser.beamHitEntity == blocker, 'expected the beam to stop at the closed blocker')
end)

test('an open blocker does not block the beam', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_blocker_open')
	local blocker = Queries.findEntityByName(map, 'blocker_open')
	assertTrue(blocker ~= nil, 'expected the fixture to load blocker_open')

	-- Drive the blocker's own Switchable directly, the same way
	-- laser_kill_test.lua drives the laser's -- no lever/switch entity is
	-- needed in the fixture just to flip this input. Blocker.OPENING_DURATION
	-- (1s = 60 frames) must fully elapse before the barrier's collider
	-- actually goes sensor=true (isBlocking(state) = state ~= 'open'), so
	-- budget well past both that and the laser's own warmup.
	blocker:getComponent(Switchable):switch({state = 'on'})
	FrameStepper.step(game, 90)

	assertEqual('open', blocker.state)
	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == nil, 'expected the beam to pass through the open blocker')
end)

test('a closed drawbridge (non-solid, exposed gap) does not block the beam', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_drawbridge_closed')
	local bridge = Queries.findEntityByName(map, 'drawbridge_closed')
	assertTrue(bridge ~= nil, 'expected the fixture to load drawbridge_closed')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertEqual('closed', bridge.state)
	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == nil, 'expected the beam to pass through the closed (gap-exposed) deck')
end)

test('a raised (solid) drawbridge deck blocks the beam', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_drawbridge_open')
	local bridge = Queries.findEntityByName(map, 'drawbridge_open')
	assertTrue(bridge ~= nil, 'expected the fixture to load drawbridge_open')

	-- Switching a drawbridge on sets state = 'opening' the same frame
	-- (Drawbridge's Switchable onStateChange calls self:setState('opening')
	-- immediately), and isDeckSolid('opening') is already true -- the deck
	-- is solid from that very frame, no need to wait out a telegraph.
	bridge:getComponent(Switchable):switch({state = 'on'})
	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(bridge.state == 'opening' or bridge.state == 'open')
	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == bridge, 'expected the beam to stop at the raised, solid deck')
end)

test('a full-power beam stops (opaque) at a solid moving-platform collider', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_platform')
	local platform = Queries.findEntityByName(map, 'platform_target')
	assertTrue(platform ~= nil, 'expected the fixture to load platform_target')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == platform, 'expected the beam to stop at the platform')
end)

test('a full-power beam destroys a boulder on contact and reaches past it the following frame', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_boulder')
	local boulder = Queries.findEntityByName(map, 'boulder_target')
	assertTrue(boulder ~= nil, 'expected the fixture to load boulder_target')

	-- Step one frame at a time up to the laser's first fully-on frame --
	-- the resolver already reports the boulder as the beam's stop point
	-- during warming (the beam is resolved every frame regardless of power
	-- state), but the boulder is only actually queueDestroy()'d once
	-- isFullyOn() gates that loop (src/entities/laser.lua).
	local frames = 0
	while not laser:isFullyOn() and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to reach full power within 40 frames')

	-- This same frame: the beam's segment stopped at the boulder (it was
	-- still physically present when querySegment ran) and queueDestroy
	-- flagged it -- entity.lua's contract is that queueDestroy is NOT
	-- instant, only the map's own entity-list update loop (a later pass
	-- within map:update, src/map/entity_factory.lua) actually removes/
	-- destroys it, which may land on this frame or the next depending on
	-- where the boulder falls relative to the laser in that pass's
	-- iteration order -- not a contract this test should pin down exactly.
	assertTrue(laser.beamHitEntity == boulder, 'expected the beam to stop at the boulder on contact')

	-- A handful more frames is comfortably past whichever pass actually
	-- removes it; once gone, a fresh re-cast (ADR 0006 -- never a stateful
	-- traveling projectile) reaches further right, since nothing else
	-- stands in that row.
	FrameStepper.step(game, 5)

	assertTrue(Queries.findEntityByName(map, 'boulder_target') == nil,
		'expected the boulder to have been removed from the map after its destroy was queued')
	assertTrue(laser.beamHitEntity == nil,
		'expected the beam to now pass straight through where the boulder used to be')
	assertTrue(laser.beamEnd.x > 900, 'expected the beam to have reached far past the boulder\'s former position')
end)
