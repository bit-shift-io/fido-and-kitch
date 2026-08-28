-- Proves the harness end-to-end: a fixture map loads through the real
-- Game/InGameState/Map/Player stack outside LÖVE, frames step without
-- error, and a player entity exists.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

test('flat_ground loads through the real stack and steps frames without error', function()
	local game = GameHarness.startGame('tests/fixtures/flat_ground.tmj')

	FrameStepper.step(game, 10)

	local ingame = game.fsm.currentState
	assertTrue(#ingame.players > 0, 'expected at least one player to have spawned')
end)
