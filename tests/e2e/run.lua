-- Real in-LÖVE e2e runner. Offers the same test()/assert* surface as
-- tests/unit/run.lua and tests/integration/run.lua, but a scenario runs
-- inside a coroutine driven from love.update rather than a synchronous
-- loop, so frames are genuinely drawn and presented (DECISIONS.md Q7).
--
-- Pacing (the --e2e-paced flag, issue 03) controls how often love.update
-- resumes that coroutine: once per real frame when paced, so exactly one
-- simulated frame lands per drawn frame and playback matches real time; as
-- many times as fit in a small wall-clock budget by default, so many
-- simulated frames land between drawn frames and the file finishes
-- quickly. Either way, tests/support/frame_stepper.lua yields the
-- coroutine after every simulated frame, which is what keeps LÖVE's own
-- event loop -- and therefore window-close detection -- ticking throughout
-- a long scenario.
--
-- Outcomes are reported back to the shell via the process exit status:
-- 0 for pass, 1 for a failing assertion, 2 for a cancelled run (the window
-- was closed mid-scenario) -- three distinct outcomes, not two
-- (DECISIONS.md Q13).
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")

-- Redirected stdout is fully block-buffered by default, which would lose
-- everything printed before a hang or crash; force line buffering so test
-- output and diagnostics always reach the log as they happen.
io.stdout:setvbuf("line")

-- Bound on how long a single real love.update call may spend resuming the
-- coroutine in fast (unpaced) mode, so a long scenario still lets LÖVE
-- process window events every so often instead of looking frozen.
local FAST_MODE_BUDGET_SECONDS = 1 / 30

local Runner = {}

local tests = {}
local failures = {}
local co = nil
local paced = false
local finished = false
local outputDir = nil

-- tests/e2e/foo_test.lua -> tests/screenshots/foo_test, so a run's captures
-- are easy to find and to clear per test file.
local function outputDirFor(testFilePath)
	local basename = testFilePath:match("([^/]+)%.lua$") or testFilePath
	return "tests/screenshots/" .. basename
end

local function valueToString(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function fail(message)
	error(message, 2)
end

function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

function assertTrue(value, message)
	if not value then
		fail(message or "expected value to be truthy")
	end
end

function assertFalse(value, message)
	if value then
		fail(message or "expected value to be falsey")
	end
end

function assertEqual(expected, actual, message)
	if expected ~= actual then
		fail(message or string.format("expected %s, got %s", valueToString(expected), valueToString(actual)))
	end
end

function assertNear(expected, actual, tolerance, message)
	tolerance = tolerance or 0.000001
	if math.abs(expected - actual) > tolerance then
		fail(
			message
				or string.format(
					"expected %s to be within %s of %s",
					valueToString(actual),
					valueToString(tolerance),
					valueToString(expected)
				)
		)
	end
end

local function loadTestFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(string.format("Could not load %s: %s", path, err))
	end
	chunk()
end

local function sanitizeForFilename(name)
	return (name:gsub("[^%w%-]+", "_"))
end

local function runAllTests()
	for _, case in ipairs(tests) do
		local ok, err = xpcall(case.fn, debug.traceback)
		if ok then
			print("✓ " .. case.name)
		else
			-- Captured here, before anything else runs: the game object
			-- (and every entity's live state) is untouched by the error
			-- unwind, so this is exactly the frame the assertion failed on,
			-- not a later or torn-down one.
			local capturePath = nil
			if Capture.hasContext() then
				local capOk, capResult = pcall(Capture.capture, "FAILURE_" .. sanitizeForFilename(case.name))
				if capOk then
					capturePath = capResult
				end
			end

			table.insert(failures, { name = case.name, error = err, capturePath = capturePath })
			print("✗ " .. case.name)
			print(err)
			if capturePath then
				print("  failure frame captured: " .. capturePath)
			end
		end
	end
end

local function reportAndExit()
	finished = true
	local passed = #tests - #failures
	print(string.format("\n%d passed, %d failed", passed, #failures))
	love.event.quit(#failures > 0 and 1 or 0)
end

local function resumeOnce()
	local ok, err = coroutine.resume(co)
	if not ok then
		finished = true
		print("e2e runner coroutine crashed: " .. tostring(err))
		love.event.quit(1)
	end
end

local DEFAULT_FILMSTRIP_INTERVAL = 10

-- e2e-filmstrip-interval=N, following the same key=value style as map=/e2e=.
local function filmstripIntervalFromArgs(args)
	for _, a in ipairs(args or {}) do
		local n = a:match("^e2e%-filmstrip%-interval=(%d+)$")
		if n then
			return tonumber(n)
		end
	end
	return DEFAULT_FILMSTRIP_INTERVAL
end

-- Called from src/main.lua once it detects the e2e launch argument, in
-- place of constructing the normal Game.
function Runner.start(testFilePath, args)
	paced = args ~= nil and tbl.includes(args, "e2e-paced")
	outputDir = outputDirFor(testFilePath)

	-- Off unless explicitly requested (DECISIONS.md Q8): a normal headed
	-- run must not be buried in hundreds of filmstrip images.
	local filmstripEnabled = args ~= nil and tbl.includes(args, "e2e-filmstrip")
	local filmstripInterval = filmstripIntervalFromArgs(args)
	local simulatedFrameCount = 0

	FrameStepper.setYieldHook(function()
		simulatedFrameCount = simulatedFrameCount + 1
		if filmstripEnabled and Capture.hasContext() and simulatedFrameCount % filmstripInterval == 0 then
			-- Zero-padded so filenames keep sorting in scenario order past
			-- a power-of-ten frame count, where naive numbering would break
			-- lexical sort and make scrubbing misleading.
			pcall(Capture.capture, string.format("filmstrip_%06d", simulatedFrameCount))
		end
		coroutine.yield()
	end)

	co = coroutine.create(function()
		loadTestFile(testFilePath)
		runAllTests()
	end)
end

function love.update(dt)
	if finished or not co then
		return
	end

	if paced then
		resumeOnce()
	else
		local start = love.timer.getTime()
		repeat
			resumeOnce()
		until finished or coroutine.status(co) == "dead" or (love.timer.getTime() - start) >= FAST_MODE_BUDGET_SECONDS
	end

	if not finished and coroutine.status(co) == "dead" then
		reportAndExit()
	end
end

function love.draw()
	if Runner.currentGame then
		Runner.currentGame:draw()
	end
end

-- src/main.lua early-returns before installing the normal love.quit, so
-- this is the only quit handler in play during an e2e run.
function love.quit()
	if not finished then
		finished = true
		print("\nCANCELLED: window closed mid-run")
		os.exit(2)
	end
end

-- tests/support/game_harness.lua calls this after constructing a game under
-- {real = true}, so love.draw and Capture.capture() have something to
-- render. Re-pointing the context to whichever game started most recently
-- keeps things correct even if a scenario starts more than one game.
_G.E2E_ON_GAME_STARTED = function(game)
	Runner.currentGame = game
	Capture.setContext(game, outputDir)
end

return Runner
