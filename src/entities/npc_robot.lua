-- src/entities/npc_robot.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCRegistry = require('src.npc.npc_registry')

local Robot = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_robot', Robot)

function Robot:init(props)
    props = props or {}
    local robotDefaults = {
        maxSpeed = 60,
        acceleration = 250,
        deceleration = 400,
        detectionRadius = 250,
        attackRange = 120,
        damage = 2,
        health = 4,
        behavior = 'patrol',
        fleeThreshold = 0.2,
        canPush = true,
        canBePushed = true,
        pushForce = 300,
        ridePlatforms = false,
        triggerSwitches = true,
        invulnerableTime = 0.3,
        patrolPoints = {},
    }
    
    local merged = {}
    for k, v in pairs(robotDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
end

return Robot