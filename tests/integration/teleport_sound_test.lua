-- Teleport entry/exit sounds, driven through the real Game/Map/World stack.
-- Teleport:use(user) is the entity's own public method (as with the other
-- Usable-driven entities in this suite) -- the Usable/Player wiring in front
-- of it is generic and covered elsewhere.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/teleport_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('using a teleport plays the entry sound at the source and the exit sound at the destination', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local source = Queries.findEntityByName(map, 'teleport_a')
	local destination = Queries.findEntityByName(map, 'teleport_b')
	assertTrue(source ~= nil and destination ~= nil, 'fixture check: both teleports should be present')

	local spy = SoundSpy.install()
	source:use(player1(game))

	spy.uninstall()
	assertEqual('in', spy.played[1])
	assertEqual('out', spy.played[2])
end)
