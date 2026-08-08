local Plan = require('tools.level_generator.plan')
local Rng = require('tools.level_generator.rng')

test('builds one objective per pair of zones available, capped at 5 colors', function()
	local plan = Plan.build(Rng.new(1), 6)
	assertEqual(3, #plan)

	plan = Plan.build(Rng.new(1), 20)
	assertEqual(5, #plan)
end)

test('always builds at least one objective, even with a single zone', function()
	local plan = Plan.build(Rng.new(1), 1)
	assertEqual(1, #plan)
	assertEqual(1, plan[1].keyZoneIndex)
	assertEqual(1, plan[1].cageZoneIndex)
end)

test('every objective has a unique color', function()
	local plan = Plan.build(Rng.new(5), 10)
	local seen = {}
	for _, objective in ipairs(plan) do
		assertFalse(seen[objective.color] == true, 'color ' .. objective.color .. ' used twice')
		seen[objective.color] = true
	end
end)

test('zone indices are always within range', function()
	local zoneCount = 7
	local plan = Plan.build(Rng.new(3), zoneCount)
	for _, objective in ipairs(plan) do
		assertTrue(objective.keyZoneIndex >= 1 and objective.keyZoneIndex <= zoneCount)
		assertTrue(objective.cageZoneIndex >= 1 and objective.cageZoneIndex <= zoneCount)
	end
end)

test('same seed produces an identical plan', function()
	local a = Plan.build(Rng.new(42), 8)
	local b = Plan.build(Rng.new(42), 8)
	assertEqual(#a, #b)
	for i = 1, #a do
		assertEqual(a[i].color, b[i].color)
		assertEqual(a[i].keyZoneIndex, b[i].keyZoneIndex)
		assertEqual(a[i].cageZoneIndex, b[i].cageZoneIndex)
	end
end)
