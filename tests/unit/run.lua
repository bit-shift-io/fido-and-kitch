local defaultTestFiles = {
	'tests/unit/runner_smoke_test.lua',
	'tests/unit/player_movement_test.lua',
	'tests/unit/bump_physics_test.lua',
	'tests/unit/lives_test.lua',
	'tests/unit/kill_zone_test.lua',
	'tests/unit/safe_position_test.lua',
	'tests/unit/ground_support_test.lua',
	'tests/unit/camera_test.lua',
	'tests/unit/timeline_reverse_test.lua',
	'tests/unit/drawbridge_test.lua',
	'tests/unit/blocker_test.lua',
	'tests/unit/map_parallax_test.lua',
	'tests/unit/pushable_support_test.lua',
	'tests/unit/pressure_switch_test.lua',
	'tests/unit/sound_test.lua',
	'tests/unit/switchable_test.lua',
	'tests/unit/story_test.lua',
	'tests/unit/npc_death_test.lua',
	'tests/unit/spider_wrap_release_test.lua',
	'tests/unit/web_test.lua',
	'tests/unit/external_tileset_test.lua',
	'tests/unit/tmx_test.lua',
	'tests/unit/tmx_template_test.lua',
	'tests/unit/entity_lifecycle_test.lua',
	'tests/unit/particles_test.lua',
	'tests/unit/usable_sparkle_test.lua',
	'tests/unit/coin_identity_test.lua',
	'tests/unit/game_hud_test.lua',
	'tests/unit/hud_centering_test.lua',
	'tests/unit/level_generator_rng_test.lua',
	'tests/unit/level_generator_tmx_writer_test.lua',
	'tests/unit/level_generator_main_test.lua',
	'tests/unit/level_generator_movement_model_test.lua',
	'tests/unit/level_generator_layout_test.lua',
	'tests/unit/level_generator_plan_test.lua',
	'tests/unit/level_generator_walkthrough_test.lua',
	'tests/unit/level_generator_rules_test.lua',
	'tests/unit/level_generator_decorate_test.lua',
	'tests/unit/teleport_start_disabled_test.lua',
	'tests/unit/level_generator_coop_test.lua',
	'tests/unit/level_generator_pushables_test.lua',
	'tests/unit/level_generator_dressing_test.lua',
	'tests/unit/input_manager_test.lua',
	'tests/unit/settings_test.lua',
	'tests/unit/map_list_selection_test.lua',
	'tests/unit/map_card_test.lua',
	'tests/unit/ladder_merge_test.lua',
	'tests/unit/ladder_annotation_test.lua',
	'tests/unit/ladder_entity_test.lua',
	'tests/unit/ladder_toggle_test.lua',
	'tests/unit/mover_platform_test.lua',
	'tests/unit/mover_platform_physics_test.lua',
	'tests/unit/replicator_test.lua',
	'tests/unit/export_png_test.lua',
}

local tests = {}
local failures = {}

local function valueToString(value)
	if type(value) == 'string' then
		return string.format('%q', value)
	end
	return tostring(value)
end

local function fail(message)
	error(message, 2)
end

function test(name, fn)
	table.insert(tests, {
		name=name,
		fn=fn,
	})
end

function assertTrue(value, message)
	if not value then
		fail(message or 'expected value to be truthy')
	end
end

function assertFalse(value, message)
	if value then
		fail(message or 'expected value to be falsey')
	end
end

function assertEqual(expected, actual, message)
	if expected ~= actual then
		fail(message or string.format('expected %s, got %s', valueToString(expected), valueToString(actual)))
	end
end

function assertNear(expected, actual, tolerance, message)
	tolerance = tolerance or 0.000001
	if math.abs(expected - actual) > tolerance then
		fail(message or string.format('expected %s to be within %s of %s', valueToString(actual), valueToString(tolerance), valueToString(expected)))
	end
end

local function testFilesFromArgs()
	local files = {}
	for i = 1, #arg do
		table.insert(files, arg[i])
	end

	if #files == 0 then
		return defaultTestFiles
	end

	return files
end

local function loadTestFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(string.format('Could not load %s: %s', path, err))
	end
	chunk()
end

local function run()
	local files = testFilesFromArgs()

	for _, file in ipairs(files) do
		loadTestFile(file)
	end

	for _, case in ipairs(tests) do
		local ok, err = xpcall(case.fn, debug.traceback)
		if ok then
			print('✓ ' .. case.name)
		else
			table.insert(failures, {
				name=case.name,
				error=err,
			})
			print('✗ ' .. case.name)
			print(err)
		end
	end

	local passed = #tests - #failures
	print(string.format('\n%d passed, %d failed', passed, #failures))

	if #failures > 0 then
		os.exit(1)
	end
end

run()
