-- src/npc/states/flee_state.lua
local Class = require('lib.hump.class')
local Vector = require('lib.hump.vector')
local NpcLocomotion = require('src.npc.npc_locomotion')

local FleeState = Class{}

function FleeState:enter(prevState)
    local entity = self.entity
    entity.fleeTimer = 0
end

function FleeState:update(dt)
    dt = NpcLocomotion.sanitizeDt(dt, "FleeState")
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
    NpcLocomotion.stepHorizontal(entity, dir.x, dt, 400, 100)
end

function FleeState:exit(prevState)
    local entity = self.entity
    entity.fleeTimer = 0
end

return FleeState