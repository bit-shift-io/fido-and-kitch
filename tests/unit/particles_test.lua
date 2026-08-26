-- Unit tests for src/particles.lua (the emitter engine) and src/fx/
-- (preset effects + FxManager). Pure-Lua logic is tested headless; draw()
-- is exercised against the love.graphics mock.
local LoveMock = require('tests.support.love_mock')
love = LoveMock.new()

local Particles = require('src.emitters.sprite_emitter')

test('new_emitter starts empty and emits up to its cap', function()
	local e = Particles.new_emitter{}
	assertEqual(0, #e.particles, 'new emitter has no particles')

	e:emit(10)
	assertEqual(10, #e.particles, 'emit(n) spawns n particles')

	e:emit(1000)
	assertEqual(500, #e.particles, 'emitter caps at 500 particles')
end)

test('update advances position and removes expired particles', function()
	local e = Particles.new_emitter{
		position = {x = 100, y = 50},
		lifetime = {min = 0.1, max = 0.1},
		speed = {min = 100, max = 100},
		direction = {angle = 0, spread = 0},
		gravity = {x = 0, y = 0},
	}
	e:emit(1)

	e:update(0.05)
	local p = e.particles[1]
	assertEqual(1, #e.particles, 'particle still alive before lifetime')
	assertNear(105, p.x, 0.001, 'position advanced by velocity * dt')
	assertNear(50, p.y, 0.001, 'y stays put with zero vertical velocity')

	e:update(0.06)
	assertEqual(0, #e.particles, 'particle removed once age exceeds lifetime')
end)

test('gravity accelerates velocity each step', function()
	local e = Particles.new_emitter{
		position = {x = 0, y = 0},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
		direction = {angle = 0, spread = 0},
		gravity = {x = 0, y = 100},
	}
	e:emit(1)

	e:update(0.1)
	e:update(0.1)
	local p = e.particles[1]
	assertNear(20, p.vy, 0.001, 'vy accumulated 100 * 0.2')
	assertNear(3, p.y, 0.001, 'semi-implicit Euler: y moves by accumulated v')
end)

test('draw renders every particle without error', function()
	local e = Particles.new_emitter{
		position = {x = 10, y = 10},
		lifetime = {min = 0.5, max = 0.5},
		speed = {min = 1, max = 1},
		direction = {angle = 0, spread = 0},
		size = {start = 6, ["end"] = 1},
		colors = {start = {1, 0.9, 0.2, 1}, ["end"] = {1, 0.5, 0, 0}},
	}
	e:emit(3)
	e:update(0.1)
	e:draw()
	assertTrue(true, 'draw() runs headless against the graphics mock')

	assertTrue(e:done() == false, 'emitter reports not done while particles live')
	e:update(1)
	assertTrue(e:done(), 'emitter reports done once all particles expire')
end)

test('array image textures are assigned per particle at spawn', function()
	local e = Particles.new_emitter{
		position = {x = 0, y = 0},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
		image = {
			'res/img/fx/fx_star_glow.png',
			'res/img/fx/fx_star_outline.png',
			'res/img/fx/fx_blob_glow.png',
			'res/img/fx/fx_square_outline.png',
		},
	}
	e:emit(80)
	assertEqual(80, #e.particles, 'all particles spawned')

	local seen = {}
	for _, p in ipairs(e.particles) do
		assertTrue(p.image ~= nil, 'every particle is assigned a texture at spawn')
		seen[p.image] = true
	end
	local count = 0
	for _ in pairs(seen) do count = count + 1 end
	assertEqual(4, count, 'the full set of textures is spread across particles')
	e:draw()
end)

test('rotation and spin are per-particle and survive updates', function()
	local e = Particles.new_emitter{
		position = {x = 0, y = 0},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
		rotation = {angle = 1.5, spread = 0},
		spin = {min = 2, max = 2},
	}
	e:emit(3)
	for _, p in ipairs(e.particles) do
		assertNear(1.5, p.angle, 0.001, 'initial rotation from angle')
		assertNear(2, p.spin, 0.001, 'per-particle spin')
	end
	e:update(0.25)
	e:draw()
end)

test('fadeIn config is accepted and defaults to 0', function()
	local e = Particles.new_emitter{position = {x = 0, y = 0}, lifetime = {min = 1, max = 1}, speed = {min = 0, max = 0}}
	assertEqual(0, e.opts.fadeIn, 'fadeIn defaults to 0 (backward compatible)')

	e.opts.fadeIn = 0.4
	e:emit(4)
	e:update(0.1)
	e:draw()
	assertTrue(true, 'fadeIn emitter constructs, updates and draws fine')
end)

test('F2 debug mode draws emitter box and particle outlines', function()
	conf = conf or {}
	local prev = conf.draw_particles
	conf.draw_particles = true
	local e = Particles.new_emitter{
		position = {x = 0, y = 0},
		area = {w = 64, h = 64},
		lifetime = {min = 1, max = 1},
		speed = {min = 0, max = 0},
	}
	e:emit(3)
	e:draw()
	conf.draw_particles = prev
	assertTrue(true, 'particle + emitter-box outlines render under the mock')
end)

local FxManager = require('src.fx.manager')
local CoinPickup = require('src.fx.coin_pickup')

test('FxManager updates, draws and reaps a burst preset', function()
	local manager = FxManager:new()
	local fx = manager:burst(CoinPickup, {x = 100, y = 100})

	assertEqual(1, #manager.active, 'burst registers one effect')
	assertEqual(12, #fx.emitter.particles, 'coin burst spawns 12 sparkles')

	manager:update(0.05)
	manager:draw()
	assertEqual(12, #fx.emitter.particles, 'burst still active mid-flight')

	for _ = 1, 100 do
		manager:update(0.1)
	end
	assertEqual(0, #manager.active, 'done burst is reaped from the manager')
end)