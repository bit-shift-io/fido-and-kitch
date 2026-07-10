local Motion = {}

function Motion.updateGravity(velocityY, gravity, gravityScale, maxFallSpeed, dt)
	local nextVelocityY = velocityY + (gravity * dt * gravityScale)
	if nextVelocityY > maxFallSpeed then
		nextVelocityY = maxFallSpeed
	end
	return nextVelocityY
end

function Motion.resolveCollisions(velocityX, velocityY, cols)
	local nextVelocityX = velocityX
	local nextVelocityY = velocityY

	for _, contact in ipairs(cols) do
		if contact.type ~= 'cross' and contact.normal then
			if contact.normal.x ~= 0 and nextVelocityX * contact.normal.x < 0 then
				nextVelocityX = 0
			end
			if contact.normal.y ~= 0 and nextVelocityY * contact.normal.y < 0 then
				nextVelocityY = 0
			end
		end
	end

	return nextVelocityX, nextVelocityY
end

return Motion
