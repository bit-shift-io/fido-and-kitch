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

local MAP = 'tests/fixtures/ladder_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('mounting a ladder plays the mount sound', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- settle onto the floor, still overlapping the ladder column

	local spy = SoundSpy.install()
	holdFor(game, controller, 'up', 0.5)

	spy.uninstall()
	assertEqual('LadderState', player1(game).fsm.currentState.name, 'fixture check: expected the player to have mounted the ladder')
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertTrue(seen.mount, 'expected the mount sound to have played')
end)
