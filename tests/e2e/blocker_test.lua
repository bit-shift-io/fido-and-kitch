-- The blocker's headed scenario: a locked blocker stopping a player under
-- real rendering, and the same blocker letting them through once its switch
-- is flipped. The decision logic is covered headless in
-- tests/unit/blocker_test.lua and the blocking/timing behaviour in
-- tests/integration/blocker_test.lua; what only a real window can give is a
-- reviewable frame of each state, plus real physics driving the crossing.
--
-- Runs against res/map/sandbox.tmj -- the demo placement a level designer
-- would author (template-instanced blocker, switch wired to it), not a
-- purpose-built fixture.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")
local Capture = require("tests.support.capture")

local FakeInput = FakeInputModule.FakeInput
local MAP = "res/map/sandbox.tmj"

-- the blocker object spans x=256..288 (see res/map/sandbox.tmj); its
-- barrier is the middle 60% of that, centred on x=272
local BLOCKER_CENTRE_X = 272
local BARRIER_HALF_WIDTH = 9.6
local PLAYER_HALF_WIDTH = 10
-- clear of the blocker's own footprint, on the far side
local FAR_SIDE_X = 320
local MAX_FRAMES = 300

-- The sandbox's push_box sits between the spawn point and the blocker, so a
-- player walking from spawn is stopped by the box rather than by the
-- blocker. Starting them past it keeps this scenario about the blocker.
local START_X = 224

test("a locked blocker stops the player under real rendering, and its switch lets them through", function()
	local game = GameHarness.startGame(MAP, { real = true })
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let the player land and settle

	local player = game.fsm.currentState.players[1]
	local blocker = Queries.findEntityByType(map, "blocker")
	assertTrue(blocker ~= nil, "expected the sandbox to contain a blocker")
	assertEqual("closed", Queries.blockerState(blocker), "expected the blocker to start locked")

	player.collider:setX(START_X)
	FrameStepper.step(game, 10)

	controller:press("right")
	for _ = 1, MAX_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), "the player must never die walking up to the blocker")
	end
	controller:release("right")
	Capture.capture("01_locked")

	local blockedX = Queries.playerPositionV(player).x
	assertTrue(blockedX > START_X, "expected the player to actually walk up to the blocker")
	assertTrue(
		blockedX + PLAYER_HALF_WIDTH <= BLOCKER_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		string.format("expected the locked blocker to stop the player, but they reached x=%.1f", blockedX)
	)

	-- Switch:use(user) is the entry point Usable:use forwards to once a
	-- player walks up and presses use -- called directly here (the
	-- precedent set by tests/integration/switch_sound_test.lua) so the
	-- scenario stays about the blocker rather than the press choreography.
	Queries.findEntityByName(map, "blocker_switch"):use(player)

	local opened = false
	for _ = 1, MAX_FRAMES do
		FrameStepper.step(game, 1)
		if Queries.blockerState(blocker) == "open" then
			opened = true
			break
		end
	end
	assertTrue(opened, "expected flipping the switch to open the blocker")
	Capture.capture("02_open")

	controller:press("right")
	local crossed = false
	for _ = 1, MAX_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), "the player must never die crossing the doorway")
		if Queries.playerPositionV(player).x >= FAR_SIDE_X then
			crossed = true
			break
		end
	end
	controller:release("right")
	Capture.capture("03_crossed")

	assertTrue(crossed, "expected the player to walk through the unlocked doorway and out the far side")
end)
