-- Round-robin player spawning: N players are handed out one per spawn point
-- until all players are placed -- extra spawn points must never duplicate
-- players (the old code spawned the full player count at EVERY spawn point,
-- so two spawn points produced four players).
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

-- Player colliders are 20x30; Player:init centres them on
-- (object.x + width*0.5, object.y - height*0.5) with width/height = 50.
local function colliderCentre(player)
	local bounds = player.collider:getBounds()
	return {x = (bounds.left + bounds.right) / 2, y = (bounds.top + bounds.bottom) / 2}
end

test('two spawn points yield exactly two players, one per point, not duplicates', function()
	local game = GameHarness.startGame('tests/fixtures/two_spawn_room.lua')
	FrameStepper.step(game, 10)

	local ingame = game.fsm.currentState
	assertEqual(2, #ingame.players, 'expected exactly two players for two spawn points')

	-- Player 1 -> first spawn point (x=64), player 2 -> second (x=224)
	local p1, p2 = ingame.players[1], ingame.players[2]
	assertEqual(1, p1.index)
	assertEqual(2, p2.index)

	local c1, c2 = colliderCentre(p1), colliderCentre(p2)
	assertTrue(c1.x < c2.x, 'expected player 1 at the left spawn and player 2 at the right spawn')
	assertEqual(64 + 25, c1.x)
	assertEqual(224 + 25, c2.x)
end)

test('more players than spawn points wraps around instead of dropping players', function()
	local game = GameHarness.startGame('tests/fixtures/spider_wrap_room.lua') -- single spawn point
	FrameStepper.step(game, 10)

	local ingame = game.fsm.currentState
	assertEqual(2, #ingame.players, 'expected both players spawned from the single spawn object')

	local c1, c2 = colliderCentre(ingame.players[1]), colliderCentre(ingame.players[2])
	assertEqual(c1.x, c2.x, 'both players share the lone spawn point')
end)
