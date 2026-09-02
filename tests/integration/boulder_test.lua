-- The boulder's momentum roll, driven through the real Game/Map/World/Player
-- stack. The roll/stop decision itself is unit-tested in
-- tests/unit/pushable_support_test.lua (nextRollVelocity); this file covers
-- what only the real stack answers -- that momentum actually carries the
-- boulder onward, and that each obstacle really does stop it.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput

local MAP = "tests/fixtures/boulder_room.tmj"

-- see the fixture's header diagram
local SURFACE_TOP = 224
local BOULDER_RESTING_Y = SURFACE_TOP - 16
local WALL_FACE = 224 -- right face of the left wall
local HOLE_CENTRE_X = 464
local HOLE_FLOOR_TOP = 256
local PLAYER_HALF_WIDTH = 10

local function settle(game)
	FrameStepper.step(game, 60)
end

local function player1(game)
	return game.fsm.currentState.players[1]
end

-- P2 spawns on top of P1 and would otherwise wander into the boulder's path;
-- park it well clear so each test has exactly one moving part
local function parkPlayer2(game, x)
	game.fsm.currentState.players[2].collider:setPosition(x, BOULDER_RESTING_Y + 1)
end

local function boulderOf(game)
	return Queries.findEntityByName(map, "boulder")
end

-- shoves the boulder rightward until it is moving, then releases -- momentum
-- alone carries it from there
local function shoveRightAndRelease(game, controller, boulder)
	local startX = boulder.collider:getX()
	controller:press("right")
	for _ = 1, 180 do
		FrameStepper.step(game, 1)
		if boulder.collider:getX() > startX + 0.5 then
			controller:release("right")
			return
		end
	end
	error("the player never got the boulder moving")
end

test("a grounded player walking into a boulder starts it rolling", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)
	parkPlayer2(game, 64)

	local boulder = boulderOf(game)
	local startX = boulder.collider:getX()
	shoveRightAndRelease(game, controller, boulder)

	assertTrue(boulder.collider:getX() > startX, "expected the shove to set the boulder moving")
end)

-- the defining difference from a push box: contact ends and it carries on
test("a boulder keeps rolling at walk speed after the player stops touching it", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)
	parkPlayer2(game, 64)

	local boulder = boulderOf(game)
	local player = player1(game)
	shoveRightAndRelease(game, controller, boulder)

	-- the player is stationary from here on, so anything the boulder covers is
	-- its own momentum
	local playerXAtRelease = Queries.playerPositionV(player).x
	local fromX = boulder.collider:getX()
	FrameStepper.step(game, 30)
	local travelled = boulder.collider:getX() - fromX

	assertNear(
		playerXAtRelease,
		Queries.playerPositionV(player).x,
		1,
		"fixture check: the player should have stopped walking after releasing"
	)
	assertNear(
		player.speed * 0.5,
		travelled,
		3,
		"expected the boulder to keep rolling at the player's walk speed on its own"
	)
end)

test("a rolling boulder stops harmlessly at a wall", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)
	parkPlayer2(game, 600)

	local boulder = boulderOf(game)
	local player = player1(game)
	-- stand on its right so the shove sends it leftward, toward the wall
	player.collider:setPosition(boulder.collider:getX() + 16 + PLAYER_HALF_WIDTH, BOULDER_RESTING_Y + 1)
	FrameStepper.step(game, 10)

	controller:press("left")
	FrameStepper.step(game, 20)
	controller:release("left")
	FrameStepper.step(game, 240) -- long enough to reach the wall and settle

	assertNear(
		WALL_FACE + 16,
		boulder.collider:getX(),
		1.5,
		"expected the boulder to come to rest flush against the wall"
	)
	assertNear(
		BOULDER_RESTING_Y,
		boulder.collider:getY(),
		1,
		"expected it to still be sitting on the surface, not to have climbed or sunk"
	)
end)

-- harmless by design: a boulder that reaches a player stops instead of
-- crushing or shunting them
test("a rolling boulder stops when it reaches a player, without shoving them", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local boulder = boulderOf(game)
	local blocker = game.fsm.currentState.players[2]
	-- park P2 in the boulder's path: far enough that the shove is over and the
	-- roll is free, but short of the hole, so the player is what stops it
	local blockerX = boulder.collider:getX() + 80
	parkPlayer2(game, blockerX)

	shoveRightAndRelease(game, controller, boulder)
	FrameStepper.step(game, 240)

	assertNear(
		blockerX - PLAYER_HALF_WIDTH - 16,
		boulder.collider:getX(),
		2,
		"expected the boulder to stop at the player it reached"
	)
	assertNear(
		blockerX,
		blocker.collider:getX(),
		1.5,
		"expected the blocking player not to be shoved along by the boulder"
	)
	assertFalse(Queries.playerIsDead(blocker), "expected the boulder to be harmless")
end)

test("a rolling boulder falls and snaps into a hole like a box", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)
	parkPlayer2(game, 64)

	local boulder = boulderOf(game)
	shoveRightAndRelease(game, controller, boulder)
	FrameStepper.step(game, 300) -- roll to the hole, drop in, settle

	assertNear(HOLE_CENTRE_X, boulder.collider:getX(), 0.5, "expected the boulder to align to the hole's tile centre")
	assertNear(HOLE_FLOOR_TOP - 16, boulder.collider:getY(), 1, "expected the boulder to come to rest filling the hole")
end)

-- "pushable again once stopped, if there's room": stopped against the wall
-- there is no room on that side, so this stops it against P2 instead, then
-- clears P2 out of the way and shoves it back the other direction.
test("a boulder that has stopped can be pushed again, back the way it came", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local boulder = boulderOf(game)
	local player = player1(game)
	parkPlayer2(game, boulder.collider:getX() + 80)

	shoveRightAndRelease(game, controller, boulder)
	FrameStepper.step(game, 240) -- roll into P2 and stop
	local stoppedX = boulder.collider:getX()

	-- the blocker walks away, leaving room on both sides
	parkPlayer2(game, 600)
	player.collider:setPosition(stoppedX + 16 + PLAYER_HALF_WIDTH, BOULDER_RESTING_Y + 1)
	FrameStepper.step(game, 10)

	controller:press("left")
	FrameStepper.step(game, 30)
	controller:release("left")

	assertTrue(
		boulder.collider:getX() < stoppedX - 20,
		"expected a stopped boulder to be pushable again in the opposite direction"
	)
end)
