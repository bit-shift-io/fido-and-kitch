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