local Rng = require('tools.level_generator.rng')

test('same seed produces the same sequence of values', function()
	local a = Rng.new(42)
	local b = Rng.new(42)

	for i = 1, 20 do
		assertEqual(a:nextUint32(), b:nextUint32())
	end
end)

test('different seeds produce different sequences', function()
	local a = Rng.new(1)
	local b = Rng.new(2)

	local same = true
	for i = 1, 20 do
		if a:nextUint32() ~= b:nextUint32() then
			same = false
		end
	end

	assertFalse(same)
end)

test('nextInt stays within the requested inclusive range', function()
	local rng = Rng.new(7)

	for i = 1, 200 do
		local v = rng:nextInt(3, 9)
		assertTrue(v >= 3 and v <= 9, 'expected ' .. v .. ' to be within [3, 9]')
	end
end)

test('deriveSeed is deterministic for the same base seed and index', function()
	assertEqual(Rng.deriveSeed(42, 3), Rng.deriveSeed(42, 3))
end)

test('deriveSeed gives different seeds for different batch indices', function()
	assertFalse(Rng.deriveSeed(42, 0) == Rng.deriveSeed(42, 1))
end)
