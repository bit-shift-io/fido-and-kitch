-- Pure decision helpers for the drawbridge state machine, extracted so they're
-- testable headless without the entity/component/world stack. Mirrors
-- src/player/ground_support.lua.
--
-- Kept in a separate file from drawbridge.lua: tests/unit/ is pure Lua with
-- no LÖVE surface at all, and drawbridge.lua constructs Sprite/Collider
-- components at require time, so it cannot be required there. Merging the
-- two would silently push these tests down to the integration tier.
--
-- State model: closed -> opening -> open -> closing -> closed, driven by a
-- single per-frame boolean, `held` -- any entity overlapping the trigger
-- tile OR the deck tile. Held pushes toward open, unheld toward closed;
-- either transition reverses an in-flight animation from the current frame.
-- No memory of past occupancy: held is recomputed fresh every frame, which
-- is what makes the reopen-then-close path (previously unreachable, see
-- DECISIONS.md Q3/Q4) just fall out of the model instead of needing a flag.
-- Solidity is intentionally coherent across opening/open/closing (deck solid
-- the whole time) so an occupant is never dropped and a mid-close reversal
-- never has to flip solidity. Closed has no barrier at all -- the gap is
-- fully exposed; approaching from the wrong side means falling in.
-- Anything counts as holding it -- players, enemies, pushed boxes -- there
-- is no entity-type eligibility.
local DrawbridgeSupport = {}

-- centre-offset (from the bridge tile's own centre) for the arrival-side
-- trigger sensor, positioned flush against the gap's edge -- not a full
-- tile out -- so the deck visibly starts lowering only once the player is
-- right at the edge (reads as "pushing the gate down"), not by tripping a
-- remote sensor a whole tile away. crossingDirection names the direction of
-- travel the bridge permits: a leftToRight bridge is arrived at from the
-- left, so the trigger sits to the left; an unrecognised or missing value
-- falls back to leftToRight.
function DrawbridgeSupport.triggerOffsetX(crossingDirection, tileWidth, triggerWidth)
	local flushOffset = tileWidth / 2 + triggerWidth / 2
	if crossingDirection == 'rightToLeft' then
		return flushOffset
	end
	return -flushOffset
end

-- Maps crossingDirection to the sprite's mirror flag. The art is a tower
-- hinged on the left with the deck lowering rightward, so unmirrored ('right')
-- is exactly a left-to-right crossing; rightToLeft mirrors it. This is the
-- inverse of treating crossingDirection as a facing value directly -- doing
-- that was the original bug (both shipped bridges drew the tower over the
-- gap). An unrecognised or missing value falls back to leftToRight's mapping.
function DrawbridgeSupport.spriteFacing(crossingDirection)
	if crossingDirection == 'rightToLeft' then
		return 'left'
	end
	return 'right'
end

-- the sprite draws 3x the object's own tile dimensions, centred on the
-- object tile -- one tile of bleed in every direction so the art can key
-- into the surrounding environment. Derived from the object's own size
-- rather than a hard-coded pixel value so it survives a tile-size change.
-- Purely visual: the deck and trigger colliders stay one tile each.
function DrawbridgeSupport.spriteBoxDimensions(objectWidth, objectHeight)
	return objectWidth * 3, objectHeight * 3
end

function DrawbridgeSupport.isDeckSolid(state)
	return state ~= 'closed'
end

-- Two zones, evaluated fresh every frame: triggerHeld (the lead-in tile on
-- the arrival side) and deckHeld (the bridge's own tile).
--
-- Only the trigger can break a CLOSED bridge -- deck overlap alone is not
-- enough. This is what keeps a wrong-side approach a real hazard: without
-- it, a wide collider grazing the far edge of the deck tile while still
-- standing on solid ground on the wrong side would pre-emptively solidify
-- the gap for it, regardless of crossingDirection. Every other transition
-- is driven by either zone once the bridge is already moving -- by the time
-- it's CLOSING, the deck is still solid, so an occupant there (having
-- crossed from the far side, or never having left) is a legitimate reason
-- to reopen, not a rescue.
function DrawbridgeSupport.nextStateOnHeldChange(state, triggerHeld, deckHeld)
	if state == 'closed' then
		if triggerHeld then
			return 'opening'
		end
		return state
	end

	if state == 'closing' then
		if triggerHeld or deckHeld then
			return 'opening'
		end
		return state
	end

	if state == 'open' or state == 'opening' then
		if not (triggerHeld or deckHeld) then
			return 'closing'
		end
		return state
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

-- true if any collider in the (combined trigger+deck) overlap set belongs
-- to an entity other than the drawbridge's own colliders (deck/trigger).
-- Anything counts -- players, enemies, pushed boxes -- there is no
-- entity-type eligibility.
function DrawbridgeSupport.isHeld(overlaps, selfEntity)
	for _, collider in ipairs(overlaps) do
		if collider.entity and collider.entity ~= selfEntity then
			return true
		end
	end
	return false
end

return DrawbridgeSupport
