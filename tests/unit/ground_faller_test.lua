-- Unit tests for src.physics.ground_faller, the pure ground-support/fall
-- primitives shared by Pushable (src/components/pushable/pushable_support.lua)
-- and the ground-following pickup behaviour. Extracted so a third consumer
-- (coin/key) doesn't duplicate the same dynamic/static decision a second time.
local GroundFaller = require('src.physics.ground_faller')

-- The physics layer cancels the velocity component pushing into a surface
-- the frame a body lands (Motion.resolveCollisions), so a resting body reads
-- as exactly zero vertical velocity while a falling one does not. Mirrors
-- pushable_support_test.lua's own isAirborne cases.
test('no vertical velocity is resting, not airborne', function()
	assertFalse(GroundFaller.isAirborne(0))
end)

test('real vertical velocity is airborne', function()
	assertTrue(GroundFaller.isAirborne(120))
end)

test('a hair of float noise in the vertical velocity is still resting', function()
	assertFalse(GroundFaller.isAirborne(0.0001))
end)

-- Mirrors pushable_support_test.lua's own bodyTypeFor cases: a settled body
-- with nothing pushing it becomes static terrain, everything else stays
-- dynamic so gravity/motion can still act on it.
test('a settled body with nothing pushing it rests as static terrain', function()
	assertEqual('static', GroundFaller.bodyTypeFor({supported = true}))
end)

test('a body with nothing under its centre goes dynamic so gravity can take it', function()
	assertEqual('dynamic', GroundFaller.bodyTypeFor({supported = false}))
end)

test('a body still carrying vertical velocity stays dynamic even once supported', function()
	assertEqual('dynamic', GroundFaller.bodyTypeFor({supported = true, airborne = true}))
end)

test('a body that is moving goes dynamic so the physics can carry it', function()
	assertEqual('dynamic', GroundFaller.bodyTypeFor({supported = true, moving = true}))
end)
