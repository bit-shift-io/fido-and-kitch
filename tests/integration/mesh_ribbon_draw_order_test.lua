-- The mesh ribbon trail (speedStreak) must render behind the player sprite,
-- not on top of it. Entity:draw() (src/entity.lua) draws components in
-- addComponent insertion order, so this is a component-ordering test rather
-- than a pixel test.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local tbl = require('src.utils.tbl')

local MAP = 'tests/fixtures/coin_room.tmj'

test('speedStreak component draws before the animations sprite', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local player = game.fsm.currentState.players[1]

	local speedStreakIndex = tbl.findIndexEq(player.components, player.speedStreak)
	local animationsIndex = tbl.findIndexEq(player.components, player.animations)

	assertTrue(speedStreakIndex ~= nil, 'fixture check: speedStreak should be a player component')
	assertTrue(animationsIndex ~= nil, 'fixture check: animations should be a player component')
	assertTrue(speedStreakIndex < animationsIndex, 'speedStreak must draw before animations to render behind the player sprite')
end)
