-- Proves the headed path end-to-end: a fixture map loads through the real
-- Game/InGameState/Map/Player stack under real LÖVE, frames step and are
-- genuinely drawn, and a player entity exists.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")

test("flat_ground loads under real LÖVE and steps frames without error", function()
	local game = GameHarness.startGame("tests/fixtures/flat_ground.tmj", { real = true })

	FrameStepper.step(game, 10)

	local ingame = game.fsm.currentState
	assertTrue(#ingame.players > 0, "expected at least one player to have spawned")

	Capture.capture("spawned")
end)
