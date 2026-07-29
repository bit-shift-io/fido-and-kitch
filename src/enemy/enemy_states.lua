-- Enemy FSM states, wired onto the shared Enemy base's StateMachine
-- component (mirrors src/player/player_states.lua).
local EnemyBrain = require('src.enemy.enemy_brain')

local ChaseState = Class{}

function ChaseState:update(dt)
	local enemy = self.entity

	if enemy.fsm:tryTransition('ClimbState') then
		return
	end

	local target = enemy:findTarget()

	local v_x, v_y = enemy.collider:getLinearVelocity()

	if target == nil then
		enemy.fsm:setState('WanderState')
		return
	end

	local enemyX = enemy.collider:getX()
	local targetX = target.collider:getX()
	local decision = EnemyBrain.decideHorizontalMovement(enemyX, targetX, enemy.speed, enemy.alignThreshold)
	enemy.collider:setLinearVelocity(decision.velocityX, v_y)
end


-- opportunistic ladder climb toward the target's Y (DECISIONS Q6); dismounts
-- and hands back to ChaseState once aligned or the ladder runs out
local ClimbState = Class{}

-- shared by canTransition (should we start/keep climbing?) and update (which
-- way, or dismount)
local function currentClimbDirection(enemy)
	local target = enemy:findTarget()
	if target == nil then
		return nil
	end

	local enemyY = enemy.collider:getY()
	local targetY = target.collider:getY()
	local hasLadderAbove = enemy:queryLadder() ~= nil
	local hasLadderBelow = enemy:queryLadderBelow() ~= nil

	return EnemyBrain.shouldClimb(enemyY, targetY, enemy.alignThreshold, hasLadderAbove, hasLadderBelow)
end

function ClimbState:canTransition()
	return currentClimbDirection(self.entity) ~= nil
end

function ClimbState:enter()
	local enemy = self.entity
	enemy.collider:setType('kinematic')
	enemy.collider:setGravityScale(0)
end

function ClimbState:exit()
	local enemy = self.entity
	enemy.collider:setType('dynamic')
	enemy.collider:setGravityScale(1)
end

function ClimbState:update(dt)
	local enemy = self.entity
	local direction = currentClimbDirection(enemy)

	if direction == nil then
		enemy.fsm:setState('ChaseState')
		return
	end

	local velocityY = direction == 'up' and -enemy.speed or enemy.speed
	enemy.collider:setLinearVelocity(0, velocityY)
end

-- no valid target: amble around the spawn point until one becomes valid
-- (DECISIONS Q4)
local WanderState = Class{}

function WanderState:update(dt)
	local enemy = self.entity

	if enemy:findTarget() ~= nil then
		enemy.fsm:setState('ChaseState')
		return
	end

	local v_x, v_y = enemy.collider:getLinearVelocity()
	local enemyX = enemy.collider:getX()
	local decision = EnemyBrain.decideWander(
		{direction = enemy.wanderDirection},
		enemyX,
		enemy.homeX,
		enemy.speed,
		enemy.wanderRange,
		dt
	)
	enemy.wanderDirection = decision.direction
	enemy.collider:setLinearVelocity(decision.velocityX, v_y)
end

-- head-stomped (DECISIONS Q10): frozen in place, no chasing/climbing/
-- wandering/wrapping/shoving, until the stun timer (enemy.stunTimer, set by
-- Enemy:stun) runs out; never entered/exited via canTransition since a
-- re-stomp must be able to refresh the timer while already stunned (see
-- Enemy:stun)
local StunnedState = Class{}

function StunnedState:enter()
	local enemy = self.entity
	enemy.collider:setType('kinematic')
	enemy.collider:setGravityScale(0)
	enemy.collider:setLinearVelocity(0, 0)
end

function StunnedState:exit()
	local enemy = self.entity
	enemy.collider:setType('dynamic')
	enemy.collider:setGravityScale(1)
end

function StunnedState:update(dt)
	local enemy = self.entity
	enemy.stunTimer = enemy.stunTimer - dt
	if enemy.stunTimer <= 0 then
		enemy.fsm:setState('ChaseState')
	end
end

return {
	ChaseState = ChaseState,
	ClimbState = ClimbState,
	WanderState = WanderState,
	StunnedState = StunnedState,
}
