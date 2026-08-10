-- Replicator behavior driven through the real Game/Map/World stack: it drops
-- a push_box every `interval` seconds, the boxes fall under gravity and land
-- on the floor, and the linked lever switch stops and restarts the spawning.
-- The fixture's replicator (top-anchored mock objects with no gid) spawns
-- boxes whose centre starts exactly at the machine's hover point (y=48) and
-- falls 96px onto the floor top (y=160), where a 32px box rests at y=144.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/replicator_room.lua'

-- A 32px box resting on the floor (top y=160) has its centre at y=144.
local BOX_RESTING_Y = 144

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function findReplicator()
	return Queries.findEntityByType(map, 'replicator')
end

local function findBoxes()
	return Queries.findEntitiesByType(map, 'push_box')
end

test('the replicator drops a push_box every interval and it lands on the floor', function()
	local game = GameHarness.startGame(MAP)
	local replicator = findReplicator()
	assertEqual('replicator', replicator.type)

	-- interval is 1.0s: no boxes yet, exactly one at the first tick.
	FrameStepper.step(game, 50)
	assertEqual(0, #findBoxes(), 'expected no boxes before the first 1s interval elapses')

	FrameStepper.step(game, 20) -- cross the 1s mark (frame 60)
	local firstBoxes = findBoxes()
	assertEqual(1, #firstBoxes, 'expected exactly one box after the first interval')

	-- let the box fall and land on the floor (a 96px drop at default gravity
	-- settles in well under 120 frames)
	FrameStepper.step(game, 120)
	assertNear(BOX_RESTING_Y, firstBoxes[1].collider:getPositionV().y, 4,
		'expected the landed box centre to rest on the floor surface')

	-- cadence sustained: 190 frames total is 3 intervals, so three boxes
	assertEqual(3, #findBoxes(), 'expected a box per elapsed 1s interval')
end)

test('the linked switch stops the replicator and re-enabling resumes it', function()
	local game = GameHarness.startGame(MAP)
	local replicator = findReplicator()
	local switch = Queries.findEntityByType(map, 'switch')
	local player = player1(game)
	assertEqual('replicator', replicator.type)
	assertEqual('switch', switch.type)

	FrameStepper.step(game, 10)
	assertEqual(0, #findBoxes(), 'fixture check: no boxes yet')

	-- lever starts off: first pull turns it on (irrelevant), second turns it
	-- off, which disables the replicator's Switchable and freezes its timer
	switch:use(player)
	switch:use(player)
	assertEqual('off', switch.state, 'fixture check: the switch should be off after two pulls')

	FrameStepper.step(game, 120) -- well past several 1s intervals
	assertEqual(0, #findBoxes(), 'expected no boxes to spawn while the switch is off')

	-- back on: spawning resumes from where the frozen accumulator stood
	switch:use(player)
	assertEqual('on', switch.state, 'fixture check: the switch should be on after the third pull')

	FrameStepper.step(game, 90) -- just past one 1s interval (frames 130+60)
	assertEqual(1, #findBoxes(), 'expected one new box after re-enabling')
end)