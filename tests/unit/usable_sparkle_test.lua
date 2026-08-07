-- Unit tests for the usable sparkles: the Particles engine's new scatter
-- `area` option, and the UsableSparkle component's auto-attach-on-Usable
-- wiring plus its in-range emission gating. Uses the headless bootstrap so a
-- real bump World can stand in for the game's proximity query.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')

local Particles = require('src.particles')
local UsableSparkle = require('src.components.usable_sparkle')

--
-- Particles engine: `area` scatters spawn points within a box
--

test('area scatters spawn points within the box', function()
	local e = Particles.new_emitter{
		position = {x = 0, y = 0},
		area = {w = 32, h = 32},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
		gravity = {x = 0, y = 0},
	}
	e:emit(200)

	local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
	for _, p in ipairs(e.particles) do
		minX = math.min(minX, p.x); maxX = math.max(maxX, p.x)
		minY = math.min(minY, p.y); maxY = math.max(maxY, p.y)
	end
	assertTrue(minX >= -16.1 and maxX <= 16.1, 'x spawns stay inside the 32px box')
	assertTrue(minY >= -16.1 and maxY <= 16.1, 'y spawns stay inside the 32px box')
	assertTrue(maxX - minX > 20, 'x actually scatters across the box')
	assertTrue(maxY - minY > 20, 'y actually scatters across the box')
end)

test('without an area emitters still spawn at the exact position', function()
	local e = Particles.new_emitter{
		position = {x = 42, y = 7},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
	}
	e:emit(5)
	for _, p in ipairs(e.particles) do
		assertEqual(42, p.x, 'x unchanged (no scatter)')
		assertEqual(7, p.y, 'y unchanged (no scatter)')
	end
end)

--
-- UsableSparkle: auto-attach and emission gating
--

local function makeUsableEntity(sparkleOption)
	local entity = Entity{}
	entity.collider = entity:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = {16, 16, 32, 32},
		body_type = 'static',
		position = Vector(16, 16),
		sensor = true,
	})
	entity:addComponent(Usable{
		entity = entity,
		use = function() end,
		sparkles = sparkleOption,
	})
	return entity
end

local function addPlayerNearby()
	local pcol = Collider{
		shape_type = 'rectangle',
		shape_arguments = {16, 16, 20, 30},
		body_type = 'static',
		position = Vector(16, 16),
		sensor = true,
	}
	pcol.entity = {type = 'player'}
	return pcol
end

test('Usable:onAttach auto-attaches a usable_sparkle component', function()
	world = HeadlessBootstrap.resetWorld()
	local entity = makeUsableEntity()
	assertTrue(entity:getComponent('usable_sparkle') ~= nil, 'sparkle added for free')
	assertTrue(entity:getComponent(UsableSparkle) ~= nil, 'findable via class too')
end)

test('sparkles=false opts out of the effect', function()
	world = HeadlessBootstrap.resetWorld()
	local entity = makeUsableEntity(false)
	assertEqual(nil, entity:getComponent('usable_sparkle'), 'no sparkle when opted out')
end)

test('sparkles emit while a player is in range and stop when they leave', function()
	world = HeadlessBootstrap.resetWorld()
	local entity = makeUsableEntity()
	local sparkle = entity:getComponent('usable_sparkle')

	local pcol = addPlayerNearby()
	assertTrue(sparkle:isPlayerInRange(), 'player standing on the usable is in range')

	for _ = 1, 8 do
		sparkle:update(0.016)
	end
	assertTrue(#sparkle.emitter.particles > 0, 'sparkles emitted while in range')

	pcol:setPosition(1000, 1000)
	assertFalse(sparkle:isPlayerInRange(), 'player far away is out of range')
	local countBefore = #sparkle.emitter.particles
	sparkle:update(0.016)
	assertEqual(countBefore, #sparkle.emitter.particles, 'no new sparkles while out of range')
end)

test('sparkles stop when the owning usable is disabled', function()
	world = HeadlessBootstrap.resetWorld()
	local entity = makeUsableEntity()
	local usable = entity:getComponent(Usable)
	local sparkle = entity:getComponent('usable_sparkle')

	addPlayerNearby()
	assertTrue(sparkle:isPlayerInRange(), 'player in range')

	usable.enabled = false
	sparkle:update(0.016)
	assertEqual(0, #sparkle.emitter.particles, 'disabled usable emits no sparkles')
end)

test('update is a safe no-op headless (no world, no emission)', function()
	world = HeadlessBootstrap.resetWorld()
	local entity = makeUsableEntity()
	local sparkle = entity:getComponent('usable_sparkle')
	world = nil
	sparkle:update(0.016)
	assertEqual(0, #sparkle.emitter.particles, 'no world -> no particles, no crash')
	world = HeadlessBootstrap.resetWorld()
end)
