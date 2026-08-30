-- src/entities/npc_bird.lua
local Class = require('lib.hump.class')
local NPCBase = require('src.npc.npc_base')
local NPCConfig = require('src.npc.npc_config')
local NPCRegistry = require('src.npc.npc_registry')

local BirdNPC = Class{__includes = NPCBase}

-- Register type at module load time
NPCRegistry.registerType('npc_bird', BirdNPC)

function BirdNPC:init(props)
    props = props or {}
    local merged = NPCConfig.getDefaults()

    -- genuinely per-NPC overrides on top of the shared defaults
    merged.idleImage = 'res/img/npc_bird_idle.png'
    merged.width = 32
    merged.height = 32
    merged.colliderWidth = 16
    merged.colliderHeight = 16
    merged.canFly = true
    merged.despawnDistance = 200
    merged.maxSpeed = 100
    merged.acceleration = 300
    merged.detectionRadius = 500
    merged.attackRange = 0
    merged.damage = 0
    merged.behavior = 'follow'
    merged.fleeThreshold = 0.5
    merged.followDistance = 60

    -- Tiled object props win over every default
    for k, v in pairs(props) do merged[k] = v end

    NPCBase.init(self, merged)

    -- Start as sensor (flying NPC), gravity handled manually
    self.collider:setSensor(true)
    self.collider:setGravityScale(0)
end

function BirdNPC:update(dt)
    -- Toggle sensor based on ladder overlap: pass through terrain only
    -- where a ladder exists, collide normally everywhere else.
    -- Probe ahead in the direction of flight so the ladder is detected
    -- before the bird reaches the exact edge (touching = zero-area overlap).
    local bounds = self.collider:getBounds()
    local vx, vy = self.collider:getLinearVelocity()
    local probe = {
        left = bounds.left,
        right = bounds.right,
        top = bounds.top,
        bottom = bounds.bottom,
    }
    local PROBE_MARGIN = 4
    if vx < 0 then probe.left = probe.left - PROBE_MARGIN end
    if vx > 0 then probe.right = probe.right + PROBE_MARGIN end
    if vy < 0 then probe.top = probe.top - PROBE_MARGIN end
    if vy > 0 then probe.bottom = probe.bottom + PROBE_MARGIN end

    local items = world:queryOverlap(probe)
    local onLadder = false
    for _, item in ipairs(items) do
        if item.entity and item.entity.isLadder then
            onLadder = true
            break
        end
    end
    self.collider:setSensor(onLadder)

    NPCBase.update(self, dt)
end

return BirdNPC