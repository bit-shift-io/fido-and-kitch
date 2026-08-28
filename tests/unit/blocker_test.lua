-- Two tiers of coverage for src/entities/blocker.lua, both headless,
-- mirroring tests/unit/drawbridge_test.lua's split:
--
-- 1. Pure decision-helper tests against Blocker._internal -- fast,
--    construction-free, one assertion per branch.
-- 2. Entity-level tests that construct a real Blocker -- real Sprite, real
--    Collider, a real bump World -- via tests/support/headless_bootstrap,
--    and drive it through Blocker:update(dt) the way the game does.
--
-- The spatial "a player/box actually stops at the barrier" criteria belong
-- to tests/integration/blocker_test.lua (real Game/Map/World stack); this
-- file covers the decision logic and the entity's own wiring.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local Blocker = require('src.entities.blocker')
local B = Blocker._internal

--
-- Part 1: pure decision helpers
--

-- A blocker is passable in exactly one state -- fully open. Everything else
-- blocks: closed, and the whole opening telegraph. This is the deliberate
-- inversion of the drawbridge's isDeckSolid: opening is slow and late (the
-- blocker stays solid through its 1s timer), closing blocks instantly while
-- the gate-lowering art plays out behind it as cosmetics.
test('closed and opening blockers are solid; only open is passable', function()
	assertTrue(B.isBlocking('closed'))
	assertTrue(B.isBlocking('opening'))
	assertFalse(B.isBlocking('open'))
end)

test('the barrier is a thin strip -- 60% of the object width, full object height', function()
	local width, height = B.barrierDimensions(32, 32)
	assertNear(19.2, width)
	assertEqual(32, height)
end)

test('barrier dimensions derive from the object, not a hard-coded tile size', function()
	local width, height = B.barrierDimensions(48, 64)
	assertNear(28.8, width)
	assertEqual(64, height)
end)

test('the sprite fills the authored object rect -- the 1:2 gate object matches its 128x256 art', function()
	local width, height = B.spriteBoxDimensions(32, 64)
	assertEqual(32, width)
	assertEqual(64, height)
end)

test('the sprite box derives from the object dimensions, not a hard-coded size', function()
	local width, height = B.spriteBoxDimensions(48, 64)
	assertEqual(48, width)
	assertEqual(64, height)
end)

-- State is recomputed fresh every frame from the linked switch's reading --
-- no flag survives between frames, the property that makes the drawbridge
-- model safe.
test('a switch turned on starts a closed blocker opening', function()
	assertEqual('opening', B.nextState('closed', true))
end)

test('a blocker with its switch still off stays closed', function()
	assertEqual('closed', B.nextState('closed', false))
end)

test('the switch staying on leaves an opening or open blocker alone', function()
	assertEqual('opening', B.nextState('opening', true))
	assertEqual('open', B.nextState('open', true))
end)

test('flipping the switch off mid-open snaps the blocker straight back to closed -- no closing state', function()
	assertEqual('closed', B.nextState('opening', false))
end)

test('flipping the switch off an open blocker closes it in the same frame', function()
	assertEqual('closed', B.nextState('open', false))
end)

test('the open telegraph is a plain 1s timer, independent of any animation', function()
	assertNear(1, B.openingDuration)
end)

--
-- Part 2: entity-level, against a real constructed Blocker
--

local function makeBlocker(properties)
	HeadlessBootstrap.resetWorld()
	return Blocker({
		x = 128, y = 96, width = 32, height = 32,
		properties = properties or {},
	})
end

test('constructs headless with a real Sprite/Collider/World stack, closed and solid', function()
	local blocker = makeBlocker()

	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'a locked blocker must be a solid barrier, not a sensor')
	assertTrue(#blocker.sprite.frames >= 2, 'expected the blocker to animate, not hold a single still frame')
end)

-- The blocker is a gid-bearing tile object like switch/key/cage/exit_door:
-- object y is the gate's BOTTOM edge (Rect.centreOfMapObject), not its top.
-- The regression this guards: authored at (128, 96, 32, 32), the barrier
-- used to hang at y=112..144 (top-anchored) instead of standing at
-- y=80..112 above the object's bottom edge -- the sandbox instance read as
-- sunk below its walkway.
test('the barrier and sprite anchor to the object bottom, like every gid tile entity', function()
	local blocker = makeBlocker()

	assertEqual(144, blocker.barrier:getPositionV().x, 'barrier centre x = object x + half width')
	assertEqual(80, blocker.barrier:getPositionV().y,
		'barrier centre y = object y - half height: bottom-anchored, not y + half height')
	assertEqual(144, blocker.sprite.position.x, 'sprite centre must match the barrier centre x')
	assertEqual(80, blocker.sprite.position.y, 'sprite centre must match the barrier centre y')
end)

-- The visual-only offset knob: the author can nudge where the gate ART sits
-- without moving the bounding box. The barrier must stay on the authored
-- centre no matter what -- that is the whole point of the property.
test('spriteOffsetY shifts only the sprite -- the barrier keeps its authored centre', function()
	local plain = makeBlocker()
	assertEqual(80, plain.barrier:getPositionV().y)
	assertEqual(80, plain.sprite.position.y, 'no property: the sprite sits on the barrier centre')

	local lifted = makeBlocker({ spriteOffsetY = -24 })
	assertEqual(144, lifted.barrier:getPositionV().x)
	assertEqual(80, lifted.barrier:getPositionV().y, 'the barrier must not move when the art lifts')
	assertEqual(56, lifted.sprite.position.y, 'a negative offset lifts the art')

	local lowered = makeBlocker({ spriteOffsetY = 24 })
	assertEqual(80, lowered.barrier:getPositionV().y)
	assertEqual(104, lowered.sprite.position.y, 'a positive offset drops the art')
end)

-- A blocker authored with no switch pointing at it is a permanent wall, not
-- an error: switch wiring lives on the switch (switch.tj's `target`), so a
-- freshly-placed blocker legitimately has nothing referencing it yet.
test('a blocker with no switch wired stays locked and solid across many frames', function()
	local blocker = makeBlocker()

	for _ = 1, 120 do
		blocker:update(1 / 60)
	end

	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor())
end)

test('nothing stands on a blocker -- the barrier is never flagged walkable', function()
	local blocker = makeBlocker()

	assertFalse(blocker.barrier.walkable == true, 'the barrier must not opt into being ground')
end)

-- Switchable defaults enabled = true; a blocker that inherited that default
-- would start unlocked, contradicting "locked by default".
local function flipSwitch(blocker, on)
	blocker:getComponent(Switchable):switch({state = on and 'on' or 'off'})
end

test('the blocker starts with its switchable disabled -- locked by default, not open', function()
	local blocker = makeBlocker()

	assertFalse(blocker:getComponent(Switchable).enabled, 'a fresh blocker must read as switched off')
end)

-- The core timing asymmetry: opening is slow and late, and the delay is a
-- timer -- NOT the sprite's animation. Flipping the switch on starts the
-- gate-rising animation, but the barrier stays SOLID until the full second
-- elapses; only then does the passage open.
test('flipping the switch on keeps the barrier solid through the whole opening telegraph', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	blocker:update(1 / 60)

	assertEqual('opening', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'the barrier must stay solid during the 1s opening telegraph')
end)

test('the barrier disables after the 1s opening timer elapses, not on any animation event', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	for _ = 1, 30 do
		blocker:update(1 / 60) -- half a second in, still telegraphing
	end
	assertEqual('opening', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'half a second in the blocker must still block')

	for _ = 1, 30 do
		blocker:update(1 / 60) -- full second elapsed
	end
	assertEqual('open', blocker.state)
	assertTrue(blocker.barrier:isSensor(), 'a fully open blocker is passable')
end)

test('the barrier opens after 1s while the gate animation runs the full 2s', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	for _ = 1, 60 do
		blocker:update(1 / 60)
	end
	assertEqual('open', blocker.state, 'the 1s telegraph timer has already opened the passage')
	assertTrue(blocker.sprite:isPlaying(), 'the 2s gate-rising animation is still mid-flight')

	for _ = 1, 200 do
		blocker:update(1 / 60)
		if not blocker.sprite:isPlaying() then
			break
		end
	end
	assertEqual(#blocker.sprite.frames, blocker.sprite.frameNum, 'the gate finishes rising on the last frame at the end of the animation')
	assertFalse(blocker.sprite:isPlaying(), 'the 2s animation ends by itself at the raised frame')
end)

test('the opening animation plays forward -- the gate rises from the fully-lowered frame', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	blocker:update(1 / 60)

	assertEqual('forward', blocker.sprite:getDirection(),
		'opening must play the gate rising forward, not reverse')
	assertEqual(1, blocker.sprite.frameNum,
		'the opening animation must start from the fully-closed (first) frame')
end)

test('blocking is not hostage to the animation: a stalled sprite still opens on the timer', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	blocker:update(1 / 60)
	blocker.sprite.timeline:stop() -- the animation can never finish -- blocking must not care

	for _ = 1, 60 do
		blocker:update(1 / 60)
	end

	assertEqual('open', blocker.state, 'the timer must open the blocker even though its animation is stalled')
	assertTrue(blocker.barrier:isSensor())
end)

test('flipping the switch on plays the open sound', function()
	local blocker = makeBlocker()
	local spy = SoundSpy.install()

	flipSwitch(blocker, true)
	blocker:update(1 / 60)

	assertEqual('opening', blocker.state)
	assertEqual('open', spy.played[1], 'the transition into opening plays the open sound')
	spy.uninstall()
end)

-- Closing: blocking is instant -- no closing state, no animation wait -- the
-- moment the switch reads off, the blocker is solid in the same frame. The
-- gate-lowering animation plays out behind it as cosmetics only.
test('flipping the switch off an open blocker blocks it instantly -- solid that same frame', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	for _ = 1, 60 do
		blocker:update(1 / 60)
	end
	assertEqual('open', blocker.state)

	local spy = SoundSpy.install()
	flipSwitch(blocker, false)
	blocker:update(1 / 60)

	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'an instant close must be solid from the first frame')
	assertEqual('close', spy.played[1], 'the transition into closed plays the close sound')
	spy.uninstall()
end)

test('closing plays the gate-lowering animation in place while the barrier is already solid', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	for _ = 1, 200 do
		blocker:update(1 / 60) -- barrier opens at 1s, the 2s gate-rising art finishes after
		if not blocker.sprite:isPlaying() then
			break
		end
	end
	assertEqual('open', blocker.state)
	assertEqual(#blocker.sprite.frames, blocker.sprite.frameNum, 'rest open: the gate is fully raised on the last frame')

	flipSwitch(blocker, false)
	blocker:update(1 / 60)

	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'the barrier must already be solid while the gate is still lowering')
	assertEqual('reverse', blocker.sprite:getDirection(), 'closing plays the gate lowering, the reverse of opening')
	assertTrue(blocker.sprite:isPlaying(), 'the close must animate the gate down, not snap the art')

	for _ = 1, 200 do
		blocker:update(1 / 60) -- the 2s lowering animation
		if not blocker.sprite:isPlaying() then
			break
		end
	end
	assertEqual(1, blocker.sprite.frameNum,
		'once the lowering animation completes the gate rests on the fully-closed frame')
	assertFalse(blocker.sprite:isPlaying(), 'the lowering animation ends by itself at the closed frame')
end)

test('flipping the switch off mid-open blocks instantly while the gate lowers from its current frame', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	for _ = 1, 30 do
		blocker:update(1 / 60) -- a quarter of the way up the 2s rising animation
	end
	assertEqual('opening', blocker.state)

	local midFrame = blocker.sprite.frameNum
	flipSwitch(blocker, false)
	blocker:update(1 / 60)

	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'an instant close must be solid from the first frame')
	assertEqual('reverse', blocker.sprite:getDirection(), 'the gate must now be lowering, not raising')
	assertTrue(blocker.sprite:isPlaying(), 'the close must animate the gate down, not snap the art')
	assertTrue(blocker.sprite.frameNum >= midFrame - 1,
		'the gate must keep lowering from where it was, not jump frames')
end)

test('the blocker opens again normally after a close, from the fully-closed frame', function()
	local blocker = makeBlocker()

	flipSwitch(blocker, true)
	blocker:update(1 / 60)
	flipSwitch(blocker, false)
	blocker:update(1 / 60)
	assertEqual('closed', blocker.state)

	flipSwitch(blocker, true)
	blocker:update(1 / 60)
	assertEqual('opening', blocker.state)
	assertEqual('forward', blocker.sprite:getDirection(), 'a reopen must also play the gate rising forward')
	assertFalse(blocker.barrier:isSensor(), 'a fresh open still keeps the barrier solid through its telegraph')
end)