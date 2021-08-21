local LadderState = Class{}

function LadderState:enter()
    print('ladder enter')
	local player = self.entity
	player:setAnimation('climb')
	player.collider:setType('kinematic')
	player.collider:setGravityScale(0)
end

function LadderState:exit()
	local player = self.entity
	player.collider:setType('dynamic')
	player.collider:setGravityScale(1)
end

function LadderState:canTransition()
	local player = self.entity
	local ladder = player:queryLadder()

	if (player:isDown("up")) then
		if (ladder) then
			return true
		end
	end

	if (player:isDown("down")) then
		local ladderBelow = player:queryLadderBelow()
		if (ladderBelow) then
			return true
		end
	end

	return false
end

function LadderState:update(dt)
    local player = self.entity

	local ladder = player:queryLadder()
	local ladderBelow = player:queryLadderBelow()

	local movingOnLadder = false

	-- in the ladder state, reset vertical velocity
	player.collider:setLinearVelocity(0, 0)

	if (player:isDown("up")) then
		if (ladder) then
			player.collider:setLinearVelocity(0, -100)
			movingOnLadder = true
		else
			player.fsm:setState('FallState')
		end
	end

	if (player:isDown("down")) then
		if (ladderBelow) then
			player.collider:setLinearVelocity(0, 100)
			movingOnLadder = true
		else
			player.fsm:setState('FallState')
		end
	end

	-- only play animation while moving up or down
	player.animations.currentState.playing = movingOnLadder
end


local WalkIdleState = Class{}

function WalkIdleState:init(props)
end

function WalkIdleState:enter()
	local player = self.entity
	player:setAnimation('idle')
end

function WalkIdleState:exit(name)
end

function WalkIdleState:update(dt)
    local player = self.entity

	-- is user falling?
    if player.fsm:tryTransition('FallState') then 
		return 
	end

	if player.fsm:tryTransition('LadderState') then return end

	local x = player.collider:getX()
	local y = player.collider:getY()
	local delta = player.speed * dt

	local useDownLast = player.useDown
	player.useDown = player:isDown('use')
	if player.useDown == true and useDownLast == false then
		player:checkForUsables()
	end

	-- reset horizontal velocity
    local v_x, v_y = player.collider:getLinearVelocity()
	player.collider:setLinearVelocity(0, v_y)


	-- movement
	-- https://github.com/jlett/Platformer-Tutorial
	-- https://github.com/ohookins/mole/blob/master/mole.lua <-- climbing code

	local isWalking = false
	
	if player:isDown("right") then
		player.collider:setLinearVelocity(100, v_y)
		isWalking = true
	end

	if player:isDown("left") then
		player.collider:setLinearVelocity(-100, v_y)
		isWalking = true
	end

	if (isWalking) then
		player:setAnimation('walk')
	else
		player:setAnimation('idle')
	end
end


local FallState = Class{}

function FallState:canTransition()
    local player = self.entity
	local onGround = player:queryOnGround()
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
end

function FallState:update(dt)
    local player = self.entity

	local v_x, v_y = player.collider:getLinearVelocity()
    player.collider:setLinearVelocity(0, v_y)
	
	local onGround = player:queryOnGround()
	if (onGround) then
		player.fsm:setState('WalkIdleState')
	end
end


return {LadderState = LadderState, WalkIdleState = WalkIdleState, FallState = FallState}