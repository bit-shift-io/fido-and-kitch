-- src/entities/npc_robot.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCConfig = require('src.npc.npc_config')
local NPCRegistry = require('src.npc.npc_registry')

local Robot = Class{__includes = NPCBase}

-- Hostile (behavior='patrol', damage=2) -- a laser beam passes through it
-- and kills it, same as a player. See NPCBase.isEnemy's comment for why
-- this is set per-species rather than as NPCBase's own default.
Robot.isEnemy = true

-- Register type at module load time
NPCRegistry.registerType('npc_robot', Robot)

function Robot:init(props)
    props = props or {}
    local merged = NPCConfig.getDefaults()

    -- genuinely per-NPC overrides on top of the shared defaults
    merged.idleImage = 'res/img/npc_blob.png'
    merged.maxSpeed = 60
    merged.acceleration = 250
    merged.detectionRadius = 250
    merged.attackRange = 120
    merged.damage = 2
    merged.health = 4
    merged.behavior = 'patrol'
    merged.fleeThreshold = 0.2
    merged.invulnerableTime = 0.3

    -- Tiled object props win over every default
    for k, v in pairs(props) do merged[k] = v end

    NPCBase.init(self, merged)
end

return Robot