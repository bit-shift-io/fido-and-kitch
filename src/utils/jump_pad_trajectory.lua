-- Trajectory module: computes a distance-proportional parabolic arc, with a
-- minimum clearance floor so short/level jumps still read as a real launch.
-- Given start and target points, returns polyline-like list of {x, y} points
local Camera = require("src.camera")

local Trajectory = {}

local DEFAULT_MIN_CLEARANCE_TILES = 2

-- Compute a parabolic arc from startPoint to targetPoint
-- Returns an ordered list of {x, y} points suitable for Path:init polyline
-- arcHeightFactor controls apex height: arcHeight = arcHeightFactor * horizontalDistance
-- minClearance (pixels, default 2 tiles) is a FLOOR: the arc's peak is
-- guaranteed to sit at least this far above the higher of the two endpoints,
-- even when the distance-proportional height alone wouldn't clear it (a
-- short or level jump would otherwise barely rise at all).
function Trajectory.computeArc(startPoint, targetPoint, arcHeightFactor, minClearance)
	arcHeightFactor = arcHeightFactor or 0.15
	minClearance = minClearance or (DEFAULT_MIN_CLEARANCE_TILES * Camera.DEFAULT_TILE_SIZE)

	local x0, y0 = startPoint.x, startPoint.y
	local x1, y1 = targetPoint.x, targetPoint.y

	-- Horizontal and vertical distances
	local dx = x1 - x0
	local dy = y1 - y0

	-- If start and end are at the same x, can't make a proper arc
	if math.abs(dx) < 0.001 then
		-- Return vertical line with a small arc
		return {
			{ x = x0, y = y0 },
			{ x = x0, y = y1 },
		}
	end

	-- Arc height scaled by horizontal distance
	-- The arc is perpendicular to the line connecting start and end
	local proportionalHeight = arcHeightFactor * math.abs(dx)

	-- Minimum height so the peak (at t=0.5, y = y0 + 0.5*dy - arcHeight)
	-- clears at least minClearance above the higher endpoint, i.e.
	-- numerically at or below min(y0,y1) - minClearance:
	--   y0 + 0.5*dy - arcHeight <= min(y0,y1) - minClearance
	--   arcHeight >= (y0 + 0.5*dy) - min(y0,y1) + minClearance
	-- (y0 + 0.5*dy) is the midpoint of the straight line, and its distance
	-- to the closer (lower-numbered) endpoint is always abs(dy)/2, so this
	-- simplifies to abs(dy)/2 + minClearance regardless of which endpoint
	-- is higher.
	local minHeightForClearance = math.abs(dy) / 2 + minClearance
	local arcHeight = math.max(proportionalHeight, minHeightForClearance)

	-- Generate points along the parabola using parametric form
	-- t ranges from 0 (start) to 1 (end)
	-- The parabola peaks at t = 0.5 with height = arcHeight
	-- Using parametric form:
	--   x = x0 + t * dx
	--   y = y0 + t * dy - arcHeight * 4 * t * (1 - t)
	-- The term 4*t*(1-t) peaks at t=0.5 with value 1. Subtracted, not added,
	-- because this engine's y grows DOWNWARD (screen/Tiled convention -- a
	-- hand-drawn jump pad path in tests/fixtures/jump_pad_room.tmj climbs
	-- from y=128 to y=64), so a launch arc that rises above the straight
	-- line connecting pad and target needs a smaller y at its midpoint, not
	-- a larger one.

	local points = {}
	local sampleCount = 20

	for i = 0, sampleCount do
		local t = i / sampleCount
		local x = x0 + t * dx
		-- Parabolic offset: 4*t*(1-t) has peak of 1 at t=0.5
		local y = y0 + t * dy - arcHeight * 4 * t * (1 - t)

		table.insert(points, { x = x, y = y })
	end

	return points
end

return Trajectory
