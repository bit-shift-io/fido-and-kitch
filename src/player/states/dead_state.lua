local SpawnFlash = require("src.utils.spawn_flash")

local DeadState = Class({})

function DeadState:enter()
	local player = self.entity

	player.sound:play("death")
	player.collider:setLinearVelocity(0, 0)
	player.collider:setType("kinematic")
	player.collider:setGravityScale(0)
	player:setAnimation("idle")

	player.flashEffect:blink(SpawnFlash.FADE, SpawnFlash.BLINKS, function()
		player:resolveDeath()
	end)
	player.flashEffect:fadeOut(SpawnFlash.FADE * SpawnFlash.BLINKS)
end

function DeadState:exit()
	local player = self.entity
	player.collider:setType("dynamic")
	player.collider:setGravityScale(1)
end

function DeadState:update(dt) end

return DeadState
