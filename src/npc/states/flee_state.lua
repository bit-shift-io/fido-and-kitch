-- src/npc/states/flee_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local FleeState = Class{}

function FleeState:enter(prevState)
    local entity = self.entity
    entity.fleeTimer = 0
end

function FleeState:update(dt)
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        Log.error("FleeState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    if not entity.target then return end
    
    -- Move away from threat
    local tx, ty = entity:getTargetPos()
    if not tx or not ty then return end
    local dx = entity.x - tx
    local dy = entity.y - ty
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 1 then return end
    
    local dir = Vector(dx, dy):normalized()
    local accel = entity.config.acceleration or 400
    local maxSpeed = entity.config.maxSpeed or 100
    
    local vx, vy = entity.collider:getLinearVelocity()
    vx = vx + dir.x * accel * dt
    
    if math.abs(vx) > maxSpeed then
        vx = (vx > 0 and 1 or -1) * maxSpeed
    end
    entity.collider:setLinearVelocity(vx, vy)
end

function FleeState:exit(prevState)
    local entity = self.entity
    entity.fleeTimer = 0
end

return FleeState