-- Reset semantics for props and pressure switches (DECISIONS Q10): a level
-- restart puts everything back to spawn, a player death changes nothing.
--
-- There is deliberately no resetToSpawn() code to test here. InGameState:load
-- builds a fresh World and Map and re-instantiates every entity from the map
-- data, so a restart resets props structurally -- a snapshot-and-restore path
-- would be a second, redundant source of truth. The risk worth covering by
-- test is therefore the opposite one: that death must NOT go through that path.
-- Same reasoning as the drawbridge's reset test.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/pressure_switch_room.tmj"

local SURFACE_TOP = 224
local BOX_RESTING_Y = SURFACE_TOP - 16
local PLAYER_RESTING_Y = SURFACE_TOP - 15
local LATCHING_PLATE_CENTRE_X = 400

-- rearranges the level: shoves the box away from its spawn column and trips
-- the latching plate, so a reset has something visible to undo
local function disturb(game)
	local box = Queries.findEntityByName(map, "push_box")
	local spawnX = box.collider:getX()

	box.collider:setPosition(spawnX + 96, BOX_RESTING_Y)
	game.fsm.currentState.players[1].collider:setPosition(LATCHING_PLATE_CENTRE_X, PLAYER_RESTING_Y)
	FrameStepper.step(game, 5)

	local plate = Queries.findEntityByName(map, "latching_plate")
	assertTrue(Queries.pressureSwitchIsActive(plate), "fixture check: the latching plate should have tripped")
	assertNear(spawnX + 96, box.collider:getX(), 1, "fixture check: the box should have been moved")

	return spawnX
end

test("a level restart returns every prop to its spawn position and every switch to off", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local box = Queries.findEntityByName(map, "push_box")
	local spawnX = disturb(game)

	game:load({ map = MAP }) -- the same path a "restart level" action takes

	local restartedBox = Queries.findEntityByName(map, "push_box")
	local restartedPlate = Queries.findEntityByName(map, "latching_plate")
	FrameStepper.step(game, 60)

	assertTrue(restartedBox ~= box, "expected a restart to instantiate a fresh prop")
	assertNear(spawnX, restartedBox.collider:getX(), 1, "expected the prop back at its spawn position")
	assertFalse(
		Queries.pressureSwitchIsActive(restartedPlate),
		"expected a latching plate to be off again after a restart"
	)
end)

-- a single death shouldn't rewind a board the player has spent time arranging
test("a player death leaves props and switch states exactly as they were", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local box = Queries.findEntityByName(map, "push_box")
	local plate = Queries.findEntityByName(map, "latching_plate")
	disturb(game)
	local disturbedX = box.collider:getX()

	local player = game.fsm.currentState.players[1]
	local livesBefore = game.fsm.currentState.lives
	player:die("water")
	-- Player:die only enters DeadState; the death is resolved once the death
	-- flash finishes (~1.2s), which is when a life is actually spent and the
	-- respawn happens -- so step well past that
	FrameStepper.step(game, 150)

	assertTrue(
		game.fsm.currentState.lives < livesBefore,
		"fixture check: the death path should really have run and cost a life"
	)
	assertEqual(
		box,
		Queries.findEntityByName(map, "push_box"),
		"expected death NOT to rebuild the map -- props must survive a respawn"
	)
	assertNear(disturbedX, box.collider:getX(), 1, "expected the prop to stay where the player left it across a death")
	assertTrue(
		Queries.pressureSwitchIsActive(plate),
		"expected a tripped latching plate to stay tripped across a death"
	)
end)
