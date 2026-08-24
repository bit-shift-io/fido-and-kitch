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
    local best = nil
    local bestDist = nil
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isLadder then
            -- Multi-hit tiebreak: the ladder whose centre is nearest the
            -- player's is the one they intend to descend.
            local dist = math.abs(entity.rect:centre().x - collider:getX())
            if not best or dist < bestDist then
                best = entity
                bestDist = dist
            end
        end
    end
    return best
end

function PlayerSensors.queryAllLadders(world, collider)
    local bounds = collider:getBounds()
    bounds.left = bounds.left + 4
    bounds.right = bounds.right - 4

    local colls = world:queryBounds(bounds)
    local ladders = {}
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isLadder then
            table.insert(ladders, entity)
        end
    end
    return ladders
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

-- Like queryOnGround but ignores ladder-owned colliders (the volume sensor
-- and the one-way top slab). Used by LadderState to detect ARRIVAL at a
-- ladder's base: standing on real terrain ends the mount, while grounding
-- against the ladder's own slab (top perch) must not.
function PlayerSensors.queryOnNonLadderGround(world, collider)
    local bounds = collider:getBounds()
    bounds.top = bounds.bottom + 4
    bounds.bottom = bounds.bottom + 5

    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity and entity.isLadder then
            -- The ladder itself is never "arriving somewhere"
        else
            local other = c.other
            if entity == nil or (c.walkable and other and not other.sensor) then
                return c
            end
        end
    end
    return nil
end

function PlayerSensors.queryFullySupported(world, bounds)
    return GroundSupport.isFullySupported(world, bounds)
end

-- Check for solid collision in horizontal direction (for ladder sliding)
-- Returns true if there's a solid (non-sensor) collider blocking movement
function PlayerSensors.queryHorizontalBlock(world, collider, direction)
    local bounds = collider:getBounds()
    local checkDist = 8 -- small distance ahead to check
    
    if direction == 'left' then
        bounds.right = bounds.left
        bounds.left = bounds.left - checkDist
    elseif direction == 'right' then
        bounds.left = bounds.right
        bounds.right = bounds.right + checkDist
    else
        return false
    end
    
    -- Also check vertical overlap slightly to catch platforms at same level
    bounds.top = bounds.top + 2
    bounds.bottom = bounds.bottom - 2
    
    local colls = world:queryBounds(bounds)
    for _, c in ipairs(colls) do
        local entity = c.entity
        local other = c.other
        -- Parts of the ladder itself (the volume sensor, the one-way top
        -- slab) never block sliding: the climber is inside/behind them by
        -- design. The slab spans the whole column width, so counting it as a
        -- wall would lock out sideways movement whenever the hang position
        -- straddles the slab band (e.g. entering from a flush platform).
        if entity and entity.isLadder then
            -- skip ladder-owned colliders
        elseif (entity == nil and not c.sensor) or (c.walkable and other and not other.sensor) then
            return true
        end
    end
    return false
end

return PlayerSensors