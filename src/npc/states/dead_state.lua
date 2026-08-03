-- src/npc/states/dead_state.lua
local Class = require('lib.hump.class')
local DeathFlash = require('src.components.death_flash')

local DeadState = Class{}

function DeadState:enter()
    local npc = self.entity
    
    -- Set collider to kinematic (non-solid) when dead
    if npc.collider then
        npc.collider:setType('kinematic')
    end
    
    -- Store original position for respawn
    npc.homeX = npc.x
    npc.homeY = npc.y
    
    -- Death timer: -1 means flash in progress, >= 0 means counting respawn delay
    npc.deathTimer = -1
    npc.deathType = npc.deathType or 'unknown'
    
    -- Start death flash; deathTimer will start after flash completes
    DeathFlash.startDeath(npc, function()
        -- Flash complete, start respawn timer
        npc.deathTimer = 0
    end)
    
    -- Emit death event for registry/cleanup
    local EventBus = require('src.utils.event_bus')
    EventBus.emit('npc_death', {npc = npc, source = npc.deathType})
end

function DeadState:update(dt)
    local npc = self.entity
    
    -- If flash is still in progress, wait
    if npc.deathTimer == -1 then
        return
    end
    
    -- Count respawn delay
    npc.deathTimer = npc.deathTimer + dt
    
    -- Check if respawn delay has elapsed
    if npc.deathTimer >= npc.RESPAWN_DELAY then
        npc:respawn()
    end
end

return DeadState