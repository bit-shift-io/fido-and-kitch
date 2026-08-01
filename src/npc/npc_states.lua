-- NPC FSM states, wired onto the shared NPC base's StateMachine
-- component (mirrors src/player/player_states.lua).
local NPCBrain = require('src.npc.npc_brain')
local DeathFlash = require('src.components.death_flash')

local ChaseState = Class{}

function ChaseState:update(dt)
	local npc = self.entity

	if npc.fsm:tryTransition('ClimbState') then
		return
	end

	local target = npc:findTarget()

	local v_x, v_y = npc.collider:getLinearVelocity()

	if target == nil then
		npc.fsm:setState('WanderState')
		npc.animations:setState('idle')
		return
	end

	local npcX = npc.collider:getX()
	local targetX = target.collider:getX()
	local decision = NPCBrain.decideHorizontalMovement(npcX, targetX, npc.speed, npc.alignThreshold)
	npc.collider:setLinearVelocity(decision.velocityX, v_y)

	if decision.velocityX ~= 0 then
		npc.animations:setState('walk')
		local facing = decision.velocityX > 0 and 'right' or 'left'
		if npc.animations.currentState.setFacing then
			npc.animations.currentState:setFacing(facing)
		end
	else
		npc.animations:setState('idle')
	end
end


local ClimbState = Class{}

local function currentClimbDirection(npc)
	local target = npc:findTarget()
	if target == nil then
		return nil
	end

	local npcY = npc.collider:getY()
	local targetY = target.collider:getY()
	local hasLadderAbove = npc:queryLadder() ~= nil
	local hasLadderBelow = npc:queryLadderBelow() ~= nil

	return NPCBrain.shouldClimb(npcY, targetY, npc.alignThreshold, hasLadderAbove, hasLadderBelow)
end

function ClimbState:canTransition()
	return currentClimbDirection(self.entity) ~= nil
end

function ClimbState:enter()
	local npc = self.entity
	npc.collider:setType('kinematic')
	npc.collider:setGravityScale(0)
end

function ClimbState:exit()
	local npc = self.entity
	npc.collider:setType('dynamic')
	npc.collider:setGravityScale(1)
end

function ClimbState:update(dt)
	local npc = self.entity
	local direction = currentClimbDirection(npc)

	if direction == nil then
		npc.fsm:setState('ChaseState')
		return
	end

	local velocityY = direction == 'up' and -npc.speed or npc.speed
	npc.collider:setLinearVelocity(0, velocityY)
	npc.animations:setState('idle')
end

local WanderState = Class{}

function WanderState:update(dt)
	local npc = self.entity

	if npc:findTarget() ~= nil then
		npc.fsm:setState('ChaseState')
		return
	end

	local v_x, v_y = npc.collider:getLinearVelocity()
	local npcX = npc.collider:getX()
	local decision = NPCBrain.decideWander(
		{direction = npc.wanderDirection},
		npcX,
		npc.homeX,
		npc.speed,
		npc.wanderRange,
		dt
	)
	npc.wanderDirection = decision.direction
	npc.collider:setLinearVelocity(decision.velocityX, v_y)

	if decision.velocityX ~= 0 then
		npc.animations:setState('walk')
		local facing = decision.velocityX > 0 and 'right' or 'left'
		if npc.animations.currentState.setFacing then
			npc.animations.currentState:setFacing(facing)
		end
	else
		npc.animations:setState('idle')
	end
end

local StunnedState = Class{}

function StunnedState:enter()
	local npc = self.entity
	npc.collider:setType('kinematic')
	npc.collider:setGravityScale(0)
	npc.collider:setLinearVelocity(0, 0)
end

function StunnedState:exit()
	local npc = self.entity
	npc.collider:setType('dynamic')
	npc.collider:setGravityScale(1)
end

function StunnedState:update(dt)
	local npc = self.entity
	npc.stunTimer = npc.stunTimer - dt
	npc.animations:setState('idle')
	if npc.stunTimer <= 0 then
		npc.fsm:setState('ChaseState')
	end
end

local DeadState = Class{}

-- The payoff for killing an enemy: a stretch of level free of it. Not
-- configurable per enemy/kill-zone/level -- one shared constant, mirroring
-- how the flash timing itself isn't tuned per entity.
local RESPAWN_DELAY = 30

function DeadState:enter()
	local npc = self.entity

	npc.collider:setLinearVelocity(0, 0)
	npc.collider:setType('kinematic')
	npc.collider:setGravityScale(0)
	npc.animations:setState('idle')

	self.canRespawn = false
	self.respawnTimer = 0

	npc:onDeath()

	DeathFlash.startDeath(npc, function()
		self.canRespawn = true
	end)
end

function DeadState:exit()
	local npc = self.entity
	npc.collider:setType('dynamic')
	npc.collider:setGravityScale(1)
end

-- The 30s window only starts counting once the death flash-out has actually
-- finished (self.canRespawn, set by DeathFlash's onComplete) -- it gates the
-- *respawn*, not the ~1.2s flash itself; the two timers are independent.
function DeadState:update(dt)
	if not self.canRespawn then
		return
	end

	self.respawnTimer = self.respawnTimer + dt
	if self.respawnTimer >= RESPAWN_DELAY then
		self.entity:respawn()
	end
end

return {
	ChaseState = ChaseState,
	ClimbState = ClimbState,
	WanderState = WanderState,
	StunnedState = StunnedState,
	DeadState = DeadState,
}