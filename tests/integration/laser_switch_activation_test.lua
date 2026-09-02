-- laser_switch activation, driven through the real Game/Map/World/Entity
-- stack. See tests/unit/laser_switch_test.lua for the switch's own pure/
-- entity-level activation logic in isolation, and
-- tests/unit/laser_beam_resolver_test.lua for the resolver's own
-- isLaserSwitch classification with fake doubles; this file covers what
-- only real physics/entity wiring can answer -- does a real laser beam
-- actually drive a real laser_switch, which drives a real blocker, across
-- real frames.
--
-- One fixture (tests/fixtures/laser_switch_room.tmj) with four independent
-- rows, each laser/switch/blocker triple on its own y row far enough apart
-- that no row's beam can reach another row's objects.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_switch_room.tmj'

-- Comfortably past the laser's own power-up telegraph (POWER_DURATION =
-- 0.3s = 18 frames, src/entities/laser.lua) so the beam has had several
-- fully-on frames to resolve/act by the time each assertion runs -- and past
-- Blocker's own OPENING_DURATION (1s = 60 frames, src/entities/blocker.lua)
-- so a switch that activated has had time to actually raise the barrier.
local SETTLE_FRAMES = 90

test('a laser correctly aimed at a laser_switch activates it, drives its blocker open, and absorbs the beam', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_ok')
	local switch = Queries.findEntityByName(map, 'switch_ok')
	local blocker = Queries.findEntityByName(map, 'blocker_ok')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_ok')
	assertTrue(switch ~= nil, 'expected the fixture to load switch_ok')
	assertTrue(blocker ~= nil, 'expected the fixture to load blocker_ok')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn(), 'expected the laser to have reached full power')
	assertTrue(switch:isActive(), 'expected the correctly-aimed switch to be active')
	assertTrue(laser.beamHitEntity == switch, 'expected the beam to stop (absorbed) at the switch, never reaching anything behind it')
	assertEqual('open', blocker.state, 'expected the activated switch to have opened its linked blocker')
end)

test('a beam hitting the switch from the wrong direction never activates it, leaving the blocker closed', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_wrongdir')
	local switch = Queries.findEntityByName(map, 'switch_wrongdir')
	local blocker = Queries.findEntityByName(map, 'blocker_wrongdir')
	assertTrue(switch ~= nil, 'expected the fixture to load switch_wrongdir')
	assertTrue(blocker ~= nil, 'expected the fixture to load blocker_wrongdir')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == switch, 'expected the beam to still stop at the switch -- it is solid regardless of direction')
	assertFalse(switch:isActive(), 'expected the wrongly-facing hit to never activate the switch')
	assertEqual('closed', blocker.state, 'expected the blocker to remain closed with the switch never activated')
end)

test('a laser that misses the switch tile entirely never activates it, leaving the blocker closed', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_missed')
	local switch = Queries.findEntityByName(map, 'switch_missed')
	local blocker = Queries.findEntityByName(map, 'blocker_missed')
	assertTrue(switch ~= nil, 'expected the fixture to load switch_missed')
	assertTrue(blocker ~= nil, 'expected the fixture to load blocker_missed')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == nil, 'expected the beam to reach its far endpoint, never touching the off-row switch')
	assertFalse(switch:isActive())
	assertEqual('closed', blocker.state)
end)

test('the switch deactivates once the valid hit stops, recomputed fresh rather than latched', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_toggle')
	local switch = Queries.findEntityByName(map, 'switch_toggle')
	assertTrue(switch ~= nil, 'expected the fixture to load switch_toggle')

	FrameStepper.step(game, SETTLE_FRAMES)
	assertTrue(laser:isFullyOn())
	assertTrue(switch:isActive(), 'expected the switch to be active while the valid hit continues')

	-- Force the beam off the same way laser_kill_test.lua does -- no lever
	-- entity is needed in the fixture just to flip this input.
	laser:getComponent(Switchable):switch({state = 'off'})
	FrameStepper.step(game, SETTLE_FRAMES)

	assertFalse(switch:isActive(), 'expected the switch to deactivate once the beam stopped validly hitting it')
end)
