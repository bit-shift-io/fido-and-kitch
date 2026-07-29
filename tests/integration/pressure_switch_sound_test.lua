-- Pressure switch press/release sounds. See tests/integration/pressure_switch_test.lua
-- for the weight-detection/latching coverage this file doesn't repeat.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/pressure_switch_room.lua'

local SURFACE_TOP = 224
local PLATE_CENTRE_X = 304
local PLAYER_RESTING_Y = SURFACE_TOP - 15

local function settle(game)
	FrameStepper.step(game, 60)
end

local function players(game)
	return game.fsm.currentState.players
end

test('a plate plays its press sound when a weight activates it and its release sound when the weight leaves', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local plate = Queries.findEntityByName(map, 'plate')
	local player = players(game)[1]

	local spy = SoundSpy.install()
	player.collider:setPosition(PLATE_CENTRE_X, PLAYER_RESTING_Y)
	FrameStepper.step(game, 5)

	assertTrue(Queries.pressureSwitchIsActive(plate), 'fixture check: expected the plate to activate')
	assertEqual('press', spy.played[1])

	player.collider:setPosition(PLATE_CENTRE_X - 200, PLAYER_RESTING_Y)
	FrameStepper.step(game, 5)

	spy.uninstall()
	assertFalse(Queries.pressureSwitchIsActive(plate), 'fixture check: expected the plate to release')
	assertEqual('release', spy.played[2])
end)
