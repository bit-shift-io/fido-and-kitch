local MovementModel = require('tools.level_generator.movement_model')

test('constants come from src/player/movement_constants, not literals in the tool', function()
	local RealConstants = require('src.player.movement_constants')
	assertEqual(RealConstants.speed, MovementModel.constants.speed)
	assertEqual(RealConstants.climbSpeed, MovementModel.constants.climbSpeed)
end)

test('two zones on the same row with touching x-ranges are walk-connected', function()
	local a = {x1 = 1, x2 = 5, y = 10}
	local b = {x1 = 6, x2 = 9, y = 10}
	assertTrue(MovementModel.canWalkBetween(a, b))
end)

test('two zones on the same row with a gap between them are not walk-connected', function()
	local a = {x1 = 1, x2 = 5, y = 10}
	local b = {x1 = 8, x2 = 9, y = 10}
	assertFalse(MovementModel.canWalkBetween(a, b))
end)

test('zones on different rows are never walk-connected (no jump exists)', function()
	local a = {x1 = 1, x2 = 5, y = 10}
	local b = {x1 = 1, x2 = 5, y = 9}
	assertFalse(MovementModel.canWalkBetween(a, b))
end)

test('a ladder connects two zones when it spans their rows and sits within both x-ranges', function()
	local upper = {x1 = 3, x2 = 6, y = 5}
	local lower = {x1 = 3, x2 = 6, y = 10}
	local ladder = {x = 4, yTop = 5, yBottom = 10}
	assertTrue(MovementModel.ladderConnects(ladder, upper, lower))
end)

test('a ladder outside a zone x-range does not connect it', function()
	local upper = {x1 = 3, x2 = 6, y = 5}
	local lower = {x1 = 3, x2 = 6, y = 10}
	local ladder = {x = 20, yTop = 5, yBottom = 10}
	assertFalse(MovementModel.ladderConnects(ladder, upper, lower))
end)

test('a ladder that does not reach both rows does not connect them', function()
	local upper = {x1 = 3, x2 = 6, y = 5}
	local lower = {x1 = 3, x2 = 6, y = 10}
	local ladder = {x = 4, yTop = 6, yBottom = 10} -- doesn't reach the upper row's surface
	assertFalse(MovementModel.ladderConnects(ladder, upper, lower))
end)

test('every zone reachable from spawn via a chain of walk and ladder edges', function()
	local zones = {
		{x1 = 1, x2 = 20, y = 15}, -- ground / spawn zone (index 1)
		{x1 = 3, x2 = 8, y = 10},
		{x1 = 3, x2 = 8, y = 6},
	}
	local ladders = {
		{x = 4, yTop = 10, yBottom = 15},
		{x = 4, yTop = 6, yBottom = 10},
	}

	local reachable = MovementModel.reachableFrom(zones, ladders, 1)

	assertTrue(reachable[1])
	assertTrue(reachable[2])
	assertTrue(reachable[3])
end)

test('a zone with no walk or ladder edge to spawn is reported unreachable', function()
	local zones = {
		{x1 = 1, x2 = 20, y = 15},
		{x1 = 3, x2 = 8, y = 6}, -- floating, no ladder connects it
	}
	local reachable = MovementModel.reachableFrom(zones, {}, 1)

	assertTrue(reachable[1])
	assertFalse(reachable[2] == true)
end)
