-- src/npc/states/patrol_state.lua
local Class = require('lib.hump.class')

local PatrolState = Class{}

function PatrolState:enter(prevState)
    local entity = self.entity

    -- Initialize patrol timers if not set
    if not entity.patrolPauseTimer then
        entity.patrolPauseTimer = 0
        entity.patrolPaused = false
        entity.patrolPauseDuration = 0
        entity.patrolWalkTimer = 0
        entity.patrolNextPause = 2 + math.random() * 3
    end
end

function PatrolState:update(dt)
    if type(dt) ~= 'number' then
        dt = 1/60
    end
    local entity = self.entity
    local config = entity.config
    local accel = config.acceleration or 400
    local maxSpeed = config.maxSpeed or 80

    -- Random idle pause during walk
    if entity.patrolPaused then
        entity.patrolPauseTimer = entity.patrolPauseTimer + dt
        if entity.patrolPauseTimer >= entity.patrolPauseDuration then
            entity.patrolPaused = false
            entity.patrolPauseTimer = 0
            self:reverse(entity)
        end
        return
    end

    -- Check for wall ahead
    if entity:isWallAhead(entity.facing) then
        self:pauseAndReverse(entity, 1.0, 2.0)
        return
    end

    -- Check for edge ahead (no ground = edge)
    if not entity:isGroundAhead(entity.facing) then
        self:pauseAndReverse(entity, 0.5, 1.5)
        return
    end

    -- Walk in facing direction (horizontal only — gravity handles vertical)
    local vx, vy = entity.collider:getLinearVelocity()
    local dirX = entity.facing == 'right' and 1 or -1
    vx = vx + dirX * accel * dt

    -- Clamp horizontal speed
    if math.abs(vx) > maxSpeed then
        vx = (vx > 0 and 1 or -1) * maxSpeed
    end
    entity.collider:setLinearVelocity(vx, vy)

    -- Random idle pauses during walk
    entity.patrolWalkTimer = entity.patrolWalkTimer + dt
    if entity.patrolWalkTimer >= entity.patrolNextPause then
        entity.patrolPaused = true
        entity.patrolPauseDuration = 0.5 + math.random() * 1.0
        entity.patrolWalkTimer = 0
        entity.patrolNextPause = 2 + math.random() * 3
        entity.collider:setLinearVelocity(0, vy)
    end
end

function PatrolState:pauseAndReverse(entity, minDur, maxDur)
    entity.patrolPaused = true
    entity.patrolPauseTimer = 0
    entity.patrolPauseDuration = minDur + math.random() * (maxDur - minDur)
    entity.patrolWalkTimer = 0
    entity.patrolNextPause = 2 + math.random() * 3
    local _, vy = entity.collider:getLinearVelocity()
    entity.collider:setLinearVelocity(0, vy)
end

function PatrolState:reverse(entity)
    entity.facing = entity.facing == 'right' and 'left' or 'right'
end

function PatrolState:exit(prevState)
    local entity = self.entity
    entity.patrolPauseTimer = nil
    entity.patrolPaused = nil
    entity.patrolPauseDuration = nil
    entity.patrolWalkTimer = nil
    entity.patrolNextPause = nil
end

return PatrolState
