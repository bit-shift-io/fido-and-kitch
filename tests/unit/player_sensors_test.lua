-- Unit coverage for src/player/player_sensors.lua's queryOnDestructibleTile,
-- mirroring tests/unit/ground_support_test.lua's style: a bare bump World +
-- raw Collider, no full entity/Sprite stack needed since the probe only
-- reads collider.entity.type.
Class = Class or require('lib.hump.class')
local World = require('src.physics.bump.world')
Collider = Collider or require('src.physics.bump.collider')
local PlayerSensors = require('src.player.player_sensors')

-- mirrors the raw, entity-less static colliders Map:createStaticPhysicsBodies
-- builds for level collision geometry
local function makeGround(centreX, centreY, width, height)
	return Collider{
		shape_type = 'rectangle',
		shape_arguments = {width, height},
		body_type = 'static',
		position = {x = centreX, y = centreY},
	}
end

local function makePlayer(centreX, centreY)
	return Collider{
		shape_type = 'rectangle',
		shape_arguments = {20, 30},
		body_type = 'dynamic',
		position = {x = centreX, y = centreY},
	}
end

test('detects a destructible_tile entity directly beneath the player', function()
	world = World:new(0, 0, true)
	local tile = makeGround(100, 516, 32, 32) -- spans x [84,116], y [500,532]
	tile.entity = {type = 'destructible_tile'}

	local player = makePlayer(100, 484) -- feet resting at y=499, just above the tile

	assertTrue(PlayerSensors.queryOnDestructibleTile(world, player))
end)

test('ordinary terrain (no entity) is not reported as a destructible tile', function()
	world = World:new(0, 0, true)
	makeGround(100, 516, 200, 32) -- plain collision-layer geometry, entity == nil

	local player = makePlayer(100, 484)

	assertFalse(PlayerSensors.queryOnDestructibleTile(world, player))
end)

test('a different entity type underfoot (e.g. a boulder) is not reported as a destructible tile', function()
	world = World:new(0, 0, true)
	local boulder = makeGround(100, 516, 32, 32)
	boulder.entity = {type = 'boulder'}

	local player = makePlayer(100, 484)

	assertFalse(PlayerSensors.queryOnDestructibleTile(world, player))
end)

test('nothing underfoot at all is not reported as a destructible tile', function()
	world = World:new(0, 0, true)

	local player = makePlayer(100, 484)

	assertFalse(PlayerSensors.queryOnDestructibleTile(world, player))
end)
