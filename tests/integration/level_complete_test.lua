-- Drives both players out through the exit door and asserts the game
-- transitions to LevelCompleteState (not straight to MenuState), then that
-- pressing "use" from there returns to MenuState. Mirrors
-- exit_door_sound_test.lua's convention of opening the door directly via
-- door:subtract(1) rather than simulating the cage/switch flow that
-- normally decrements actor_count -- the door's variable counter is
-- orthogonal to player-exit counting, which is what this test cares about.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput

local MAP = "tests/fixtures/exit_door_two_players_room.tmj"

test("both players exiting the door transitions to LevelCompleteState, not MenuState", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 30) -- settle onto the floor

	local door = Queries.findEntityByType(map, "exit_door")
	assertTrue(door ~= nil, "fixture check: exit door should be present")

	door:subtract(1) -- actor_count 1 -> 0, opens the door
	FrameStepper.step(game, 5) -- let the open animation/state settle

	assertEqual("open", door.state, "fixture check: door should be open before use")

	local players = Queries.findEntitiesByType(map, "player")
	assertEqual(2, #players, "fixture check: expected 2 players spawned")

	door:use(players[1])
	door:use(players[2])
	FrameStepper.step(game, 1) -- entity_factory processes queueDestroy flags on the next layer update

	assertEqual(
		"LevelCompleteState",
		game.fsm.currentState.name,
		"game state should be LevelCompleteState once all players have exited"
	)
end)

test("pressing use on LevelCompleteState returns to MenuState", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 30)

	local door = Queries.findEntityByType(map, "exit_door")
	door:subtract(1)
	FrameStepper.step(game, 5)

	local players = Queries.findEntitiesByType(map, "player")
	door:use(players[1])
	door:use(players[2])
	FrameStepper.step(game, 1)

	assertEqual("LevelCompleteState", game.fsm.currentState.name, "precondition: should be on LevelCompleteState")

	-- Game:setGameState's swallowEdges (mirrored by the harness) discards
	-- whatever is held on the very next update() call after a transition, so
	-- this frame consumes that swallow before the deliberate press below
	-- (see input_manager.lua's swallowNextEdges) rather than eating it.
	FrameStepper.step(game, 1)

	local controller = FakeInput.new()
	controller:press("return")
	FrameStepper.step(game, 1)
	controller:release("return")

	assertEqual("MenuState", game.fsm.currentState.name, "pressing use/start should return to MenuState")
end)
