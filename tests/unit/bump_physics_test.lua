local motion = require('src.physics.bump.motion')

test('gravity increases downward velocity', function()
	local velocityY = 10
	local gravity = 300
	local gravityScale = 1
	local maxFallSpeed = 500
	local dt = 0.1

	local nextVelocityY = motion.updateGravity(velocityY, gravity, gravityScale, maxFallSpeed, dt)
	assertEqual(40, nextVelocityY)
end)

test('fall speed clamps at terminal velocity', function()
	local velocityY = 490
	local gravity = 300
	local gravityScale = 1
	local maxFallSpeed = 500
	local dt = 0.1

	local nextVelocityY = motion.updateGravity(velocityY, gravity, gravityScale, maxFallSpeed, dt)
	assertEqual(500, nextVelocityY)
end)

test('solid vertical collision cancels vertical velocity when moving into the surface', function()
	local velocityX = 0
	local velocityY = 100

	-- collision from below (ground), normal points up (0, -1)
	local cols = {
		{
			type = 'touch',
			normal = { x = 0, y = -1 }
		}
	}

	local nextVelocityX, nextVelocityY = motion.resolveCollisions(velocityX, velocityY, cols)
	assertEqual(0, nextVelocityX)
	assertEqual(0, nextVelocityY)
end)

test('cross/sensor contact does not cancel velocity', function()
	local velocityX = 100
	local velocityY = 100

	local cols = {
		{
			type = 'cross',
			normal = { x = 0, y = -1 }
		}
	}

	local nextVelocityX, nextVelocityY = motion.resolveCollisions(velocityX, velocityY, cols)
	assertEqual(100, nextVelocityX)
	assertEqual(100, nextVelocityY)
end)
