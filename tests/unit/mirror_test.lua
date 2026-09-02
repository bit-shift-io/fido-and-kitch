-- Two tiers of coverage for src/entities/mirror.lua, mirroring
-- tests/unit/blocker_test.lua's split:
--
-- 1. Pure decision-helper tests against Mirror._internal -- the rotation
--    cycle and the redirect (direction-pair) lookup, fast and
--    construction-free.
-- 2. Entity-level tests that construct a real Mirror -- real Sprite, real
--    Collider, a real bump World -- via tests/support/headless_bootstrap,
--    driven through a real Switchable the way a linked switch would.
--
-- The resolver's own recursion through a mirror (bounce/redirect/cap) is
-- covered by tests/unit/laser_beam_resolver_test.lua's fake-double tests;
-- this file covers the mirror entity's own rotation/redirect logic and its
-- wiring, not the resolver's use of it.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')

local Mirror = require('src.entities.mirror')
local M = Mirror._internal

--
-- Part 1: pure decision helpers
--

test('the rotation cycle advances each orientation to the correct next one', function()
	assertEqual('down-right', M.nextOrientation('up-right'))
	assertEqual('down-left', M.nextOrientation('down-right'))
	assertEqual('up-left', M.nextOrientation('down-left'))
	assertEqual('up-right', M.nextOrientation('up-left'))
end)

test('redirect exits the other connected direction when entered from either one', function()
	assertEqual('right', M.redirect('up-right', 'up'))
	assertEqual('up', M.redirect('up-right', 'right'))
	assertEqual('right', M.redirect('down-right', 'down'))
	assertEqual('down', M.redirect('down-right', 'right'))
	assertEqual('left', M.redirect('down-left', 'down'))
	assertEqual('down', M.redirect('down-left', 'left'))
	assertEqual('left', M.redirect('up-left', 'up'))
	assertEqual('up', M.redirect('up-left', 'left'))
end)

test('redirect returns nil for a direction the orientation does not connect', function()
	assertTrue(M.redirect('up-right', 'down') == nil)
	assertTrue(M.redirect('up-right', 'left') == nil)
	assertTrue(M.redirect('down-left', 'up') == nil)
	assertTrue(M.redirect('down-left', 'right') == nil)
end)

--
-- Part 2: entity-level, against a real constructed Mirror
--

local function makeMirror(properties)
	HeadlessBootstrap.resetWorld()
	local props = {}
	for k, v in pairs(properties or {}) do props[k] = v end
	-- template art merged in-game (res/entities/mirror.tj); stub mirrors it
	-- so the sprite has real frames to index into
	props.image = props.image or 'res/img/entity_switch.png'
	props.frames = props.frames or 4
	props.duration = props.duration or 1
	props.playing = false
	return Mirror({
		x = 128, y = 96, width = 32, height = 32,
		properties = props,
	}, nil)
end

test('constructs headless with a real Sprite/Collider/World stack, solid and at its authored orientation', function()
	local mirror = makeMirror()

	assertEqual('up-right', mirror.orientation, 'default orientation with none authored')
	assertFalse(mirror.collider:isSensor(), 'a mirror must be a solid obstacle, not a sensor')
end)

test('an authored orientation is respected at construction', function()
	local mirror = makeMirror({orientation = 'down-left'})

	assertEqual('down-left', mirror.orientation)
end)

test('a mirror redirects a beam via its current orientation', function()
	local mirror = makeMirror({orientation = 'up-right'})

	assertEqual('right', mirror:redirect('up'))
	assertEqual('up', mirror:redirect('right'))
	assertTrue(mirror:redirect('down') == nil)
end)

-- Switch-controlled rotation: only the 'on' transition rotates, the 'off'
-- transition is a no-op -- the mirror's onStateChange callback ignores it,
-- mirroring the same discipline src/entities/blocker.lua uses for its own
-- Switchable-driven behaviour.
local function flipSwitch(mirror, on)
	mirror:getComponent(Switchable):switch({state = on and 'on' or 'off'})
end

test('an "on" switch activation rotates the mirror 90 degrees clockwise', function()
	local mirror = makeMirror({orientation = 'up-right'})

	flipSwitch(mirror, true)

	assertEqual('down-right', mirror.orientation)
end)

test('an "off" switch activation never rotates the mirror', function()
	local mirror = makeMirror({orientation = 'up-right'})

	flipSwitch(mirror, false)

	assertEqual('up-right', mirror.orientation, 'the off transition must be a no-op')
end)

test('repeated "on" activations advance through the full 4-cycle and wrap around', function()
	local mirror = makeMirror({orientation = 'up-right'})

	flipSwitch(mirror, true)
	assertEqual('down-right', mirror.orientation)

	flipSwitch(mirror, true)
	assertEqual('down-left', mirror.orientation)

	flipSwitch(mirror, true)
	assertEqual('up-left', mirror.orientation)

	flipSwitch(mirror, true)
	assertEqual('up-right', mirror.orientation, 'expected the cycle to wrap back to the start')
end)

-- A lever switch.lua toggles on/off/on/off each press -- linking one to a
-- mirror must rotate it only on every OTHER press (the on-presses), never
-- on the off-presses in between.
test('alternating on/off activations (a lever toggle) rotate only on the on-presses', function()
	local mirror = makeMirror({orientation = 'up-right'})

	flipSwitch(mirror, true) -- press 1: on
	assertEqual('down-right', mirror.orientation)

	flipSwitch(mirror, false) -- press 2: off
	assertEqual('down-right', mirror.orientation, 'the off-press must not rotate the mirror')

	flipSwitch(mirror, true) -- press 3: on
	assertEqual('down-left', mirror.orientation)

	flipSwitch(mirror, false) -- press 4: off
	assertEqual('down-left', mirror.orientation, 'the off-press must not rotate the mirror')
end)

test('a mirror with no switch wired never rotates, across many frames', function()
	local mirror = makeMirror({orientation = 'up-right'})

	for _ = 1, 120 do
		mirror:update(1 / 60)
	end

	assertEqual('up-right', mirror.orientation)
end)
