-- src/npc/states/wander_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')

local WanderState = Class{}

function WanderState:enter(prevState)
    local entity = self.entity
    -- Pick random point within wander radius
    local radius = entity.config.wanderRadius or 100
    local angle = math.random() * 2 * math.pi
    entity.wanderTarget = {
        x = entity.x + math.cos(angle) * radius,
        y = entity.y + math.sin(angle) * radius
    }
    entity.wanderTimer = 0
end

function WanderState:update(dt)
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        print("ERROR WanderState:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end
    local entity = self.entity
    if not entity.wanderTarget then
        self:enter()
        return
    end
    
    local dx = entity.wanderTarget.x - entity.x
    local dy = entity.wanderTarget.y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 10 then
        -- Reached target, pick new one
        entity.wanderTimer = entity.wanderTimer + dt
        if entity.wanderTimer > 2 then
            self:enter()
        end
        return
    end
    
    -- Move toward target
    local dir = Vector(dx, dy):normalized()
    local dirX, dirY = dir.x, dir.y
    local accel = entity.config.acceleration or 200
    local maxSpeed = entity.config.maxSpeed or 50
    
    entity.collider.vx = entity.collider.vx + dirX * accel * dt
    entity.collider.vy = entity.collider.vy + dirY * accel * dt
    
    -- Clamp to max speed
    local speed = math.sqrt(entity.collider.vx^2 + entity.collider.vy^2)
    if speed > maxSpeed then
        entity.collider.vx = entity.collider.vx / speed * maxSpeed
        entity.collider.vy = entity.collider.vy / speed * maxSpeed
    end
end

function WanderState:exit(prevState)
    local entity = self.entity
    entity.wanderTarget = nil
    entity.wanderTimer = 0
end

return WanderState