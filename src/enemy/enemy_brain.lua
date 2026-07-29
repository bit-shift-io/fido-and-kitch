local EnemyBrain = {}

function EnemyBrain.pickTarget(enemyPos, players, bans)
	bans = bans or {}
	local nearest = nil
	local nearestDistance = nil

	for _, player in ipairs(players) do
		local banKey = player.entity or player
		if not player.isDead() and not player.wrapped and not EnemyBrain.isBanned(bans, banKey) then
			local distance = math.abs(player.x - enemyPos.x)
			if nearestDistance == nil or distance < nearestDistance then
				nearest = player
				nearestDistance = distance
			end
		end
	end

	return nearest
end

function EnemyBrain.decideHorizontalMovement(enemyX, targetX, speed, alignThreshold)
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

-- opportunistic ladder use only: an enemy climbs toward the target's Y only
-- if it is already overlapping a usable ladder in that direction (no route
-- planning or ladder seeking -- DECISIONS Q6)
function EnemyBrain.shouldClimb(enemyY, targetY, alignThreshold, hasLadderAbove, hasLadderBelow)
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

-- robot shove: a steady sideways push away from the robot while overlapping,
-- always escapable (shoveSpeed is comfortably below player walk speed --
-- DECISIONS Q7). Wrapped players are immune (DECISIONS Q8/Q15).
function EnemyBrain.decideShove(enemyX, targetX, shoveSpeed, wrapped)
	if wrapped then
		return 0
	end

	if targetX < enemyX then
		return -shoveSpeed
	end

	return shoveSpeed
end

-- harassment bans (DECISIONS Q3): per enemy-instance, per-player timers that
-- exclude a player from targeting until they expire
function EnemyBrain.ban(bans, player, duration)
	bans[player] = duration
end

function EnemyBrain.isBanned(bans, player)
	return bans[player] ~= nil and bans[player] > 0
end

function EnemyBrain.tickBans(bans, dt)
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

-- robot chase-to-ban rule (DECISIONS Q3): the clock runs from target
-- acquisition and resets whenever the target changes or is lost; reaching
-- chaseBanTime signals the caller to ban that target
function EnemyBrain.updateChaseTimer(chaseTimer, target, dt, chaseBanTime)
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

-- no valid target: amble back and forth within wanderRange of homeX,
-- reversing at each edge (DECISIONS Q4)
function EnemyBrain.decideWander(wanderState, enemyX, homeX, wanderSpeed, wanderRange, dt)
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

-- head-stomp detection (DECISIONS Q10): geometric, not a physical landing --
-- the caller has already established X/Y overlap (e.g. via a world query),
-- so this only needs to confirm the player is falling and their feet are in
-- the enemy's upper "stomp zone"
function EnemyBrain.isStomp(playerVelocityY, playerBottom, enemyTop, enemyHeight, stompZoneRatio)
	if playerVelocityY <= 0 then
		return false
	end

	local stompZoneBottom = enemyTop + enemyHeight * stompZoneRatio
	return playerBottom <= stompZoneBottom
end

return EnemyBrain
