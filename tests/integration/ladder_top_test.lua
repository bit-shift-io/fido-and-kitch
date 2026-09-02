-- Bare ladder top: the ladder's top edge is a one-way platform in its own
-- right -- a player who climbs out of the volume stands ON it even with no
-- terrain beneath, and the bare top walks like ground onto an adjacent
-- flush ledge.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput
local runUntil = FakeInputModule.runUntil

local MAP = "tests/fixtures/ladder_top_room.tmj"

local TOP_EDGE_Y = 192 -- merged column spans y [192, 352]; nothing under the top

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function feetY(player)
	return player.collider:getBounds().bottom
end

-- Perch on the bare top by dropping onto it, descend into the volume by
-- holding down, then climb back up and out onto the slab.
local function mountToTop(game, controller, player)
	runUntil(game, function()
		return player.fsm.currentState.name == "WalkIdleState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, 180)

	controller:press("down")
	runUntil(game, function()
		return player.fsm.currentState.name == "LadderState" and feetY(player) > TOP_EDGE_Y + 20
	end, FrameStepper.secondsToFrames(3))
	controller:release("down")

	controller:press("up")
	-- Up at the top is a no-op under the edge-key model: the climb ends
	-- hovering at the volume's top edge, still mounted.
	runUntil(game, function()
		return player.fsm.currentState.name == "LadderState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, FrameStepper.secondsToFrames(3))
	controller:release("up")

	-- Dismount by sliding right off the column onto the adjacent flush ledge.
	controller:press("right")
	runUntil(game, function()
		return player.fsm.currentState.name == "WalkIdleState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, FrameStepper.secondsToFrames(3))
	controller:release("right")
end

test("a player climbing out of the volume stands on the bare ladder top with no terrain beneath", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	local player = player1(game)

	mountToTop(game, controller, player)

	assertTrue(
		math.abs(feetY(player) - TOP_EDGE_Y) <= 3,
		"expected to stand on the ladder top edge y=" .. TOP_EDGE_Y .. ", feet at " .. tostring(feetY(player))
	)

	-- Idle: still supported by the top alone (the fixture has no blocks
	-- anywhere beneath the top edge), no fall, no re-mount.
	for _ = 1, FrameStepper.secondsToFrames(0.5) do
		FrameStepper.step(game, 1)
	end
	assertEqual("WalkIdleState", player.fsm.currentState.name, "expected to keep standing on the bare top")
	assertTrue(
		math.abs(feetY(player) - TOP_EDGE_Y) <= 3,
		"expected the bare top to hold the player at y=" .. TOP_EDGE_Y .. ", feet at " .. tostring(feetY(player))
	)
end)

test("a player falling onto the bare ladder top from above lands standing on it", function()
	local game = GameHarness.startGame(MAP)
	local player = player1(game)

	-- No input: the drop onto the column ends standing on the slab.
	runUntil(game, function()
		return player.fsm.currentState.name == "WalkIdleState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, 180)
end)

test("pressing down while standing on the bare top descends into the ladder volume", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	local player = player1(game)

	-- Perch via drop, then descend by holding down: the one-way top must
	-- not hold the player -- the mount-down probe reaches the volume below.
	runUntil(game, function()
		return player.fsm.currentState.name == "WalkIdleState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, 180)

	controller:press("down")
	runUntil(game, function()
		return player.fsm.currentState.name == "LadderState" and feetY(player) > TOP_EDGE_Y + 24
	end, FrameStepper.secondsToFrames(3))
	controller:release("down")

	-- Hanging inside with no keys held: gravity stays suspended.
	local hangY = feetY(player)
	for _ = 1, FrameStepper.secondsToFrames(0.5) do
		FrameStepper.step(game, 1)
	end
	assertEqual(
		"LadderState",
		player.fsm.currentState.name,
		"expected to keep hanging inside the volume after releasing down"
	)
	assertTrue(
		math.abs(feetY(player) - hangY) <= 2,
		"expected gravity to stay suspended while hanging (drift " .. tostring(math.abs(feetY(player) - hangY)) .. "px)"
	)
end)

test("the bare ladder top walks like ground onto an adjacent flush ledge", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	local player = player1(game)

	mountToTop(game, controller, player)

	controller:press("right")

	local sawNonWalkState = false
	local reachedLedgeCentre = false

	for _ = 1, FrameStepper.secondsToFrames(3) do
		FrameStepper.step(game, 1)
		if player.fsm.currentState.name ~= "WalkIdleState" then
			sawNonWalkState = true
		end
		if Queries.playerPositionV(player).x >= 208 then
			reachedLedgeCentre = true
			break
		end
	end

	controller:release("right")

	assertTrue(reachedLedgeCentre, "expected the player to walk across the bare top onto the flush ledge")
	assertFalse(sawNonWalkState, "expected the whole crossing to stay grounded walking (no mount/climb/fall states)")
end)

test("sliding off the top dismounts directly without a fall or landing sound", function()
	local SoundSpy = require("tests.support.sound_spy")
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	local player = player1(game)

	-- Replicate mountToTop steps 1-3 inline (perch -> descend -> hover),
	-- because step 4's runUntil returns silently on timeout and we need to
	-- instrument the dismount window itself.
	runUntil(game, function()
		return player.fsm.currentState.name == "WalkIdleState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, 180)
	controller:press("down")
	runUntil(game, function()
		return player.fsm.currentState.name == "LadderState" and feetY(player) > TOP_EDGE_Y + 20
	end, 180)
	controller:release("down")
	controller:press("up")
	runUntil(game, function()
		return player.fsm.currentState.name == "LadderState" and math.abs(feetY(player) - TOP_EDGE_Y) <= 3
	end, FrameStepper.secondsToFrames(3))
	controller:release("up")

	-- Slide right off the top onto the flush ledge. The dismount must be a
	-- direct handoff to walking: no FallState frame (which kills vx -- the
	-- stutter) and no 'land' thud.
	local spy = SoundSpy.install()
	local sawFall = false
	local reachedWalk = false
	controller:press("right")
	for _ = 1, FrameStepper.secondsToFrames(2) do
		FrameStepper.step(game, 1)
		if player.fsm.currentState.name == "WalkIdleState" then
			reachedWalk = true
			break
		end
		if player.fsm.currentState.name == "FallState" then
			sawFall = true
		end
	end
	controller:release("right")
	spy.uninstall()

	assertTrue(reachedWalk, "expected the side-slide to dismount onto the ledge")
	assertFalse(sawFall, "expected no fall frame during a ground-adjacent dismount")
	for _, name in ipairs(spy.played) do
		assertFalse(
			name == "land",
			"expected no landing sound on a direct dismount (played: " .. table.concat(spy.played, ",") .. ")"
		)
	end
end)
