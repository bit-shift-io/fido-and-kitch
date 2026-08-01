local PlayerMovement = {}

function PlayerMovement.decideHorizontalMovement(input, speed, velocityY)
    local velocityX = 0
    local facing = nil
    local animation = 'idle'

    if input.right then
        velocityX = speed
        facing = 'right'
        animation = 'walk'
    end

    if input.left then
        velocityX = -speed
        facing = 'left'
        animation = 'walk'
    end

    return {
        velocityX = velocityX,
        velocityY = velocityY,
        facing = facing,
        animation = animation,
    }
end

function PlayerMovement.decideLadderMovement(input, climbSpeed, ladder, ladderBelow)
    local velocityX = 0
    local velocityY = 0
    local animation = 'climb'
    local movingOnLadder = false

    if input.up then
        if ladder then
            velocityY = -climbSpeed
            movingOnLadder = true
        else
            return nil -- transition to fall
        end
    end

    if input.down then
        if ladderBelow then
            velocityY = climbSpeed
            movingOnLadder = true
        else
            return nil -- transition to fall
        end
    end

    return {
        velocityX = velocityX,
        velocityY = velocityY,
        animation = animation,
        movingOnLadder = movingOnLadder,
    }
end

function PlayerMovement.nearestLadderCentre(playerCentreX, ladderCentres)
    if #ladderCentres == 0 then
        return nil
    end

    local nearest = ladderCentres[1]
    local minDist = math.abs(playerCentreX - nearest)

    for i = 2, #ladderCentres do
        local centre = ladderCentres[i]
        local dist = math.abs(playerCentreX - centre)
        if dist < minDist then
            minDist = dist
            nearest = centre
        end
    end

    return nearest
end

function PlayerMovement.isCentred(playerCentreX, targetCentreX, slideSpeed, dt)
    local slideStep = slideSpeed * dt
    return math.abs(playerCentreX - targetCentreX) <= slideStep
end

function PlayerMovement.resolveActiveAxis(input)
    local verticalHeld = input.verticalHeld
    local horizontalHeld = input.horizontalHeld
    local verticalNewlyPressed = input.verticalNewlyPressed
    local horizontalNewlyPressed = input.horizontalNewlyPressed
    local previousAxis = input.previousAxis

    -- If a new key was pressed on an axis, that axis wins
    if verticalNewlyPressed and not horizontalNewlyPressed then
        return 'vertical'
    end
    if horizontalNewlyPressed and not verticalNewlyPressed then
        return 'horizontal'
    end

    -- If both newly pressed, last-pressed wins (but we don't have timing info here,
    -- so default to vertical for simultaneous presses)
    if verticalNewlyPressed and horizontalNewlyPressed then
        return 'vertical'
    end

    -- No new presses - stay on current axis if it's still held
    if previousAxis == 'vertical' and verticalHeld then
        return 'vertical'
    end
    if previousAxis == 'horizontal' and horizontalHeld then
        return 'horizontal'
    end

    -- Fall back to whatever axis is still held
    if verticalHeld then
        return 'vertical'
    end
    if horizontalHeld then
        return 'horizontal'
    end

    return nil
end

function PlayerMovement.shouldFallOffLadder(overlapsAnyLadder)
    return not overlapsAnyLadder
end

local DEFAULT_BOUNCE_FORCE = 220

function PlayerMovement.applyBounce(collider, force)
    local v_x, v_y = collider:getLinearVelocity()
    collider:setLinearVelocity(v_x, -(force or DEFAULT_BOUNCE_FORCE))
end

function PlayerMovement.applyGravity(collider)
    local v_x, v_y = collider:getLinearVelocity()
    collider:setLinearVelocity(0, v_y)
end

return PlayerMovement