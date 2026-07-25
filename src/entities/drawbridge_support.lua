-- Pure decision helpers for the drawbridge state machine, extracted so they're
-- testable headless without the entity/component/world stack. Mirrors
-- src/player/ground_support.lua.
--
-- State model: closed -> opening -> open -> closing -> closed.
-- Solidity is intentionally coherent across opening/open/closing (deck solid
-- the whole time, barrier only present when fully closed) so an occupant is
-- never dropped and a mid-close reversal never has to flip solidity.
local DrawbridgeSupport = {}

-- how far ahead of the bridge tile (in tiles) the correct-side trigger
-- sensor sits, so the deck is already solid before an entity reaches the gap
function DrawbridgeSupport.triggerOffsetX(facing, tileWidth)
	if facing == 'left' then
		return -tileWidth
	end
	return tileWidth
end

-- players can always open a bridge; enemies only when opted in
function DrawbridgeSupport.mayOpen(entityType, allowEnemies)
	if entityType == 'player' then
		return true
	end
	if allowEnemies and entityType == 'enemy' then
		return true
	end
	return false
end

function DrawbridgeSupport.isDeckSolid(state)
	return state ~= 'closed'
end

function DrawbridgeSupport.isBarrierPresent(state)
	return state == 'closed'
end

-- an eligible entity overlapping the correct-side trigger sensor: starts a
-- fresh open from closed, or reverses a close-in-progress back to open
function DrawbridgeSupport.nextStateOnTrigger(state, entityType, allowEnemies)
	if not DrawbridgeSupport.mayOpen(entityType, allowEnemies) then
		return state
	end

	if state == 'closed' or state == 'closing' then
		return 'opening'
	end

	return state
end

-- occupancy (any entity overlapping the bridge tile, players or enemies
-- alike) governs staying open and reopening; it is the safety net that
-- guarantees the bridge never closes on an occupant, independent of who
-- (or whether anyone) touched the trigger sensor.
--
-- `hasBeenOccupied` guards the open->closing edge: closing only begins once
-- someone has actually been on the tile and then left ("the last one
-- clears the footprint"), not the instant it opens. Without this, a bridge
-- that just finished opening -- deck deliberately made solid before the
-- triggering entity has physically arrived, per the lead-in trigger design
-- -- would see `occupied == false` and immediately reverse right back to
-- closing before anyone ever set foot on it.
function DrawbridgeSupport.nextStateOnOccupancyChange(state, occupied, hasBeenOccupied)
	if state == 'open' and hasBeenOccupied and not occupied then
		return 'closing'
	end

	if state == 'closing' and occupied then
		return 'opening'
	end

	return state
end

function DrawbridgeSupport.nextStateOnAnimationFinish(state)
	if state == 'opening' then
		return 'open'
	end

	if state == 'closing' then
		return 'closed'
	end

	return state
end

-- true if any collider in the overlap set belongs to an entity other than
-- the drawbridge's own colliders (deck/barrier/trigger)
function DrawbridgeSupport.hasOccupant(overlaps, selfEntity)
	for _, collider in ipairs(overlaps) do
		if collider.entity and collider.entity ~= selfEntity then
			return true
		end
	end
	return false
end

return DrawbridgeSupport
