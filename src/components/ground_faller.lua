-- Keeps its collider static while the ground under its centre-x holds, and
-- flips to a dynamic, gravity-driven fall the instant that support
-- disappears -- settling back to static once it lands. Any entity can add
-- this; today that's the ground-following pickup behaviour (coin, key --
-- see src/entities/pickup_prop.lua), so a coin/key resting on a destructible
-- tile drops when the tile is destroyed instead of hovering in place.
--
-- Composes the pure decisions in src/physics/ground_faller.lua, mirroring
-- how src/components/pushable/pushable.lua splits its own per-frame world
-- polling from its support module's pure logic. Pushable additionally
-- decides push direction/speed and snaps to a tile on drop; this component
-- has no need for either -- a stationary pickup simply falls straight down
-- at whatever x it already had, with no push-across-tiles case to snap for.
--
-- Unlike Pushable, this can't lean on the physics engine to cancel its
-- vertical velocity on landing: a pickup's collider is a SENSOR (so players
-- can walk into it without being blocked, and it must never block anything
-- else either), and colFilter lets any contact with a sensor 'cross'
-- straight through with no collision response at all -- a dynamic sensor
-- collider still receives gravity and moves, while producing no solid
-- collision response (confirmed by how Collider:worldUpdate only skips
-- static bodies). So `supported` alone decides static-vs-dynamic here (no
-- separate airborne/settling check), and this component zeroes the vertical
-- velocity itself the instant support reappears -- otherwise a
-- perpetually-falling collider would just keep dropping through the ground
-- it landed on.
--
-- `groundProbeOffset` (optional): how far below the collider's own centre-y
-- to probe for ground, in place of the collider's own physical bottom edge.
-- PickupProp needs this: its collider is a circle whose bump box is sized by
-- RADIUS, not diameter (src/physics/bump/world.lua's newCollider), so its
-- physical box is half the height of the object's authored/visual footprint
-- and does not sit flush with whatever it visually rests on -- probing from
-- the physical bottom reads existing, already-placed map coins/keys as
-- unsupported and drops them a few pixels at load. Passing the authored
-- half-height instead makes the probe agree with where the object was
-- actually placed.
local GroundFaller = require('src.physics.ground_faller')

local GroundFallerComponent = Class{}

function GroundFallerComponent:init(props)
	self.type = 'ground_faller'
	self.collider = props.collider
	self.groundProbeOffset = props.groundProbeOffset
end

function GroundFallerComponent:update(dt)
	local bottom = self.groundProbeOffset
		and (self.collider:getY() + self.groundProbeOffset)
		or self.collider:getBounds().bottom
	local supported = GroundFaller.hasSupportUnderCentre(world, self.collider:getX(), bottom)

	if supported then
		local velocityX = self.collider:getLinearVelocity()
		self.collider:setLinearVelocity(velocityX, 0)
	end

	self.collider:setType(GroundFaller.bodyTypeFor({supported = supported}))
end

return GroundFallerComponent
