local PlayerMovement = {}

function PlayerMovement.decideHorizontalMovement(input, speed, velocityY)
	local velocityX = 0
	local facing = nil
	local animation = 'idle'

	if input.right then
		velocityX = speed
		facing = 'right'
		animation = 'walk'
	end

	if input.left then
		velocityX = -speed
		facing = 'left'
		animation = 'walk'
	end

	return {
		velocityX = velocityX,
		velocityY = velocityY,
		facing = facing,
		animation = animation,
	}
end

return PlayerMovement

