-- Integration test: exercises the real bump World/Collider query underlying
-- GroundSupport.isFullySupported, the same way kill_zone_test.lua does.
Class = Class or require('lib.hump.class')
local World = require('src.physics.bump.world')
Collider = Collider or require('src.physics.bump.collider')
local GroundSupport = require('src.player.ground_support')

-- mirrors the raw, entity-less static colliders Map:createStaticPhysicsBodies
-- builds for level collision geometry
local function makeGround(centreX, centreY, width, height)
	return Collider{
		shape_type = 'rectangle',
		shape_arguments = {centreX, centreY, width, height},
		body_type = 'static',
		position = {x = centreX, y = centreY},
	}
end

test('fully supported when both feet are well within solid ground', function()
	world = World:new(0, 0, true)
	makeGround(100, 500, 200, 32) -- spans x [0,200], y [484,516]

	local bounds = {left = 90, right = 110, bottom = 480}

	assertTrue(GroundSupport.isFullySupported(world, bounds))
end)

test('not fully supported when a foot hangs off the ledge edge', function()
	world = World:new(0, 0, true)
	makeGround(100, 500, 200, 32) -- spans x [0,200], y [484,516]

	-- right foot corner sits past x=200, off the ledge
	local bounds = {left = 190, right = 210, bottom = 480}

	assertFalse(GroundSupport.isFullySupported(world, bounds))
end)

test('not fully supported when entirely over open air', function()
	world = World:new(0, 0, true)
	makeGround(100, 500, 200, 32) -- spans x [0,200], y [484,516]

	local bounds = {left = 400, right = 420, bottom = 480}

	assertFalse(GroundSupport.isFullySupported(world, bounds))
end)
