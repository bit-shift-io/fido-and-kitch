-- Door open/close sounds, driven through a real switch on the real
-- Game/Map/World stack. See tests/integration/door_test.lua for the
-- blocking/crossing coverage this file doesn't repeat.
--
-- Note the keys are wired the right way round here: `open` on opening and
-- `close` on closing. src/entities/drawbridge.lua has them swapped, which
-- is not a convention to copy.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/door_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function flipSwitch(game)
	Queries.findEntityByName(map, 'switch1'):use(player1(game))
end

-- SoundSpy records every sound the whole game plays, and flipping the
-- switch necessarily plays the switch's own 'on'/'off' toggle first -- so
-- these assert the door's key is among them, not that it came first.
local function assertPlayed(spy, key)
	for _, played in ipairs(spy.played) do
		if played == key then
			return
		end
	end
	assertTrue(false, string.format('expected a "%s" sound to have played, got: %s', key, table.concat(spy.played, ', ')))
end

test('the door plays an open sound when its switch unlocks it', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local door = Queries.findEntityByType(map, 'door')
	local spy = SoundSpy.install()

	flipSwitch(game)
	FrameStepper.step(game, 1)

	spy.uninstall()
	assertEqual('opening', door.state, 'fixture check: expected the door to start opening')
	assertPlayed(spy, 'open')
end)

test('the door plays a close sound when its switch relocks it', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local door = Queries.findEntityByType(map, 'door')
	flipSwitch(game)
	FrameStepper.step(game, 60)
	assertEqual('open', door.state, 'fixture check: expected the door to be open before relocking it')

	local spy = SoundSpy.install()
	flipSwitch(game)
	FrameStepper.step(game, 1)

	spy.uninstall()
	assertEqual('closing', door.state, 'fixture check: expected the door to start closing')
	assertPlayed(spy, 'close')
end)
