local PlayerMovement = require('src.player.player_movement')
local PlayerSensors = require('src.player.player_sensors')
local Log = require('src.utils.log')

local FallState = Class{}

function FallState:canTransition()
    local player = self.entity
    local onGround = PlayerSensors.queryOnGround(world, player.collider)
    if onGround then
        return false
    else
        return true
    end
end

function FallState:enter()
    Log.debug('fall enter')
    local player = self.entity
    player:setAnimation('fall')
    local _, v_y = player.collider:getLinearVelocity()
    player.collider:setLinearVelocity(0, v_y)
    if player.speedStreak then
        player.speedStreak:enable()
    end
end

function FallState:update(dt)
    local player = self.entity

    PlayerMovement.applyGravity(player.collider)

    local onGround = PlayerSensors.queryOnGround(world, player.collider)
    if onGround then
        if player.speedStreak then
            player.speedStreak:disable()
        end
        player.fsm:setState('WalkIdleState')
        return
    end

    if player.ladderCatchGrace then
        player.ladderCatchGrace = player.ladderCatchGrace - dt
        if player.ladderCatchGrace <= 0 then
            player.ladderCatchGrace = nil
        else
            return
        end
    end

    local ladders = PlayerSensors.queryAllLadders(world, player.collider)
    if PlayerMovement.shouldCatchFall(onGround, ladders) then
        if player.speedStreak then
            player.speedStreak:disable()
        end
        player.fsm:setState('LadderState')
    end
end

return FallState