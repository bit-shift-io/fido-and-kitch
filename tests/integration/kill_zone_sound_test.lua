-- Kill zone death-type sound, driven through the real Game/Map/World/Player
-- stack. See tests/unit/kill_zone_test.lua for the pure detection-geometry
-- coverage this file doesn't repeat.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/kill_zone_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('falling into a water kill zone plays the water death sound', function()
	local game = GameHarness.startGame(MAP)
	local spy = SoundSpy.install()

	FrameStepper.step(game, 90) -- fall from spawn straight into the kill zone

	spy.uninstall()
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertTrue(player1(game):isDead(), 'fixture check: expected the player to have died')
	assertTrue(seen.water, 'expected the water death sound to have played')
end)
