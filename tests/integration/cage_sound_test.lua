-- Cage/bird-release sound, driven through the real Game/Map/World stack.
-- Cage:use(user) is the entity's own public method (as with switch_sound_test
-- calling Switch:use directly) -- the Usable requiredItem gating in front of
-- it is generic Usable/Player wiring already covered elsewhere.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/cage_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('using a cage plays its open sound', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	-- Cage doesn't carry its Tiled object name onto self.name, so address it
	-- by type instead (only one cage in this fixture)
	local cage = Queries.findEntityByType(map, 'cage')
	assertTrue(cage ~= nil, 'fixture check: cage should be present')

	local spy = SoundSpy.install()
	cage:use(player1(game))

	spy.uninstall()
	assertEqual('open', spy.played[1])
end)
