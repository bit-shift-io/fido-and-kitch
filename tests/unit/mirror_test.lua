-- Two tiers of coverage for src/entities/mirror.lua, mirroring
-- tests/unit/blocker_test.lua's split:
--
-- 1. Pure decision-helper tests against Mirror._internal -- the reflection
--    table lookup, fast and construction-free.
-- 2. Entity-level tests that construct a real Mirror -- real Sprite, real
--    Collider, a real bump World -- via tests/support/headless_bootstrap,
--    driven through a real Switchable the way a linked switch would.
--
-- Double-sided 45-degree mirror model (see mirror.lua's file header): a
-- `flipMirror` bool picks one of the two diagonals ("/" = false, "\" =
-- true), and every incoming direction redirects into exactly one outgoing
-- direction -- there is no "wrong side" to block, unlike the old
-- 4-orientation design this superseded.
--
-- The resolver's own recursion through a mirror (bounce/redirect/cap) is
-- covered by tests/unit/laser_beam_resolver_test.lua's fake-double tests;
-- this file covers the mirror entity's own redirect logic and its wiring,
-- not the resolver's use of it.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")

local Mirror = require("src.entities.mirror")
local M = Mirror._internal

--
-- Part 1: pure decision helpers
--

test('the "/" diagonal (flipMirror=false) reflects up<->right and down<->left', function()
	assertEqual("right", M.redirect(false, "up"))
	assertEqual("up", M.redirect(false, "right"))
	assertEqual("left", M.redirect(false, "down"))
	assertEqual("down", M.redirect(false, "left"))
end)

test('the "\\" diagonal (flipMirror=true) reflects up<->left and down<->right', function()
	assertEqual("left", M.redirect(true, "up"))
	assertEqual("up", M.redirect(true, "left"))
	assertEqual("right", M.redirect(true, "down"))
	assertEqual("down", M.redirect(true, "right"))
end)

test("redirect is its own inverse -- reflecting the outgoing direction back returns to the incoming one", function()
	for _, flipMirror in ipairs({ false, true }) do
		for _, incoming in ipairs({ "up", "down", "left", "right" }) do
			local outgoing = M.redirect(flipMirror, incoming)
			assertEqual(
				incoming,
				M.redirect(flipMirror, outgoing),
				"expected reflecting back through the outgoing direction to return to the incoming one"
			)
		end
	end
end)

--
-- Part 2: entity-level, against a real constructed Mirror
--

local function makeMirror(properties)
	HeadlessBootstrap.resetWorld()
	local props = {}
	for k, v in pairs(properties or {}) do
		props[k] = v
	end
	-- template art merged in-game (res/entities/mirror.tj); stub mirrors it
	-- so the sprite has real frames to index into
	props.image = props.image or "res/img/entity_switch.png"
	props.frames = props.frames or 2
	props.duration = props.duration or 1
	props.playing = false
	return Mirror({
		x = 128,
		y = 96,
		width = 32,
		height = 32,
		properties = props,
	}, nil)
end

test(
	"constructs headless with a real Sprite/Collider/World stack, solid and at its authored flipMirror value",
	function()
		local mirror = makeMirror()

		assertFalse(mirror.flipMirror, 'default flipMirror (false, "/") with none authored')
		assertFalse(
			mirror.collider:isSensor(),
			"a mirror must be solid to the BEAM (raycast classification reads .sensor)"
		)
		assertTrue(
			mirror.collider.nonSolidEntityTypes and mirror.collider.nonSolidEntityTypes.player,
			"solid for the beam is not the same as solid for a player -- a mirror is a small mounted fixture, not a wall, and must never physically block or catch one"
		)
	end
)

test("an authored flipMirror value is respected at construction", function()
	local mirror = makeMirror({ flipMirror = true })

	assertTrue(mirror.flipMirror)
end)

test("a mirror redirects a beam via its current flipMirror value, never blocking", function()
	local mirror = makeMirror({ flipMirror = false })

	assertEqual("right", mirror:redirect("up"))
	assertEqual("up", mirror:redirect("right"))
	assertEqual("left", mirror:redirect("down"))
	assertEqual("down", mirror:redirect("left"))
end)

test("a mirror exposes its collider centre as its bounce pivot point", function()
	local mirror = makeMirror()

	-- makeMirror's fixture object is {x=128,y=96,width=32,height=32},
	-- bottom-anchored like every other gid-template entity (object.y is
	-- the BOTTOM edge) -- so the true centre is (128+16, 96-16).
	local x, y = mirror:getPosition()
	assertEqual(144, x)
	assertEqual(80, y)
end)

-- Switch-controlled flip: only the 'on' transition flips it, the 'off'
-- transition is a no-op -- the mirror's onStateChange callback ignores it,
-- mirroring the same discipline src/entities/blocker.lua uses for its own
-- Switchable-driven behaviour.
local function flipSwitch(mirror, on)
	mirror:getComponent(Switchable):switch({ state = on and "on" or "off" })
end

test('an "on" switch activation flips the mirror to the other diagonal', function()
	local mirror = makeMirror({ flipMirror = false })

	flipSwitch(mirror, true)

	assertTrue(mirror.flipMirror)
end)

test('by default, an "off" switch activation flips the mirror too', function()
	local mirror = makeMirror({ flipMirror = false })

	flipSwitch(mirror, false)

	assertTrue(mirror.flipMirror, "the off transition should flip when rotateOnBothTriggers is unset (default true)")
end)

test('with rotateOnBothTriggers=false, an "off" switch activation never flips the mirror', function()
	local mirror = makeMirror({ flipMirror = false, rotateOnBothTriggers = false })

	flipSwitch(mirror, false)

	assertFalse(mirror.flipMirror, "the off transition must be a no-op when rotateOnBothTriggers is false")
end)

test('repeated "on" activations toggle back and forth between the two diagonals', function()
	local mirror = makeMirror({ flipMirror = false })

	flipSwitch(mirror, true)
	assertTrue(mirror.flipMirror)

	flipSwitch(mirror, true)
	assertFalse(mirror.flipMirror, 'expected a second "on" activation to flip back')

	flipSwitch(mirror, true)
	assertTrue(mirror.flipMirror)
end)

test("by default, alternating on/off activations (a lever toggle) flip on every press", function()
	local mirror = makeMirror({ flipMirror = false })

	flipSwitch(mirror, true) -- press 1: on
	assertTrue(mirror.flipMirror)

	flipSwitch(mirror, false) -- press 2: off
	assertFalse(mirror.flipMirror, "the off-press should flip too when rotateOnBothTriggers is unset (default true)")

	flipSwitch(mirror, true) -- press 3: on
	assertTrue(mirror.flipMirror)
end)

-- A lever switch.lua toggles on/off/on/off each press -- with
-- rotateOnBothTriggers=false, a mirror must flip only on every OTHER press
-- (the on-presses), never on the off-presses in between.
test("alternating on/off activations (a lever toggle) flip only on the on-presses", function()
	local mirror = makeMirror({ flipMirror = false, rotateOnBothTriggers = false })

	flipSwitch(mirror, true) -- press 1: on
	assertTrue(mirror.flipMirror)

	flipSwitch(mirror, false) -- press 2: off
	assertTrue(mirror.flipMirror, "the off-press must not flip the mirror")

	flipSwitch(mirror, true) -- press 3: on
	assertFalse(mirror.flipMirror)

	flipSwitch(mirror, false) -- press 4: off
	assertFalse(mirror.flipMirror, "the off-press must not flip the mirror")
end)

test("a mirror with no switch wired never flips, across many frames", function()
	local mirror = makeMirror({ flipMirror = false })

	for _ = 1, 120 do
		mirror:update(1 / 60)
	end

	assertFalse(mirror.flipMirror)
end)
