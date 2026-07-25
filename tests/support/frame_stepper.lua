-- Advances a harnessed game at a fixed 1/60s timestep, matching DECISIONS.md
-- Q8: deterministic across machines, no wall-clock dependency.
local DT = 1 / 60

local FrameStepper = {}

-- Set only by the e2e runner (tests/e2e/run.lua), never by unit/integration
-- tests: lets a headed scenario yield its driving coroutine back to LÖVE's
-- own update/draw cycle after every simulated frame, so frames are genuinely
-- presented and the window stays responsive across a long-running scenario.
-- nil everywhere else, so headless behaviour is completely unchanged.
local yieldHook = nil

function FrameStepper.setYieldHook(fn)
	yieldHook = fn
end

function FrameStepper.step(game, frames)
	for _ = 1, frames do
		game:update(DT)
		if yieldHook then
			yieldHook()
		end
	end
end

function FrameStepper.secondsToFrames(seconds)
	return math.floor(seconds / DT + 0.5)
end

return FrameStepper
