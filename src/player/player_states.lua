local PlayerMovement = require('src.player.player_movement')
local PlayerSensors = require('src.player.player_sensors')
local Log = require('src.utils.log')
local TeleportTrail = require('src.fx.teleport_trail')

local LadderState = Class{}

-- A side press within the last half-tile below the ladder top finishes the
-- climb to the top hover (a platform is likely adjacent there); deeper side
-- presses slide off the side as a normal dismount.
local HALF_TILE = 16

function LadderState:enter()
    Log.debug('ladder enter')
    local player = self.entity
    player:setAnimation('climb')
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.sound:play('mount')

    -- Initialize ladder mode state. A mount entered via up/down begins
    -- aligning to the ladder centre as before; a fall catch (no vertical key
    -- held) enters straight into climbing so an unattended player hangs in
    -- place instead of being auto-aligned -- auto-align is reserved for
   -- actually using the vertical keys (see NOTES.md 2026-08-24).
    local verticalHeld = player:isDown("up") or player:isDown("down")
    self.mode = PlayerMovement.resolveEntryMode(verticalHeld) -- 'aligning', 'climbing', 'sliding'
    self.targetCentreX = nil
    self.isInitialMount = verticalHeld -- walk-speed slide only for genuine mounts, not catches

    -- A downward mount carries intent: target the below-detected ladder's
    -- centre rather than whatever else the body grazes (e.g. the up-leading
    -- column at a seam).
    if player:isDown("down") then
        local below = PlayerSensors.queryLadderBelow(world, player.collider)
        if below then
            self.targetCentreX = below.rect:centre().x
        end
    end

    -- Re-baseline the per-axis held trackers: they are edge-detection state
    -- maintained by LadderState:update, so keys that were already held before
    -- this entry (e.g. a direction held throughout the fall that led here)
    -- would otherwise register as phantom fresh presses on the first update.
    player.verticalHeld = verticalHeld
    player.horizontalHeld = player:isDown("left") or player:isDown("right")
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

    -- Leaving via a sideways slide is a deliberate dismount: open a short
    -- catch-grace window so the fall out of the column can't re-mount the
    -- same ladder on the next frame.
    if self.mode == 'sliding' then
        player.ladderCatchGrace = 0.2
    end
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

-- Place the player's feet exactly on a ground collider's top face so an
-- eject-to-walk lands without any residual drop. `ground` is the raw bump
-- record returned by queryOnNonLadderGround (its Collider component is
-- `other`, not the record itself).
local function snapOntoGround(player, ground)
    local b = player.collider:getBounds()
    local other = ground.other
    local top = other and other:getBounds().top
    if not top then return end
    player.collider:setPosition(player.collider:getX(), top - b.height / 2)
end

function LadderState:update(dt)
    local player = self.entity

    local downPressed = player:isDown("down")
    local upPressed = player:isDown("up")
    local leftPressed = player:isDown("left")
    local rightPressed = player:isDown("right")

    -- Get all overlapping ladders. While descending, also count a ladder
    -- detected directly below -- even when other ladders ARE overlapped:
    -- at a seam the body can graze the up-leading column while the intended
    -- down route is the neighbouring one, and flush-under-platform mounts
    -- start with only the below-probe hitting. See
    -- PlayerMovement.resolveLadderOverlap.
    local directLadders = PlayerSensors.queryAllLadders(world, player.collider)
    local ladderBelowForOverlap = nil
    if downPressed then
        ladderBelowForOverlap = PlayerSensors.queryLadderBelow(world, player.collider)
    end
    local ladders = PlayerMovement.resolveLadderOverlap(directLadders, downPressed, ladderBelowForOverlap)

    -- Arriving at the base dismounts: touching down on real ground while
    -- DESCENDING ends the mount. Guards: the down-press is the descent
    -- intent (a hanging climber passes THROUGH solids -- a platform
    -- crossing the column below their feet is not an arrival); a
    -- below-hit means the descent is still in progress (down-mounts from
    -- an upper platform start grounded with ladder below).
    if downPressed and ladderBelowForOverlap == nil then
        local ground = PlayerSensors.queryOnNonLadderGround(world, player.collider)
        if ground then
            -- Snap exactly onto the surface before converting: the eject
            -- fires while the feet probe first sees ground (1-5px above it),
            -- and a dynamic body dropped from there lands with a visible
            -- hop + landing thud.
            snapOntoGround(player, ground)
            player.fsm:setState('WalkIdleState')
            return
        end
    end

    -- Check if we should fall off (no ladder overlap at all). Vertical edge
    -- keys are exempt: pressing up at the top or down at the bottom of a
    -- column is a no-op (stay mounted). A held horizontal key is NOT --
    -- sliding clear of the column is the deliberate dismount.
    if PlayerMovement.shouldFallOffLadder(#ladders > 0)
        and not upPressed and not downPressed then
        -- Ground right below means this dismount is a step-off, not a fall:
        -- land directly so there is no one-frame FallState stutter (velocity
        -- zeroed) and no landing thud. The slab is excluded by the probe, so
        -- sliding off a bare top still falls naturally.
        local ground = PlayerSensors.queryOnNonLadderGround(world, player.collider)
        if ground then
            snapOntoGround(player, ground)
            player.fsm:setState('WalkIdleState')
        else
            player.fsm:setState('FallState')
        end
        return
    end

    -- Update per-axis edge tracking for last-pressed arbitration
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
        velocityX, velocityY, movingOnLadder, exited = self:updateClimbing(player, upPressed, downPressed, activeAxis, ladderCentres, dt)
    elseif self.mode == 'sliding' then
        velocityX, velocityY, movingOnLadder, exited = self:updateSliding(player, activeAxis, leftPressed, rightPressed, ladders, dt)
    end

    if exited then return end

    player.collider:setLinearVelocity(velocityX, velocityY)
    local anim = player.animations.currentState
    anim.playing = movingOnLadder
    if not movingOnLadder then
        -- Freeze on the climb sheet's first frame while hanging: there is
        -- no dedicated climb art ('climb' aliases the Jump sheet), and
        -- pausing mid-cycle leaves an airborne-looking pose.
        anim:setFrameNum(1)
    end
end

-- Per-mode ladder steps. Each returns (velocityX, velocityY, movingOnLadder,
-- exited); when `exited` is true the step already transitioned to another
-- state and update() must return without writing velocity.
function LadderState:updateAligning(player, playerCentreX, ladderCentres, dt)
    -- Find target centre (nearest ladder centre-x), but never override an
    -- intent-carried sticky target set at mount time (down-mounts aim at
    -- the below-detected ladder even when another is nearer).
    if not self.targetCentreX and #ladderCentres > 0 then
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

function LadderState:updateClimbing(player, upPressed, downPressed, activeAxis, ladderCentres, dt)
    if activeAxis ~= 'vertical' then
        -- Switch to sliding mode -- but only on a fresh directional press.
        -- A horizontal key already held when the fall-catch happened (e.g.
        -- walking off a platform into the ladder column) must not slide the
        -- player straight back out of the volume; it stays ignored until
        -- re-pressed or released.
        if activeAxis == 'horizontal' and not player.horizontalNewlyPressed then
            return 0, 0, false, false
        end
        self.mode = 'sliding'
        return 0, 0, false, false
    end

    if (upPressed or downPressed) then
        -- Vertical movement happens from the ladder centre-x: an off-centre
        -- hang (e.g. after a slide) realigns first, then climbs. Auto-align
        -- while up/down is held is the spec'd behavior (NOTES.md 2026-08-24).
        -- A sticky mount target wins over plain proximity.
        local centreX = self.targetCentreX
        if not centreX and #ladderCentres > 0 then
            centreX = PlayerMovement.nearestLadderCentre(player.collider:getX(), ladderCentres)
        end
        if centreX and math.abs(player.collider:getX() - centreX) > 1 then
            self.targetCentreX = centreX
            self.mode = 'aligning'
            self.isInitialMount = false
            return 0, 0, false, false
        end
    end

    if upPressed then
        -- Check if still overlapping any ladder (use queryAllLadders for full overlap check)
        local ladders = PlayerSensors.queryAllLadders(world, player.collider)
        if #ladders > 0 then
            -- Clamp the upward step at the highest overlapped ladder's top
            -- edge: with variable frame timing a plain climbSpeed step can
            -- overshoot the top and leave the player floating above the
            -- column. A zero step means hover at the top edge.
            local feetY = player.collider:getBounds().bottom
            local topY
            for _, ladder in ipairs(ladders) do
                local rect = ladder.rect -- bottom-anchored
                local ladderTop = rect.y - rect.height
                if not topY or ladderTop < topY then
                    topY = ladderTop
                end
            end
            local step = PlayerMovement.climbUpStep(feetY, topY, player.climbSpeed, dt)
            if step <= 0 then
                return 0, 0, false, false
            end
            return 0, -step / dt, true, false
        end

        -- Top of the ladder: up is a no-op -- stay mounted hovering at the
        -- top rung. Sliding off the side is the way down (user directive).
        return 0, 0, false, false
    elseif downPressed then
        local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)
        if ladderBelow then
            return 0, player.climbSpeed, true, false
        end
        -- Bottom of the ladder: down is a no-op -- stay mounted.
        return 0, 0, false, false
    end

    return 0, 0, false, false
end

function LadderState:updateSliding(player, activeAxis, leftPressed, rightPressed, ladders, dt)
    if activeAxis == 'vertical' then
        -- Back to realigning on an up/down press: vertical movement happens
        -- from the ladder centre, so recentre first, then climb.
        self.mode = 'aligning'
        self.isInitialMount = false
        return 0, 0, false, false
    end


    -- Within the last half-tile below the top a platform is likely adjacent:
    -- finish the climb to the top hover and let the held key carry the
    -- climber across from there. Deeper down, sliding off the side is just a
    -- normal dismount.
    local function finishClimbOrSlide(direction)
        if not atTop and topY and feet <= topY + HALF_TILE then
            local rise = PlayerMovement.climbUpStep(feet, topY, player.climbSpeed, dt)
            if rise > 0 then
                return 0, -rise / dt, true, false
            end
        end
        return direction * player.slideSpeed, 0, true, false
    end

    -- From the exact-top hover a side press IS the dismount: skip the
    -- hold-at-the-edge gate so the slide can carry the climber out of the
    -- column (the fall-off guard then ejects naturally).
    local atTop = false
    local topY
    local feet = player.collider:getBounds().bottom
    for _, ladder in ipairs(ladders) do
        local ladderTop = ladder.rect.y - ladder.rect.height
        if not topY or ladderTop < topY then
            topY = ladderTop
        end
        if feet <= topY + 3 then
            atTop = true
            break
        end
    end

    if leftPressed then
        -- Check for horizontal block on left
        local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, 'left')
        if not blocked then
            return finishClimbOrSlide(-1)
        end
    elseif rightPressed then
        -- Check for horizontal block on right
        local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, 'right')
        if not blocked then
            return finishClimbOrSlide(1)
        end
    end

    -- Released: hold position. Auto-align is reserved for vertical-key
    -- mounts (see NOTES.md 2026-08-24); an off-centre spot on the ladder
    -- is a valid resting place, so sliding must not bounce back to centre-x.
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

    -- No-gravity zone: a falling player overlapping the ladder volume is
    -- caught automatically, no mount key needed. A short grace window after
    -- deliberately sliding off a ladder suppresses the instant re-catch,
    -- which would otherwise drop the player straight back onto the same
    -- ladder (falls carry no horizontal momentum).
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

local TeleportTravelState = Class{}

function TeleportTravelState:enter(prevState, params)
    local player = self.entity
    self.curve = params.curve
    self.duration = params.duration
    self.destX = params.destX
    self.destY = params.destY
    self.camera = params.camera
    self.sourceTeleport = params.sourceTeleport
    self.targetTeleport = params.targetTeleport
    self.elapsed = 0
    
    -- Hide player
    player.visible = false
    
    -- Make collider kinematic with no gravity
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.collider:setLinearVelocity(0, 0)
    
    -- Stop any current animation
    player:setAnimation('idle')
    
    -- Disable speed streak during teleport
    if player.speedStreak then
        player.speedStreak:disable()
    end
    
    -- Add camera extra target to track the player during travel
    if self.camera then
        self.camera:addExtraTarget('teleport_travel', {
            x = self.curve.startX - 16,
            y = self.curve.startY - 16,
            w = 32,
            h = 32,
        })
    end
end

function TeleportTravelState:update(dt)
    local player = self.entity
    self.elapsed = self.elapsed + dt
    
    -- Update camera extra target position along the curve
    if self.camera then
        local t = math.min(self.elapsed / self.duration, 1)
        local pos = TeleportTrail.computeCurvePoint(self.curve, t)
        self.camera:addExtraTarget('teleport_travel', {
            x = pos.x - 16,
            y = pos.y - 16,
            w = 32,
            h = 32,
        })
    end
    
    if self.elapsed >= self.duration then
        -- Teleport complete - move player to destination
        player.collider:setPosition(self.destX, self.destY)
        -- Transition to WalkIdleState
        player.fsm:setState('WalkIdleState')
    end
end

function TeleportTravelState:exit()
    local player = self.entity
    
    -- Spawn EXIT burst at destination
    if self.targetTeleport and self.targetTeleport.map and self.targetTeleport.map.fx then
        local TeleportBurst = require('src.fx.teleport_burst')
        self.targetTeleport.map.fx:add(TeleportBurst{
            position = {x = self.destX, y = self.destY},
        })
    end
    
    -- Remove camera extra target
    if self.camera then
        self.camera:removeExtraTarget('teleport_travel')
    end
    
-- Show player
    player.visible = true
    
    -- Restore physics
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
    player.collider:setLinearVelocity(0, 0)
end


local JumpTravelState = Class{}

function JumpTravelState:enter(prevState, params)
    local player = self.entity
    self.pathFollow = params.pathFollow
    self.duration = params.duration
    self.camera = params.camera
    self.elapsed = 0
    
    -- Start the path follow timeline
    if self.pathFollow and self.pathFollow.timeline then
        self.pathFollow.timeline:play()
    end
    
    -- Make collider kinematic with no gravity
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.collider:setLinearVelocity(0, 0)
    
    -- Set launch animation
    player:setAnimation('fall')
    
    -- Add camera extra target to track the player during travel
    if self.camera then
        local pos = self.pathFollow:getPositionV()
        self.camera:addExtraTarget('jump_travel', {
            x = pos.x - 16,
            y = pos.y - 16,
            w = 32,
            h = 32,
        })
    end
    
    -- Enable speed streak
    if player.speedStreak then
        player.speedStreak:enable()
    end
end

function JumpTravelState:update(dt)
    local player = self.entity
    self.elapsed = self.elapsed + dt
    
    -- Update path follow to move player along spline
    if self.pathFollow then
        self.pathFollow:update(dt)
    end
    
    -- Update camera extra target position
    if self.camera and self.pathFollow then
        local pos = self.pathFollow:getPositionV()
        self.camera:addExtraTarget('jump_travel', {
            x = pos.x - 16,
            y = pos.y - 16,
            w = 32,
            h = 32,
        })
    end
    
    if self.elapsed >= self.duration then
        -- Travel complete
        player.fsm:setState('FallState')
    end
end

function JumpTravelState:exit()
    local player = self.entity
    
    -- Remove camera extra target
    if self.camera then
        self.camera:removeExtraTarget('jump_travel')
    end
    
    -- Disable speed streak (FallState will re-enable if still airborne)
    if player.speedStreak then
        player.speedStreak:disable()
    end
    
    -- Restore physics - preserve downward velocity from path for smooth transition
    local vx, vy = 0, 0
    if self.pathFollow then
        local vel = self.pathFollow:getVelocity()
        vx, vy = vel.x, vel.y
    end
    -- Ensure downward velocity is at least terminal velocity for seamless fall
    local TERMINAL_VELOCITY = 500
    if vy < TERMINAL_VELOCITY then
        vy = TERMINAL_VELOCITY
    end
    
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
    player.collider:setLinearVelocity(vx, vy)
end

return {
    LadderState = LadderState,
    WalkIdleState = WalkIdleState,
    FallState = FallState,
    DeadState = DeadState,
    WrappedState = WrappedState,
    TeleportTravelState = TeleportTravelState,
    JumpTravelState = JumpTravelState,
}