-- Coin pickup sound, driven through the real Game/Map/World/Player stack.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/coin_room.tmj'

test('walking into a coin plays its pickup sound', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- let the player settle onto the floor

	assertTrue(Queries.findEntityByName(map, 'coin1') ~= nil, 'fixture check: coin should be present before pickup')

	local spy = SoundSpy.install()
	holdFor(game, controller, 'right', 2)

	spy.uninstall()
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertTrue(seen.pickup, 'expected the coin to play a pickup sound')
end)
