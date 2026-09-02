-- Pure ground-support/fall primitives shared by anything that rests on the
-- ground and must start falling the instant that ground disappears:
-- Pushable (push_box, boulder, via
-- src/components/pushable/pushable_support.lua, which delegates here) and
-- the ground-following pickup behaviour (coin, key). No knowledge of push
-- direction, plate-seating, or collision groups -- those stay
-- pushable-specific in pushable_support.lua. Sits beside
-- src/player/ground_support.lua, which owns the actual world-query
-- predicate this composes.
local GroundSupport = require('src.player.ground_support')

local GroundFaller = {}

-- Below this much vertical velocity a body counts as resting rather than
-- falling. The physics layer cancels the velocity component pushing into a
-- surface the frame a body lands (Motion.resolveCollisions), so a settled
-- body reads as exactly zero -- the tolerance only exists to keep float
-- noise from reading as flight.
local RESTING_VELOCITY_TOLERANCE = 0.001

function GroundFaller.isAirborne(velocityY)
	return math.abs(velocityY) > RESTING_VELOCITY_TOLERANCE
end

-- ADR 0002: support is decided by what is under the body's CENTRE-x alone,
-- not by how much of its footprint still overlaps a ledge. Probes a thin
-- band just below the body's bottom edge, mirroring
-- Pushable:hasSupportUnderCentre's own probe.
function GroundFaller.hasSupportUnderCentre(world, centreX, bottom)
	return GroundSupport.hasGroundAt(world, centreX, bottom + 4, bottom + 5)
end

-- Whether a body should currently be a static collider or a dynamic one.
--
-- A body at rest is STATIC, so it behaves exactly like the terrain it stands
-- in for -- this is correctness, not optimisation: a dynamic body
-- re-resolves gravity every frame, and when a dynamic body's top is flush
-- with a walking surface lib/bump reports a player's contact against it as a
-- wall (normal (-1,0)) rather than a step. It goes dynamic only while it
-- genuinely needs to move: nothing under its centre (gravity must take it),
-- still settling after a landing (going static mid-settle would freeze it
-- hanging above the surface, since support is probed a few pixels below its
-- feet), or moving under its own push/momentum.
function GroundFaller.bodyTypeFor(state)
	if not state.supported or state.airborne or state.moving then
		return 'dynamic'
	end

	return 'static'
end

return GroundFaller
