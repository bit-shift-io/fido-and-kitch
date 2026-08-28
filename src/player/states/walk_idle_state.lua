local PlayerMovement = require('src.player.player_movement')

local WalkIdleState = Class{}

local STEP_INTERVAL = 0.3

function WalkIdleState:enter(prevState)
    local player = self.entity
    player:setAnimation('idle')
    player.stepTimer = 0

    if prevState ~= nil and prevState.name == 'FallState' then
        player.sound:play('land')
    end
end

function WalkIdleState:exit(name)
end

function WalkIdleState:update(dt)
    local player = self.entity

    if player.fsm:tryTransition('FallState') then
        return
    end

    if player.fsm:tryTransition('LadderState') then return end

    local v_x, v_y = player.collider:getLinearVelocity()

    local useDownLast = player.useDown
    player.useDown = player:isDown('use')
    if player.useDown == true and useDownLast == false then
        player:checkForUsables()
        if player.fsm.currentState ~= self then return end
    end

    local input = {
        right = player:isDown("right"),
        left = player:isDown("left")
    }
    local decision = PlayerMovement.decideHorizontalMovement(input, player.speed, v_y)

    player.collider:setLinearVelocity(decision.velocityX, decision.velocityY)
    if decision.facing then
        player:setFacing(decision.facing)
    end
    player:setAnimation(decision.animation)

    if decision.animation == 'walk' then
        player.stepTimer = player.stepTimer + dt
        if player.stepTimer >= STEP_INTERVAL then
            player.stepTimer = player.stepTimer - STEP_INTERVAL
            player.sound:play('step')
        end
    else
        player.stepTimer = 0
    end
end

return WalkIdleState