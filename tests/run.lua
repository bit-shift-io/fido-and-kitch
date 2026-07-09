local defaultTestFiles = {
	'tests/runner_smoke_test.lua',
	'tests/player_movement_test.lua',
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
