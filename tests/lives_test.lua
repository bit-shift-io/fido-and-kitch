local Lives = require('src.player.lives')

test('default lives count is 2', function()
	assertEqual(2, Lives.defaultCount())
end)

test('death at 2 lives respawns with 1 life left', function()
	local result = Lives.applyDeath(2)

	assertEqual(1, result.lives)
	assertEqual('respawn', result.outcome)
end)

test('death at 1 life respawns with 0 lives left', function()
	local result = Lives.applyDeath(1)

	assertEqual(0, result.lives)
	assertEqual('respawn', result.outcome)
end)

test('death at 0 lives triggers game over', function()
	local result = Lives.applyDeath(0)

	assertEqual(0, result.lives)
	assertEqual('gameover', result.outcome)
end)
