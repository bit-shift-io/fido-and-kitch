-- Loads every exported map under res/map/ through the real Game/InGameState/
-- Map stack and steps a few frames, so a broken Tiled export or a bad entity
-- `type` reference in any shipped level is caught automatically. Enumerated,
-- not hardcoded, so adding a new map needs no test-file changes.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

local function listMapFiles()
	local files = {}
	local pipe = io.popen('ls res/map/*.lua res/map/*.tmx 2>/dev/null')
	for path in pipe:lines() do
		table.insert(files, path)
	end
	pipe:close()
	table.sort(files)
	return files
end

test('every real map under res/map/ loads and steps a few frames without error', function()
	local files = listMapFiles()
	-- Asserted explicitly, not just "> 0": a glob that silently starts
	-- returning zero files (e.g. a typo'd pattern after some future
	-- reorganisation) would otherwise still pass every per-map assertion
	-- below, covering nothing while looking green.
	assertEqual(5, #files, 'expected exactly 5 maps under res/map/ (fab1, ll1, ll2, lurid_2p_01, sandbox), found:\n'
		.. table.concat(files, '\n'))

	local failures = {}

	for _, path in ipairs(files) do
		local ok, err = pcall(function()
			local game = GameHarness.startGame(path)
			FrameStepper.step(game, 5)
		end)

		if not ok then
			table.insert(failures, string.format('%s: %s', path, tostring(err)))
		end
	end

	assertEqual(0, #failures, 'maps failed to load:\n' .. table.concat(failures, '\n'))
end)
