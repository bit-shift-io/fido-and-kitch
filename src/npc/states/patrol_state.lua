-- src/npc/states/patrol_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local PatrolState = Class{}

function PatrolState:enter(prevState)
    local entity = self.entity
    local points = entity.config.patrolPoints
    if not points or #points == 0 then return end
    
    local idx = entity.currentPatrolIndex or 1
    entity.patrolTarget = points[idx]
end

function PatrolState:update(dt)
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        print("ERROR PatrolState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    local points = entity.config.patrolPoints
    if not points or #points == 0 then return end
    if not entity.patrolTarget then
        self:enter()
        return
    end
    
    local dx = entity.patrolTarget.x - entity.x
    local dy = entity.patrolTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 10 then
        -- Reached patrol point, advance to next
        local idx = (entity.currentPatrolIndex or 1) + (entity.patrolDirection or 1)
        if idx > #points then
            idx = #points - 1
            entity.patrolDirection = -1
        elseif idx < 1 then
            idx = 2
            entity.patrolDirection = 1
        end
        entity.currentPatrolIndex = idx
        entity.patrolTarget = points[idx]
        return
    end
    
    local dir = Vector(dx, dy):normalized()
    local dirX, dirY = dir.x, dir.y
    local accel = entity.config.acceleration or 200
    local maxSpeed = entity.config.maxSpeed or 50
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function PatrolState:exit(prevState)
    local entity = self.entity
    entity.patrolTarget = nil
end

return PatrolState