-- Issue 02 (terrain and traversal): a generated multi-zone level with
-- ladders must load in the real game and produce actual Ladder entities the
-- player can climb -- not just parse without error.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Main = require('tools.level_generator.main')

local GENERATED_PATH = 'res/map/generated/_test_terrain.tmx'

local function writeGeneratedFixture(seed, size)
	local result = Main.generate({seed = seed, count = 1, size = size})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('a generated terrain level loads with real ladder entities matching the layout', function()
	local Layout = require('tools.level_generator.layout')
	local Rng = require('tools.level_generator.rng')
	local layout = Layout.generate(Rng.new(9), {size = 'medium'})

	writeGeneratedFixture(9, 'medium')
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local ladders = map:getEntitiesByType('ladder')
		assertEqual(#layout.ladders, #ladders, 'expected one Ladder entity per layout ladder')
		for _, ladder in ipairs(ladders) do
			assertTrue(ladder.isLadder, 'expected a real Ladder entity with isLadder set')
		end
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
