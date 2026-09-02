-- Player movement sounds (land/step/death), driven through the real
-- Game/Map/World/Player stack. There is no jump in this game: falling (off a
-- ledge, out of a ladder, etc.) is the state machine's "airborne" signal and
-- is silent; 'land' plays on the transition back to WalkIdleState.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local SoundSpy = require("tests.support.sound_spy")

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = "tests/fixtures/flat_ground.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a player falling from spawn stays silent entering FallState and plays land on settling", function()
	local game = GameHarness.startGame(MAP)
	local spy = SoundSpy.install()

	FrameStepper.step(game, 60) -- fall from spawn and settle onto the floor

	spy.uninstall()
	local seen = {}
	for _, name in ipairs(spy.played) do
		seen[name] = true
	end
	assertFalse(seen.jump, "there is no jump in this game: FallState must stay silent")
	assertTrue(seen.land, "expected a land sound when settling back onto the floor")
end)

test("a player playing dead plays the death sound", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle first so death isn't conflated with the fall/land sounds

	local spy = SoundSpy.install()
	player1(game):die("water")

	spy.uninstall()
	assertEqual(1, #spy.played)
	assertEqual("death", spy.played[1])
end)

test("a walking player periodically plays a step sound, but an idle player does not", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- settle

	local spy = SoundSpy.install()
	holdFor(game, controller, "right", 2)
	local stepsWhileWalking = 0
	for _, name in ipairs(spy.played) do
		if name == "step" then
			stepsWhileWalking = stepsWhileWalking + 1
		end
	end
	assertTrue(stepsWhileWalking >= 2, "expected multiple step sounds while walking for 2 seconds")

	local countBeforeIdle = #spy.played
	FrameStepper.step(game, 60) -- a full second idle
	spy.uninstall()
	assertEqual(countBeforeIdle, #spy.played, "expected no step sounds while idle")
end)
