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
