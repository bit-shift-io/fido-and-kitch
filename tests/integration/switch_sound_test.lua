-- Switch/lever on-off sounds, driven through the real Game/Map/World stack.
-- Switch:use(user) is the public entry point Usable:use forwards to once a
-- player has walked up and pressed use (already covered generically by
-- Usable/Player wiring elsewhere) -- this file calls it directly so the
-- sound assertions aren't coupled to reproducing that walk-and-press
-- choreography through real physics.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/switch_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('using an off switch plays the on sound', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, 'switch1')
	local spy = SoundSpy.install()
	switch:use(player1(game))

	spy.uninstall()
	assertEqual('on', switch.state)
	assertEqual('on', spy.played[1])
end)

test('using an on switch plays the off sound', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, 'switch1')
	switch:use(player1(game)) -- turn it on first
	assertEqual('on', switch.state, 'fixture check: expected the switch to be on before this test')

	local spy = SoundSpy.install()
	switch:use(player1(game))

	spy.uninstall()
	assertEqual('off', switch.state)
	assertEqual('off', spy.played[1])
end)
