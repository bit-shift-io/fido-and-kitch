-- src/npc/states/chase_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local ChaseState = Class{}

function ChaseState:enter(prevState)
    local entity = self.entity
    if entity.target then
        local tx, ty = entity:getTargetPos()
        entity.chaseTarget = {x = tx, y = ty}
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
    local tx, ty = entity:getTargetPos()
    entity.chaseTarget.x = tx
    entity.chaseTarget.y = ty
    
    local dx = entity.chaseTarget.x - entity.x
    local dy = entity.chaseTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 5 then return end
    
    local dir = Vector(dx, dy):normalized()
    local accel = entity.config.acceleration or 300
    local maxSpeed = entity.config.maxSpeed or 80
    
    local vx, vy = entity.collider:getLinearVelocity()
    vx = vx + dir.x * accel * dt
    
    if math.abs(vx) > maxSpeed then
        vx = (vx > 0 and 1 or -1) * maxSpeed
    end
    entity.collider:setLinearVelocity(vx, vy)
end

function ChaseState:exit(prevState)
    local entity = self.entity
    entity.chaseTarget = nil
end

return ChaseState