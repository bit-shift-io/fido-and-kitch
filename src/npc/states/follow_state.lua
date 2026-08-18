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
        Log.error("FollowState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    
    if not entity.target then return end
    
    -- Resolve target position (entity with collider or plain table)
    local tx, ty = entity:getTargetPos()
    if not tx or not ty then
        entity.target = nil
        return
    end
    
    local followDist = entity.config.followDistance or 40
    local dx = tx - entity.x
    local dy = ty - entity.y
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
    local accel = entity.config.acceleration or 250
    local maxSpeed = entity.config.maxSpeed or 60
    
    local vx, vy = entity.collider:getLinearVelocity()
    
    -- Flying NPCs (canFly) move in both X and Y; ground NPCs only move horizontally
    if entity.config.canFly then
        vx = vx + dir.x * accel * dt
        vy = vy + dir.y * accel * dt
        
        if math.abs(vx) > maxSpeed then
            vx = (vx > 0 and 1 or -1) * maxSpeed
        end
        if math.abs(vy) > maxSpeed then
            vy = (vy > 0 and 1 or -1) * maxSpeed
        end
    else
        vx = vx + dir.x * accel * dt
        
        if math.abs(vx) > maxSpeed then
            vx = (vx > 0 and 1 or -1) * maxSpeed
        end
    end
    
    entity.collider:setLinearVelocity(vx, vy)
end

function FollowState:exit(prevState)
    local entity = self.entity
    entity.followTimer = 0
end

return FollowState