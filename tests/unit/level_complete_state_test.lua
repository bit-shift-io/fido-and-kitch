-- Verifies LevelCompleteState:load computes the same score/medal as
-- LevelScore.compute for the props InGameState hands it, with no rendering
-- involved (love.graphics.newFont is only called from :enter, not :load).
require("tests.support.headless_bootstrap")
local LevelCompleteState = require("src.states.level_complete_state")
local LevelScore = require("src.scoring.level_score")

local function newState()
	return LevelCompleteState({})
end

test("load computes livesPct/coinsPct/totalPct/medal matching LevelScore.compute", function()
	local state = newState()

	local props = {
		map = "res/map/sandbox.tmj",
		lives = 1,
		maxLives = 2,
		coins = 4,
		totalCoins = 5,
		time = 95,
	}

	state:load(props)

	local expected = LevelScore.compute({
		livesRemaining = props.lives,
		maxLives = props.maxLives,
		coinsCollected = props.coins,
		totalCoins = props.totalCoins,
	})

	assertEqual(expected.livesPct, state.score.livesPct)
	assertEqual(expected.coinsPct, state.score.coinsPct)
	assertEqual(expected.totalPct, state.score.totalPct)
	assertEqual(expected.medal, state.score.medal)
end)

test("load stores the raw props for display (hearts, coins, time)", function()
	local state = newState()

	state:load({
		map = "res/map/sandbox.tmj",
		lives = 2,
		maxLives = 2,
		coins = 10,
		totalCoins = 10,
		time = 65,
	})

	assertEqual(2, state.livesRemaining)
	assertEqual(2, state.maxLives)
	assertEqual(10, state.coinsCollected)
	assertEqual(10, state.totalCoins)
	assertEqual(65, state.timeTaken)
	assertEqual("gold", state.score.medal)
end)

test("load defaults missing props to zero rather than erroring", function()
	local state = newState()

	state:load(nil)

	assertEqual(0, state.livesRemaining)
	assertEqual(0, state.maxLives)
	assertEqual(0, state.coinsCollected)
	assertEqual(0, state.totalCoins)
	assertEqual(0, state.timeTaken)
end)
