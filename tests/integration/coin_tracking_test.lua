-- Walks P1 onto the single coin in coin_room (spawn 64,128 32x32; coin at
-- 120,160 20x20). Rect.centreOfMapObject is bottom-anchored (y - height/2),
-- so the coin's game centre is (130,150); the event must carry it. Asserts
-- the coin is also in the inventory under the constant name 'coin' (Task 1).
local GameHarness = require('tests.support.game_harness')
local FakeInput = require('tests.support.fake_input').FakeInput
local FrameStepper = require('tests.support.frame_stepper')

local MAP = 'tests/fixtures/coin_room.lua'

test('walking onto a coin emits coin_collected with the coin position', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local controller = FakeInput.new()
	local EventBus = require('src.utils.event_bus')

	local collected = {}
	local disconnect = EventBus.on('coin_collected', function(data)
		table.insert(collected, data)
	end)

	controller:press('right')
	FrameStepper.step(game, 180)
	controller:release('right')

	disconnect()

	assertEqual(1, #collected, 'expected exactly one coin_collected event')
	assertEqual(130, collected[1].x, 'event should carry the coin centre x')
	assertEqual(150, collected[1].y, 'event should carry the coin centre y')
	assertTrue(state.players[1].inventory:hasItems('coin', 1), 'the coin should be in the player inventory under the constant name')
end)

test('InGameState counts the level total and increments on collection', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local controller = FakeInput.new()

	assertEqual(1, state.totalCoins, 'fixture has a single coin')
	assertEqual(0, state.coinsCollected, 'no coins collected yet')

	controller:press('right')
	FrameStepper.step(game, 180)
	controller:release('right')

	assertEqual(1, state.coinsCollected, 'coin collection should be counted')
end)
