-- The lever switch carries a 5-frame toggle animation: using it must play the
-- strip forward (off -> on, frames 1..5) or in reverse (on -> off, frames
-- 5..1) rather than snapping to the end frame. Driven through the real
-- Game/Map/World stack on tests/fixtures/switch_room.lua.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/switch_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function switchSprite(game)
	local switch = Queries.findEntityByName(map, 'switch1')
	return switch.sprite
end

test('using an off switch plays the forward animation', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, 'switch1')
	local sprite = switchSprite(game)
	assertFalse(sprite:isPlaying(), 'sprite should rest before the first use')
	assertEqual(1, sprite.frameNum)

	switch:use(player1(game))
	assertEqual('on', switch.state)
	assertTrue(sprite:isPlaying(), 'flipping on must start the animation')
	assertEqual('forward', sprite:getDirection())
	assertEqual(1, sprite.frameNum, 'forward playback should start at frame 1')

	FrameStepper.step(game, 12) -- 0.2s in, halfway through the 0.4s strip
	assertTrue(sprite.frameNum > 1 and sprite.frameNum < 5,
		'expected the animation to have advanced, got frame ' .. sprite.frameNum)

	FrameStepper.step(game, 600) -- run the strip to its end
	assertFalse(sprite:isPlaying(), 'animation should stop once the strip completes')
	assertEqual(5, sprite.frameNum, 'switch should rest on the last frame when on')
end)

test('using an on switch plays the reverse animation', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, 'switch1')
	local sprite = switchSprite(game)
	switch:use(player1(game)) -- on first
	FrameStepper.step(game, 660) -- let the forward strip finish
	assertEqual(5, sprite.frameNum)

	switch:use(player1(game)) -- now flip it off
	assertEqual('off', switch.state)
	assertTrue(sprite:isPlaying(), 'flipping off must start the animation')
	assertEqual('reverse', sprite:getDirection())
	assertEqual(5, sprite.frameNum, 'reverse playback should start at frame 5')

	FrameStepper.step(game, 12)
	assertTrue(sprite.frameNum < 5 and sprite.frameNum > 1,
		'expected reverse playback to have advanced, got frame ' .. sprite.frameNum)

	FrameStepper.step(game, 600)
	assertFalse(sprite:isPlaying(), 'reverse animation should stop once the strip completes')
	assertEqual(1, sprite.frameNum, 'switch should rest on the first frame when off')
end)
