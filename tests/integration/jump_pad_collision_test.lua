-- End-to-end proof that a player riding a jump-pad path stops at a solid
-- obstacle instead of flying through it: a path-riding player is kinematic
-- and would otherwise cross every collider. PathFollow now stops advancing
-- on a solid hit (src/components/path_follow.lua, unit-tested directly in
-- tests/unit/path_follow_test.lua) and JumpTravelState ends the state early
-- via FallState when that happens (src/player/states/jump_travel_state.lua).
--
-- Fixture: tests/fixtures/jump_pad_collision_room.tmj -- one shared floor
-- (top y=224) under two jump pads:
--   - jump_pad_wall: a straight horizontal path (y=208) that runs into a
--     static wall placed across it.
--   - jump_pad_pushable: the same straight horizontal shape, running into a
--     push_box resting on the same floor (its authored position already
--     rests it with its centre at y=208, dead in the path's line).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local FIXTURE = "tests/fixtures/jump_pad_collision_room.tmj"
local BOOTSTRAP_FIXTURE = "tests/fixtures/jump_pad_room.tmj"

-- GameHarness.bootGlobals/love.conf only ever wire up on the FIRST
-- GameHarness.startGame call in the process (see
-- jump_pad_target_trajectory_test.lua for the full explanation) -- force
-- that one-time boot here before any test below runs.
GameHarness.startGame(BOOTSTRAP_FIXTURE)

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function boundsOverlap(a, b)
	return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top
end

-- Positions the player exactly on the pad first: JumpPad:use computes its
-- world-space offset from the user's CURRENT position (see
-- src/entities/jump_pad.lua), so starting anywhere off the pad's own centre
-- would shift the whole path along with it.
local function driveJumpUntilStateChange(game, pad, maxFrames)
	local player = player1(game)
	local padCentre = pad.collider:getPositionV()
	player.collider:setPositionV(padCentre)
	player.collider:setLinearVelocity(0, 0)

	pad:use(player)

	for _ = 1, maxFrames do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		if stateName ~= "JumpTravelState" then
			return stateName
		end
	end

	return "JumpTravelState (timed out)"
end

test("a path blocked by a solid tile ends in FallState, never entering the wall", function()
	local game = GameHarness.startGame(FIXTURE)
	FrameStepper.step(game, 5) -- let entities finish initialising

	local pad = Queries.findEntityByName(map, "jump_pad_wall")
	assertTrue(pad ~= nil, "fixture check: jump_pad_wall should be present")

	local player = player1(game)
	local stateName = driveJumpUntilStateChange(game, pad, 300)

	assertEqual("FallState", stateName, "expected an early FallState handoff, got: " .. tostring(stateName))

	-- the wall is a plain collision-layer rectangle, not an entity -- read
	-- its bounds straight from the fixture's authored geometry instead of
	-- an entity lookup
	local wallBounds = { left = 300, right = 332, top = 150, bottom = 300 }
	local playerBounds = player.collider:getBounds()
	assertFalse(boundsOverlap(playerBounds, wallBounds), "player must not overlap the wall on the blocked frame")

	-- falls and lands normally afterward
	for _ = 1, 120 do
		FrameStepper.step(game, 1)
		if player.fsm.currentState.name == "WalkIdleState" then
			break
		end
	end
	assertEqual(
		"WalkIdleState",
		player.fsm.currentState.name,
		"expected the player to land normally after the blocked exit"
	)
end)

test("a path blocked by a pushable ends in FallState and the pushable does not move", function()
	local game = GameHarness.startGame(FIXTURE)
	FrameStepper.step(game, 5) -- let entities finish initialising

	local pad = Queries.findEntityByName(map, "jump_pad_pushable")
	local box = Queries.findEntityByName(map, "path_blocking_box")
	assertTrue(pad ~= nil, "fixture check: jump_pad_pushable should be present")
	assertTrue(box ~= nil, "fixture check: path_blocking_box should be present")

	local boxStartPos = box.collider:getPositionV()

	local player = player1(game)
	local stateName = driveJumpUntilStateChange(game, pad, 300)

	assertEqual("FallState", stateName, "expected an early FallState handoff, got: " .. tostring(stateName))

	local playerBounds = player.collider:getBounds()
	local boxBounds = box.collider:getBounds()
	assertFalse(boundsOverlap(playerBounds, boxBounds), "player must not overlap the pushable on the blocked frame")

	local boxEndPos = box.collider:getPositionV()
	assertNear(boxStartPos.x, boxEndPos.x, 0.5, "the pushable must not move on impact")
	assertNear(boxStartPos.y, boxEndPos.y, 0.5, "the pushable must not move on impact")
end)

test("regression: an unblocked jump-pad path completes exactly as before", function()
	local game = GameHarness.startGame(BOOTSTRAP_FIXTURE)
	FrameStepper.step(game, 5) -- let entities finish initialising

	local pad = Queries.findEntityByName(map, "jump_pad1")
	assertTrue(pad ~= nil, "fixture check: jump pad should be present")

	local stateName = driveJumpUntilStateChange(game, pad, 300)

	assertTrue(
		stateName == "WalkIdleState" or stateName == "FallState",
		"expected a natural, unblocked path exit, got: " .. tostring(stateName)
	)
end)
