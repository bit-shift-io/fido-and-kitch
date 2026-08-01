-- Pure decision helpers for the pressure switch, extracted so they're testable
-- headless without the entity/component/world stack. Mirrors
-- src/player/ground_support.lua and src/components/pushable/pushable_support.lua.
-- (The drawbridge used to be a third example of this split; ADR 0005 merged
-- it back into a single src/entities/drawbridge.lua once
-- tests/support/headless_bootstrap.lua made constructing a full entity
-- headless possible.)
local PressureSwitchSupport = {}

-- How far a weight's centre-x may sit from the plate tile's centre and still
-- count as being on it. "Substantially on it" (DECISIONS Q11): merely
-- overlapping the plate is not enough -- a box resting with one edge barely
-- over the plate is not standing on it, and neither is a player brushing past
-- the edge. A quarter of a tile each way is generous enough to feel fair while
-- still requiring the weight to be recognisably seated.
PressureSwitchSupport.TOLERANCE = 8

function PressureSwitchSupport.isWeightOn(weightCentreX, plateCentreX)
	return math.abs(weightCentreX - plateCentreX) <= PressureSwitchSupport.TOLERANCE
end

-- Whether the plate should be active next frame. The caller drives its target
-- whenever this differs from the current state, which is all the momentary vs
-- latching difference amounts to:
--   * momentary (default) follows the weight, so it transitions twice -- on
--     when the first weight arrives, off when the last one leaves -- and
--     re-drives the target both times
--   * latching never returns to off, so it transitions once and drives once
-- Presence is recomputed fresh every frame from whatever is currently on the
-- plate, so several weights count as one activation and it releases only when
-- the last of them leaves, with no occupancy bookkeeping to get out of step.
function PressureSwitchSupport.nextActivation(isActive, latching, weightPresent)
	if isActive and latching then
		return true
	end

	return weightPresent
end

return PressureSwitchSupport
