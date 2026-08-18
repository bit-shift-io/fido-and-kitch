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
        Log.error("WanderState:update received non-number dt:", type(dt), dt)
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
    
    -- Move toward target (horizontal only — gravity handles vertical)
    local dir = Vector(dx, dy):normalized()
    local accel = entity.config.acceleration or 200
    local maxSpeed = entity.config.maxSpeed or 50
    
    local vx, vy = entity.collider:getLinearVelocity()
    vx = vx + dir.x * accel * dt
    
    -- Clamp horizontal speed
    if math.abs(vx) > maxSpeed then
        vx = (vx > 0 and 1 or -1) * maxSpeed
    end
    entity.collider:setLinearVelocity(vx, vy)
end

function WanderState:exit(prevState)
    local entity = self.entity
    entity.wanderTarget = nil
    entity.wanderTimer = 0
end

return WanderState