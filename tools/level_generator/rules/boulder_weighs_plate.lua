-- Optional, non-gating flourish (issue 07 / DECISIONS.md Q14): a boulder
-- placed a short roll from a pressure plate. Boulders are pushable props in
-- 'roll' mode (src/entities/boulder.lua) -- a shove sends them rolling under
-- their own momentum until they hit something and stop; a plate they come
-- to rest within tolerance of seats them onto its exact centre
-- (src/components/pushable/pushable.lua's seatOnPlate), and a pushable prop
-- counts as weight for src/entities/pressure_switch.lua's hasWeight(). Once
-- seated the boulder is a *permanent* weight (never leaves on its own), so
-- this drives its target continuously -- unlike the lever/jump-pad
-- flourishes, nothing needs to be "used" for the effect to hold. The target
-- (a teleport shortcut, same as switch_disables_teleport) is never required.
local TILE = 32
local MIN_ZONE_WIDTH = 8

local Rule = {}
Rule.id = 'boulder-weighs-plate-teleport'

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
	local y = surfaceY(zone.y)

	local boulderId = startId
	local plateId = startId + 1
	local stopperId = startId + 2
	local teleportAId = startId + 3
	local teleportBId = startId + 4

	return {
		objects = {
			{
				id = boulderId,
				template = '../../editor/boulder.tj',
				name = 'boulder',
				type = 'boulder',
				x = zone.x1 * TILE,
				y = y,
			},
			{
				id = plateId,
				name = 'pressure_switch',
				type = 'pressure_switch',
				x = (zone.x1 + 2) * TILE,
				y = y,
				width = TILE,
				height = TILE,
				properties = {
					{name = 'target', type = 'object', value = teleportAId},
					{name = 'latching', type = 'bool', value = false},
				},
			},
			-- An idle push_box, never shoved, doubles as a wall: settled
			-- pushables are static (PushableSupport.bodyTypeFor). Placed
			-- immediately past the plate so the rolling boulder stops with
			-- its centre right at the plate's centre, inside seatOnPlate's
			-- tolerance, instead of rolling straight over it forever (roll
			-- velocity has no friction/decay -- src/components/pushable/
			-- pushable_support.lua's nextRollVelocity -- it only stops on
			-- hitting something).
			{
				id = stopperId,
				template = '../../editor/push_box.tj',
				name = 'push_box',
				type = 'push_box',
				x = (zone.x1 + 3) * TILE,
				y = y,
			},
			{
				id = teleportAId,
				template = '../../editor/teleport.tj',
				name = 'teleport',
				type = 'teleport',
				x = math.min(zone.x1 + 5, zone.x2) * TILE,
				y = y,
				properties = {
					{name = 'target', type = 'object', value = teleportBId},
					{name = 'enabled', type = 'bool', value = false},
				},
			},
			{
				id = teleportBId,
				template = '../../editor/teleport.tj',
				name = 'teleport',
				type = 'teleport',
				x = zone.x2 * TILE,
				y = y,
				properties = {
					{name = 'target', type = 'object', value = teleportAId},
				},
			},
		},
		idsUsed = 5,
		walkthroughStep = '(optional) push the boulder onto the nearby pressure plate -- it settles there permanently, '
			.. 'powering a nearby teleporter for as long as it stays seated. Not required to finish the level.',
	}
end

return Rule
