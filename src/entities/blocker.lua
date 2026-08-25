-- Switch-gated blocker across a horizontal passage: a solid barrier by
-- default that opens -- and stays open -- while its linked switch reports
-- `on`. Blocks everything -- players, enemies, pushed boxes alike; there
-- is no entity-type eligibility.
--
-- The opening and closing timing is deliberately asymmetric. Opening is
-- slow and late: the barrier stays solid for a full second after the
-- switch flips and only stops blocking once that delay elapses, so a
-- switch flip has a visible one-second telegraph before the passage opens.
-- The delay is a plain timer, deliberately NOT the sprite's animation -- the
-- gate-rising art just runs alongside it -- so blocking is never hostage to
-- animation playback. Closing inverts the asymmetry: the barrier snaps back
-- to solid the very same frame the switch reads off -- a blocker slams shut
-- rather than easing down, and nothing can slip through a half-closed gap --
-- while the gate-lowering art plays out over the same second as pure
-- cosmetics, reversing the opening motion in place.
--
-- Mirrors src/entities/drawbridge.lua's state model (`closed`, `opening`,
-- `open`, `closing`) and its "recompute fresh every frame, keep no flags"
-- discipline, minus the bridge's `closing` state: a close is a same-frame
-- state flip, so there is nothing mid-flight to track -- the gate-lowering
-- animation that follows is cosmetic, not a state. What it inverts from the
-- bridge is which state is permissive: the bridge spans a pit, so solid is
-- the forgiving state; a blocker bars a passage, so passable is. Hence
-- isBlocking(state) = state ~= 'open' -- passable in exactly one state --
-- against the bridge's isDeckSolid(state) = state == 'closed'.
--
-- Single file, not the multi-file directory ADR 0003 originally called
-- for: tests/support/headless_bootstrap.lua (ADR 0005) constructs a real
-- entity in the unit tier, so the pure decision helpers stay private
-- locals here and are reached only through the `Blocker._internal` white-box
-- seam at the bottom -- the drawbridge/pressure-switch pattern.

local Blocker = Class{__includes = Entity}

-- Passable in exactly one state. Every other state -- closed, and the whole
-- opening animation -- blocks, so nothing slips through the gap while the
-- blocker is raising, and a fresh switch flip snaps it solid immediately.
-- The opening telegraph: how long the barrier stays solid after the switch
-- flips before the passage opens. A timer, not the sprite's animation --
-- blocking must survive a stalled or absent animation.
local OPENING_DURATION = 1

local function isBlocking(state)
	return state ~= 'open'
end

-- The barrier is a thin vertical strip 60% of the object wide, centred in
-- the object's rect, full height. Thin so the closed blocker reads as a
-- doorway you are stopped at rather than a wall the width of the art;
-- derived from the object's own size rather than pixels so a tile-size
-- change survives.
local BARRIER_WIDTH_FRACTION = 0.6

local function barrierDimensions(objectWidth, objectHeight)
	return objectWidth * BARRIER_WIDTH_FRACTION, objectHeight
end

-- The sprite draws 2x the object's height (its width is unchanged), centred
-- on it -- bleed in every direction so blocker art can key into the
-- surrounding terrain (frame, lintel, threshold). Purely decorative: it is
-- never a hint about what blocks or what can be stood on.
--
-- Centred on the object rect like the drawbridge's, so it needs no
-- vertical lift. The exit door lifts its own 2x box only because it
-- anchors on Rect.centreOfMapObject (bottom-anchored, for gid-bearing tile
-- objects) rather than on the rect's centre.
local function spriteBoxDimensions(objectWidth, objectHeight)
	return objectWidth, objectHeight * 2
end

-- The sprite sits 16px below the rect's centre, purely cosmetic: the
-- barrier (collision) stays anchored to the object's centre. Tuned so the
-- blocker art reads correctly against its frame/lintel without moving the
-- blocking strip.
local SPRITE_OFFSET_Y = 12

-- The whole state model, as one pure function of the live input -- the
-- linked switch's reading -- recomputed fresh every frame. There is no
-- memory here on purpose: no flag from a previous cycle for a later frame
-- to trust, which is what kept the drawbridge from getting permanently
-- stuck (see its DECISIONS.md Q3/Q4).
local function nextState(state, enabled)
	if state == 'closed' then
		if enabled then
			return 'opening'
		end
		return state
	end

	if state == 'opening' then
		if enabled then
			return state
		end
		return 'closed'
	end

	-- open
	if enabled then
		return state
	end
	return 'closed'
end

-- A blocker has no `closing` state: a close is a same-frame state flip --
-- the opening transition is driven by OPENING_DURATION (see update), and a
-- close is driven by nothing -- it is instant. There is deliberately no
-- nextStateOnAnimationFinish: blocking is never tied to animation playback.

-- A close snaps the STATE -- and therefore the barrier's solidity -- the
-- same frame the switch reads off, while the art eases the gate down over
-- the same second as cosmetics: reverseFromCurrent flips the running
-- animation's direction in place, so the gate lowers from wherever it is --
-- a smooth reversal mid-raise, a full descent from rest-open -- instead of
-- an instant art snap. Blocking never waits on it and never depends on it.

function Blocker:init(object)
	Entity.init(self, object, 'blocker')
	self.state = 'closed'

	self.rect = Rect(object)
	local position = self.rect:centre()

	-- visual footprint only -- the barrier below stays a thin strip; the
	-- bigger sprite is purely decorative bleed and must never be treated as
	-- a hint about what blocks or what can be stood on
	local spriteBoxWidth, spriteBoxHeight = spriteBoxDimensions(object.width, object.height)
	self.sprite = self:addComponent(Sprite{
		image = 'res/img/entity_blocker.png',
		frames = 48,
		-- the gate animation is 2s and purely cosmetic; the barrier opens on
		-- the 1s telegraph timer regardless of where the art has got to
		duration = 2,
		loop = false,
		playing = false,
		position = position + Vector(0, SPRITE_OFFSET_Y),
		shape_arguments = {spriteBoxWidth, spriteBoxHeight},
	})

	-- start at rest closed: the gate fully lowered -- the FIRST frame of the
	-- sheet -- with the timeline parked at its start so a later opening plays
	-- forward from the correct spot
	self.sprite:playForward()
	self.sprite.timeline:stop()

	-- Deliberately NOT collider.walkable: nothing stands on a blocker. The
	-- flag is for entity-owned colliders a player walks along (the
	-- drawbridge's deck), and an unlock would drop whoever was standing here.
	local barrierWidth, barrierHeight = barrierDimensions(self.rect.width, self.rect.height)
	self.barrier = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {barrierWidth, barrierHeight},
		body_type = 'static',
		position = position,
		sensor = not isBlocking(self.state),
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_blocker_open.wav',
			close = 'res/snd/entity_blocker_close.wav',
		}
	})

	-- Switchable defaults enabled = true; a blocker must start LOCKED, so the
	-- default is overridden explicitly. The callback only records the
	-- reading -- every decision is made in update() from the recomputed
	-- input, so a switch flipped twice between frames can't leave the blocker
	-- acting on a state that no longer holds.
	self.switchEnabled = false
	self:addComponent(Switchable{
		entity = self,
		enabled = false,
		onStateChange = function(enabled)
			self.switchEnabled = enabled
		end
	})

	self.openingTimer = 0
end

-- flip solidity to match the new state
function Blocker:setState(state)
	self.state = state
	self.barrier:setSensor(not isBlocking(state))
end

function Blocker:update(dt)
	Entity.update(self, dt)

	-- recomputed fresh every frame, never remembered
	local nextBlockerState = nextState(self.state, self.switchEnabled)

	if nextBlockerState == 'opening' then
		if self.state ~= 'opening' then
			-- fresh open: raise the gate (forward -- frame 1 up to the last
			-- frame) and start the telegraph timer
			self.sprite:playForward()
			self.sound:play('open')
			self.openingTimer = 0
			self:setState('opening')
		end

		-- the passage opens on the timer, not on animation finish -- the
		-- sprite may stall or be absent and the blocker still opens on time
		self.openingTimer = self.openingTimer + dt
		if self.openingTimer >= OPENING_DURATION then
			self:setState('open')
		end
		return
	end

	if nextBlockerState ~= self.state then
		-- closed: blocking is instant -- solid this same frame -- while the
		-- gate-lowering animation plays out as cosmetics, reversing the
		-- opening motion in place
		self.sprite:reverseFromCurrent()
		self.sound:play('close')
		self:setState('closed')
	end
end

-- White-box seam for tests/unit/blocker_test.lua only -- see
-- drawbridge.lua's equivalent comment. Not for use by production code.
Blocker._internal = {
	isBlocking = isBlocking,
	barrierDimensions = barrierDimensions,
	spriteBoxDimensions = spriteBoxDimensions,
	nextState = nextState,
	openingDuration = OPENING_DURATION,
}

return Blocker