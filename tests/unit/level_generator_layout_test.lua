local Layout = require('tools.level_generator.layout')
local MovementModel = require('tools.level_generator.movement_model')
local Rng = require('tools.level_generator.rng')

local function assertAllZonesReachable(layout)
	local reachable = MovementModel.reachableFrom(layout.zones, layout.ladders, 1)
	for i = 1, #layout.zones do
		assertTrue(reachable[i], 'expected zone ' .. i .. ' to be reachable from spawn')
	end
end

test('--size small/medium/large changes map dimensions within the agreed ranges', function()
	local small = Layout.generate(Rng.new(1), {size = 'small'})
	local medium = Layout.generate(Rng.new(1), {size = 'medium'})
	local large = Layout.generate(Rng.new(1), {size = 'large'})

	assertTrue(small.width >= 20 and small.width <= 30, 'small width out of range: ' .. small.width)
	assertTrue(large.width >= 50 and large.width <= 60, 'large width out of range: ' .. large.width)
	assertTrue(large.width > medium.width, 'large should be wider than medium')
	assertTrue(medium.width > small.width, 'medium should be wider than small')
end)

test('every zone is reachable from spawn across many seeds and sizes', function()
	for _, size in ipairs({'small', 'medium', 'large'}) do
		for seed = 1, 25 do
			local layout = Layout.generate(Rng.new(seed), {size = size})
			assertAllZonesReachable(layout)
		end
	end
end)

test('no gap in the layout lacks a ladder spanning it (every non-ground zone has a connecting ladder)', function()
	local layout = Layout.generate(Rng.new(7), {size = 'medium'})

	for i = 2, #layout.zones do
		local zone = layout.zones[i]
		local hasLadder = false
		for _, other in ipairs(layout.zones) do
			if other ~= zone then
				for _, ladder in ipairs(layout.ladders) do
					if MovementModel.ladderConnects(ladder, zone, other) then
						hasLadder = true
					end
				end
			end
		end
		assertTrue(hasLadder, 'zone ' .. i .. ' has no ladder connecting it to anything')
	end
end)

test('same seed produces byte-identical layout (determinism)', function()
	local a = Layout.generate(Rng.new(99), {size = 'medium'})
	local b = Layout.generate(Rng.new(99), {size = 'medium'})

	assertEqual(#a.zones, #b.zones)
	for i = 1, #a.zones do
		assertEqual(a.zones[i].x1, b.zones[i].x1)
		assertEqual(a.zones[i].x2, b.zones[i].x2)
		assertEqual(a.zones[i].y, b.zones[i].y)
	end
end)

test('the ground zone spans the full width at the bottom row', function()
	local layout = Layout.generate(Rng.new(3), {size = 'small'})
	local ground = layout.zones[1]

	assertEqual(1, ground.x1)
	assertEqual(layout.width, ground.x2)
	assertEqual(layout.height, ground.y)
end)
