-- Two tiers of coverage for src/entities/door.lua, both headless, mirroring
-- tests/unit/drawbridge_test.lua's split:
--
-- 1. Pure decision-helper tests against Door._internal -- fast,
--    construction-free, one assertion per branch.
-- 2. Entity-level tests that construct a real Door -- real Sprite, real
--    Collider, a real bump World -- via tests/support/headless_bootstrap,
--    and drive it through Door:update(dt) the way the game does.
--
-- The spatial "a player/box actually stops at the barrier" criteria belong
-- to tests/integration/door_test.lua (real Game/Map/World stack); this file
-- covers the decision logic and the entity's own wiring.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local Door = require('src.entities.door')
local D = Door._internal

--
-- Part 1: pure decision helpers
--

-- The mirror image of the drawbridge's isDeckSolid: for a bridge over a
-- pit the permissive state is solid, for a door it is passable, so the
-- door is solid in exactly one state -- fully closed.
test('a closed door is solid', function()
	assertTrue(D.isDoorSolid('closed'))
end)

test('opening, open and closing doors are all passable -- the permissive state wins through a transition', function()
	for _, state in ipairs({'opening', 'open', 'closing'}) do
		assertFalse(D.isDoorSolid(state), state .. ' should be passable')
	end
end)

test('the barrier is a thin strip -- 25% of the object width, full object height', function()
	local width, height = D.barrierDimensions(32, 32)
	assertEqual(8, width)
	assertEqual(32, height)
end)

test('barrier dimensions derive from the object, not a hard-coded tile size', function()
	local width, height = D.barrierDimensions(48, 64)
	assertEqual(12, width)
	assertEqual(64, height)
end)

test('the sprite box is 3x the object dimensions, centred -- decorative bleed only', function()
	local width, height = D.spriteBoxDimensions(32, 32)
	assertEqual(96, width)
	assertEqual(96, height)
end)

test('the sprite box derives from the object dimensions, not a hard-coded size', function()
	local width, height = D.spriteBoxDimensions(48, 64)
	assertEqual(144, width)
	assertEqual(192, height)
end)

-- State is recomputed fresh every frame from (switch enabled, doorway
-- occupied) -- no flag survives between frames, the property that makes the
-- drawbridge model safe. `occupied` is always false here; slice 04's
-- occupancy branches are exercised further down.
test('a switch turned on unlocks a closed door', function()
	assertEqual('opening', D.nextState('closed', true, false))
end)

test('a door with its switch still off stays closed', function()
	assertEqual('closed', D.nextState('closed', false, false))
end)

test('an unoccupied doorway lets an open door close once the switch goes off', function()
	assertEqual('closing', D.nextState('open', false, false))
end)

test('the switch staying on leaves an opening or open door alone', function()
	assertEqual('opening', D.nextState('opening', true, false))
	assertEqual('open', D.nextState('open', true, false))
end)

test('flipping the switch off mid-open reverses the door back toward closed', function()
	assertEqual('closing', D.nextState('opening', false, false))
end)

test('flipping the switch back on mid-close reopens the door', function()
	assertEqual('opening', D.nextState('closing', true, false))
end)

test('a closing door with the switch off and a clear doorway keeps closing', function()
	assertEqual('closing', D.nextState('closing', false, false))
end)

-- Occupancy only ever protects: a switch must never be able to seal a
-- player into the doorway (see DECISIONS.md Q4).
test('an occupied doorway keeps an open door open even with the switch off', function()
	assertEqual('open', D.nextState('open', false, true))
end)

test('something entering the doorway mid-close reverses the door back to opening', function()
	assertEqual('opening', D.nextState('closing', false, true))
end)

test('an occupant cannot open a locked door -- it only defers closing', function()
	assertEqual('closed', D.nextState('closed', false, true))
end)

-- The doorway is the object's whole rect, not the thin barrier: an entity
-- straddling the threshold is standing in the door's way and must count.
-- No height margin, unlike the drawbridge's OCCUPANCY_HEIGHT_MARGIN -- its
-- deck is a floor with occupants standing ABOVE it, whereas a door is
-- already full height and an occupant overlaps its rect directly.
test('the doorway covers the full object rect, not just the barrier strip', function()
	local bounds = D.doorwayBounds({x = 128, y = 96, width = 32, height = 32})

	assertEqual(128, bounds.left)
	assertEqual(160, bounds.right)
	assertEqual(96, bounds.top)
	assertEqual(128, bounds.bottom)
end)

test('the door\'s own colliders never count as occupants', function()
	local door = {}
	local ownCollider = {entity = door}
	local terrainCollider = {entity = nil}
	local occupantCollider = {entity = {type = 'player'}}

	assertFalse(D.isOccupied({ownCollider, terrainCollider}, door))
	assertFalse(D.isOccupied({}, door))
	assertTrue(D.isOccupied({occupantCollider}, door))
end)

test('anything occupies a doorway -- players, enemies and props alike', function()
	local door = {}

	assertTrue(D.isOccupied({{entity = {type = 'enemy'}}}, door))
	assertTrue(D.isOccupied({{entity = {type = 'push_box'}}}, door))
end)

test('the open animation finishing transitions opening to open', function()
	assertEqual('open', D.nextStateOnAnimationFinish('opening'))
end)

test('the close animation finishing transitions closing to closed', function()
	assertEqual('closed', D.nextStateOnAnimationFinish('closing'))
end)

test('animation finish has no effect on closed or open (nothing mid-flight)', function()
	assertEqual('closed', D.nextStateOnAnimationFinish('closed'))
	assertEqual('open', D.nextStateOnAnimationFinish('open'))
end)

--
-- Part 2: entity-level, against a real constructed Door
--

local function makeDoor(properties)
	HeadlessBootstrap.resetWorld()
	return Door({
		x = 128, y = 96, width = 32, height = 32,
		properties = properties or {},
	})
end

test('constructs headless with a real Sprite/Collider/World stack, closed and solid', function()
	local door = makeDoor()

	assertEqual('closed', door.state)
	assertFalse(door.barrier:isSensor(), 'a locked door must be a solid barrier, not a sensor')
	assertEqual(4, #door.sprite.frames)
end)

-- A door authored with no switch pointing at it is a permanent wall, not an
-- error: switch wiring lives on the switch (switch.tx's `target`), so a
-- freshly-placed door legitimately has nothing referencing it yet.
test('a door with no switch wired stays locked and solid across many frames', function()
	local door = makeDoor()

	for _ = 1, 120 do
		door:update(1 / 60)
	end

	assertEqual('closed', door.state)
	assertFalse(door.barrier:isSensor())
end)

test('nothing stands on a door -- the barrier is never flagged walkable', function()
	local door = makeDoor()

	assertFalse(door.barrier.walkable == true, 'the barrier must not opt into being ground')
end)

-- Switchable defaults enabled = true; a door that inherited that default
-- would start unlocked, contradicting "locked by default".
local function flipSwitch(door, on)
	door:getComponent(Switchable):switch({state = on and 'on' or 'off'})
end

test('the door starts with its switchable disabled -- locked by default, not open', function()
	local door = makeDoor()

	assertFalse(door:getComponent(Switchable).enabled, 'a fresh door must read as switched off')
end)

test('flipping the switch on makes the barrier passable from the frame opening starts', function()
	local door = makeDoor()
	local spy = SoundSpy.install()

	flipSwitch(door, true)
	door:update(1 / 60)

	assertEqual('opening', door.state)
	assertTrue(door.barrier:isSensor(), 'the barrier must go passable as soon as opening begins')
	assertEqual('open', spy.played[1], 'the transition into opening plays the open sound')

	spy.uninstall()
end)

test('the barrier turns solid again only once the closing animation finishes', function()
	local door = makeDoor()

	flipSwitch(door, true)
	door:update(1 / 60)
	door:onAnimationFinish() -- opening -> open

	local spy = SoundSpy.install()
	flipSwitch(door, false)
	door:update(1 / 60)

	assertEqual('closing', door.state)
	assertTrue(door.barrier:isSensor(), 'a closing door stays passable -- nothing is sealed in mid-animation')
	assertEqual('close', spy.played[1], 'the transition into closing plays the close sound')
	spy.uninstall()

	door:onAnimationFinish() -- closing -> closed
	assertEqual('closed', door.state)
	assertFalse(door.barrier:isSensor(), 'a fully closed door is solid again')
end)

-- reverseFromCurrent flips direction from the frame currently showing;
-- playForward/playReverse restart from an end. Reversing mid-transition
-- with the latter would snap the art, right next to the player.
-- a bare dynamic collider standing in for an occupant (player/enemy/pushed
-- box) -- the fake-collider convention from drawbridge_test.lua. groupIndex
-- must be concrete and distinct from -1 (the players' group): two colliders
-- that never set one both read nil, and nil == nil in Lua, so World.colFilter
-- would treat them as the same group and never collide them at all.
local function spawnOccupant(x, y)
	local occupant = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 8, 30},
		body_type = 'dynamic',
		position = {x = x, y = y},
	}
	occupant.entity = {type = 'occupant'}
	occupant:setGroupIndex(100)
	return occupant
end

test('a switch flipped off with someone in the doorway leaves the door open, not closing', function()
	local door = makeDoor()

	flipSwitch(door, true)
	door:update(1 / 60)
	door:onAnimationFinish() -- opening -> open

	spawnOccupant(door.rect:centre().x, door.rect.y + 16)
	flipSwitch(door, false)
	for _ = 1, 120 do
		door:update(1 / 60)
	end

	assertEqual('open', door.state, 'a permanent occupant must leave the door permanently open')
	assertTrue(door.barrier:isSensor(), 'the door must stay passable -- nobody is sealed in')
end)

test('the door closes on its own once the doorway clears, with no further switch input', function()
	local door = makeDoor()

	flipSwitch(door, true)
	door:update(1 / 60)
	door:onAnimationFinish()

	local occupant = spawnOccupant(door.rect:centre().x, door.rect.y + 16)
	flipSwitch(door, false)
	door:update(1 / 60)
	assertEqual('open', door.state, 'fixture check: expected the occupant to defer the close')

	occupant:destroy()
	door:update(1 / 60)

	assertEqual('closing', door.state, 'expected the cleared doorway alone to start the close')
end)

test('something entering the doorway mid-close reverses the door back to opening', function()
	local door = makeDoor()

	flipSwitch(door, true)
	door:update(1 / 60)
	door:onAnimationFinish()
	flipSwitch(door, false)
	door:update(1 / 60)
	assertEqual('closing', door.state, 'fixture check: expected the door to be closing')

	spawnOccupant(door.rect:centre().x, door.rect.y + 16)
	door:update(1 / 60)

	assertEqual('opening', door.state)
	assertTrue(door.barrier:isSensor())
end)

test('reversing an in-flight transition reverses the animation in place, with no frame snap', function()
	local door = makeDoor()

	flipSwitch(door, true)
	door:update(1 / 60)
	door:update(1 / 60) -- part-way through opening
	local midFrame = door.sprite.frameNum

	flipSwitch(door, false)
	door:update(1 / 60)

	assertEqual('closing', door.state)
	assertTrue(math.abs(door.sprite.frameNum - midFrame) <= 1,
		'expected the reversal to continue from the current frame, not snap to an end')
end)
