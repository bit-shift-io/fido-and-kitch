-- Mirror bounce/redirect/switch-rotation, driven through the real
-- Game/Map/World/Entity stack. See tests/unit/laser_beam_resolver_test.lua
-- for the pure recursion/bounce-cap coverage this file doesn't repeat, and
-- tests/unit/mirror_test.lua for the mirror's own rotation-cycle/redirect
-- logic in isolation. This file covers what only real physics/entity
-- wiring can answer: does a real mirror collider actually redirect (or
-- block) a real laser beam, and does a real lever switch actually rotate
-- a real mirror mid-beam.
--
-- One fixture (tests/fixtures/laser_mirror_room.tmj) with three independent
-- rows, each laser/mirror pair on its own x column past the bounce so no
-- row's redirected beam can cross another row's objects.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_mirror_room.tmj'

-- Comfortably past the laser's own power-up telegraph (POWER_DURATION =
-- 0.3s = 18 frames, src/entities/laser.lua) so the beam has had at least
-- one fully-on frame to resolve/act by the time each assertion runs.
local SETTLE_FRAMES = 25

test('a laser bent around a corner by one mirror destroys a boulder a straight beam could never reach', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_bounce')
	local mirror = Queries.findEntityByName(map, 'mirror_bounce')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_bounce')
	assertTrue(mirror ~= nil, 'expected the fixture to load mirror_bounce')
	assertTrue(Queries.findEntityByName(map, 'boulder_bounce_target') ~= nil,
		'expected the fixture to load boulder_bounce_target before the beam reaches it')

	-- Step one frame at a time up to the laser's first fully-on frame, then
	-- a handful more -- the same two-phase pattern
	-- laser_blocking_test.lua's boulder case uses, since queueDestroy is
	-- not instant (src/entity.lua).
	local frames = 0
	while not laser:isFullyOn() and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to reach full power within 40 frames')

	FrameStepper.step(game, 5)

	assertTrue(Queries.findEntityByName(map, 'boulder_bounce_target') == nil,
		'expected the bounced beam to have destroyed the boulder behind the corner')
end)

test('a beam hitting a wrongly-facing mirror is blocked at the mirror, never reaching the boulder behind it', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_wrong')
	local mirror = Queries.findEntityByName(map, 'mirror_wrong')
	assertTrue(mirror ~= nil, 'expected the fixture to load mirror_wrong')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn())
	assertTrue(laser.beamHitEntity == mirror, 'expected the beam to stop (opaque) at the wrongly-facing mirror')
	assertTrue(Queries.findEntityByName(map, 'boulder_beyond') ~= nil,
		'expected the boulder behind the blocking mirror to remain untouched')
end)

test('a lever switch linked to a mirror rotates it mid-beam, changing which target the same laser hits', function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByName(map, 'laser_switchable')
	local mirror = Queries.findEntityByName(map, 'mirror_switchable')
	local targetUp = Queries.findEntityByName(map, 'blocker_up')
	local targetDown = Queries.findEntityByName(map, 'blocker_down')
	local lever = Queries.findEntityByName(map, 'mirror_lever')
	assertTrue(mirror ~= nil, 'expected the fixture to load mirror_switchable')
	assertTrue(targetUp ~= nil, 'expected the fixture to load blocker_up')
	assertTrue(targetDown ~= nil, 'expected the fixture to load blocker_down')
	assertTrue(lever ~= nil, 'expected the fixture to load mirror_lever')

	FrameStepper.step(game, SETTLE_FRAMES)

	assertTrue(laser:isFullyOn())
	assertEqual('up-right', mirror.orientation, 'expected the mirror to still be at its authored orientation')
	assertTrue(laser.beamHitEntity == targetUp, 'expected the beam to redirect up into the first target')

	-- The lever's own switch toggles on/off/on/off each press -- one use
	-- flips it 'on', which is the only transition that rotates the mirror
	-- (src/entities/mirror.lua's onStateChange ignores the 'off' edge).
	lever:use(nil)
	FrameStepper.step(game, SETTLE_FRAMES)

	assertEqual('down-right', mirror.orientation, 'expected one "on" activation to rotate the mirror 90 degrees clockwise')
	assertTrue(laser.beamHitEntity == targetDown,
		'expected the same beam to now redirect down into the second target after the mirror rotated')
end)
