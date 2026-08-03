-- src/npc/states/chase_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local ChaseState = Class{}

function ChaseState:enter(prevState)
    local entity = self.entity
    if entity.target then
        entity.chaseTarget = {x = entity.target.x, y = entity.target.y}
    end
end

function ChaseState:update(dt)
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        print("ERROR ChaseState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    if not entity.target or not entity.chaseTarget then
        return
    end
    
    -- Update chase target to current target position
    entity.chaseTarget.x = entity.target.x
    entity.chaseTarget.y = entity.target.y
    
    local dx = entity.chaseTarget.x - entity.x
    local dy = entity.chaseTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 5 then return end
    
    local dir = Vector(dx, dy):normalized()
    local dirX, dirY = dir.x, dir.y
    local accel = entity.config.acceleration or 300
    local maxSpeed = entity.config.maxSpeed or 80
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function ChaseState:exit(prevState)
    local entity = self.entity
    entity.chaseTarget = nil
end

return ChaseState