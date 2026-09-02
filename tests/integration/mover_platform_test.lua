-- Mover platform behavior driven through the real Game/Map/World stack: the
-- platform advances along its deck-line path at speed*dt, a player standing
-- on deck is carried by the exact per-frame delta, and the linked lever
-- switch stops and restarts it in place. The fixture's platform bridges a
-- gap at floor level (deck top flush with the floor surface, drawn as the
-- deck line at y=160) so a rider settles onto it naturally without input
-- choreography.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/mover_platform_room.tmj"

-- Player collider is 30 tall, so a body resting on the deck (top y=160) has
-- its center at y=145.
local PLAYER_RESTING_Y = 145

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function findPlatform()
	return Queries.findEntityByType(map, "mover_platform")
end

test("the platform advances along its path at speed*dt", function()
	local game = GameHarness.startGame(MAP)
	local platform = findPlatform()
	assertEqual("mover_platform", platform.type)

	local x0 = platform.collider:getPositionV().x
	assertNear(192, x0, 0.001, "fixture check: platform should start with its deck on the first waypoint")

	FrameStepper.step(game, 60) -- 1s at 100px/s (speed 100, no pause)
	local x1 = platform.collider:getPositionV().x
	assertNear(100, x1 - x0, 2, "expected the platform to advance ~100px after 1s")
	assertNear(176, platform.collider:getPositionV().y, 0.001, "expected a horizontal path to keep y constant")
end)

test("a player standing on the deck is carried by the exact platform delta", function()
	local game = GameHarness.startGame(MAP)
	local platform = findPlatform()
	local player = player1(game)

	local pp = platform.collider:getPositionV()
	player.collider:setPosition(pp.x, PLAYER_RESTING_Y)

	-- let the rider fall and settle onto the deck (it takes a few frames for
	-- gravity to seat it flush on the platform top)
	local grounded = false
	for _ = 1, 60 do
		FrameStepper.step(game, 1)
		if player:queryOnGround() then
			grounded = true
			break
		end
	end
	assertTrue(grounded, "expected the rider to land and stand on the deck")

	local riding = false
	for _ = 1, 40 do
		local platBefore = platform.collider:getPositionV()
		local plyBefore = player.collider:getPositionV()
		FrameStepper.step(game, 1)
		local platDelta = platform.collider:getPositionV().x - platBefore.x
		local plyDelta = player.collider:getPositionV().x - plyBefore.x

		if math.abs(platDelta) > 0.001 then
			riding = true
			assertNear(
				platDelta,
				plyDelta,
				0.002,
				"expected the rider to move by the exact platform delta, got platDelta="
					.. platDelta
					.. ", plyDelta="
					.. plyDelta
			)
		end
	end
	assertTrue(riding, "expected the platform to be moving at some point during the carry check")
	assertNear(
		PLAYER_RESTING_Y,
		player.collider:getPositionV().y,
		2,
		"expected the carried rider to stay on the deck, not fall or rise"
	)
end)

test("the linked switch stops the platform in place and restarting it resumes", function()
	local game = GameHarness.startGame(MAP)
	local platform = findPlatform()
	local switch = Queries.findEntityByType(map, "switch")
	local player = player1(game)

	FrameStepper.step(game, 10)

	-- lever starts off: first pull turns it on, second turns it off (gates off)
	switch:use(player)
	switch:use(player)
	assertEqual("off", switch.state, "fixture check: the switch should be off after two pulls")

	local frozenX = platform.collider:getPositionV().x
	local frozenY = platform.collider:getPositionV().y
	FrameStepper.step(game, 60)
	assertNear(
		frozenX,
		platform.collider:getPositionV().x,
		0.001,
		"expected the platform to stay in place while the switch is off"
	)
	assertNear(
		frozenY,
		platform.collider:getPositionV().y,
		0.001,
		"expected the platform to stay in place while the switch is off"
	)

	-- back on: the platform resumes from where it stopped
	switch:use(player)
	assertEqual("on", switch.state, "fixture check: the switch should be on after the third pull")
	local resumedX = platform.collider:getPositionV().x
	FrameStepper.step(game, 30)
	assertTrue(
		platform.collider:getPositionV().x ~= resumedX,
		"expected the platform to resume moving once the switch is back on"
	)
end)
