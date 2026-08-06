-- The story entity's screen-space speech bubble under real LÖVE, with real
-- rendering: the bubble appears above the entity when a player presses use,
-- the typewriter reveal advances, and the frame is captured so the rounded
-- box, tail, and centred text are actually exercised against love.graphics --
-- something the headless tiers cannot do (their love.* mock never draws).
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local Capture = require('tests.support.capture')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

test('a story bubble shows, reveals, and renders over its entity', function()
	local game = GameHarness.startGame('tests/fixtures/story_room.lua', {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 60) -- land and settle

	local story = Queries.findEntityByName(map, 'story1')
	local player = game.fsm.currentState.players[1]
	assertTrue(story ~= nil, 'fixture check: story1 should be present')

	-- walk onto the story sensor and press use (P1's use key is rshift)
	holdFor(game, controller, 'right', 0.9)
	controller:press('rshift')
	FrameStepper.step(game, 2)
	controller:release('rshift')

	assertTrue(story.bubbles[player] ~= nil, 'expected a bubble record for the triggering player')
	assertTrue(story.bubbles[player].visible, 'expected the use to show the player\'s bubble')

	-- let the typewriter reveal advance, then draw the mid-reveal frame
	FrameStepper.step(game, 5)
	assertTrue(story.bubbles[player].revealElapsed > 0, 'expected the reveal to be in progress')

	Capture.capture('story_bubble')
end)
