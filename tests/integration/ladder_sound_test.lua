-- Ladder mount sound, driven through the real Game/Map/World/Player stack.
-- See DECISIONS.md/HANDOFF.md under .scratch/sound-component/: only a mount
-- sound is wired here -- LadderState (src/player/player_states.lua) has no
-- horizontal-slide mechanic to hook a 'slide' sound into, so that half of
-- issue 13 doesn't apply to this codebase as it stands.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local SoundSpy = require('tests.support.sound_spy')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/ladder_fall_catch_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('entering a ladder by mounting or fall-catch plays the mount sound', function()
	local game = GameHarness.startGame(MAP)
	local player = player1(game)

	-- The fixture's spawn drops straight down the ladder column's interior,
	-- so under the no-gravity-zone model the player is caught into
	-- LadderState during the spawn fall -- same LadderState:enter path a
	-- deliberate up/down mount takes.
	local spy = SoundSpy.install()

	local runUntil = require('tests.support.fake_input').runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	spy.uninstall()
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertTrue(seen.mount, 'expected the mount sound to have played on entering the ladder')
end)
