local SafePosition = require('src.player.safe_position')

test('safe position starts at the seeded spawn point', function()
	local tracker = SafePosition.new(10, 20, 0.5)

	assertEqual(10, tracker.x)
	assertEqual(20, tracker.y)
end)

test('grounded for less than the threshold does not move the safe position', function()
	local tracker = SafePosition.new(10, 20, 0.5)

	tracker:update(0.3, true, 100, 200)

	assertEqual(10, tracker.x)
	assertEqual(20, tracker.y)
end)

test('grounded past the threshold commits the new position', function()
	local tracker = SafePosition.new(10, 20, 0.5)

	tracker:update(0.3, true, 100, 200)
	tracker:update(0.3, true, 100, 200)

	assertEqual(100, tracker.x)
	assertEqual(200, tracker.y)
end)

test('going airborne resets the grounded timer', function()
	local tracker = SafePosition.new(10, 20, 0.5)

	tracker:update(0.3, true, 100, 200)
	tracker:update(0.1, false, 999, 999) -- brief touch-down interrupted mid-fall
	tracker:update(0.3, true, 100, 200)

	-- still under threshold since the timer reset, so the seed position holds
	assertEqual(10, tracker.x)
	assertEqual(20, tracker.y)
end)

test('position keeps updating while grounding remains stable', function()
	local tracker = SafePosition.new(10, 20, 0.5)

	tracker:update(0.6, true, 100, 200)
	tracker:update(0.1, true, 150, 200)

	assertEqual(150, tracker.x)
	assertEqual(200, tracker.y)
end)
