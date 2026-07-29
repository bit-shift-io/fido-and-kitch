-- Stricter ground check than Player:queryOnGround(): requires solid ground
-- under BOTH feet corners (with an inward margin), not just anywhere under a
-- wide strip. Used to gate safe-position recording so a player hanging off
-- a ledge edge never gets recorded as "safely" grounded there.
local GroundSupport = {}

local DEFAULT_MARGIN = 6

-- Is there something standable directly under this single x, in the vertical
-- band top..bottom? Public because pushable props probe support the same way
-- (under their centre-x, see ADR 0001) and duplicating the walkable/sensor
-- rules is exactly how the two would drift apart.
function GroundSupport.hasGroundAt(world, x, top, bottom)
	local probe = {left = x - 2, right = x + 2, top = top, bottom = bottom}
	local colls = world:queryBounds(probe)
	for _, c in ipairs(colls) do
		-- `walkable` is a capability flag, not a standing guarantee -- an
		-- entity-owned collider (e.g. a drawbridge deck) can currently be a
		-- sensor, in which case it must not count as ground (see
		-- Player:queryOnGround for the same fix)
		if c.entity == nil or (c.walkable and not c.other.sensor) then
			return true
		end
	end
	return false
end

function GroundSupport.isFullySupported(world, bounds, margin)
	margin = margin or DEFAULT_MARGIN
	local top = bounds.bottom + 4
	local bottom = bounds.bottom + 5

	return GroundSupport.hasGroundAt(world, bounds.left + margin, top, bottom)
		and GroundSupport.hasGroundAt(world, bounds.right - margin, top, bottom)
end

return GroundSupport
