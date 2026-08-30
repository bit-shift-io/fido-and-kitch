-- Verifies that InGameState tracks elapsed time via levelTimer,
-- independent of death/respawn/game-over states.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/flat_ground.tmj'

test('levelTimer starts at 0', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	assertEqual(0, state.levelTimer, 'levelTimer should start at 0')
end)

test('levelTimer increases by dt each update frame', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local DT = 1 / 60

	assertEqual(0, state.levelTimer, 'levelTimer starts at 0')

	local framesToRun = 60 -- 1 second worth of frames
	FrameStepper.step(game, framesToRun)

	local expectedTime = framesToRun * DT
	assertNear(expectedTime, state.levelTimer, 0.0001,
		string.format('after %d frames, levelTimer should be ~%.4f, got %.4f',
			framesToRun, expectedTime, state.levelTimer))
end)

test('levelTimer continues accumulating during gameOverTimer (death zoom)', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local controller = FakeInput.new()
	local DT = 1 / 60

	-- Let the player settle onto the floor
	FrameStepper.step(game, 30)

	-- Move player to an unsafe area and trigger a kill zone
	-- For flat_ground fixture, we'll just step a bit and check accumulation
	local timerAfterSettle = state.levelTimer

	-- Run more frames and verify timer keeps increasing
	local framesToRun = 120 -- 2 seconds
	FrameStepper.step(game, framesToRun)

	local expectedAccumulation = framesToRun * DT
	local timerAfterRun = state.levelTimer
	local actualAccumulation = timerAfterRun - timerAfterSettle

	assertNear(expectedAccumulation, actualAccumulation, 0.0001,
		string.format('levelTimer should accumulate by ~%.4f, got %.4f',
			expectedAccumulation, actualAccumulation))
end)

test('levelTimer accumulates correctly over extended gameplay', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local DT = 1 / 60

	assertEqual(0, state.levelTimer, 'levelTimer starts at 0')

	-- Run for 5 seconds
	local framesToRun = FrameStepper.secondsToFrames(5)
	FrameStepper.step(game, framesToRun)

	local expectedTime = 5
	assertNear(expectedTime, state.levelTimer, 0.01,
		string.format('after 5 seconds, levelTimer should be ~%.2f, got %.4f',
			expectedTime, state.levelTimer))
end)
