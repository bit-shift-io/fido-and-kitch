-- src/npc/states/dead_state.lua
local Class = require('lib.hump.class')

local DeadState = Class{}

function DeadState:enter()
    local npc = self.entity
    
    -- Set collider to kinematic (non-solid) when dead
    if npc.collider then
        npc.collider:setType('kinematic')
    end
    
    -- homeX/homeY are set once in NPCBase:init() to the original spawn
    -- position. Do NOT overwrite them here — if the NPC falls through a
    -- kill zone before detection, the current position could be far below
    -- the map, causing an infinite die-respawn loop at the bad position.
    
    -- Death timer: -1 means flash in progress, >= 0 means counting respawn delay
    npc.deathTimer = -1
    npc.deathType = npc.deathType or 'unknown'
    
    -- Use sprite blink + fade-out; deathTimer will start after blink completes
    if npc.flashEffect then
        npc.flashEffect:blink(0.15, 8, function()
            npc.deathTimer = 0
        end)
        npc.flashEffect:fadeOut(0.15 * 8)
    else
        npc.deathTimer = 0
    end
    
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