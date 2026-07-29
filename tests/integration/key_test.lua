-- Key pickup sound, driven through the real Game/Map/World/Player stack.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/key_room.lua'

test('walking into a key plays its pickup sound', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- let the player settle onto the floor

	-- Key doesn't carry its Tiled object name onto self.name, so address it by
	-- type instead (only one key in this fixture)
	assertTrue(Queries.findEntityByType(map, 'key') ~= nil, 'fixture check: key should be present before pickup')

	local spy = SoundSpy.install()
	holdFor(game, controller, 'right', 2)

	spy.uninstall()
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertTrue(seen.pickup, 'expected the key to play a pickup sound')
end)
