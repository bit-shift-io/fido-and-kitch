-- Conservative reachability model. The player has no jump (verified against
-- src/player/player_states.lua, player_movement.lua, player.lua -- only
-- walking, ladder climbing, and later-issue jump-pad/drawbridge/pushable
-- mechanics exist), so this model only ever asserts two transitions: walking
-- across contiguous ground on the same row, and climbing a ladder that spans
-- exactly between two rows. It never assumes a gap can be crossed.
local MovementModel = {}

-- Sourced from src/, not duplicated as literals, so the model can never
-- drift from the real player's speeds (DECISIONS.md Q12).
MovementModel.constants = require("src.player.movement_constants")

--- True if a and b sit on the same row with touching or overlapping
-- x-ranges -- i.e. the player can walk from one directly into the other.
function MovementModel.canWalkBetween(a, b)
	if a.y ~= b.y then
		return false
	end
	return a.x1 <= b.x2 + 1 and b.x1 <= a.x2 + 1
end

--- True if `ladder` (a {x, yTop, yBottom} column) spans exactly from one
-- zone's row to the other's, and its column sits within both zones'
-- x-ranges (so the player can step onto/off it at both ends).
function MovementModel.ladderConnects(ladder, zoneA, zoneB)
	local upper, lower
	if zoneA.y < zoneB.y then
		upper, lower = zoneA, zoneB
	else
		upper, lower = zoneB, zoneA
	end

	if ladder.yTop ~= upper.y or ladder.yBottom ~= lower.y then
		return false
	end

	local inUpper = ladder.x >= upper.x1 and ladder.x <= upper.x2
	local inLower = ladder.x >= lower.x1 and ladder.x <= lower.x2
	return inUpper and inLower
end

--- Builds the set of zone indices reachable from `startIndex` by walking
-- and/or climbing ladders, per the two transitions above.
function MovementModel.reachableFrom(zones, ladders, startIndex)
	local reachable = { [startIndex] = true }
	local frontier = { startIndex }

	while #frontier > 0 do
		local current = table.remove(frontier)
		local currentZone = zones[current]

		for i, zone in ipairs(zones) do
			if not reachable[i] then
				local connected = MovementModel.canWalkBetween(currentZone, zone)
				if not connected then
					for _, ladder in ipairs(ladders) do
						if MovementModel.ladderConnects(ladder, currentZone, zone) then
							connected = true
							break
						end
					end
				end

				if connected then
					reachable[i] = true
					table.insert(frontier, i)
				end
			end
		end
	end

	return reachable
end

return MovementModel
