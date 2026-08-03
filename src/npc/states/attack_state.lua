-- src/npc/states/attack_state.lua
local Class = require('lib.hump.class')

local AttackState = Class{}

function AttackState:enter(prevState)
    local entity = self.entity
    entity.attackTimer = entity.attackTimer or 0
end

function AttackState:update(dt)
    local entity = self.entity
    if not entity.target then return end
    
    local cooldown = entity.config.attackCooldown or 1.0
    entity.attackTimer = entity.attackTimer + dt
    
    if entity.attackTimer >= cooldown then
        entity.attackTimer = 0
        local dmg = entity.config.damage or 1
        if entity.target.takeDamage then
            entity.target:takeDamage(dmg, entity)
        end
    end
end

function AttackState:exit(prevState)
    local entity = self.entity
    entity.attackTimer = 0
end

return AttackState