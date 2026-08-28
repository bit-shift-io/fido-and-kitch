-- Key pickup sound, driven through the real Game/Map/World/Player stack.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/key_room.tmj'

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

test('the key tint is wired and drawn before the sprite', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local key = Queries.findEntityByType(map, 'key')
	assertTrue(key ~= nil, 'fixture check: key should be present before pickup')

	local tintIndex, spriteIndex = nil, nil
	local tint = nil
	for i, component in ipairs(key.components) do
		if component.type == 'tint' then
			tintIndex = i
			tint = component
		elseif component.type == 'sprite' then
			spriteIndex = i
		end
	end

	assertTrue(tint ~= nil, 'expected the key to carry a Tint component')
	local expected = {1, 0.2, 0.2, 1}
	for i = 1, 4 do
		assertEqual(expected[i], tint.color[i], 'expected the red key fixture to tint red (channel ' .. i .. ')')
	end

	assertTrue(tintIndex ~= nil, 'expected to find the Tint component in the draw order')
	assertTrue(spriteIndex ~= nil, 'expected to find the Sprite component in the draw order')
	assertTrue(tintIndex < spriteIndex,
		'expected the Tint to be added before the Sprite so its setColor lands before the art renders')
end)
