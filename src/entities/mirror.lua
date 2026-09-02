-- A static-position diagonal reflector for laser beams (see src/entities/
-- laser_beam_resolver.lua for how the resolver uses it, and CONTEXT.md's
-- Mirror glossary entry).
--
-- `orientation` is one of 4 diagonal values (up-right, down-right,
-- down-left, up-left), each NAMING the two directions it connects -- e.g.
-- up-right connects up and right: a beam entering while travelling up
-- exits travelling right, and vice versa. A beam travelling in a direction
-- the mirror doesn't connect is not redirected (see Mirror:redirect).
--
-- Optional switch-driven rotation: mirrors src/entities/blocker.lua's
-- "owns an optional Switchable, reacts only to one edge" wiring, but even
-- simpler -- a mirror has no timer/animation, just an instant orientation
-- flip on the 'on' edge only. Switchable:switch() already passes the
-- resulting boolean straight into onStateChange (src/components/
-- switchable.lua), and the callers that drive it -- switch.lua/
-- pressure_switch.lua/timer_switch.lua -- already only call it on their
-- own state CHANGE, so "rotates once per activation" falls out for free
-- with no extra debouncing here. A mirror never polls anything in
-- update(): with no switch wired to it, nothing ever calls :switch() on
-- its Switchable, so it stays at its authored orientation forever.
--
-- The collider is solid (sensor = false), same as any other opaque prop:
-- a beam arriving from a direction this mirror doesn't connect must stop
-- here exactly like hitting a wall (see the resolver's isMirror branch --
-- entity:redirect returning nil falls through to being treated as any
-- other opaque obstacle).
--
-- No real sprite-sheet art exists for a mirror (see src/entities/laser.lua's
-- file header for the project-wide reason -- nothing here can author real
-- binary image data). res/entities/mirror.tj reuses entity_switch.png as a
-- 4-frame placeholder sheet, one frame per orientation, the same
-- placeholder-reuse precedent laser.tj already set. Sprite:setFrameNum
-- picks the right static frame directly -- there is no animation to play,
-- just a rotation-driven frame swap.
local SpriteProps = require('src.entities.sprite_props')

local Mirror = Class{__includes = Entity}

-- Each orientation names the two directions it connects. A beam entering
-- from either direction in the pair exits travelling the other.
local CONNECTIONS = {
	['up-right'] = {'up', 'right'},
	['down-right'] = {'down', 'right'},
	['down-left'] = {'down', 'left'},
	['up-left'] = {'up', 'left'},
}

-- The fixed 4-cycle rotation, one step clockwise per 'on' activation.
local ROTATION_CYCLE = {
	['up-right'] = 'down-right',
	['down-right'] = 'down-left',
	['down-left'] = 'up-left',
	['up-left'] = 'up-right',
}

-- Which placeholder sheet frame (1-4) corresponds to each orientation --
-- arbitrary but stable, matching res/entities/mirror.tj's 4-frame sheet.
local ORIENTATION_FRAME = {
	['up-right'] = 1,
	['down-right'] = 2,
	['down-left'] = 3,
	['up-left'] = 4,
}

local DEFAULT_ORIENTATION = 'up-right'

local function nextOrientation(orientation)
	return ROTATION_CYCLE[orientation] or orientation
end

-- incomingDirection -> outgoing direction, or nil when incomingDirection is
-- not one of this orientation's two connected directions (blocked/opaque).
local function redirect(orientation, incomingDirection)
	local pair = CONNECTIONS[orientation]
	if not pair then
		return nil
	end
	if incomingDirection == pair[1] then
		return pair[2]
	elseif incomingDirection == pair[2] then
		return pair[1]
	end
	return nil
end

function Mirror:init(object, map)
	Entity.init(self, object, 'mirror')

	self.orientation = (object.properties and object.properties.orientation) or DEFAULT_ORIENTATION

	-- Bottom-anchored, like every other gid-template entity (switch,
	-- blocker, laser): object.y is the mount's bottom edge.
	local position = Rect.centreOfMapObject(object)
	local shapeArguments = Rect.shapeArgs(object.width, object.height)

	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = shapeArguments
	spriteProps.playing = false
	self.sprite = self:addComponent(Sprite(spriteProps))
	self:updateSpriteFrame()

	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shapeArguments,
		body_type = 'static',
		sensor = false,
		position = position,
	})

	-- Optional: nothing ever calls :switch() on this unless a lever/
	-- pressure_switch/timer_switch's own `target` points at this mirror's
	-- object id, in which case only the 'on' transition rotates it.
	self:addComponent(Switchable{
		entity = self,
		enabled = true,
		onStateChange = function(enabled)
			if enabled then
				self.orientation = nextOrientation(self.orientation)
				self:updateSpriteFrame()
			end
		end
	})
end

function Mirror:updateSpriteFrame()
	local frameNum = ORIENTATION_FRAME[self.orientation] or 1
	if #self.sprite.frames >= frameNum then
		self.sprite:setFrameNum(frameNum)
	end
end

-- incomingDirection -> outgoing direction, or nil (blocked/opaque) --
-- the generic seam src/entities/laser_beam_resolver.lua calls without
-- needing to know what the 4 orientation values mean.
function Mirror:redirect(incomingDirection)
	return redirect(self.orientation, incomingDirection)
end

-- White-box seam for tests/unit/mirror_test.lua only.
Mirror._internal = {
	redirect = redirect,
	nextOrientation = nextOrientation,
	connections = CONNECTIONS,
	orientationFrame = ORIENTATION_FRAME,
	defaultOrientation = DEFAULT_ORIENTATION,
}

return Mirror
