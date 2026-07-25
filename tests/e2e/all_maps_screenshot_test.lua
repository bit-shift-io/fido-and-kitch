-- Loads every exported map under res/map/ through the real Game/InGameState/
-- Map stack under real LÖVE and captures a screenshot of each -- visual
-- evidence a human or an AI agent can review without launching every map by
-- hand. Enumerated, not hardcoded, so adding a new map needs no test-file
-- changes. Mirrors tests/integration/all_maps_load_test.lua's headless
-- load-every-map check; this is the same idea plus real rendering.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Capture = require('tests.support.capture')

local function listMapFiles()
	local files = {}
	local pipe = io.popen('ls res/map/*.lua 2>/dev/null')
	for path in pipe:lines() do
		table.insert(files, path)
	end
	pipe:close()
	table.sort(files)
	return files
end

local function captureNameFor(path)
	return path:match('([^/]+)%.lua$') or path
end

test('every real map under res/map/ loads and captures a screenshot', function()
	local files = listMapFiles()
	assertTrue(#files > 0, 'expected to find at least one map under res/map/')

	local failures = {}

	for _, path in ipairs(files) do
		local ok, err = pcall(function()
			local game = GameHarness.startGame(path, {real = true})
			FrameStepper.step(game, 5)
			Capture.capture(captureNameFor(path))
		end)

		if not ok then
			table.insert(failures, string.format('%s: %s', path, tostring(err)))
		end
	end

	assertEqual(0, #failures, 'maps failed to load or capture:\n' .. table.concat(failures, '\n'))
end)
