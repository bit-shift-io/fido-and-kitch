local PlayerMovement = {}

function PlayerMovement.decideHorizontalMovement(input, speed, velocityY)
	if input.right then
		return {
			velocityX=speed,
			velocityY=velocityY,
			facing='right',
			animation='walk',
		}
	end

	return {
		velocityX=0,
		velocityY=velocityY,
		animation='idle',
	}
end

return PlayerMovement
