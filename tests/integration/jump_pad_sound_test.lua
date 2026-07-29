-- Jump pad launch sound, driven through the real Game/Map/World stack.
-- JumpPad:use(user) is the entity's own public method (as with
-- switch_sound_test/cage_sound_test) -- the Usable wiring in front of it is
-- generic and covered elsewhere.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/jump_pad_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('using a jump pad plays its launch sound', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local pad = Queries.findEntityByName(map, 'jump_pad1')
	assertTrue(pad ~= nil, 'fixture check: jump pad should be present')

	local spy = SoundSpy.install()
	pad:use(player1(game))

	spy.uninstall()
	assertEqual('launch', spy.played[1])
end)
