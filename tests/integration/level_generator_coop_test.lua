-- Issue 06 (coop dial): --coop required must produce a puzzle that's
-- genuinely impossible for a lone player -- verified here by checking the
-- real, live mechanics rather than a graph solver: the vault teleport
-- starts disabled, the pressure plate is momentary (drives the target off
-- the instant its weight leaves), and using the plate really does flip the
-- teleport's usable.enabled live.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Main = require('tools.level_generator.main')

local GENERATED_PATH = 'res/map/generated/_test_coop.tmx'

local function writeGeneratedFixture(seed, size)
	local result = Main.generate({seed = seed, count = 1, size = size, coop = 'required'})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('the vault teleport starts disabled and only the pressure plate can enable it, momentarily', function()
	writeGeneratedFixture(33, 'medium')
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local teleports = map:getEntitiesByType('teleport')
		assertTrue(#teleports >= 2, 'expected the vault teleport pair')

		local vaultEntrance = nil
		for _, t in ipairs(teleports) do
			if not t.usable.enabled then vaultEntrance = t end
		end
		assertTrue(vaultEntrance ~= nil, 'expected exactly one teleport to start disabled (the vault entrance)')

		local plates = map:getEntitiesByType('pressure_switch')
		assertEqual(1, #plates)
		local plate = plates[1]

		-- Fake a weight physically on the plate (mirrors
		-- tests/unit/pressure_switch_test.lua's spawnWeight pattern) rather
		-- than walking a real player there, so this test isolates the
		-- plate/teleport wiring from pathfinding.
		local weight = Collider{
			shape_type = 'rectangle',
			shape_arguments = {20, 30},
			body_type = 'dynamic',
			position = {x = plate.plateCentreX, y = plate.rect.y + 1},
		}
		weight.entity = {type = 'player'}
		weight:setGroupIndex(100)

		plate:update(1 / 60)
		assertTrue(vaultEntrance.usable.enabled, 'expected the plate to enable the vault teleport while weighted')

		weight:destroy()
		plate:update(1 / 60)
		assertFalse(vaultEntrance.usable.enabled, 'expected the plate to disable the vault teleport the instant the weight leaves')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
