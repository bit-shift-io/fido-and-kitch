-- Ladder no-gravity zone: a falling player who overlaps the ladder volume
-- must be caught automatically (no input, no mount key), hanging in place
-- with gravity suspended -- instead of falling through the column to the
-- floor (the side-entry fall-through bug).
-- Companion invariant: a GROUNDED player walking through the base column is
-- never auto-caught (catch requires being airborne or pressing up/down).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput

local CATCH_MAP = "tests/fixtures/ladder_fall_catch_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

local runUntil = FakeInputModule.runUntil

test("a player falling into a ladder volume is caught without any input and hangs with gravity suspended", function()
	local game = GameHarness.startGame(CATCH_MAP)
	local player = player1(game)

	local sawFallState = false
	local caughtAt = nil
	local catchY = nil

	for i = 1, FrameStepper.secondsToFrames(2) do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name

		if stateName == "FallState" then
			sawFallState = true
		end

		if sawFallState and stateName == "LadderState" then
			caughtAt = i
			catchY = Queries.playerPositionV(player).y
			break
		end
	end

	assertTrue(sawFallState, "fixture check: expected the mid-air spawn to put the player into FallState")
	assertTrue(
		caughtAt ~= nil,
		"expected the falling player to be caught into LadderState by the ladder volume without any input"
	)

	-- Hang stability: gravity must stay suspended while overlapping the
	-- volume with no keys held.
	local maxDrift = 0
	for _ = 1, FrameStepper.secondsToFrames(0.5) do
		FrameStepper.step(game, 1)
		local drift = math.abs(Queries.playerPositionV(player).y - catchY)
		if drift > maxDrift then
			maxDrift = drift
		end
	end
	assertTrue(maxDrift <= 2, "expected the caught player to hang in place (drift " .. tostring(maxDrift) .. "px)")
end)

test("a grounded player walking through the ladder base column is never auto-caught", function()
	local game = GameHarness.startGame(CATCH_MAP)
	local controller = FakeInput.new()

	-- Player 2 spawns on the floor beside the column (player 1 takes the
	-- mid-air spawn and hangs in the volume -- irrelevant here).
	local player = game.fsm.currentState.players[2]
	local startX = Queries.playerPositionV(player).x
	assertTrue(
		startX > 160 and startX < 300,
		"fixture check: expected player 2 on the floor spawn right of the ladder, got x=" .. tostring(startX)
	)

	controller:press("a") -- player 2 left

	local sawLadderState = false
	local pastColumnX = 96 -- column spans x [128, 160]; walk well clear of it
	local reached = false

	for _ = 1, FrameStepper.secondsToFrames(3) do
		FrameStepper.step(game, 1)
		if player.fsm.currentState.name == "LadderState" then
			sawLadderState = true
		end
		if Queries.playerPositionV(player).x <= pastColumnX then
			reached = true
			break
		end
	end

	controller:release("a")

	assertTrue(reached, "expected the player to walk across the ladder column to x=" .. pastColumnX)
	assertFalse(sawLadderState, "expected grounded walkthrough of the ladder volume never to enter LadderState")
end)

-- NOTE: falling into the volume while ALREADY HOLDING a horizontal key (which
-- used to slide the player through and out of the ladder) is now covered by
-- tests/integration/ladder_catch_slide_test.lua -- the authoritative spec that
-- stale held directions must hang, not slide out -- so it is not duplicated
-- here.
