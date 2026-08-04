-- src/npc/npc_config.lua
local NPCConfig = {}

NPCConfig.BehaviorTypes = {
    follow = { description = 'Follow a target entity (player or NPC)' },
    wander = { description = 'Random movement within bounds' },
    patrol = { description = 'Move between defined patrol points' },
    chase = { description = 'Pursue a detected target aggressively' },
    attack = { description = 'Engage target in combat' },
    flee = { description = 'Run away from threat' },
}

NPCConfig.Defaults = {
    maxSpeed = 80,
    acceleration = 400,
    deceleration = 600,
    detectionRadius = 160,
    attackRange = 32,
    fleeThreshold = 0.3,
    behavior = 'wander',
    patrolPoints = {},
    followTarget = nil,
    canPush = true,
    canBePushed = true,
    pushForce = 200,
    ridePlatforms = false,
    triggerSwitches = false,
    health = 1,
    damage = 1,
    invulnerableTime = 0.5,
    hopHeight = 120,
    hopCooldown = 0.5,
    despawnDistance = 0,
}

function NPCConfig.getDefaults()
    local copy = {}
    for k, v in pairs(NPCConfig.Defaults) do
        copy[k] = v
    end
    return copy
end

function NPCConfig.getBehaviorTypes()
    local types = {}
    for k, v in pairs(NPCConfig.BehaviorTypes) do
        types[k] = v
    end
    return types
end

function NPCConfig.validate(props)
    if props.behavior and not NPCConfig.BehaviorTypes[props.behavior] then
        return false, 'Invalid behavior type: ' .. tostring(props.behavior)
    end
    if props.maxSpeed and props.maxSpeed < 0 then
        return false, 'maxSpeed must be non-negative'
    end
    if props.detectionRadius and props.detectionRadius < 0 then
        return false, 'detectionRadius must be non-negative'
    end
    if props.health and props.health < 0 then
        return false, 'health must be non-negative'
    end
    if props.patrolPoints and type(props.patrolPoints) ~= 'table' then
        return false, 'patrolPoints must be a table'
    end
    return true, nil
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