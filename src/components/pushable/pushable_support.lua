-- Pure decision helpers for the Pushable component, extracted so they're
-- testable headless without the entity/component/world stack (pushable.lua
-- constructs nothing itself, but the props that use it evaluate
-- Class{__includes = Entity} and build Sprite/Collider at require time, which
-- tests/unit/ cannot load). Mirrors src/player/ground_support.lua. (The
-- drawbridge and pressure switch used to be further examples of this split;
-- ADR 0005 merged both back into single files -- src/entities/drawbridge.lua
-- and src/entities/pressure_switch.lua -- once
-- tests/support/headless_bootstrap.lua made constructing a full entity
-- headless possible. Pushable itself stays split: it's a component shared by
-- multiple prop entities, not one entity's own logic.)
--
-- Sits beside its component in src/components/pushable/ rather than inside any
-- one prop's directory: the behaviour is shared by push_box and boulder, and
-- the pressure switch reads it too. Directory named after the component with
-- real filenames kept and no init.lua, per ADR 0003.
local PushableSupport = {}

-- Collision group allocation for pushable props. World.colFilter ignores a
-- collision between two colliders with a matching groupIndex -- it's there so
-- co-op players pass through each other (Player:init sets -1) -- and nil ==
-- nil is true in Lua. A prop therefore needs an index that is:
--   * concrete, or it matches the terrain's unset nil and falls through the floor
--   * not -1, or it passes through players
--   * unique per prop, or props pass through each other and a box stacked on
--     a box drops straight through it
-- Positive and monotonically increasing satisfies all three. The counter is
-- never reset: a level restart builds fresh colliders, and simply continuing
-- to count avoids handing a rebuilt prop an index a stale one still holds.
local nextGroup = 0

function PushableSupport.nextGroupIndex()
	nextGroup = nextGroup + 1
	return nextGroup
end

-- Where a Tiled object's centre actually is, which depends on how the object
-- was authored:
--   * a plain rectangle object (no gid) is TOP-anchored -- Tiled's y is the
--     top edge, so the centre is half a tile below it
--   * a tile object (has a gid, which is what dragging a template from
--     Tiled's palette produces) is BOTTOM-anchored -- Tiled's y is the
--     bottom edge, so the centre is half a tile above it
-- Both shapes exist in this project's maps for the same prop type, so the
-- anchoring can't be assumed: src/entities/switch.lua's gid object needs the
-- second rule, while the hand-edited push_box objects in
-- res/map/sandbox.tmj need the first. Guessing wrong buries a
-- template-placed prop a full tile inside the floor.
function PushableSupport.spawnCentre(object)
	local centreX = object.x + object.width * 0.5

	if object.gid then
		return centreX, object.y - object.height * 0.5
	end

	return centreX, object.y + object.height * 0.5
end

-- Below this much vertical velocity a prop counts as resting rather than
-- falling. The physics layer cancels the velocity component pushing into a
-- surface the frame a body lands (Motion.resolveCollisions), so a settled
-- prop reads as exactly zero -- the tolerance only exists to keep float
-- noise from reading as flight.
local RESTING_VELOCITY_TOLERANCE = 0.001

function PushableSupport.isAirborne(velocityY)
	return math.abs(velocityY) > RESTING_VELOCITY_TOLERANCE
end

-- Whether the prop is in a state that can be shoved at all, independent of
-- whether anyone is currently shoving it. `state` is a plain table of
-- booleans: {airborne, pushableOnTop, playerOnTop, allowPushWhenStoodOn}.
--
-- A pushable resting on top hard-blocks the prop below it, so shoving the
-- bottom of a stack can never leave the top one hanging. A player on top
-- blocks by default (don't let someone slide the floor out from under their
-- own feet) but is opt-in per prop, which is what makes "one player rides
-- while the other pushes" co-op puzzles authorable. The opt-in covers
-- players only -- it never unblocks a stacked prop.
function PushableSupport.isPushableNow(state)
	if state.airborne then
		return false
	end

	if state.pushableOnTop then
		return false
	end

	if state.playerOnTop and not state.allowPushWhenStoodOn then
		return false
	end

	return true
end

-- One pusher's contribution: which way it is shoving this prop, if at all.
-- Pushing is a walking action, so an airborne pusher contributes nothing --
-- a mid-air collision is just a block.
local function pusherDirection(pusher, propCentreX)
	if not pusher.grounded then
		return 0
	end

	if pusher.centreX < propCentreX and pusher.holdingRight then
		return 1
	end

	if pusher.centreX > propCentreX and pusher.holdingLeft then
		return -1
	end

	return 0
end

-- Which way the adjacent pushers are collectively shoving this prop: -1
-- (left), 1 (right) or 0 (not being pushed). Each pusher is a plain table
-- {centreX, grounded, holdingLeft, holdingRight} -- deliberately not a Player,
-- so this stays pure and testable.
--
-- Intent, not velocity, decides this. Once the prop blocks the pusher, the
-- physics layer cancels the pusher's horizontal velocity every frame
-- (Motion.resolveCollisions), so reading velocity would report "not pushing"
-- at exactly the moment the player is leaning hardest into the prop.
--
-- Contributions are summed so two players shoving opposite faces cancel out
-- rather than one winning by query order.
function PushableSupport.pushDirection(pushers, propCentreX)
	local direction = 0

	for _, pusher in ipairs(pushers) do
		direction = direction + pusherDirection(pusher, propCentreX)
	end

	if direction > 0 then
		return 1
	elseif direction < 0 then
		return -1
	end

	return 0
end

-- Which collision group the prop should be in right now: its own at all times.
--
-- The prop keeps its own groupIndex even while falling. This means bump blocks
-- the player from walking through a falling prop -- the player waits at the
-- edge while the prop drops below their feet, then walks off freely. The prop
-- remains solid to the player throughout the fall and lands normally.
function PushableSupport.groupIndexFor(state, ownGroupIndex)
	return ownGroupIndex
end

-- Whether the prop should currently be a static body or a dynamic one.
--
-- A prop at rest is STATIC, so it behaves exactly like the terrain it stands
-- in for. This is correctness, not optimisation: a dynamic body re-resolves
-- gravity every frame, and when a dynamic prop's top is flush with a walking
-- surface lib/bump reports the player's contact against it as a wall
-- (normal (-1,0)) rather than a step. A box filling a one-tile hole would
-- then BLOCK the player instead of carrying them across -- the exact
-- opposite of the mechanic. A static collider with identical geometry is
-- crossed correctly, the same way the drawbridge's static deck is.
--
-- It goes dynamic only while it genuinely needs to move: nothing under its
-- centre (gravity must take it), still settling after a landing (going static
-- mid-settle would freeze it hanging above the surface, since support is
-- probed a few pixels below its feet), or moving under a push or its own momentum.
function PushableSupport.bodyTypeFor(state)
	if not state.supported or state.airborne or state.moving then
		return 'dynamic'
	end

	return 'static'
end

-- The centre-x of the tile the prop's centre-x currently sits over -- where
-- a falling prop aligns to (ADR 0001). Alignment happens only on the forcing
-- events (dropping into a gap, seating on a pressure switch), never as the
-- prop's normal resting behaviour, which is why this is a snap target rather
-- than something applied continuously.
--
-- A centre exactly on a tile boundary belongs to the tile it is entering,
-- which is how the floor division falls out -- there is no ambiguous
-- half-tile case to special-case.
function PushableSupport.snapTargetX(propCentreX, tileWidth)
	return math.floor(propCentreX / tileWidth) * tileWidth + tileWidth * 0.5
end

-- How fast the prop should travel in the already-decided direction: the walk
-- speed of the fastest pusher actually contributing to that direction. Taken
-- from the pusher rather than a constant here so it cannot drift out of sync
-- with Player.speed. Pushers leaning on the opposite face contribute nothing
-- and must not set the pace.
function PushableSupport.pushSpeed(pushers, propCentreX, direction)
	if direction == 0 then
		return 0
	end

	local speed = 0

	for _, pusher in ipairs(pushers) do
		if pusherDirection(pusher, propCentreX) == direction and (pusher.speed or 0) > speed then
			speed = pusher.speed
		end
	end

	return speed
end

-- Roll mode's momentum (the boulder): a shove starts it moving and it then
-- carries on by itself, where slide mode (the box) only moves while actively
-- pushed. Returns the horizontal velocity it should carry this frame.
--
-- All three stop conditions -- a wall, another prop, a player -- collapse into
-- one check. The physics layer cancels the velocity component pushing into a
-- surface (Motion.resolveCollisions), so a roll that set out at 100 and comes
-- back resolved to 0 has hit something solid, whatever it was. Falling stops
-- it too: a prop that drops into a gap arrives stationary rather than carrying
-- its momentum out the other side.
--
-- A fresh shove always wins over existing momentum, which is what lets a
-- stopped boulder be pushed back the way it came.
function PushableSupport.nextRollVelocity(state)
	if state.falling then
		return 0
	end

	local pushVelocity = state.pushVelocity or 0
	if pushVelocity ~= 0 then
		return pushVelocity
	end

	local currentRoll = state.currentRoll or 0
	if currentRoll == 0 then
		return 0
	end

	if (state.resolvedVelocityX or 0) == 0 then
		return 0
	end

	return currentRoll
end

-- Whether the source teleporter's tile is clear, and if not, whether the
-- overlapping box can be pushed clear and in which direction. Direction is
-- derived from the box's position relative to the tile's centre --
-- overlapping from the left pushes left, from the right pushes right
-- (DECISIONS.md Q2), the same "clear it like a player pushed it out of the
-- way" framing.
--
-- `overlappingPushables` is whatever already overlaps the tile -- the world
-- query is the caller's job (this module has no world access), the same
-- split `pushDirection` above uses for its already-queried `pushers`. Each
-- entry only needs a `centreX`. Only the first overlapping box is ever
-- considered: no chain-push resolution (DECISIONS.md Q3), matching the
-- existing "no train of two props" rule.
--
-- `escapeBlocked` is `{left = bool, right = bool}` -- whether the adjacent
-- escape cell in that direction is blocked, by a wall or another pushable;
-- again the caller's job to query, since a wall and a pushable both simply
-- mean "can't go there" from this function's point of view.
function PushableSupport.sourceTileClearCheck(tileBounds, overlappingPushables, escapeBlocked)
	if #overlappingPushables == 0 then
		return {status = 'clear'}
	end

	local tileCentreX = (tileBounds.left + tileBounds.right) * 0.5
	local direction = (overlappingPushables[1].centreX < tileCentreX) and 'left' or 'right'

	if escapeBlocked[direction] then
		return {status = 'stuck'}
	end

	return {status = 'pushable', direction = direction}
end

-- Whether any Pushable overlaps the destination teleporter's tile at all --
-- no direction, no escape-cell logic, since there's no player at the
-- destination to push anything out of the way (DECISIONS.md Q2b). Like
-- `sourceTileClearCheck`, the overlap query itself is the caller's job.
function PushableSupport.destinationTileOccupied(overlappingPushables)
	return #overlappingPushables > 0
end

return PushableSupport
