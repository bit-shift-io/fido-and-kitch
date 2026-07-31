local NPCBrain = {}

function NPCBrain.pickTarget(enemyPos, players, bans)
	bans = bans or {}
	local nearest = nil
	local nearestDistance = nil

	for _, player in ipairs(players) do
		local banKey = player.entity or player
		if not player.isDead() and not player.wrapped and not NPCBrain.isBanned(bans, banKey) then
			local distance = math.abs(player.x - enemyPos.x)
			if nearestDistance == nil or distance < nearestDistance then
				nearest = player
				nearestDistance = distance
			end
		end
	end

	return nearest
end

function NPCBrain.decideHorizontalMovement(enemyX, targetX, speed, alignThreshold)
	local delta = targetX - enemyX

	if math.abs(delta) <= alignThreshold then
		return {
			velocityX = 0,
			animation = 'idle',
		}
	end

	if delta > 0 then
		return {
			velocityX = speed,
			animation = 'walk',
		}
	end

	return {
		velocityX = -speed,
		animation = 'walk',
	}
end

function NPCBrain.shouldClimb(enemyY, targetY, alignThreshold, hasLadderAbove, hasLadderBelow)
	local delta = targetY - enemyY

	if math.abs(delta) <= alignThreshold then
		return nil
	end

	if delta < 0 and hasLadderAbove then
		return 'up'
	end

	if delta > 0 and hasLadderBelow then
		return 'down'
	end

	return nil
end

function NPCBrain.decideShove(enemyX, targetX, shoveSpeed, wrapped)
	if wrapped then
		return 0
	end

	if targetX < enemyX then
		return -shoveSpeed
	end

	return shoveSpeed
end

function NPCBrain.ban(bans, player, duration)
	bans[player] = duration
end

function NPCBrain.isBanned(bans, player)
	return bans[player] ~= nil and bans[player] > 0
end

function NPCBrain.tickBans(bans, dt)
	for player, remaining in pairs(bans) do
		local nextRemaining = remaining - dt
		if nextRemaining <= 0 then
			bans[player] = nil
		else
			bans[player] = nextRemaining
		end
	end
	return bans
end

function NPCBrain.updateChaseTimer(chaseTimer, target, dt, chaseBanTime)
	if target == nil then
		return {target = nil, elapsed = 0}, false
	end

	if chaseTimer.target ~= target then
		chaseTimer = {target = target, elapsed = 0}
	end

	local elapsed = chaseTimer.elapsed + dt

	if elapsed >= chaseBanTime then
		return {target = nil, elapsed = 0}, true
	end

	return {target = target, elapsed = elapsed}, false
end

function NPCBrain.decideWander(wanderState, enemyX, homeX, wanderSpeed, wanderRange, dt)
	local direction = wanderState.direction or 1

	if enemyX - homeX >= wanderRange then
		direction = -1
	elseif homeX - enemyX >= wanderRange then
		direction = 1
	end

	return {
		velocityX = wanderSpeed * direction,
		direction = direction,
	}
end

function NPCBrain.isStomp(playerVelocityY, playerBottom, enemyTop, enemyHeight, stompZoneRatio)
	if playerVelocityY <= 0 then
		return false
	end

	local stompZoneBottom = enemyTop + enemyHeight * stompZoneRatio
	return playerBottom <= stompZoneBottom
end

return NPCBrain