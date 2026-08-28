-- Issue 01 (walking skeleton): the generated .tmj must actually load and
-- play through the real Game/InGameState/Map stack, the same as any
-- hand-made map -- proving the whole pipe (generate -> .tmj -> game) works.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Main = require('tools.level_generator.main')

local GENERATED_PATH = 'res/map/generated/_test_walking_skeleton.tmj'

local function writeGeneratedFixture()
	local result = Main.generate({seed = 4242, count = 1})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('a generated walking-skeleton level loads and steps in the real game', function()
	writeGeneratedFixture()
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local ingame = game.fsm.currentState
		assertEqual(2, #ingame.players, 'expected both players spawned from the single spawn object')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
