-- Exit door open sound, driven through the real Game/Map/World stack.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/exit_door_room.lua'

test('the exit door plays an open sound when the last actor exits (actor_count reaches 0)', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local door = Queries.findEntityByType(map, 'exit_door')
	assertTrue(door ~= nil, 'fixture check: exit door should be present')

	local spy = SoundSpy.install()
	door:subtract(1) -- actor_count 1 -> 0, triggers ExitDoor:open()

	spy.uninstall()
	assertEqual('open', door.state, 'fixture check: expected the door to be open once the counter hits zero')
	assertEqual('open', spy.played[1])
end)
