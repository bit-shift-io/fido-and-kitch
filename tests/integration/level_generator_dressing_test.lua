-- Issue 08 (enemies and dressing): the generated background/coins/enemies
-- must load as real entities in the actual game, not just valid-looking TMX.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Main = require('tools.level_generator.main')

-- NPC entities never reliably get self.name/self.type set from the Tiled
-- object (src/npc/npc_base.lua's Spider/Robot :init don't forward the raw
-- tiled object into Entity.init, only the merged config) -- a pre-existing
-- gap, not something this feature introduced (the game's own spider tests
-- already fail on a related issue: see the baseline 16 pre-existing
-- integration failures). NPCRegistry.spawn unconditionally sets
-- npc._typeName, so that's the reliable way to count spawned NPCs by type.
-- Required lazily (inside the test) since it needs the Class global that
-- only exists after GameHarness has booted globals.
local function countNpcsByType(typeName)
	local NPCRegistry = require('src.npc.npc_registry')
	local count = 0
	for _, npc in ipairs(NPCRegistry.getAll()) do
		if npc._typeName == typeName then count = count + 1 end
	end
	return count
end

local GENERATED_PATH = 'res/map/generated/_test_dressing.tmj'

local function writeGeneratedFixture(seed, size, difficulty)
	local result = Main.generate({seed = seed, count = 1, size = size, difficulty = difficulty})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('a difficulty-5 generated level loads real coins and enemies, and a real background', function()
	writeGeneratedFixture(55, 'large', 5)
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local coins = map:getEntitiesByType('coin')
		assertTrue(#coins >= 1, 'expected at least one real coin entity')

		local enemyCount = countNpcsByType("npc_spider") + countNpcsByType("npc_robot")
		assertTrue(enemyCount >= 1, 'expected at least one real enemy entity')

		assertTrue(map.backgroundMap ~= nil, 'expected a loaded background map')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)

test('a difficulty-1 generated level loads with zero enemies', function()
	writeGeneratedFixture(55, 'large', 1)
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local enemyCount = countNpcsByType("npc_spider") + countNpcsByType("npc_robot")
		assertEqual(0, enemyCount)
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
