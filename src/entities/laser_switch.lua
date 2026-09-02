-- A laser-activated switch: a solid fixture (roof/wall/floor-mounted, like
-- `laser`/`mirror`/`blocker`) that drives its own `target` -- through exactly
-- the `target` + `Switchable`-or-`:switch()` mechanism `switch`/
-- `pressure_switch`/`blocker` already use -- for as long as a fully-on laser
-- beam is hitting its face from the ONE direction its `direction` property
-- names (e.g. a roof-mounted switch expecting a beam travelling `up` into
-- it). A hit from any other direction is a non-event: the resolver falls
-- through to this entity's own plain solidity (see below), same as any
-- other opaque obstacle.
--
-- "Absorbs the beam" needs ZERO logic here: this entity's own collider is
-- solid (sensor = false) unconditionally, so src/entities/laser_beam_
-- resolver.lua already stops any beam here regardless of direction, exactly
-- like a wall. All this file adds is a way for the resolver to ask, for a
-- hit it already decided stops here, whether THIS hit also counts as a
-- valid activation -- see :acceptsDirection below, the same "entity owns
-- its own direction knowledge, resolver only delegates" split
-- src/entities/mirror.lua's :redirect established.
--
-- Active/inactive is recomputed fresh every frame with no memory of a
-- previous cycle, same discipline as src/entities/pressure_switch.lua --
-- but unlike a pressure plate (which can poll "is anything on me right now"
-- for itself every frame via a world query), this switch has no cheap way
-- to ask "is a beam hitting me right now": only src/entities/laser.lua's
-- own update, which already ran the resolver this frame, knows that. So the
-- laser tells this switch about a valid hit via :receiveValidHit(), called
-- from Laser:update only while self:isFullyOn() (mirroring how killed/
-- destroyed are already gated there) -- and this switch's own update(dt)
-- reads that flag, decides on/off fresh, drives the target on a state
-- CHANGE only (matching pressure_switch's momentary-by-default model -- no
-- latching requested for this entity), and clears the flag for the next
-- frame.
--
-- Frame-timing consequence (documented per the slice's gotchas -- read this
-- before debugging a level): whether the switch reacts on the SAME frame
-- the laser hits it, or one frame LATER, depends on entity update order
-- within the map's entity list (whichever of Laser:update/LaserSwitch:
-- update happens to run first this frame, itself just insertion order --
-- the same "components run in list order" reality already present
-- elsewhere in this codebase, nothing unique to this slice):
--   * laser updates BEFORE the switch in the list: :receiveValidHit() is
--     called, then the switch's OWN update reads the just-set flag in the
--     same frame -- reacts immediately.
--   * laser updates AFTER the switch: the switch's update reads whatever
--     flag survived from the PREVIOUS frame's laser update (already true
--     or false), then clears it; the laser sets it fresh a moment later
--     this same frame, to be read on the NEXT frame's switch update. A
--     one-frame lag, not a stuck state -- the flag is unconditionally read
--     then cleared every single frame regardless of order, so a beam that
--     stops hitting (or starts) is reflected within one frame either way
--     and the switch can never get permanently stuck on or off.
-- Both orderings are self-correcting and deterministic for a fixed entity
-- order; the difference is a same-frame reaction vs a one-frame lag, never
-- a mistaken final state once the beam has been on (or off) for more than a
-- single frame.
local SpriteProps = require('src.entities.sprite_props')

local LaserSwitch = Class{__includes = Entity}

-- Pure: does a beam travelling `incomingDirection` validly hit a face whose
-- accepted direction is `switchDirection`? Kept as a free function (with a
-- thin entity method wrapping it, mirroring src/entities/mirror.lua's
-- redirect/:redirect split) purely so tests/unit/laser_switch_test.lua can
-- exercise it construction-free.
local function acceptsDirection(incomingDirection, switchDirection)
	return incomingDirection == switchDirection
end

function LaserSwitch:init(object, map)
	Entity.init(self, object, 'laser_switch')

	self.direction = (object.properties and object.properties.direction) or 'up'
	self.state = 'off'
	self.hitThisFrame = false

	-- Bottom-anchored, like every other gid-template mounted fixture
	-- (laser, mirror, blocker, switch): object.y is the mount's BOTTOM
	-- edge, so the rect's top sits one height above it.
	local topLeftY = object.y - object.height
	self.rect = Rect{x = object.x, y = topLeftY, width = object.width, height = object.height}
	local position = self.rect:centre()

	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = self.rect:colliderShapeArgs()
	self.sprite = self:addComponent(Sprite(spriteProps))

	-- Solid, unconditionally: this is what makes "absorbs the beam" free --
	-- the resolver's default "anything else non-sensor is opaque" rule
	-- already stops any beam here, valid direction or not, with zero
	-- resolver logic beyond recording the valid-direction case (see
	-- src/entities/laser_beam_resolver.lua's isLaserSwitch branch).
	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = 'static',
		sensor = false,
		position = position,
	})

	-- Solid for the BEAM (raycast classification only ever reads .sensor,
	-- never this) but never a physical obstacle to a player -- like
	-- src/entities/mirror.lua, this is a small mounted fixture, not a wall,
	-- so a player must be able to walk or fall straight through/onto it
	-- rather than getting caught standing on top of it. Mirrors
	-- src/entities/npc_rabbit.lua's own use of this same
	-- World.ignoresEntity mechanism (src/physics/bump/world.lua).
	self.collider.nonSolidEntityTypes = { player = true }

	-- Resolved the same way src/entities/pressure_switch.lua/switch.lua
	-- resolve their own target -- this entity OWNS a target pointing AT
	-- something else, it does not own its own Switchable the way
	-- laser.lua/mirror.lua do (those are driven BY a switch; this IS the
	-- switch, driving something else).
	if object.properties and object.properties.target then
		self.target = map:getObjectById(object.properties.target.id)
	end

	self.sound = self:addComponent(Sound{
		sounds = {
			press = 'res/snd/entity_pressure_press.wav',
			release = 'res/snd/entity_pressure_release.wav',
		}
	})
end

function LaserSwitch:isActive()
	return self.state == 'on'
end

-- incomingDirection -> true/false, the generic seam
-- src/entities/laser_beam_resolver.lua calls without needing to know what
-- "direction" means for this entity -- mirrors Mirror:redirect.
function LaserSwitch:acceptsDirection(incomingDirection)
	return acceptsDirection(incomingDirection, self.direction)
end

-- Called by Laser:update (only while the beam is fully on) when this
-- frame's resolved beam validly hit this switch's face. Purely records the
-- fact for this switch's own update to react to -- see the file header for
-- the resulting frame-timing discussion.
function LaserSwitch:receiveValidHit()
	self.hitThisFrame = true
end

function LaserSwitch:update(dt)
	Entity.update(self, dt)

	local wasActive = self:isActive()
	local isActive = self.hitThisFrame
	self.hitThisFrame = false

	if isActive == wasActive then
		return
	end

	self.state = isActive and 'on' or 'off'
	self.sound:play(isActive and 'press' or 'release')
	self:driveTarget()
end

-- mirrors src/entities/pressure_switch.lua's driveTarget: the target reads
-- this switch's `state` through a Switchable if it has one, else a raw
-- `.switch` method.
function LaserSwitch:driveTarget()
	if self.target == nil or self.target.entity == nil then
		return
	end

	local switchable = self.target.entity.getComponent and self.target.entity:getComponent(Switchable)
	if switchable then
		switchable:switch(self, nil)
	elseif self.target.entity.switch then
		self.target.entity:switch(self, nil)
	end
end

-- White-box seam for tests/unit/laser_switch_test.lua only; not for use by
-- production code.
LaserSwitch._internal = {
	acceptsDirection = acceptsDirection,
}

return LaserSwitch
