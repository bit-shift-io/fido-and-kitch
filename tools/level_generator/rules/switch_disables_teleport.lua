-- Optional, non-gating flourish (DECISIONS.md Q14): a teleport pair
-- connecting the ground zone to the topmost zone as a bonus shortcut --
-- both ends are already reachable by walking/climbing, so the shortcut is
-- never required -- plus a switch that toggles teleport A's Switchable
-- enabled state. Teleports start enabled=true (src/entities/teleport.lua
-- forwards no start-disabled option), so the switch's real, working effect
-- is turning the shortcut off, then back on -- not "opening" it.
local TILE = 32

local Rule = {}
Rule.id = "switch-disables-teleport-shortcut"

local function surfaceY(row)
	return (row - 1) * TILE
end

function Rule.canApply(layout)
	return #layout.zones >= 2
end

function Rule.apply(rng, layout, startId)
	local a = layout.zones[1]
	local b = layout.zones[#layout.zones]

	local teleportAId = startId
	local teleportBId = startId + 1
	local switchId = startId + 2

	local aX = a.x1 * TILE
	local bX = b.x1 * TILE
	local switchX = math.min(a.x1 + 1, a.x2) * TILE

	return {
		objects = {
			{
				id = teleportAId,
				template = "../../entities/teleport.tj",
				name = "teleport",
				type = "teleport",
				x = aX,
				y = surfaceY(a.y),
				properties = { { name = "target", type = "object", value = teleportBId } },
			},
			{
				id = teleportBId,
				template = "../../entities/teleport.tj",
				name = "teleport",
				type = "teleport",
				x = bX,
				y = surfaceY(b.y),
				properties = { { name = "target", type = "object", value = teleportAId } },
			},
			{
				id = switchId,
				template = "../../entities/switch.tj",
				name = "switch",
				type = "switch",
				x = switchX,
				y = surfaceY(a.y),
				properties = { { name = "target", type = "object", value = teleportAId } },
			},
		},
		idsUsed = 3,
		walkthroughStep = "(optional) a shortcut teleporter links the ground to the top platform; "
			.. "a nearby switch can turn it off and back on, but it starts working and nothing requires it.",
	}
end

return Rule
