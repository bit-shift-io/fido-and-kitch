local PlayerMovement = require('src.player.player_movement')
local PlayerSensors = require('src.player.player_sensors')
local Log = require('src.utils.log')

local LadderState = Class{}

function LadderState:enter()
    Log.debug('ladder enter')
    local player = self.entity
    player:setAnimation('climb')
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.sound:play('mount')

    -- Initialize ladder mode state
    self.mode = 'aligning' -- 'aligning', 'climbing', 'sliding'
    self.targetCentreX = nil
    self.isInitialMount = true -- true for first mount from ground, false for re-aligns
end

function LadderState:exit()
    local player = self.entity
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)

    -- LadderState drives movement by setting velocity directly on a
    -- kinematic body; without clearing it here, whatever velocity was set
    -- on the last ladder frame (e.g. still climbing upward) carries into
    -- the now gravity-affected dynamic body, so dismounting at the top of
    -- a ladder would coast upward past the platform before gravity caught
    -- up with it.
    player.collider:setLinearVelocity(0, 0)
end

function LadderState:canTransition()
    local player = self.entity
    local ladders = PlayerSensors.queryAllLadders(world, player.collider)

    if player:isDown("up") then
        if #ladders > 0 then
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

    local downPressed = player:isDown("down")

    -- Get all overlapping ladders. When mounting/descending onto a ladder
    -- flush against the underside of a platform, the collider can still be
    -- touching (not yet overlapping) the ladder's top edge, so also count a
    -- ladder detected directly below while descending -- see
    -- PlayerMovement.resolveLadderOverlap.
    local directLadders = PlayerSensors.queryAllLadders(world, player.collider)
    local ladderBelowForOverlap = nil
    if #directLadders == 0 and downPressed then
        ladderBelowForOverlap = PlayerSensors.queryLadderBelow(world, player.collider)
    end
    local ladders = PlayerMovement.resolveLadderOverlap(directLadders, downPressed, ladderBelowForOverlap)

    -- Check if we should fall off (no ladder overlap at all)
    if PlayerMovement.shouldFallOffLadder(#ladders > 0) then
        player.fsm:setState('FallState')
        return
    end

    -- Update per-axis edge tracking for last-pressed arbitration
    local upPressed = player:isDown("up")
    local leftPressed = player:isDown("left")
    local rightPressed = player:isDown("right")

    local verticalHeld = upPressed or downPressed
    local horizontalHeld = leftPressed or rightPressed

    local verticalNewlyPressed = verticalHeld and not player.verticalHeld
    local horizontalNewlyPressed = horizontalHeld and not player.horizontalHeld

    player.verticalHeld = verticalHeld
    player.horizontalHeld = horizontalHeld
    player.verticalNewlyPressed = verticalNewlyPressed
    player.horizontalNewlyPressed = horizontalNewlyPressed

    -- Resolve active axis using last-pressed arbitration
    local activeAxis = PlayerMovement.resolveActiveAxis({
        verticalHeld = verticalHeld,
        horizontalHeld = horizontalHeld,
        verticalNewlyPressed = verticalNewlyPressed,
        horizontalNewlyPressed = horizontalNewlyPressed,
        previousAxis = player.previousLadderAxis
    })

    if activeAxis then
        player.previousLadderAxis = activeAxis
    end

    local playerCentreX = player.collider:getX()
    local ladderCentres = {}
    for _, ladder in ipairs(ladders) do
        table.insert(ladderCentres, ladder.rect:centre().x)
    end

    local velocityX = 0
    local velocityY = 0
    local movingOnLadder = false
    local exited = false

    if self.mode == 'aligning' then
        velocityX, velocityY, movingOnLadder, exited = self:updateAligning(player, playerCentreX, ladderCentres, dt)
    elseif self.mode == 'climbing' then
        velocityX, velocityY, movingOnLadder, exited = self:updateClimbing(player, upPressed, downPressed, activeAxis)
    elseif self.mode == 'sliding' then
        velocityX, velocityY, movingOnLadder, exited = self:updateSliding(player, activeAxis, leftPressed, rightPressed)
    end

    if exited then return end

    player.collider:setLinearVelocity(velocityX, velocityY)
    player.animations.currentState.playing = movingOnLadder
end

-- Per-mode ladder steps. Each returns (velocityX, velocityY, movingOnLadder,
-- exited); when `exited` is true the step already transitioned to another
-- state and update() must return without writing velocity.
function LadderState:updateAligning(player, playerCentreX, ladderCentres, dt)
    -- Find target centre (nearest ladder centre-x)
    if #ladderCentres > 0 then
        self.targetCentreX = PlayerMovement.nearestLadderCentre(playerCentreX, ladderCentres)
    end

    if not self.targetCentreX then
        -- No ladders overlapped - should have been caught by fall-off check
        player.fsm:setState('FallState')
        return 0, 0, false, true
    end

    local slideSpeed = self.isInitialMount and player.speed or player.slideSpeed
    local centred = PlayerMovement.isCentred(playerCentreX, self.targetCentreX, slideSpeed, dt)

    if centred then
        -- Snap exactly to centre and transition to climbing
        player.collider:setX(self.targetCentreX)
        self.mode = 'climbing'
        self.isInitialMount = false
        return 0, 0, false, false
    end

    -- Slide toward centre
    local direction = self.targetCentreX > playerCentreX and 1 or -1
    return direction * slideSpeed, 0, true, false
end

function LadderState:updateClimbing(player, upPressed, downPressed, activeAxis)
    if activeAxis ~= 'vertical' then
        -- Switch to sliding mode
        self.mode = 'sliding'
        return 0, 0, false, false
    end

    if upPressed then
        -- Check if still overlapping any ladder (use queryAllLadders for full overlap check)
        local ladders = PlayerSensors.queryAllLadders(world, player.collider)
        if #ladders > 0 then
            return 0, -player.climbSpeed, true, false
        end

        -- No ladder above - check if we can get off at the top (on ground ahead)
        local onGround = PlayerSensors.queryOnGround(world, player.collider)
        if onGround then
            player.fsm:setState('WalkIdleState')
        else
            player.fsm:setState('FallState')
        end
        return 0, 0, false, true
    elseif downPressed then
        local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)
        if ladderBelow then
            return 0, player.climbSpeed, true, false
        end
        player.fsm:setState('FallState')
        return 0, 0, false, true
    end

    return 0, 0, false, false
end

function LadderState:updateSliding(player, activeAxis, leftPressed, rightPressed)
    if activeAxis ~= 'horizontal' then
        -- Switch to aligning mode to re-centre (slow speed)
        self.mode = 'aligning'
        self.isInitialMount = false
        return 0, 0, false, false
    end

    if leftPressed then
        -- Check for horizontal block on left
        local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, 'left')
        if not blocked then
            return -player.slideSpeed, 0, true, false
        end
    elseif rightPressed then
        -- Check for horizontal block on right
        local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, 'right')
        if not blocked then
            return player.slideSpeed, 0, true, false
        end
    end

    return 0, 0, false, false
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
    Log.debug('fall enter')
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

function DeadState:enter()
    local player = self.entity

    player.sound:play('death')
    player.collider:setLinearVelocity(0, 0)
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player:setAnimation('idle')

    -- Use flash effect blink + fade-out
    player.flashEffect:blink(0.15, 8, function()
        player:resolveDeath()
    end)
    player.flashEffect:fadeOut(0.15 * 8)
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