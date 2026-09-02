-- Blocker open/close sounds, driven through a real switch on the real
-- Game/Map/World stack. See tests/integration/blocker_test.lua for the
-- blocking/crossing coverage this file doesn't repeat.
--
-- Note the keys are wired the right way round here: `open` on opening and
-- `close` on closing. src/entities/drawbridge.lua has them swapped, which
-- is not a convention to copy.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")
local SoundSpy = require("tests.support.sound_spy")

local MAP = "tests/fixtures/blocker_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function flipSwitch(game)
	Queries.findEntityByName(map, "switch1"):use(player1(game))
end

-- SoundSpy records every sound the whole game plays, and flipping the
-- switch necessarily plays the switch's own 'on'/'off' toggle first -- so
-- these assert the blocker's key is among them, not that it came first.
local function assertPlayed(spy, key)
	for _, played in ipairs(spy.played) do
		if played == key then
			return
		end
	end
	assertTrue(
		false,
		string.format('expected a "%s" sound to have played, got: %s', key, table.concat(spy.played, ", "))
	)
end

test("the blocker plays an open sound when its switch unlocks it", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local blocker = Queries.findEntityByType(map, "blocker")
	local spy = SoundSpy.install()

	flipSwitch(game)
	FrameStepper.step(game, 1)

	spy.uninstall()
	assertEqual("opening", blocker.state, "fixture check: expected the blocker to start opening")
	assertPlayed(spy, "open")
end)

test("the blocker plays a close sound when its switch relocks it", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local blocker = Queries.findEntityByType(map, "blocker")
	flipSwitch(game)
	FrameStepper.step(game, 125) -- let the blocker finish opening (1s animation)
	assertEqual("open", blocker.state, "fixture check: expected the blocker to be open before relocking it")

	local spy = SoundSpy.install()
	flipSwitch(game)
	FrameStepper.step(game, 1)

	spy.uninstall()
	assertEqual("closed", blocker.state, "fixture check: expected the blocker to snap closed instantly")
	assertPlayed(spy, "close")
end)
