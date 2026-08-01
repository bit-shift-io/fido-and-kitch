local movement = require('src.player.player_movement')

test('moving right chooses positive velocity, right facing, and walk animation', function()
	local decision = movement.decideHorizontalMovement({right=true, left=false}, 100, 12)

	assertEqual(100, decision.velocityX)
	assertEqual(12, decision.velocityY)
	assertEqual('right', decision.facing)
	assertEqual('walk', decision.animation)
end)

test('moving left chooses negative velocity, left facing, and walk animation', function()
	local decision = movement.decideHorizontalMovement({right=false, left=true}, 100, 12)

	assertEqual(-100, decision.velocityX)
	assertEqual(12, decision.velocityY)
	assertEqual('left', decision.facing)
	assertEqual('walk', decision.animation)
end)

test('no horizontal input chooses zero velocity and idle animation', function()
	local decision = movement.decideHorizontalMovement({right=false, left=false}, 100, 12)

	assertEqual(0, decision.velocityX)
	assertEqual(12, decision.velocityY)
	assertEqual(nil, decision.facing)
	assertEqual('idle', decision.animation)
end)

test('nearestLadderCentre returns the closest ladder centre-x to player centre-x', function()
	local playerCentreX = 100
	local ladderCentres = { 80, 120, 200 }
	local centre = movement.nearestLadderCentre(playerCentreX, ladderCentres)

	assertEqual(80, centre)
end)

test('nearestLadderCentre returns the only ladder when one provided', function()
	local playerCentreX = 100
	local ladderCentres = { 150 }
	local centre = movement.nearestLadderCentre(playerCentreX, ladderCentres)

	assertEqual(150, centre)
end)

test('nearestLadderCentre resolves ties deterministically (first encountered)', function()
	local playerCentreX = 100
	local ladderCentres = { 80, 120 }
	local centre = movement.nearestLadderCentre(playerCentreX, ladderCentres)

	assertEqual(80, centre)
end)

test('isCentred returns true when player is within one slide-step of centre', function()
	local slideSpeed = 100
	local dt = 1/60
	local slideStep = slideSpeed * dt
	local result = movement.isCentred(100, 100 + slideStep * 0.5, slideSpeed, dt)

	assertTrue(result)
end)

test('isCentred returns true when player is exactly at centre', function()
	local slideSpeed = 100
	local dt = 1/60
	local result = movement.isCentred(100, 100, slideSpeed, dt)

	assertTrue(result)
end)

test('isCentred returns false when player is beyond one slide-step from centre', function()
	local slideSpeed = 100
	local dt = 1/60
	local slideStep = slideSpeed * dt
	local result = movement.isCentred(100, 100 + slideStep * 2, slideSpeed, dt)

	assertFalse(result)
end)

test('resolveActiveAxis switches to horizontal when horizontal newly pressed while vertical held', function()
	local axis = movement.resolveActiveAxis({
		verticalHeld = true,
		horizontalHeld = true,
		verticalNewlyPressed = false,
		horizontalNewlyPressed = true,
		previousAxis = 'vertical'
	})

	assertEqual('horizontal', axis)
end)

test('resolveActiveAxis switches to vertical when vertical newly pressed while horizontal held', function()
	local axis = movement.resolveActiveAxis({
		verticalHeld = true,
		horizontalHeld = true,
		verticalNewlyPressed = true,
		horizontalNewlyPressed = false,
		previousAxis = 'horizontal'
	})

	assertEqual('vertical', axis)
end)

test('resolveActiveAxis stays on current axis when no new press', function()
	local axis = movement.resolveActiveAxis({
		verticalHeld = true,
		horizontalHeld = true,
		verticalNewlyPressed = false,
		horizontalNewlyPressed = false,
		previousAxis = 'vertical'
	})

	assertEqual('vertical', axis)
end)

test('resolveActiveAxis falls back to held axis when active axis released', function()
	local axis = movement.resolveActiveAxis({
		verticalHeld = true,
		horizontalHeld = false,
		verticalNewlyPressed = false,
		horizontalNewlyPressed = false,
		previousAxis = 'horizontal'
	})

	assertEqual('vertical', axis)
end)

test('resolveActiveAxis returns nil when no axis held', function()
	local axis = movement.resolveActiveAxis({
		verticalHeld = false,
		horizontalHeld = false,
		verticalNewlyPressed = false,
		horizontalNewlyPressed = false,
		previousAxis = 'vertical'
	})

	assertEqual(nil, axis)
end)

test('shouldFallOffLadder returns false when overlapping at least one ladder', function()
	local result = movement.shouldFallOffLadder(true)

	assertFalse(result)
end)

test('shouldFallOffLadder returns true when not overlapping any ladder', function()
	local result = movement.shouldFallOffLadder(false)

	assertTrue(result)
end)

test('resolveLadderOverlap returns the direct overlaps unchanged when already overlapping', function()
	local ladders = { 'ladderA' }
	local result = movement.resolveLadderOverlap(ladders, true, 'ladderBelow')

	assertEqual(1, #result)
	assertEqual('ladderA', result[1])
end)

test('resolveLadderOverlap folds in a ladder below while descending onto it from flush above', function()
	local result = movement.resolveLadderOverlap({}, true, 'ladderBelow')

	assertEqual(1, #result)
	assertEqual('ladderBelow', result[1])
end)

test('resolveLadderOverlap stays empty when descending but no ladder is below', function()
	local result = movement.resolveLadderOverlap({}, true, nil)

	assertEqual(0, #result)
end)

test('resolveLadderOverlap stays empty when not pressing down, even if a ladder is below', function()
	local result = movement.resolveLadderOverlap({}, false, 'ladderBelow')

	assertEqual(0, #result)
end)
