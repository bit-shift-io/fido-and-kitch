local PlayerMovement = require('src.player.player_movement')
local PlayerSensors = require('src.player.player_sensors')
local Flash = require('src.components.flash')

local LadderState = Class{}

function LadderState:enter()
    print('ladder enter')
    local player = self.entity
    player:setAnimation('climb')
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.sound:play('mount')
end

function LadderState:exit()
    local player = self.entity
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
end

function LadderState:canTransition()
    local player = self.entity
    local ladder = PlayerSensors.queryLadder(world, player.collider)

    if player:isDown("up") then
        if ladder then
            return true
        end
    end

    if player:isDown("down") then
        local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)
        if ladderBelow then
            return true
        end
    end

    return false
end

function LadderState:update(dt)
    local player = self.entity

    local ladder = PlayerSensors.queryLadder(world, player.collider)
    local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)

    local decision = PlayerMovement.decideLadderMovement({
        up = player:isDown("up"),
        down = player:isDown("down"),
    }, player.climbSpeed, ladder, ladderBelow)

    if decision == nil then
        player.fsm:setState('FallState')
        return
    end

    player.collider:setLinearVelocity(decision.velocityX, decision.velocityY)
    player.animations.currentState.playing = decision.movingOnLadder
end


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
    print('fall enter')
    local player = self.entity
    player:setAnimation('fall')
    local v_x, v_y = player.collider:getLinearVelocity()
    player.collider:setLinearVelocity(0, v_y)
    player.sound:play('jump')
end

function FallState:update(dt)
    local player = self.entity

    PlayerMovement.applyGravity(player.collider)

    local onGround = PlayerSensors.queryOnGround(world, player.collider)
    if onGround then
        player.fsm:setState('WalkIdleState')
    end
end


local DeadState = Class{}

local DEATH_FLASH_INTERVAL = 0.15
local DEATH_FLASH_BLINKS = 8
local DEATH_FADE_DURATION = DEATH_FLASH_INTERVAL * DEATH_FLASH_BLINKS

function DeadState:enter()
    local player = self.entity

    player.sound:play('death')
    player.collider:setLinearVelocity(0, 0)
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player:setAnimation('idle')

    player.alpha = 1
    player.fadeTween = Tween.new(DEATH_FADE_DURATION, player, {alpha = 0})

    player.flash = player:addComponent(Flash{
        target = player,
        property = 'visible',
        interval = DEATH_FLASH_INTERVAL,
        blinks = DEATH_FLASH_BLINKS,
        onComplete = utils.forwardFunc(player.resolveDeath, player)
    })
end

function DeadState:exit()
    local player = self.entity
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
end

function DeadState:update(dt)
end


local WrappedState = Class{}

function WrappedState:enter()
    local player = self.entity
    player.wrapped = true
    player:setAnimation('idle')
end

function WrappedState:exit()
    local player = self.entity
    player.wrapped = false
    player.web = nil
end

function WrappedState:update(dt)
    local player = self.entity

    local v_x, v_y = player.collider:getLinearVelocity()
    player.collider:setLinearVelocity(0, v_y)

    player.web:update(dt)
    if player.web:isExpired() then
        player.fsm:setState('WalkIdleState')
    end
end

return {
    LadderState = LadderState,
    WalkIdleState = WalkIdleState,
    FallState = FallState,
    DeadState = DeadState,
    WrappedState = WrappedState,
}