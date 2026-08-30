-- src/npc/npc_config.lua
local NPCConfig = {}

NPCConfig.Defaults = {
    maxSpeed = 80,
    acceleration = 400,
    detectionRadius = 160,
    attackRange = 32,
    fleeThreshold = 0.3,
    behavior = 'wander',
    ridePlatforms = false,
    health = 1,
    damage = 1,
    invulnerableTime = 0.5,
    hopHeight = 120,
    hopCooldown = 0.5,
    followDistance = 40,
    canFly = false,
    despawnDistance = 0,
}

function NPCConfig.getDefaults()
    local copy = {}
    for k, v in pairs(NPCConfig.Defaults) do
        copy[k] = v
    end
    return copy
end

function NPCConfig.mergeWithDefaults(props)
    local defaults = NPCConfig.getDefaults()
    local result = {}
    for k, v in pairs(defaults) do
        if props[k] ~= nil then
            result[k] = props[k]
        else
            result[k] = v
        end
    end
    return result
end

return NPCConfig
