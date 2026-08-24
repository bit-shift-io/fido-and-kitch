-- Integration test runner. Mirrors tests/unit/run.lua's test()/assert*/file-list
-- pattern so both suites feel like one testing convention; kept separate so
-- ./test-unit.sh stays fast and untouched (see .scratch/integration-testing/).
--
-- lib/sti is a directory module (lib/sti/init.lua); the default luajit/lua
-- package.path only searches system init.lua locations, not a local one, so
-- add it -- real LÖVE resolves requires differently and never hits this gap.
package.path = './?/init.lua;' .. package.path

local defaultTestFiles = {
	'tests/integration/harness_smoke_test.lua',
	'tests/integration/ladder_slab_slide_test.lua',
	'tests/integration/ladder_top_test.lua',
	'tests/integration/ladder_switch_test.lua',
	'tests/integration/ladder_catch_slide_test.lua',
	'tests/integration/ladder_seam_test.lua',
	'tests/integration/ladder_flank_test.lua',
	'tests/integration/npc_ladder_test.lua',
	'tests/integration/movement_test.lua',
	'tests/integration/player_spawn_round_robin_test.lua',
	'tests/integration/all_maps_load_test.lua',
	'tests/integration/capture_guard_test.lua',
	'tests/integration/drawbridge_test.lua',
	'tests/integration/blocker_test.lua',
	'tests/integration/blocker_sound_test.lua',
	'tests/integration/pushable_test.lua',
	'tests/integration/boulder_test.lua',
	'tests/integration/pressure_switch_test.lua',
	'tests/integration/pushable_reset_test.lua',
	'tests/integration/coin_test.lua',
	'tests/integration/player_sound_test.lua',
	'tests/integration/drawbridge_sound_test.lua',
	'tests/integration/switch_sound_test.lua',
	'tests/integration/switch_animation_test.lua',
	'tests/integration/switchable_teleport_test.lua',
	'tests/integration/key_test.lua',
	'tests/integration/cage_sound_test.lua',
	'tests/integration/exit_door_sound_test.lua',
	'tests/integration/jump_pad_sound_test.lua',
	'tests/integration/kill_zone_sound_test.lua',
	'tests/integration/npc_kill_zone_respawn_test.lua',
	'tests/integration/spider_wrap_release_test.lua',
	'tests/integration/teleport_sound_test.lua',
	'tests/integration/ladder_sound_test.lua',
	'tests/integration/ladder_platform_mount_test.lua',
	'tests/integration/ladder_top_exit_test.lua',
	'tests/integration/ladder_merge_climb_test.lua',
	'tests/integration/mover_platform_test.lua',
	'tests/integration/replicator_test.lua',
	'tests/integration/pressure_switch_sound_test.lua',
	'tests/integration/external_tileset_test.lua',
	'tests/integration/tmx_test.lua',
	'tests/integration/coin_tracking_test.lua',
	'tests/integration/player_died_payload_test.lua',
	'tests/integration/story_test.lua',
	'tests/integration/level_generator_walking_skeleton_test.lua',
	'tests/integration/level_generator_terrain_test.lua',
	'tests/integration/level_generator_objective_spine_test.lua',
	'tests/integration/level_generator_rules_test.lua',
	'tests/integration/level_generator_hazards_test.lua',
	'tests/integration/level_generator_coop_test.lua',
	'tests/integration/level_generator_pushables_test.lua',
	'tests/integration/level_generator_dressing_test.lua',
	'tests/integration/level_generator_end_to_end_test.lua',
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
