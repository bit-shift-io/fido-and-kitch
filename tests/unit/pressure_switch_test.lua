-- Two tiers of coverage for src/entities/pressure_switch.lua, both headless,
-- mirroring tests/unit/drawbridge_test.lua's split (see ADR 0005):
--
-- 1. Pure decision-helper tests against PressureSwitch._internal -- fast,
--    construction-free, one assertion per branch.
--
-- 2. Entity-level tests that construct a real PressureSwitch -- real
--    Collider, real Sound, a real bump World -- via
--    tests/support/headless_bootstrap, and drive it through
--    PressureSwitch:update(dt) the way the game does.
--
-- The target-driving mechanism (a real Ladder/Blocker reacting to :switch())
-- and the momentary/latching gameplay scenarios through a real Game/Map
-- stack stay in tests/integration/pressure_switch_test.lua and
-- pressure_switch_sound_test.lua; this file covers the plate's own
-- decision logic and wiring, not the surrounding game.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local PressureSwitch = require('src.entities.pressure_switch')
local P = PressureSwitch._internal

local PLATE_CENTRE_X = 304

--
-- Part 1: pure decision helpers
--

-- "Substantially on it" (DECISIONS Q11): overlapping the plate is not enough,
-- the weight's centre-x has to be near the plate tile's centre. A box resting
-- with one edge barely over the plate is not standing on it.
test('a weight centred on the plate is on it', function()
	assertTrue(P.isWeightOn(PLATE_CENTRE_X, PLATE_CENTRE_X))
end)

test('a weight slightly off-centre is still substantially on the plate', function()
	assertTrue(P.isWeightOn(PLATE_CENTRE_X + 4, PLATE_CENTRE_X))
	assertTrue(P.isWeightOn(PLATE_CENTRE_X - 4, PLATE_CENTRE_X))
end)

test('a weight merely overlapping the plate edge is not on it', function()
	assertFalse(P.isWeightOn(PLATE_CENTRE_X + 15, PLATE_CENTRE_X))
	assertFalse(P.isWeightOn(PLATE_CENTRE_X - 15, PLATE_CENTRE_X))
end)

test('a plate with a weight on it activates', function()
	assertTrue(P.nextActivation(false, false, true))
end)

test('a momentary plate releases when the weight leaves', function()
	assertFalse(P.nextActivation(true, false, false))
end)

test('a plate with nothing on it stays off', function()
	assertFalse(P.nextActivation(false, false, false))
end)

-- latching is the one-shot trigger option for designers: once tripped it never
-- releases, however the weight moves afterwards
test('a latching plate stays on after the weight leaves', function()
	assertTrue(P.nextActivation(true, true, false))
end)

test('a latching plate that has not been tripped yet is still off', function()
	assertFalse(P.nextActivation(false, true, false))
end)

--
-- Part 2: entity-level, against a real constructed PressureSwitch
--

-- mirrors the fake-collider convention in kill_zone_test.lua and
-- tests/unit/drawbridge_test.lua's spawnOccupant. groupIndex must be
-- concrete and distinct from -1 (the players' group) -- see those files for
-- why an unset groupIndex silently matches any other unset one.
local function spawnWeight(x, y, props)
	local weight = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 20, 30},
		body_type = 'dynamic',
		position = {x = x, y = y},
	}
	weight.entity = props or {type = 'player'}
	weight:setGroupIndex(100)
	return weight
end

local function makeSwitch(properties)
	HeadlessBootstrap.resetWorld()
	return PressureSwitch({
		x = 288, y = 96, width = 32, height = 32,
		properties = properties,
	})
end

test('constructs headless with a real Collider/Sound/World stack, off and not a barrier', function()
	local switch = makeSwitch()

	assertEqual('off', switch.state)
	assertFalse(switch:isActive())
	assertTrue(switch.collider:isSensor(), 'the plate is a sensor -- weights cross it freely, never blocked')
end)

test('a player standing on the plate activates it and plays the press sound', function()
	local switch = makeSwitch()
	local spy = SoundSpy.install()

	spawnWeight(switch.plateCentreX, switch.rect.y + 1)
	switch:update(1/60)

	assertTrue(switch:isActive())
	assertEqual('press', spy.played[1])

	spy.uninstall()
end)

test('a pushable prop counts as a weight just as a player does', function()
	local switch = makeSwitch()
	spawnWeight(switch.plateCentreX, switch.rect.y + 1, {isPushable = true})
	switch:update(1/60)

	assertTrue(switch:isActive())
end)

test('something merely near the plate edge, off-tolerance, does not activate it', function()
	local switch = makeSwitch()
	spawnWeight(switch.plateCentreX + 15, switch.rect.y + 1)
	switch:update(1/60)

	assertFalse(switch:isActive())
end)

test('a momentary plate releases (and plays the release sound) once the weight leaves', function()
	local switch = makeSwitch()

	local weight = spawnWeight(switch.plateCentreX, switch.rect.y + 1)
	switch:update(1/60)
	assertTrue(switch:isActive())

	weight:destroy()
	local spy = SoundSpy.install()
	switch:update(1/60)

	assertFalse(switch:isActive())
	assertEqual('release', spy.played[1])

	spy.uninstall()
end)

test('a latching plate stays on through the real entity once tripped, even after the weight leaves', function()
	local switch = makeSwitch({latching = true})

	local weight = spawnWeight(switch.plateCentreX, switch.rect.y + 1)
	switch:update(1/60)
	assertTrue(switch:isActive())

	weight:destroy()
	switch:update(1/60)
	assertTrue(switch:isActive(), 'expected a latching plate to stay on after the weight leaves')
end)

test('seatCentreX offers the plate centre only within tolerance, nil otherwise', function()
	local switch = makeSwitch()

	assertEqual(switch.plateCentreX, switch:seatCentreX(switch.plateCentreX + 4))
	assertEqual(nil, switch:seatCentreX(switch.plateCentreX + 15))
end)

test('activating drives the target through :switch(), the same mechanism the lever switch uses', function()
	local switch = makeSwitch()
	local switchedWith = {}
	-- bypasses map:getObjectById (no real Map here) -- driveTarget only
	-- reads self.target.entity, so a bare fake stands in fine
	switch.target = {entity = {switch = function(self_, triggeringSwitch) table.insert(switchedWith, triggeringSwitch) end}}

	spawnWeight(switch.plateCentreX, switch.rect.y + 1)
	switch:update(1/60)

	assertEqual(1, #switchedWith)
	assertEqual(switch, switchedWith[1])
end)
