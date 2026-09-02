-- Drives a player via the real input path (Player:isDown reading
-- love.keyboard/love.joystick each frame) across flat_ground, proving both
-- keyboard and joystick paths move the player and that releasing input
-- stops it -- and that P1/P2 input schemes don't leak into each other.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor
local runUntil = FakeInputModule.runUntil

local MAP = "tests/fixtures/flat_ground.tmj"

-- let both players fall from their spawn onto the floor and settle into
-- WalkIdleState before driving any horizontal input
local function settle(game)
	FrameStepper.step(game, 30)
end

test("keyboard-driven P1 movement: holding right advances position and sets facing, releasing stops it", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local player = game.fsm.currentState.players[1]
	local startX = Queries.playerPositionV(player).x

	holdFor(game, controller, "right", 1)

	local heldX = Queries.playerPositionV(player).x
	assertTrue(heldX > startX, "expected P1 to move right while holding the key")
	assertEqual("right", Queries.playerFacing(player))

	FrameStepper.step(game, 10)
	local afterReleaseX = Queries.playerPositionV(player).x
	assertEqual(heldX, afterReleaseX, "expected P1 to stop moving once the key is released")
end)

test("joystick-driven P1 movement: holding the horizontal axis right advances position", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	local joystick = controller:assignJoystick(1)
	settle(game)

	local player = game.fsm.currentState.players[1]
	local startX = Queries.playerPositionV(player).x

	joystick:setAxes(1, 0)
	FrameStepper.step(game, FrameStepper.secondsToFrames(1))

	local heldX = Queries.playerPositionV(player).x
	assertTrue(heldX > startX, "expected P1 to move right while holding the joystick axis")
	assertEqual("right", Queries.playerFacing(player))

	joystick:setAxes(0, 0)
	FrameStepper.step(game, 10)
	local afterReleaseX = Queries.playerPositionV(player).x
	assertEqual(heldX, afterReleaseX, "expected P1 to stop moving once the axis returns to neutral")
end)

test("keyboard-driven P2 movement uses its own control scheme and does not move P1", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local players = game.fsm.currentState.players
	local p1, p2 = players[1], players[2]
	local p1StartX = Queries.playerPositionV(p1).x
	local p2StartX = Queries.playerPositionV(p2).x

	holdFor(game, controller, "d", 1)

	local p1EndX = Queries.playerPositionV(p1).x
	local p2EndX = Queries.playerPositionV(p2).x

	assertEqual(p1StartX, p1EndX, "expected P2 input to leave P1 unmoved")
	assertTrue(p2EndX > p2StartX, "expected P2 to move right on its own control scheme (d)")
	assertEqual("right", Queries.playerFacing(p2))
end)

test("runUntil steps frames until a predicate holds", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()

	local player = game.fsm.currentState.players[1]
	controller:press("right")

	runUntil(game, function()
		return Queries.playerFacing(player) == "right"
	end, 120)

	assertEqual("right", Queries.playerFacing(player))
end)
