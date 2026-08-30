local LevelScore = require('src.scoring.level_score')

test('full lives + all coins yields 100% score and gold medal', function()
	local result = LevelScore.compute{
		livesRemaining = 2,
		maxLives = 2,
		coinsCollected = 5,
		totalCoins = 5,
	}

	assertEqual(100, result.livesPct)
	assertEqual(100, result.coinsPct)
	assertEqual(100, result.totalPct)
	assertEqual('gold', result.medal)
end)

test('1 of 2 lives with 0 coins yields 25% score and bronze medal', function()
	local result = LevelScore.compute{
		livesRemaining = 1,
		maxLives = 2,
		coinsCollected = 0,
		totalCoins = 5,
	}

	assertEqual(50, result.livesPct)
	assertEqual(0, result.coinsPct)
	assertEqual(25, result.totalPct)
	assertEqual('bronze', result.medal)
end)

test('1 of 2 lives with all coins yields 75% score and silver medal', function()
	local result = LevelScore.compute{
		livesRemaining = 1,
		maxLives = 2,
		coinsCollected = 5,
		totalCoins = 5,
	}

	assertEqual(50, result.livesPct)
	assertEqual(100, result.coinsPct)
	assertEqual(75, result.totalPct)
	assertEqual('silver', result.medal)
end)

test('zero-coin level treats coin score as 100% regardless of collected', function()
	local result = LevelScore.compute{
		livesRemaining = 1,
		maxLives = 2,
		coinsCollected = 0,
		totalCoins = 0,
	}

	assertEqual(50, result.livesPct)
	assertEqual(100, result.coinsPct)
	assertEqual(75, result.totalPct)
end)

test('exactly 50% total score yields bronze medal (strictly greater for silver)', function()
	local result = LevelScore.compute{
		livesRemaining = 1,
		maxLives = 2,
		coinsCollected = 0,
		totalCoins = 5,
	}

	assertEqual(25, result.totalPct)
	assertEqual('bronze', result.medal)
end)

test('exactly 100% total score yields gold medal', function()
	local result = LevelScore.compute{
		livesRemaining = 2,
		maxLives = 2,
		coinsCollected = 5,
		totalCoins = 5,
	}

	assertEqual(100, result.totalPct)
	assertEqual('gold', result.medal)
end)

test('score above 50% but below 100% yields silver medal', function()
	local result = LevelScore.compute{
		livesRemaining = 2,
		maxLives = 2,
		coinsCollected = 2,
		totalCoins = 5,
	}

	assertNear(70, result.totalPct, 0.1)
	assertEqual('silver', result.medal)
end)

test('percentage calculations handle fractional coins correctly', function()
	local result = LevelScore.compute{
		livesRemaining = 1,
		maxLives = 3,
		coinsCollected = 1,
		totalCoins = 3,
	}

	assertNear(33.333, result.livesPct, 0.1)
	assertNear(33.333, result.coinsPct, 0.1)
	assertNear(33.333, result.totalPct, 0.1)
	assertEqual('bronze', result.medal)
end)
