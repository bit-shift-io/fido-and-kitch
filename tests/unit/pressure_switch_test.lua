-- Unit tests for the pressure switch's pure decision helpers. The entity
-- itself composes a Collider and drives a real target entity, so that side is
-- covered in tests/integration/pressure_switch_test.lua.
Class = Class or require('lib.hump.class')
local PressureSwitchSupport = require('src.entities.pressure_switch.pressure_switch_support')

local PLATE_CENTRE_X = 304

-- "Substantially on it" (DECISIONS Q11): overlapping the plate is not enough,
-- the weight's centre-x has to be near the plate tile's centre. A box resting
-- with one edge barely over the plate is not standing on it.
test('a weight centred on the plate is on it', function()
	assertTrue(PressureSwitchSupport.isWeightOn(PLATE_CENTRE_X, PLATE_CENTRE_X))
end)

test('a weight slightly off-centre is still substantially on the plate', function()
	assertTrue(PressureSwitchSupport.isWeightOn(PLATE_CENTRE_X + 4, PLATE_CENTRE_X))
	assertTrue(PressureSwitchSupport.isWeightOn(PLATE_CENTRE_X - 4, PLATE_CENTRE_X))
end)

test('a weight merely overlapping the plate edge is not on it', function()
	assertFalse(PressureSwitchSupport.isWeightOn(PLATE_CENTRE_X + 15, PLATE_CENTRE_X))
	assertFalse(PressureSwitchSupport.isWeightOn(PLATE_CENTRE_X - 15, PLATE_CENTRE_X))
end)

test('a plate with a weight on it activates', function()
	assertTrue(PressureSwitchSupport.nextActivation(false, false, true))
end)

test('a momentary plate releases when the weight leaves', function()
	assertFalse(PressureSwitchSupport.nextActivation(true, false, false))
end)

test('a plate with nothing on it stays off', function()
	assertFalse(PressureSwitchSupport.nextActivation(false, false, false))
end)

-- latching is the one-shot trigger option for designers: once tripped it never
-- releases, however the weight moves afterwards
test('a latching plate stays on after the weight leaves', function()
	assertTrue(PressureSwitchSupport.nextActivation(true, true, false))
end)

test('a latching plate that has not been tripped yet is still off', function()
	assertFalse(PressureSwitchSupport.nextActivation(false, true, false))
end)
