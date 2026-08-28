-- The pressure switch driven through the real Game/Map/World/Player stack:
-- weight detection, the momentary/latching difference, and driving a real
-- target entity. The activation and latching decisions themselves are
-- unit-tested in tests/unit/pressure_switch_test.lua.
--
-- The target is a real `ladder` with a `switchOn` snippet (`entity:grow(2)`),
-- so "it drove its target" is observed as the ladder actually growing, through
-- the project's own switch mechanism -- nothing is mocked.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/pressure_switch_room.tmj'

-- see the fixture's header diagram
local SURFACE_TOP = 224
local PLATE_CENTRE_X = 304
local LATCHING_PLATE_CENTRE_X = 400
local PLAYER_RESTING_Y = SURFACE_TOP - 15
local BOX_RESTING_Y = SURFACE_TOP - 16
local PLAYER_HALF_WIDTH = 10

local function settle(game)
	FrameStepper.step(game, 60)
end

local function players(game)
	return game.fsm.currentState.players
end

local function stand(player, x)
	player.collider:setPosition(x, PLAYER_RESTING_Y)
end

test('a player standing substantially on the plate activates it', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	assertFalse(Queries.pressureSwitchIsActive(plate), 'expected an empty plate to start off')

	stand(players(game)[1], PLATE_CENTRE_X)
	FrameStepper.step(game, 5)

	assertTrue(Queries.pressureSwitchIsActive(plate), 'expected a player on the plate to activate it')
end)

-- merely overlapping the plate is not standing on it (DECISIONS Q11)
test('a player brushing the plate\'s edge does not activate it', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	stand(players(game)[1], PLATE_CENTRE_X - 15)
	FrameStepper.step(game, 5)

	assertFalse(Queries.pressureSwitchIsActive(plate),
		'expected a weight only clipping the plate edge to leave it off')
end)

test('activating the plate drives its target through the switch mechanism', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local ladder = Queries.findEntityByName(map, 'target_ladder')
	local heightBefore = ladder:tileHeight()

	stand(players(game)[1], PLATE_CENTRE_X)
	FrameStepper.step(game, 5)

	-- the fixture's ladder grows 2 tiles on switchOn
	assertEqual(heightBefore + 2, ladder:tileHeight(),
		'expected the plate to drive its target, growing the ladder')
end)

test('a momentary plate releases when the weight leaves', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	local player = players(game)[1]

	stand(player, PLATE_CENTRE_X)
	FrameStepper.step(game, 5)
	assertTrue(Queries.pressureSwitchIsActive(plate), 'fixture check: the plate should be on first')

	stand(player, 64)
	FrameStepper.step(game, 5)

	assertFalse(Queries.pressureSwitchIsActive(plate),
		'expected a momentary plate to follow the weight and release')
end)

test('a latching plate stays on after the weight leaves', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'latching_plate')
	local player = players(game)[1]

	stand(player, LATCHING_PLATE_CENTRE_X)
	FrameStepper.step(game, 5)
	assertTrue(Queries.pressureSwitchIsActive(plate), 'fixture check: the latching plate should trip first')

	stand(player, 64)
	FrameStepper.step(game, 5)

	assertTrue(Queries.pressureSwitchIsActive(plate),
		'expected a latching plate to hold once tripped')
end)

test('two weights count as one activation, and it releases only when the last leaves', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	local p1, p2 = players(game)[1], players(game)[2]

	stand(p1, PLATE_CENTRE_X)
	stand(p2, PLATE_CENTRE_X)
	FrameStepper.step(game, 5)
	assertTrue(Queries.pressureSwitchIsActive(plate), 'expected two weights to activate the plate')

	stand(p1, 64)
	FrameStepper.step(game, 5)
	assertTrue(Queries.pressureSwitchIsActive(plate),
		'expected the plate to stay on while one weight remains')

	stand(p2, 96)
	FrameStepper.step(game, 5)
	assertFalse(Queries.pressureSwitchIsActive(plate),
		'expected the plate to release once the last weight left')
end)

test('a pushable on the plate activates it, just as a player does', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	local box = Queries.findEntityByName(map, 'push_box')

	box.collider:setPosition(PLATE_CENTRE_X, BOX_RESTING_Y)
	-- keep the players well clear so the box is the only weight in play
	stand(players(game)[1], 64)
	stand(players(game)[2], 96)
	FrameStepper.step(game, 5)

	assertTrue(Queries.pressureSwitchIsActive(plate), 'expected a box on the plate to activate it')
end)

-- DECISIONS Q12: seating happens on push-RELEASE, never mid-push, so the snap
-- can never fight the player's input while they are still shoving
test('a box pushed onto the plate seats itself on release and can be pushed back off', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	local box = Queries.findEntityByName(map, 'push_box')
	local player = players(game)[1]
	stand(players(game)[2], 32)

	-- leave the box deliberately off-centre but within seating tolerance,
	-- with the player flush behind it as though they had just pushed it there
	box.collider:setPosition(PLATE_CENTRE_X - 5, BOX_RESTING_Y)
	stand(player, PLATE_CENTRE_X - 5 - 16 - PLAYER_HALF_WIDTH)
	FrameStepper.step(game, 10)

	assertNear(PLATE_CENTRE_X, box.collider:getX(), 0.5,
		'expected the released box to seat itself on the plate tile centre')
	assertTrue(Queries.pressureSwitchIsActive(plate), 'expected the seated box to hold the plate on')

	-- and it is not stuck there: pushing it away releases the plate again
	holdFor(game, controller, 'right', 1)

	assertTrue(box.collider:getX() > PLATE_CENTRE_X + 20, 'expected the box to be pushable off the plate')
	assertFalse(Queries.pressureSwitchIsActive(plate),
		'expected the momentary plate to release once the box was pushed off')
end)
