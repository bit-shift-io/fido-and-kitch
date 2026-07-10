-- Stricter ground check than Player:queryOnGround(): requires solid ground
-- under BOTH feet corners (with an inward margin), not just anywhere under a
-- wide strip. Used to gate safe-position recording so a player hanging off
-- a ledge edge never gets recorded as "safely" grounded there.
local GroundSupport = {}

local DEFAULT_MARGIN = 6

local function hasGroundAt(world, x, top, bottom)
	local probe = {left = x - 2, right = x + 2, top = top, bottom = bottom}
	local colls = world:queryBounds(probe)
	for _, c in ipairs(colls) do
		if c.entity == nil then
			return true
		end
	end
	return false
end

function GroundSupport.isFullySupported(world, bounds, margin)
	margin = margin or DEFAULT_MARGIN
	local top = bounds.bottom + 4
	local bottom = bounds.bottom + 5

	return hasGroundAt(world, bounds.left + margin, top, bottom)
		and hasGroundAt(world, bounds.right - margin, top, bottom)
end

return GroundSupport
