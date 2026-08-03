-- src/entities/npc_spider.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCConfig = require('src.npc.npc_config')
local NPCRegistry = require('src.npc.npc_registry')

local Spider = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_spider', Spider)

function Spider:init(props)
    props = props or {}
    -- Spider-specific defaults
    local spiderDefaults = {
        idleImage = 'res/img/npc_spider.png',
        maxSpeed = 90,
        acceleration = 350,
        deceleration = 500,
        detectionRadius = 200,
        attackRange = 24,
        damage = 1,
        health = 2,
        behavior = 'chase',
        fleeThreshold = 0.25,
        canPush = false,
        canBePushed = true,
        pushForce = 100,
        ridePlatforms = false,
        triggerSwitches = false,
        invulnerableTime = 0.5,
    }
    
    -- Merge spider defaults with provided props, then with NPCConfig defaults
    local merged = {}
    for k, v in pairs(spiderDefaults) do merged[k] = v end
    for k, v in pairs(props) do merged[k] = v end
    
    NPCBase.init(self, merged)
end

-- Override onDeath to release any wrapped target immediately
function Spider:onDeath()
    if self.wrappedTarget and self.wrappedTarget.wrapped then
        self.wrappedTarget:releaseWrap()
    end
    self.wrappedTarget = nil
end

return Spider