local GroundSupport = require('src.player.ground_support')

local PlayerSensors = {}

function PlayerSensors.queryKillZone(world, collider)
    local bounds = collider:getBounds()
    bounds.left = bounds.left + 4
    bounds.right = bounds.right - 4

    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isKillZone then
            return entity
        end
    end
    return nil
end

function PlayerSensors.queryLadder(world, collider, offset)
    local bounds = collider:getBounds()
    bounds.left = bounds.left + 4
    bounds.right = bounds.right - 4
    bounds.bottom = bounds.bottom - (offset or 4)

    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isLadder then
            return entity
        end
    end
    return nil
end

function PlayerSensors.queryLadderBelow(world, collider, topOffset, bottomOffset)
    local bounds = collider:getBounds()
    bounds.left = bounds.left + 4
    bounds.right = bounds.right - 4
    bounds.top = bounds.bottom + (topOffset or 4)
    bounds.bottom = bounds.bottom + (bottomOffset or 5)

    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isLadder then
            return entity
        end
    end
    return nil
end

function PlayerSensors.queryOnGround(world, collider)
    local bounds = collider:getBounds()
    bounds.top = bounds.bottom + 4
    bounds.bottom = bounds.bottom + 5

    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        -- `walkable` is a capability flag ("this collider counts as ground
        -- when solid"), not a standing guarantee -- an entity-owned collider
        -- like a drawbridge deck can currently be a sensor (e.g. closed), in
        -- which case it must not count as ground
        local other = c.other
        if entity == nil or (c.walkable and other and not other.sensor) then
            return true
        end
    end
    return false
end

function PlayerSensors.queryFullySupported(world, bounds)
    return GroundSupport.isFullySupported(world, bounds)
end

return PlayerSensors