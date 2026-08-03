-- src/npc/states/follow_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local FollowState = Class{}

function FollowState:enter(prevState)
    local entity = self.entity
    entity.followTimer = 0
end

function FollowState:update(dt)
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        print("ERROR FollowState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    if not entity.target then return end
    
    -- Defensive: ensure target has x,y
    if not entity.target.x or not entity.target.y then
        entity.target = nil
        return
    end
    
    local followDist = entity.config.followDistance or 40
    local dx = entity.target.x - entity.x
    local dy = entity.target.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- If too close, back off; if too far, approach
    local targetDist = followDist
    if dist < targetDist * 0.5 then
        -- Too close, move away
        dx, dy = -dx, -dy
    elseif dist > targetDist * 2 then
        -- Too far, move closer aggressively
    end
    
    if dist < 5 then return end
    
    local dir = Vector(dx, dy):normalized()
    local dirX, dirY = dir.x, dir.y
    local accel = entity.config.acceleration or 250
    local maxSpeed = entity.config.maxSpeed or 60
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function FollowState:exit(prevState)
    local entity = self.entity
    entity.followTimer = 0
end

return FollowState