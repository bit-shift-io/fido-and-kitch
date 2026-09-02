-- A static-position diagonal reflector for laser beams (see src/entities/
-- laser_beam_resolver.lua for how the resolver uses it, and CONTEXT.md's
-- Mirror glossary entry).
--
-- Double-sided 45-degree mirror: a `flipMirror` bool picks one of the two
-- physically-realizable diagonals -- `false` is "/" (bottom-left to
-- top-right), `true` is "\" (top-left to bottom-right). Because a real
-- mirror reflects off EITHER face, there is no "wrong side" any more: every
-- incoming direction redirects into exactly one outgoing direction (see
-- REFLECTIONS below), never blocked/absorbed the way the old single-sided,
-- 4-orientation design could be. This replaces that earlier 4-orientation
-- model (up-right/down-right/down-left/up-left, each connecting only an
-- adjacent PAIR of directions and blocking the other two) -- see DECISIONS.md
-- for the superseded design.
--
-- Optional switch-driven flip: mirrors src/entities/blocker.lua's "owns an
-- optional Switchable, reacts only to one edge" wiring, but even simpler --
-- a mirror has no timer/animation, just an instant flip on the 'on' edge
-- only. Switchable:switch() already passes the resulting boolean straight
-- into onStateChange (src/components/switchable.lua), and the callers that
-- drive it -- switch.lua/pressure_switch.lua/timer_switch.lua -- already
-- only call it on their own state CHANGE, so "flips once per activation"
-- falls out for free with no extra debouncing here. A mirror never polls
-- anything in update(): with no switch wired to it, nothing ever calls
-- :switch() on its Switchable, so it stays at its authored flipMirror value
-- forever. With only two states, "rotating" it is just toggling the bool --
-- there is no cycle to advance through.
--
-- The collider is solid (sensor = false), same as any other opaque prop --
-- a mirror is a physical obstacle, it just happens to redirect every beam
-- that reaches it rather than stopping one.
--
-- No real sprite-sheet art exists for a mirror (see src/entities/laser.lua's
-- file header for the project-wide reason -- nothing here can author real
-- binary image data). res/entities/mirror.tj reuses entity_switch.png as a
-- 2-frame placeholder sheet, one frame per flipMirror state.
-- Sprite:setFrameNum picks the right static frame directly -- there is no
-- animation to play, just a flip-driven frame swap.
local SpriteProps = require('src.entities.sprite_props')

local Mirror = Class{__includes = Entity}

-- Every incoming direction redirects somewhere -- a double-sided mirror
-- never blocks. Each table is its own inverse (redirecting the OUTGOING
-- direction back in reflects back to the original incoming one), matching
-- how a real mirror works from either face.
local REFLECTIONS = {
	[false] = { -- "/" (bottom-left to top-right)
		up = 'right',
		right = 'up',
		down = 'left',
		left = 'down',
	},
	[true] = { -- "\" (top-left to bottom-right)
		up = 'left',
		left = 'up',
		down = 'right',
		right = 'down',
	},
}

-- Which placeholder sheet frame (1-2) corresponds to each flipMirror state --
-- arbitrary but stable, matching res/entities/mirror.tj's 2-frame sheet.
local FLIP_FRAME = {
	[false] = 1,
	[true] = 2,
}

local DEFAULT_FLIP_MIRROR = false

-- incomingDirection -> outgoing direction. Always succeeds for a real
-- flipMirror value (true/false) -- a double-sided mirror has no
-- "unconnected" direction to block, unlike the old 4-orientation design.
local function redirect(flipMirror, incomingDirection)
	local table_ = REFLECTIONS[flipMirror]
	if not table_ then
		return nil
	end
	return table_[incomingDirection]
end

function Mirror:init(object, map)
	Entity.init(self, object, 'mirror')

	self.flipMirror = (object.properties and object.properties.flipMirror) or DEFAULT_FLIP_MIRROR

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

	-- Solid for the BEAM (raycast classification only ever reads .sensor,
	-- never this) but never a physical obstacle to a player -- a mirror is a
	-- small mounted fixture, not a wall, so a player must be able to walk
	-- or fall straight through/onto it rather than getting caught standing
	-- on top of it. Mirrors src/entities/npc_rabbit.lua's own use of this
	-- same World.ignoresEntity mechanism (src/physics/bump/world.lua) to be
	-- solid against the world in general but pass through players.
	self.collider.nonSolidEntityTypes = { player = true }

	-- Optional: nothing ever calls :switch() on this unless a lever/
	-- pressure_switch/timer_switch's own `target` points at this mirror's
	-- object id, in which case only the 'on' transition flips it.
	self:addComponent(Switchable{
		entity = self,
		enabled = true,
		onStateChange = function(enabled)
			if enabled then
				self.flipMirror = not self.flipMirror
				self:updateSpriteFrame()
			end
		end
	})
end

function Mirror:updateSpriteFrame()
	local frameNum = FLIP_FRAME[self.flipMirror] or 1
	if #self.sprite.frames >= frameNum then
		self.sprite:setFrameNum(frameNum)
	end
end

-- x, y: this mirror's own centre -- the point a bounced beam pivots
-- through, not wherever the incoming raycast happened to cross its
-- collider's edge. See laser_beam_resolver.lua's isMirror branch for why
-- that distinction matters for keeping a multi-mirror chain grid-aligned.
function Mirror:getPosition()
	return self.collider:getX(), self.collider:getY()
end

-- incomingDirection -> outgoing direction -- the generic seam
-- src/entities/laser_beam_resolver.lua calls without needing to know what
-- flipMirror means. Always returns a direction (never nil) for a real
-- mirror: double-sided, it has no unconnected/blocked incoming direction.
function Mirror:redirect(incomingDirection)
	return redirect(self.flipMirror, incomingDirection)
end

-- White-box seam for tests/unit/mirror_test.lua only.
Mirror._internal = {
	redirect = redirect,
	reflections = REFLECTIONS,
	flipFrame = FLIP_FRAME,
	defaultFlipMirror = DEFAULT_FLIP_MIRROR,
}

return Mirror
