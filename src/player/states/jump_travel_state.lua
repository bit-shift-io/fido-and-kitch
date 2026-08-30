local JumpTravelState = Class{}

function JumpTravelState:enter(prevState, params)
    local player = self.entity
    self.pathFollow = params.pathFollow
    self.duration = params.duration
    self.camera = params.camera
    self.elapsed = 0
    self._lastVelocity = Vector(0, 0)
    
    if self.pathFollow and self.pathFollow.timeline then
        self.pathFollow.timeline:play()
    end
    
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player.collider:setLinearVelocity(0, 0)
    
    player:setAnimation('fall')
    
    if self.camera then
        local pos = self.pathFollow:getPositionV()
        self.camera:addExtraTarget('jump_travel', {
            x = pos.x - 16,
            y = pos.y - 16,
            w = 32,
            h = 32,
        })
    end
    
    if player.speedStreak then
        player.speedStreak:enable()
    end
end

function JumpTravelState:update(dt)
    local player = self.entity
    self.elapsed = self.elapsed + dt
    
    if self.pathFollow then
        self.pathFollow:update(dt)
        local vel = self.pathFollow:getVelocity()
        if vel and (vel.x ~= 0 or vel.y ~= 0) then
            self._lastVelocity = vel:clone()
        end
    end
    
    if self.camera and self.pathFollow then
        local pos = self.pathFollow:getPositionV()
        self.camera:addExtraTarget('jump_travel', {
            x = pos.x - 16,
            y = pos.y - 16,
            w = 32,
            h = 32,
        })
    end
    
    if self.pathFollow and self.pathFollow:wasBlocked() then
        self._groundedExit = false
        player.fsm:setState('FallState')
        return
    end

    local PlayerSensors = require('src.player.player_sensors')
    local onGround = PlayerSensors.queryOnGround(world, player.collider)

    -- End travel as soon as the player reaches the ground, even if the
    -- scripted path hasn't fully elapsed yet. Guarded by a minimum elapsed
    -- fraction so the initial moment at the launch pad (still grounded before
    -- the path lifts the player off) doesn't cancel the jump instantly.
    if onGround and self.elapsed >= self.duration * 0.5 then
        self._groundedExit = true
        player.fsm:setState('WalkIdleState')
    elseif self.elapsed >= self.duration then
        self._groundedExit = false
        player.fsm:setState('FallState')
    end
end

function JumpTravelState:exit()
    local player = self.entity
    
    if self.camera then
        self.camera:removeExtraTarget('jump_travel')
    end
    
    if self.pathFollow then
        self.pathFollow:finish()
        player:removeComponent(self.pathFollow)
    end
    
    if player.speedStreak then
        player.speedStreak:disable()
    end
    
    local vy = 0
    if self._groundedExit == nil then
        if self._lastVelocity and self._lastVelocity.y ~= 0 then
            vy = self._lastVelocity.y
        end
    end
    
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
    player.collider:setLinearVelocity(0, vy)
end

return JumpTravelState
