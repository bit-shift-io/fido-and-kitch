-- The Story entity driven through the real Game/Map/World/Player stack: use
-- toggles a per-player speech bubble, leaving the sensor's overlap auto-dismisses
-- it, and the 0.5s cooldown gates re-triggering. The typewriter pacing and the
-- cooldown arithmetic themselves are unit-tested in tests/unit/story_test.lua.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = "tests/fixtures/story_room.tmj"

-- story1 occupies x:160..192, y:128..160 (floor top is y=160; Tiled objects are
-- bottom-anchored). A resting player (20x30 collider, centre y=145) overlaps it
-- when its centre x is in (150, 202); the use-trigger query window (±16px) is
-- wider, (144, 208). Walking right ~0.9s from the spawn puts the player inside.

local function settle(game)
	FrameStepper.step(game, 60)
end

local function players(game)
	return game.fsm.currentState.players
end

local function pressUse(game, controller)
	controller:press("rshift") -- P1's use key
	FrameStepper.step(game, 2)
	controller:release("rshift")
end

test("pressing use over a story shows the bubble; walking away auto-dismisses it", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local story = Queries.findEntityByName(map, "story1")
	local player = players(game)[1]
	assertTrue(story ~= nil, "fixture check: story1 should be present")

	-- walk onto the story sensor and press use
	holdFor(game, controller, "right", 0.9)
	pressUse(game, controller)

	assertTrue(story.bubbles[player] ~= nil, "expected a bubble record for the triggering player")
	assertTrue(story.bubbles[player].visible, "expected the use to show the player's bubble")

	-- while still overlapping, the typewriter reveal keeps advancing
	FrameStepper.step(game, 3)
	assertTrue(story.bubbles[player].revealElapsed > 0, "expected the reveal to be in progress")

	-- walking away from the sensor auto-dismisses the bubble
	holdFor(game, controller, "left", 0.3)
	FrameStepper.step(game, 2)
	assertFalse(story.bubbles[player].visible, "expected the bubble to dismiss once the player left the sensor")
end)

test("re-triggering is gated by the cooldown, then allowed again once it drains", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local story = Queries.findEntityByName(map, "story1")
	local player = players(game)[1]

	-- show the bubble, then walk off (dismissal starts the cooldown)
	holdFor(game, controller, "right", 0.9)
	pressUse(game, controller)
	holdFor(game, controller, "left", 0.3)
	FrameStepper.step(game, 2)
	assertFalse(story.bubbles[player].visible, "fixture check: bubble should be dismissed")

	-- return within the 0.5s cooldown window: use is ignored
	holdFor(game, controller, "right", 0.3)
	pressUse(game, controller)
	assertFalse(story.bubbles[player].visible, "expected the cooldown to block an immediate re-trigger")

	-- once the cooldown drains, use shows the bubble again
	FrameStepper.step(game, 40)
	pressUse(game, controller)
	assertTrue(story.bubbles[player].visible, "expected use to show the bubble again after the cooldown")
end)
