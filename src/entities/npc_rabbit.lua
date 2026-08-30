-- src/entities/npc_rabbit.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCConfig = require('src.npc.npc_config')
local NPCRegistry = require('src.npc.npc_registry')

local RabbitNPC = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_rabbit', RabbitNPC)

function RabbitNPC:init(props)
    props = props or {}
    local merged = NPCConfig.getDefaults()

    -- genuinely per-NPC overrides on top of the shared defaults
    merged.idleImage = 'res/img/npc_rabbit_idle.png'
    merged.width = 32
    merged.height = 32
    merged.colliderWidth = 32
    merged.colliderHeight = 32
    merged.ridePlatforms = true
    merged.followDistance = 40
    merged.hopHeight = 60
    merged.hopCooldown = 0.5
    merged.despawnDistance = 200
    merged.acceleration = 350
    merged.detectionRadius = 120
    merged.attackRange = 0
    merged.damage = 0
    merged.behavior = 'follow'
    merged.fleeThreshold = 0.4

    -- Tiled object props win over every default
    for k, v in pairs(props) do merged[k] = v end

    NPCBase.init(self, merged)
    
    -- Ensure collider is walkable for platform riding
    self.collider.walkable = true
    -- Make rabbit pass through players and cages (non-solid vs those entity types)
    self.collider.nonSolidEntityTypes = { player = true, cage = true }
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