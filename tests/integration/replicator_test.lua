-- Replicator behavior driven through the real Game/Map/World stack: a switch
-- press immediately spawns one push_box which falls under gravity and lands
-- on the floor, and the maxSpawns budget (1) leaves further presses inert
-- once spent. The fixture's replicator (rotation 0, ceiling mount) spawns
-- top-anchored mock objects with no gid, so the box's top edge emits at
-- object.y + height (y=96, centre y=112) and falls 64px onto the floor top
-- (y=160), where a 32px box rests at y=144.
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

test('a switch press immediately spawns one push_box that falls and lands on the floor', function()
	local game = GameHarness.startGame(MAP)
	local replicator = findReplicator()
	local switch = Queries.findEntityByType(map, 'switch')
	local player = player1(game)
	assertEqual('replicator', replicator.type)
	assertEqual('switch', switch.type)

	FrameStepper.step(game, 10)
	assertEqual(0, #findBoxes(), 'fixture check: no boxes before any press')

	-- one press = one spawn, immediately (no timer involved)
	switch:use(player)
	local boxes = findBoxes()
	assertEqual(1, #boxes, 'expected exactly one box after the first press')

	-- the box falls and lands on the floor (a 64px drop at default gravity
	-- settles in well under 120 frames)
	FrameStepper.step(game, 120)
	assertNear(BOX_RESTING_Y, boxes[1].collider:getPositionV().y, 4,
		'expected the landed box centre to rest on the floor surface')
end)

test('the maxSpawns budget is spent after one spawn and further presses are inert', function()
	local game = GameHarness.startGame(MAP)
	local replicator = findReplicator()
	local switch = Queries.findEntityByType(map, 'switch')
	local player = player1(game)
	assertEqual('replicator', replicator.type)

	FrameStepper.step(game, 10)
	switch:use(player)
	assertEqual(1, #findBoxes(), 'first press spawns the box')

	-- second press: budget spent, nothing new spawns, existing box still there
	switch:use(player)
	FrameStepper.step(game, 60)
	assertEqual(1, #findBoxes(), 'expected no second box once the budget is spent')

	-- third press stays inert too
	switch:use(player)
	FrameStepper.step(game, 60)
	assertEqual(1, #findBoxes(), 'expected further presses to stay inert once spent')
end)