-- Integration test: exercises the real bump World/Collider overlap query that
-- Player:queryKillZone() relies on, without any LÖVE dependency (World/Collider
-- only touch love.graphics in their draw methods, which this test never calls).
-- these must be set as globals (not locals): World:newCollider() relies on
-- the global `Collider` to set up each collider's metatable, mirroring how
-- src/main.lua wires classes for the running game.
Class = Class or require('lib.hump.class')
local World = require('src.physics.bump.world')
Collider = Collider or require('src.physics.bump.collider')

-- mirrors the bounds-narrowing Player:queryKillZone() applies before querying
local function narrowedBounds(collider)
	local bounds = collider:getBounds()
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4
	return bounds
end

local function findKillZone(collider)
	local hits = world:queryBounds(narrowedBounds(collider))
	for _, c in ipairs(hits) do
		if c.entity and c.entity.isKillZone then
			return c.entity
		end
	end
	return nil
end

local function makeKillZone(x, y, width, height, deathType)
	local collider = Collider{
		shape_type = 'rectangle',
		shape_arguments = {x, y, width, height},
		body_type = 'static',
		sensor = true,
		position = {x = x, y = y},
	}
	collider.entity = {isKillZone = true, deathType = deathType}
	return collider
end

local function makePlayerCollider(x, y)
	return Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 20, 30},
		body_type = 'dynamic',
		position = {x = x, y = y},
	}
end

test('a player spawned on top of a kill zone is detected, carrying its death type', function()
	world = World:new(0, 0, true)
	makeKillZone(100, 100, 100, 100, 'water')
	local player = makePlayerCollider(100, 100)

	local zone = findKillZone(player)

	assertTrue(zone ~= nil, 'expected the kill zone to be detected')
	assertEqual('water', zone.deathType)
end)

test('a player standing well away from a kill zone is not detected', function()
	world = World:new(0, 0, true)
	makeKillZone(100, 100, 100, 100, 'water')
	local player = makePlayerCollider(500, 500)

	local zone = findKillZone(player)

	assertEqual(nil, zone)
end)

test('a player just touching the narrowed edge of the kill zone is not detected', function()
	world = World:new(0, 0, true)
	makeKillZone(100, 100, 100, 100, 'water')
	-- kill zone spans x in [50,150]; place the player's narrowed bounds just outside it
	local player = makePlayerCollider(170, 100)

	local zone = findKillZone(player)

	assertEqual(nil, zone)
end)
