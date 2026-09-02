-- FlyToDoorState: once the exit door opens (ExitDoor:open() -- see
-- src/entities/exit_door.lua), every bird currently following a player
-- detaches, flies an independent swoop-curve arc to the door
-- (src/npc/states/fly_to_door_state.lua), and is removed from the map on
-- arrival. A bird mid-FlyToTargetState when the door opens abandons that
-- flight and heads for the door instead. Rabbits are unaffected beyond the
-- existing despawnNearbyNPCs radius-despawn.
--
-- Driven through the real Game/Map/World stack, like bird_target_flight_test
-- (slice 03) whose fixture pattern (a bird cage with a `target` pointing at a
-- switch) this test's fixture (bird_door_exit_room.tmj) reuses, extended with
-- a plain bird_cage/rabbit_cage (no target) and an exit_door.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/bird_door_exit_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function settle(game)
	FrameStepper.step(game, 60)
end

-- Steps the game one frame at a time (up to maxFrames) until `predicate()`
-- returns true, so tests don't hard-code an exact frame count for how long
-- a swoop-curve flight takes to complete.
local function stepUntil(game, predicate, maxFrames)
	for _ = 1, maxFrames do
		if predicate() then
			return true
		end
		FrameStepper.step(game, 1)
	end
	return predicate()
end

test("a following bird leaves FollowState and flies to the door once it opens", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByName(map, "exit_door")
	assertTrue(door ~= nil, "fixture check: exit door should exist")

	local cage = Queries.findEntityByName(map, "bird_cage")
	assertTrue(cage ~= nil, "fixture check: bird cage should exist")

	local user = player1(game)
	cage:use(user)
	local bird = cage.actor
	assertTrue(bird ~= nil, "cage should spawn a bird")

	-- Let the bird catch up into FollowState before the door opens.
	FrameStepper.step(game, 30)
	assertEqual(
		"FollowState",
		bird.stateMachine.currentState.name,
		"fixture check: bird should be following the player before the door opens"
	)

	door:open()
	FrameStepper.step(game, 1)

	assertEqual(
		"FlyToDoorState",
		bird.stateMachine.currentState.name,
		"bird should leave FollowState and enter FlyToDoorState once the door opens"
	)

	local doorX, doorY = door.sprite.position.x, door.sprite.position.y
	local startDist = math.sqrt((bird.x - doorX) ^ 2 + (bird.y - doorY) ^ 2)

	-- Step a few frames and confirm the bird's distance to the door has
	-- shrunk -- a gradual arc, not an instant teleport.
	FrameStepper.step(game, 5)
	local midDist = math.sqrt((bird.x - doorX) ^ 2 + (bird.y - doorY) ^ 2)
	assertTrue(midDist < startDist, "bird should be converging on the door mid-flight")
end)

test("the bird is removed from the map once its flight to the door completes", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByName(map, "exit_door")
	local cage = Queries.findEntityByName(map, "bird_cage")
	local user = player1(game)
	cage:use(user)
	local bird = cage.actor

	FrameStepper.step(game, 30)
	door:open()

	local finished = stepUntil(game, function()
		return bird.destroy_flag == true
	end, 300)

	assertTrue(finished, "bird should be queued for destruction within a reasonable number of frames")
end)

test("a bird still mid-FlyToTargetState when the door opens abandons that flight for the door", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByName(map, "exit_door")
	local cage = Queries.findEntityByName(map, "bird_cage_with_target")
	assertTrue(cage ~= nil, "fixture check: bird cage with target should exist")

	local user = player1(game)
	cage:use(user)
	local bird = cage.actor
	assertTrue(bird ~= nil, "cage should spawn a bird")

	FrameStepper.step(game, 1)
	assertEqual(
		"FlyToTargetState",
		bird.stateMachine.currentState.name,
		"fixture check: bird should be forced into FlyToTargetState on spawn"
	)

	-- Still mid-flight (hasn't reached the switch yet).
	FrameStepper.step(game, 2)
	assertEqual(
		"FlyToTargetState",
		bird.stateMachine.currentState.name,
		"fixture check: bird should still be mid-flight to the switch"
	)
	assertTrue(not bird.flownToTarget, "fixture check: bird should not have reached the switch yet")

	door:open()
	FrameStepper.step(game, 1)

	assertEqual(
		"FlyToDoorState",
		bird.stateMachine.currentState.name,
		"door opening should override an in-progress FlyToTargetState with FlyToDoorState"
	)
end)

test("a following rabbit is unaffected by the door opening beyond the existing despawn radius (regression)", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByName(map, "exit_door")
	local cage = Queries.findEntityByName(map, "rabbit_cage")
	assertTrue(cage ~= nil, "fixture check: rabbit cage should exist")

	local user = player1(game)
	cage:use(user)
	local rabbit = cage.actor
	assertTrue(rabbit ~= nil, "cage should spawn a rabbit")

	FrameStepper.step(game, 30)
	assertEqual(
		"FollowState",
		rabbit.stateMachine.currentState.name,
		"fixture check: rabbit should be following the player before the door opens"
	)

	local ok, err = pcall(function()
		door:open()
		FrameStepper.step(game, 60)
	end)
	assertTrue(ok, "door opening should not crash with a following rabbit nearby: " .. tostring(err))

	assertTrue(rabbit.forcedState == nil, "rabbit should never receive a forcedState from the door event")
	assertTrue(rabbit.stateMachine.currentState.name ~= "FlyToDoorState", "rabbit should never enter FlyToDoorState")
end)
