-- Pure unit tests for src/entities/laser.lua's power state machine, driven
-- directly against Laser._internal -- no Sprite/Collider/World construction
-- needed (mirrors tests/unit/blocker_test.lua's Part 1: pure decision
-- helpers). Entity-level (sound-once-per-edge, timeline reverse-in-place)
-- coverage belongs to tests/integration/laser_powerup_safety_test.lua,
-- which constructs a real Laser through the full game stack.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
HeadlessBootstrap.resetWorld()

local Laser = require('src.entities.laser')
local L = Laser._internal

test('an off laser starts warming once its switch is enabled', function()
	assertEqual('warming', L.nextState('off', true))
end)

test('an off laser with its switch still disabled stays off', function()
	assertEqual('off', L.nextState('off', false))
end)

test('a warming laser stays warming while the switch stays enabled', function()
	assertEqual('warming', L.nextState('warming', true))
end)

test('a fully-on laser stays on while the switch stays enabled', function()
	assertEqual('on', L.nextState('on', true))
end)

-- Switching off mid-warming reverses from wherever it currently is --
-- 'cooling', not an instant snap to 'off'.
test('switching off mid-warming moves to cooling, not straight to off', function()
	assertEqual('cooling', L.nextState('warming', false))
end)

test('switching off a fully-on laser starts cooling', function()
	assertEqual('cooling', L.nextState('on', false))
end)

test('a cooling laser stays cooling while the switch stays disabled', function()
	assertEqual('cooling', L.nextState('cooling', false))
end)

-- Interrupted mid-power-down: switching back on before cooling finishes
-- reverses back to warming rather than finishing the power-down first.
test('switching on mid-cooling reverses back to warming', function()
	assertEqual('warming', L.nextState('cooling', true))
end)

-- Animation-finish transitions: warming completes to the held 'on' frame;
-- cooling completes back to 'off'. Neither 'off' nor 'on' has anything
-- mid-flight for a finish signal to act on.
test('the warm-up animation finishing holds the laser at on', function()
	assertEqual('on', L.nextStateOnAnimationFinish('warming'))
end)

test('the power-down animation finishing returns the laser to off', function()
	assertEqual('off', L.nextStateOnAnimationFinish('cooling'))
end)

test('animation finish has no effect on off or on -- nothing mid-flight', function()
	assertEqual('off', L.nextStateOnAnimationFinish('off'))
	assertEqual('on', L.nextStateOnAnimationFinish('on'))
end)

-- The single gate every interaction (kill/block/destroy/activate) should
-- read: only the held final frame is full power.
test('only the on state is fully on -- off/warming/cooling all gate interactions off', function()
	assertFalse(L.isFullyOn('off'))
	assertFalse(L.isFullyOn('warming'))
	assertTrue(L.isFullyOn('on'))
	assertFalse(L.isFullyOn('cooling'))
end)

-- Frame data is authored directly, thin -> full width, ascending: no
-- procedural width/color computation anywhere in the render path.
test('power frames run from a thin first frame to a wider, brighter last frame', function()
	local frames = L.powerFrames
	assertTrue(#frames >= 2, 'expected more than one frame to animate through')
	assertTrue(frames[1].width < frames[#frames].width,
		'expected the beam to widen from the first frame to the last')
end)
