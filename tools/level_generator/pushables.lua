-- Box-fills-hole geometry (issue 07): a one-tile gap immediately past the
-- ground zone's own right edge, with a small "far platform" beyond it --
-- additive, like coop.lua's vault, so it never touches the ground zone's
-- own tile range or Layout's zone/ladder invariants. A push_box starts on
-- solid ground right at the gap; pushing it one tile right drops it into
-- the gap where it settles as solid ground (src/components/pushable/pushable.lua:
-- "supported is decided by what's under the prop's centre-x alone... the
-- moment its centre crosses onto an unsupported tile it commits to falling
-- into that tile"), bridging the gap. A kill zone under the gap makes
-- falling in before it's bridged a recoverable death (respawn) rather than
-- a permanent stranding -- there's no ladder back up from the world's
-- bottom boundary.
local Pushables = {}

local TILE = 32
local FAR_PLATFORM_LEN = 4
local KILL_ZONE_HEIGHT_TILES = 2

local function surfaceY(row)
	return (row - 1) * TILE
end

--- @param layout A tools.level_generator.layout result.
function Pushables.planBoxBridge(layout)
	local groundRow = layout.height
	local holeCol = layout.width + 1
	local farFirstCol = holeCol + 1
	local farLastCol = holeCol + FAR_PLATFORM_LEN
	local newWidth = farLastCol

	local holeLeftPx = (holeCol - 1) * TILE

	return {
		newWidth = newWidth,
		groundRow = groundRow,
		holeCol = holeCol,
		farColumns = {first = farFirstCol, last = farLastCol},
		boxSpawnX = (layout.width - 1) * TILE,
		boxSpawnY = surfaceY(groundRow),
		farObjectiveX = (farFirstCol + 1 - 1) * TILE,
		farObjectiveY = surfaceY(groundRow),
		killZone = {
			x = holeLeftPx,
			y = surfaceY(groundRow),
			width = TILE,
			height = KILL_ZONE_HEIGHT_TILES * TILE,
			deathType = 'pit',
		},
	}
end

return Pushables
