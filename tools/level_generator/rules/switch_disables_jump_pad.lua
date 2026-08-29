-- Optional, non-gating flourish (DECISIONS.md Q14): a jump pad giving a
-- short, safe hop within a single wide-enough zone (start and landing tiles
-- both inside the zone's own x-range, so it never launches the player
-- somewhere unreachable), plus a switch that can turn it off/on. Like the
-- teleport flourish, the pad starts enabled -- the switch's real effect is
-- disabling it, not gating access.
local TILE = 32
local MIN_ZONE_WIDTH = 6

local Rule = {}
Rule.id = 'switch-disables-jump-pad-hop'

local function surfaceY(row)
	return (row - 1) * TILE
end

local function findWideZone(layout)
	for _, zone in ipairs(layout.zones) do
		if (zone.x2 - zone.x1 + 1) >= MIN_ZONE_WIDTH then
			return zone
		end
	end
	return nil
end

function Rule.canApply(layout)
	return findWideZone(layout) ~= nil
end

function Rule.apply(rng, layout, startId)
	local zone = findWideZone(layout)

	local pathId = startId
	local padId = startId + 1
	local switchId = startId + 2

	local padX = zone.x1 * TILE
	local y = surfaceY(zone.y)

	return {
		objects = {
			{
				id = pathId,
				name = 'jump_path',
				x = padX,
				y = y,
				-- Short hop landing 4 tiles further along the same zone --
				-- always within [zone.x1, zone.x2] given MIN_ZONE_WIDTH.
				polyline = {{x = 0, y = 0}, {x = TILE * 2, y = -TILE}, {x = TILE * 4, y = 0}},
			},
			{
				id = padId,
				template = '../../entities/jump_pad.tj',
				name = 'jump_pad',
				type = 'jump_pad',
				x = padX,
				y = y,
				properties = {{name = 'path', type = 'object', value = pathId}},
			},
			{
				id = switchId,
				template = '../../entities/switch.tj',
				name = 'switch',
				type = 'switch',
				x = math.min(zone.x1 + 1, zone.x2) * TILE,
				y = y,
				properties = {{name = 'target', type = 'object', value = padId}},
			},
		},
		idsUsed = 3,
		walkthroughStep = '(optional) a jump pad gives a quick hop across the platform; its switch can turn it off and back on.',
	}
end

return Rule
