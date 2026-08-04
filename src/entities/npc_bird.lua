-- src/entities/npc_bird.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCRegistry = require('src.npc.npc_registry')

local BirdNPC = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_bird', BirdNPC)

function BirdNPC:init(props)
    props = props or {}
    local birdDefaults = {
        idleImage = 'res/img/npc_bird_idle.png',
        maxSpeed = 100,
        acceleration = 300,
        deceleration = 400,
        detectionRadius = 300,
        attackRange = 0,  -- Bird doesn't attack
        damage = 0,
        health = 1,
        behavior = 'follow',
        fleeThreshold = 0.5,
        canPush = false,
        canBePushed = false,
        pushForce = 0,
        ridePlatforms = false,
        triggerSwitches = false,
        invulnerableTime = 0.5,
        followDistance = 60,
        canFly = true,
        despawnDistance = 400,
    }
    
    local merged = {}
    for k, v in pairs(birdDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
    
    -- Override collider for flying (non-solid)
    self.collider.solid = false
end

return BirdNPC