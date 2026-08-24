-- Regression: a player hanging inside a ladder volume whose body overlaps
-- the top-slab band must still be able to slide sideways. The slab spans the
-- full column width, so queryHorizontalBlock used to report a wall on BOTH
-- sides whenever the hover position intersected the slab band (e.g. entering
-- a ladder from a platform at slab height) -- up/down worked but left/right
-- were dead even on fresh presses.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/ladder_fall_catch_room.lua'
-- Column x[128,160], volume y[192,352], top slab band y[192,200].
-- Centre y=196 puts the 30px-tall body squarely across the slab band.
local DROP_X, DROP_Y = 144, 196

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('sliding works while hanging with the body across the top-slab band', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	player.collider:setPosition(DROP_X, DROP_Y)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Fresh press right: must slide past the slab band, not be walled in.
	controller:press('right')
	runUntil(game, function()
		return Queries.playerPositionV(player).x > DROP_X + 6
	end, FrameStepper.secondsToFrames(1))
	controller:release('right')
end)

test('descending below the slab band restores normal sliding too', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	player.collider:setPosition(DROP_X, DROP_Y)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	controller:press('down') -- descend out of the slab band
	runUntil(game, function()
		return Queries.playerPositionV(player).y > DROP_Y + 24
	end, 120)
	controller:release('down')

	controller:press('left')
	runUntil(game, function()
		return Queries.playerPositionV(player).x < DROP_X - 6
	end, FrameStepper.secondsToFrames(1))
	controller:release('left')
end)
