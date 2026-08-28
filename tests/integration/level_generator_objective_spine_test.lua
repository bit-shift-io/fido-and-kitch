-- Issue 03 (objective spine): using every generated cage must open the real
-- exit door, through the game's actual all_cages_unlocked mechanism (not
-- the dead actor_count/bird path the docs originally assumed -- see
-- DECISIONS.md Q13). Cage:use(player) is called directly, same as
-- cage_sound_test.lua -- the inventory/requiredItem gating in front of it is
-- generic Usable/Player wiring already covered elsewhere.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Main = require('tools.level_generator.main')

local GENERATED_PATH = 'res/map/generated/_test_objective_spine.tmj'

local function writeGeneratedFixture(seed, size)
	local result = Main.generate({seed = seed, count = 1, size = size})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('using every generated cage opens the exit door', function()
	writeGeneratedFixture(42, 'medium')
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local player1 = game.fsm.currentState.players[1]
		local cages = map:getEntitiesByType('cage')
		assertTrue(#cages >= 1, 'expected at least one generated cage')

		for _, cage in ipairs(cages) do
			cage:use(player1)
		end

		local exitDoors = map:getEntitiesByType('exit_door')
		assertEqual(1, #exitDoors)
		assertTrue(exitDoors[1].usable.enabled, 'expected the exit door to become usable once every cage is used')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
