-- Bird cage-to-switch directed flight: a bird released from a cage whose
-- `target` property points at a switch flies a swoop-curve arc to it (via
-- FlyToTargetState -- src/npc/states/fly_to_target_state.lua), activates
-- the switch exactly as a player using it would, then hands control back
-- to the utility system, which resumes normal player-following.
--
-- Driven through the real Game/Map/World stack, like cage_target_test.lua
-- and cage_sound_test.lua (slice 02) whose fixture (bird_target_room.tmj)
-- this test reuses -- extended with a `target_blocker` (Switchable) so the
-- switch's effect on activation is observable.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")
local SoundSpy = require("tests.support.sound_spy")

local MAP = "tests/fixtures/bird_target_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function settle(game)
	FrameStepper.step(game, 60)
end

-- Steps the game one frame at a time (up to maxFrames) until `predicate()`
-- returns true, so tests don't hard-code an exact frame count for how long
-- the swoop-curve flight takes to complete.
local function stepUntil(game, predicate, maxFrames)
	for _ = 1, maxFrames do
		if predicate() then
			return true
		end
		FrameStepper.step(game, 1)
	end
	return predicate()
end

test("bird with a target flies a swoop-curve arc to the switch and activates it on arrival", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local cage = Queries.findEntityByName(map, "bird_cage_with_target")
	assertTrue(cage ~= nil, "fixture check: bird cage with target should exist")

	local switch = Queries.findEntityByName(map, "target_switch")
	assertTrue(switch ~= nil, "fixture check: target switch should exist")
	assertEqual("off", switch.state, "fixture check: switch should start off")

	local blocker = Queries.findEntityByName(map, "target_blocker")
	assertTrue(blocker ~= nil, "fixture check: target blocker should exist")
	assertEqual("closed", blocker.state, "fixture check: blocker should start closed")

	local soundSpy = SoundSpy.install()

	cage:use(player1(game))
	local bird = cage.actor
	assertTrue(bird ~= nil, "cage should spawn a bird")

	-- The very first update after spawn must force FlyToTargetState ahead
	-- of the default utility pick (which would otherwise choose FollowState
	-- immediately, since setTarget(user) already ran in Cage:use).
	FrameStepper.step(game, 1)
	assertEqual(
		"FlyToTargetState",
		bird.stateMachine.currentState.name,
		"bird should be forced into FlyToTargetState on its first update after spawn"
	)

	-- Capture the bird's position a couple of frames in, to prove the
	-- flight is a gradual multi-frame arc and not an instant teleport.
	FrameStepper.step(game, 2)
	local midX, midY = bird.x, bird.y
	local switchX, switchY = switch.collider:getX(), switch.collider:getY()
	local startDist = math.sqrt((midX - switchX) ^ 2 + (midY - switchY) ^ 2)
	assertTrue(startDist > 5, "bird should still be well short of the switch a few frames into the flight")

	-- Step until the flight completes (forcedState cleared) or we give up.
	local arrived = stepUntil(game, function()
		return bird.flownToTarget == true
	end, 300)
	soundSpy.uninstall()

	assertTrue(arrived, "bird should finish its flight and clear forcedState within a reasonable number of frames")
	assertTrue(bird.flownToTarget, "bird should remember it already flew to its target")

	-- The bird should have arrived at (or very near) the switch.
	local finalDist = math.sqrt((bird.x - switchX) ^ 2 + (bird.y - switchY) ^ 2)
	assertTrue(finalDist < 20, "bird should land at or very near the switch, got distance " .. tostring(finalDist))

	-- The switch should have activated exactly as if a player had used it:
	-- state flipped, sound played, and its linked blocker opened.
	assertEqual("on", switch.state, "switch should have flipped on")
	local playedOn = false
	for _, name in ipairs(soundSpy.played) do
		if name == "on" then
			playedOn = true
		end
	end
	assertTrue(playedOn, "switch on sound should have played")

	-- The blocker (the switch's Switchable target) telegraphs open after a
	-- delay, then opens -- give it time to settle.
	FrameStepper.step(game, 90)
	assertEqual("open", blocker.state, "switch activation should have opened its linked blocker")
end)

test("after activating the switch, the bird resumes following the player", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local cage = Queries.findEntityByName(map, "bird_cage_with_target")
	local user = player1(game)
	cage:use(user)
	local bird = cage.actor

	local arrived = stepUntil(game, function()
		return bird.flownToTarget == true
	end, 300)
	assertTrue(arrived, "fixture check: bird should finish its flight")

	-- Give the utility system a frame to pick FollowState now that
	-- forcedState is clear.
	FrameStepper.step(game, 1)
	assertEqual(
		"FollowState",
		bird.stateMachine.currentState.name,
		"bird should transition to FollowState once its forced flight is done"
	)

	local distBefore = math.sqrt((bird.x - user.collider:getX()) ^ 2 + (bird.y - user.collider:getY()) ^ 2)

	FrameStepper.step(game, 60)

	assertEqual(
		"FollowState",
		bird.stateMachine.currentState.name,
		"bird should still be following, not stuck in FlyToTargetState"
	)
	local distAfter = math.sqrt((bird.x - user.collider:getX()) ^ 2 + (bird.y - user.collider:getY()) ^ 2)
	assertTrue(
		distAfter < distBefore or distAfter < (bird.config.followDistance or 60) * 1.5,
		"bird should have moved toward the player (or already be within following range)"
	)
end)

test("the bird flies back to the player gradually once its target flight ends, not an instant teleport", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local cage = Queries.findEntityByName(map, "bird_cage_with_target")
	local user = player1(game)
	cage:use(user)
	local bird = cage.actor

	local arrived = stepUntil(game, function()
		return bird.flownToTarget == true
	end, 300)
	assertTrue(arrived, "fixture check: bird should finish its flight")

	-- Move BOTH players well outside the old despawnDistance=200 catch-up
	-- radius from the switch the bird is standing at (detectNearestPlayer
	-- retargets to whichever player is closest every frame, so both must
	-- move or the bird just tracks the other one) -- checkDespawn used to
	-- fire the very next frame and snap the bird instantly onto the
	-- nearest player's position; assert that no longer happens.
	for _, p in ipairs(game.fsm.currentState.players) do
		p.collider:setPosition(bird.x + 400, bird.y)
	end
	local xAtArrival, yAtArrival = bird.x, bird.y

	FrameStepper.step(game, 1)

	local moved = math.sqrt((bird.x - xAtArrival) ^ 2 + (bird.y - yAtArrival) ^ 2)
	assertTrue(
		moved < 20,
		"bird should move gradually (a single frame at follow speed), not teleport; moved "
			.. tostring(moved)
			.. "px in one frame"
	)
end)

test("a bird released from a cage with no target never enters FlyToTargetState (regression)", function()
	local game = GameHarness.startGame("tests/fixtures/cage_room.tmj")
	settle(game)

	local cage = Queries.findEntityByType(map, "cage")
	assertTrue(cage ~= nil, "fixture check: cage should exist")

	cage:use(player1(game))
	local bird = cage.actor
	assertTrue(bird ~= nil, "cage should spawn a bird")
	assertTrue(bird.switchTarget == nil, "fixture check: bird should have no switchTarget")

	FrameStepper.step(game, 120)

	assertTrue(bird.forcedState == nil, "forcedState should stay nil for a bird with no switchTarget")
	assertTrue(
		bird.stateMachine.currentState.name ~= "FlyToTargetState",
		"bird should never enter FlyToTargetState without a switchTarget"
	)
end)

test("debug mode: the in-flight PathFollow draws without error", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local previousDebug = conf.debug
	conf.debug = true

	local ok, err = pcall(function()
		local cage = Queries.findEntityByName(map, "bird_cage_with_target")
		cage:use(player1(game))
		local bird = cage.actor

		FrameStepper.step(game, 2)
		assertEqual("FlyToTargetState", bird.stateMachine.currentState.name, "fixture check: bird should be mid-flight")

		local pathFollow = bird:getComponent(PathFollow)
		assertTrue(pathFollow ~= nil, "fixture check: bird should have an active PathFollow component")
		pathFollow:draw()
	end)

	conf.debug = previousDebug
	assertTrue(ok, "PathFollow:draw() should not error in debug mode: " .. tostring(err))
end)
