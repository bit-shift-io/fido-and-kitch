-- src/entities/npc_rabbit.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCRegistry = require('src.npc.npc_registry')
local Vector = require('lib.hump.vector')

local RabbitNPC = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_rabbit', RabbitNPC)

function RabbitNPC:init(props)
    props = props or {}
    local rabbitDefaults = {
        idleImage = 'res/img/npc_rabbit_idle.png',
        maxSpeed = 80,
        acceleration = 350,
        deceleration = 500,
        detectionRadius = 200,
        attackRange = 0,
        damage = 0,
        health = 1,
        behavior = 'follow',
        fleeThreshold = 0.4,
        canPush = false,
        canBePushed = true,
        pushForce = 150,
        ridePlatforms = true,
        triggerSwitches = false,
        invulnerableTime = 0.5,
        followDistance = 40,
        hopHeight = 120,
        hopCooldown = 0.5,
        despawnDistance = 400,
    }
    
    local merged = {}
    for k, v in pairs(rabbitDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    -- Ensure collider is walkable for platform riding
    self.collider.walkable = true
    self.hopTimer = 0
end

function RabbitNPC:update(dt)
    NPCBase.update(self, dt)
    
    -- Handle hopping when following
    if self.target and self.stateMachine.currentState.name == 'FollowState' then
        self.hopTimer = self.hopTimer - dt
        if self.hopTimer <= 0 and self:isOnGround() then
            local vx, vy = self.collider:getLinearVelocity()
            self.collider:setLinearVelocity(vx, -self.config.hopHeight)
            self.hopTimer = self.config.hopCooldown
        end
    end
end

return RabbitNPC