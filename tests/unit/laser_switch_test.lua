-- Two tiers of coverage for src/entities/laser_switch.lua, mirroring
-- tests/unit/mirror_test.lua's split:
--
-- 1. Pure decision-helper tests against LaserSwitch._internal --
--    acceptsDirection, fast and construction-free.
-- 2. Entity-level tests that construct a real LaserSwitch -- real Sprite,
--    real Collider, a real bump World -- via tests/support/headless_
--    bootstrap, driven through :receiveValidHit()/:update(dt) the way
--    src/entities/laser.lua drives it.
--
-- The resolver's own classification of a laser_switch hit (recording it
-- into `activated` only for the accepted direction) is covered by
-- tests/unit/laser_beam_resolver_test.lua's fake-double tests; this file
-- covers the switch entity's own activation/target-driving logic and
-- wiring, not the resolver's use of it. The real end-to-end wiring (a real
-- laser beam driving a real laser_switch driving a real blocker, across
-- real frames) is covered by
-- tests/integration/laser_switch_activation_test.lua.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local LaserSwitch = require('src.entities.laser_switch')
local L = LaserSwitch._internal

--
-- Part 1: pure decision helpers
--

test('acceptsDirection is true only when the incoming direction matches the configured one', function()
	assertTrue(L.acceptsDirection('up', 'up'))
	assertFalse(L.acceptsDirection('down', 'up'))
	assertFalse(L.acceptsDirection('left', 'up'))
	assertFalse(L.acceptsDirection('right', 'up'))
end)

--
-- Part 2: entity-level, against a real constructed LaserSwitch
--

local function makeSwitch(properties)
	HeadlessBootstrap.resetWorld()
	local props = {}
	for k, v in pairs(properties or {}) do props[k] = v end
	props.direction = props.direction or 'up'
	-- template art merged in-game (res/entities/laser_switch.tj); stub
	-- mirrors it so the sprite has real frames to index into
	props.image = props.image or 'res/img/entity_switch.png'
	props.frames = props.frames or 1
	props.duration = props.duration or 1
	return LaserSwitch({
		x = 128, y = 96, width = 32, height = 32,
		properties = props,
	}, nil)
end

test('constructs headless with a real Sprite/Collider/World stack, off, solid, and at its authored direction', function()
	local switch = makeSwitch({direction = 'up'})

	assertEqual('up', switch.direction)
	assertEqual('off', switch.state)
	assertFalse(switch:isActive())
	assertFalse(switch.collider:isSensor(), 'a laser_switch must be solid so it absorbs the beam for free')
	assertTrue(switch.collider.nonSolidEntityTypes and switch.collider.nonSolidEntityTypes.player,
		'solid for the beam is not the same as solid for a player -- a laser_switch must never physically block one')
end)

test(':acceptsDirection delegates to the configured direction', function()
	local switch = makeSwitch({direction = 'up'})

	assertTrue(switch:acceptsDirection('up'))
	assertFalse(switch:acceptsDirection('down'))
end)

test('a valid hit this frame activates the switch and plays the press sound', function()
	local switch = makeSwitch()
	local spy = SoundSpy.install()

	switch:receiveValidHit()
	switch:update(1 / 60)

	assertTrue(switch:isActive())
	assertEqual('press', spy.played[1])

	spy.uninstall()
end)

test('no hit this frame leaves the switch off', function()
	local switch = makeSwitch()

	switch:update(1 / 60)

	assertFalse(switch:isActive())
end)

test('the switch deactivates (and plays the release sound) the frame a valid hit stops', function()
	local switch = makeSwitch()

	switch:receiveValidHit()
	switch:update(1 / 60)
	assertTrue(switch:isActive())

	local spy = SoundSpy.install()
	switch:update(1 / 60) -- no :receiveValidHit() this frame -- the hit stopped
	assertFalse(switch:isActive())
	assertEqual('release', spy.played[1])

	spy.uninstall()
end)

test('a continuing valid hit every frame keeps the switch on without re-driving the target', function()
	local switch = makeSwitch()
	local switchedCount = 0
	switch.target = {entity = {switch = function() switchedCount = switchedCount + 1 end}}

	for _ = 1, 5 do
		switch:receiveValidHit()
		switch:update(1 / 60)
	end

	assertTrue(switch:isActive())
	assertEqual(1, switchedCount, 'expected the target to be driven only once, on the on-transition')
end)

test('the hit flag is consumed each frame -- it never latches without a fresh :receiveValidHit()', function()
	local switch = makeSwitch()

	switch:receiveValidHit()
	switch:update(1 / 60)
	assertTrue(switch:isActive())

	switch:update(1 / 60) -- flag was cleared last update; nothing hit this frame
	assertFalse(switch:isActive())
end)

test('activating drives the target through :switch(), the same mechanism pressure_switch/switch use', function()
	local switch = makeSwitch()
	local switchedWith = {}
	-- bypasses map:getObjectById (no real Map here) -- driveTarget only
	-- reads self.target.entity, so a bare fake stands in fine
	switch.target = {entity = {switch = function(self_, triggeringSwitch) table.insert(switchedWith, triggeringSwitch) end}}

	switch:receiveValidHit()
	switch:update(1 / 60)

	assertEqual(1, #switchedWith)
	assertEqual(switch, switchedWith[1])
end)
