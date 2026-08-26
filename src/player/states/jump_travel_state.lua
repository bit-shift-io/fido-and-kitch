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
    
    if self.elapsed >= self.duration then
        player.fsm:setState('FallState')
    end
end

function JumpTravelState:exit()
    local player = self.entity
    
    if self.camera then
        self.camera:removeExtraTarget('jump_travel')
    end
    
    if player.speedStreak then
        player.speedStreak:disable()
    end
    
    local vx, vy = 0, 0
    if self._lastVelocity and (self._lastVelocity.x ~= 0 or self._lastVelocity.y ~= 0) then
        vx, vy = self._lastVelocity.x, self._lastVelocity.y
    end
    local TERMINAL_VELOCITY = 500
    if vy < TERMINAL_VELOCITY then
        vy = TERMINAL_VELOCITY
    end
    
    player.collider:setType('dynamic')
    player.collider:setGravityScale(1)
    player.collider:setLinearVelocity(vx, vy)
end

return JumpTravelState