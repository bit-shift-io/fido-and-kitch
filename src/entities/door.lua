-- Switch-gated barrier across a horizontal passage: locked (solid) by
-- default, unlocked (passable) while its linked switch reports `on`.
-- Locked blocks everything -- players, enemies, pushed boxes alike; there
-- is no entity-type eligibility.
--
-- Mirrors src/entities/drawbridge.lua's state model (`closed`, `opening`,
-- `open`, `closing`) and its "recompute fresh every frame, keep no flags"
-- discipline. What it inverts is which state is permissive: the bridge
-- spans a pit, so solid is the forgiving state; a door bars a passage, so
-- passable is. Hence isDoorSolid(state) = state == 'closed' against the
-- bridge's isDeckSolid(state) = state ~= 'closed'.
--
-- Single file, not the multi-file directory ADR 0003 originally called
-- for: tests/support/headless_bootstrap.lua (ADR 0005) constructs a real
-- entity in the unit tier, so the pure decision helpers stay private
-- locals here and are reached only through the `Door._internal` white-box
-- seam at the bottom -- the drawbridge/pressure-switch pattern.

local Door = Class{__includes = Entity}

-- Solid in exactly one state. Every transition state is passable, so the
-- permissive side wins throughout an animation: nothing is ever sealed in
-- or crushed by a frame of it.
local function isDoorSolid(state)
	return state == 'closed'
end

-- The barrier is a thin vertical strip a quarter of the object wide,
-- centred in the object's rect, full height. Thin so the closed door reads
-- as a doorway you are stopped at rather than a wall the width of the art;
-- derived from the object's own size rather than pixels so a tile-size
-- change survives.
local BARRIER_WIDTH_FRACTION = 0.25

local function barrierDimensions(objectWidth, objectHeight)
	return objectWidth * BARRIER_WIDTH_FRACTION, objectHeight
end

-- The sprite draws 2x the object's own dimensions, centred on it -- half a
-- tile of bleed in every direction so door art can key into the
-- surrounding terrain (frame, lintel, threshold). Matches the drawbridge's
-- and the exit door's box, so every prop-scale entity draws to the same
-- footprint. Purely decorative: it is never a hint about what blocks or
-- what can be stood on.
--
-- Centred on the object rect like the drawbridge's, so it needs no
-- vertical lift. The exit door lifts its own 2x box only because it
-- anchors on Rect.centreOfMapObject (bottom-anchored, for gid-bearing tile
-- objects) rather than on the rect's centre.
local function spriteBoxDimensions(objectWidth, objectHeight)
	return objectWidth * 2, objectHeight * 2
end

-- The whole state model, as one pure function of the two live inputs --
-- the linked switch's reading and whether anything is standing in the
-- doorway -- both recomputed fresh every frame. There is no memory here on
-- purpose: no flag from a previous cycle for a later frame to trust, which
-- is what kept the drawbridge from getting permanently stuck (see its
-- DECISIONS.md Q3/Q4).
--
-- `occupied` only ever protects: it defers a close and reverses one already
-- under way, so a switch can never seal an entity into the doorway. It
-- cannot hold a door open against a switch that is still on, and it cannot
-- open a locked door.
local function nextState(state, enabled, occupied)
	if state == 'closed' then
		if enabled then
			return 'opening'
		end
		return state
	end

	if state == 'opening' or state == 'open' then
		if enabled or occupied then
			return state
		end
		return 'closing'
	end

	if state == 'closing' then
		if enabled or occupied then
			return 'opening'
		end
		return state
	end

	return state
end

-- The doorway is the object's whole rect, not the thin barrier: an entity
-- straddling the threshold is still in the door's way. Deliberately without
-- the drawbridge's OCCUPANCY_HEIGHT_MARGIN -- that margin exists because a
-- deck is a floor and its occupants stand ABOVE it, whereas a door is
-- already full height and anything in the way overlaps its rect directly.
local function doorwayBounds(rect)
	return {
		left = rect.x,
		right = rect.x + rect.width,
		top = rect.y,
		bottom = rect.y + rect.height,
	}
end

-- true if any collider in the doorway overlap set belongs to an entity
-- other than the door's own. Anything counts -- players, enemies, pushed
-- boxes -- there is no entity-type eligibility, exactly as with the
-- drawbridge's isHeld.
local function isOccupied(overlaps, selfEntity)
	for _, collider in ipairs(overlaps) do
		if collider.entity and collider.entity ~= selfEntity then
			return true
		end
	end
	return false
end

local function nextStateOnAnimationFinish(state)
	if state == 'opening' then
		return 'open'
	end

	if state == 'closing' then
		return 'closed'
	end

	return state
end

function Door:init(object)
	Entity.init(self, object, 'door')
	self.state = 'closed'

	self.rect = Rect(object)
	local position = self.rect:centre()

	-- visual footprint only -- the barrier below stays a thin strip; the
	-- bigger sprite is purely decorative bleed and must never be treated as
	-- a hint about what blocks or what can be stood on
	local spriteBoxWidth, spriteBoxHeight = spriteBoxDimensions(object.width, object.height)
	self.sprite = self:addComponent(Sprite{
		image = 'res/img/entity_door.png',
		frames = 2, -- todo: make more
		-- the drawbridge's pace: fast enough that the door finishes opening
		-- while whoever flipped the switch is still walking toward it
		duration = 0.3,
		loop = false,
		playing = false,
		position = position,
		shape_arguments = {0, 0, spriteBoxWidth, spriteBoxHeight},
		finish = utils.bindSelf(self.onAnimationFinish, self),
	})

	-- Deliberately NOT collider.walkable: nothing stands on a door. The flag
	-- is for entity-owned colliders a player walks along (the drawbridge's
	-- deck), and an unlock would drop whoever was standing here.
	local barrierWidth, barrierHeight = barrierDimensions(self.rect.width, self.rect.height)
	self.barrier = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, barrierWidth, barrierHeight},
		body_type = 'static',
		position = position,
		sensor = not isDoorSolid(self.state),
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_door_open.wav',
			close = 'res/snd/entity_door_close.wav',
		}
	})

	-- Switchable defaults enabled = true; a door must start LOCKED, so the
	-- default is overridden explicitly. The callback only records the
	-- reading -- every decision is made in update() from the recomputed
	-- inputs, so a switch flipped twice between frames can't leave the door
	-- acting on a state that no longer holds.
	self.switchEnabled = false
	self:addComponent(Switchable{
		entity = self,
		enabled = false,
		onStateChange = function(enabled)
			self.switchEnabled = enabled
		end
	})
end

-- flip solidity to match the new state
function Door:setState(state)
	self.state = state
	self.barrier:setSensor(not isDoorSolid(state))
end

function Door:update(dt)
	Entity.update(self, dt)

	-- recomputed fresh every frame, never remembered: no flag from an
	-- earlier frame can outlive the occupant it described
	local occupied = isOccupied(world:queryOverlap(doorwayBounds(self.rect)), self)

	local nextDoorState = nextState(self.state, self.switchEnabled, occupied)
	if nextDoorState == self.state then
		return
	end

	if nextDoorState == 'opening' then
		if self.state == 'closing' then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playForward() -- fresh open from the fully-closed end
		end
		self.sound:play('open')
	elseif nextDoorState == 'closing' then
		if self.state == 'opening' then
			self.sprite:reverseFromCurrent() -- reverse in place, no snap
		else
			self.sprite:playReverse() -- fresh close from the fully-open end
		end
		self.sound:play('close')
	end

	self:setState(nextDoorState)
end

function Door:onAnimationFinish()
	self:setState(nextStateOnAnimationFinish(self.state))
end

-- White-box seam for tests/unit/door_test.lua only -- see
-- drawbridge.lua's equivalent comment. Not for use by production code.
Door._internal = {
	isDoorSolid = isDoorSolid,
	barrierDimensions = barrierDimensions,
	spriteBoxDimensions = spriteBoxDimensions,
	nextState = nextState,
	doorwayBounds = doorwayBounds,
	isOccupied = isOccupied,
	nextStateOnAnimationFinish = nextStateOnAnimationFinish,
}

return Door
