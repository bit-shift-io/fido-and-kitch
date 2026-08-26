local DeadState = Class{}

function DeadState:enter()
    local player = self.entity

    player.sound:play('death')
    player.collider:setLinearVelocity(0, 0)
    player.collider:setType('kinematic')
    player.collider:setGravityScale(0)
    player:setAnimation('idle')

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

return DeadState