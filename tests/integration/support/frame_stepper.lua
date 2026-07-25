-- Advances a harnessed game at a fixed 1/60s timestep, matching DECISIONS.md
-- Q8: deterministic across machines, no wall-clock dependency.
local DT = 1 / 60

local FrameStepper = {}

function FrameStepper.step(game, frames)
	for _ = 1, frames do
		game:update(DT)
	end
end

function FrameStepper.secondsToFrames(seconds)
	return math.floor(seconds / DT + 0.5)
end

return FrameStepper
