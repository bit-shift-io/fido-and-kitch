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
        print("ERROR FleeState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    if not entity.target then return end
    
    -- Move away from threat
    local dx = entity.x - entity.target.x
    local dy = entity.y - entity.target.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 1 then return end
    
    local dir = Vector(dx, dy):normalized()
    local dirX, dirY = dir.x, dir.y
    local accel = entity.config.acceleration or 400
    local maxSpeed = entity.config.maxSpeed or 100
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function FleeState:exit(prevState)
    local entity = self.entity
    entity.fleeTimer = 0
end

return FleeState