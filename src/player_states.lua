local LadderState = Class{}

function LadderState:init(props)
    print('ladder state init')
end

function LadderState:enter()
    print('enter')
end

function LadderState:exit(name)
end

function LadderState:update(dt)
    local player = self.entity

	local isUsingLadder = false

	-- in the ladder state, reset vertical velocity
	if (player.fsm.current == 'ladder' and player.ladder == nil) then
		player.collider:setLinearVelocity(0, 0)
	end

	-- TODO: when the player is using the ladder, we somehow need to disable
	-- collisions with tiles, we did this in the dart version by putting the player into 
	-- 'kinematic' mode. OR we can disable the collision that a ladder tile
	-- might be on, so player can move through it.... this second method won't work
	-- if there are other physics objects on top of the ladder!
	if (love.keyboard.isDown("up") and player.ladder ~= nil) then
		player.collider:setLinearVelocity(0, -100)
		isUsingLadder = true
	end

	if (love.keyboard.isDown("down")) then
		local ladderBelow = player:ladderBelow()
		if player.ladder ~= nil or ladderBelow ~= nil then
			player.collider:setLinearVelocity(0, 100)
			isUsingLadder = true
		end
	end

    if isUsingLadder == false and player.ladder == nil then
        player.fsm.setState('FallState')
    end
end


local WalkIdleState = Class{}

function WalkIdleState:init(props)
end

function WalkIdleState:enter()
end

function WalkIdleState:exit(name)
end

function WalkIdleState:update(dt)
    local player = self.entity

	-- is user falling?
    if player.fsm:tryTransition('FallState') then return end

	local x = player.collider:getX()
	local y = player.collider:getY()
	local delta = player.speed * dt

	local eDownLast = player.eDown
	player.eDown = love.keyboard.isDown("e")
	if player.eDown == true and eDownLast == false then
		player:checkForUsables()
	end

	-- reset horizontal velocity
    local v_x, v_y = player.collider:getLinearVelocity()
	player.collider:setLinearVelocity(0, v_y)


	-- movement
	-- https://github.com/jlett/Platformer-Tutorial
	-- https://github.com/ohookins/mole/blob/master/mole.lua <-- climbing code

	local isWalking = false
	
	if love.keyboard.isDown("right") then
		player.collider:setLinearVelocity(100, v_y)
		isWalking = true
	end

	if love.keyboard.isDown("left") then
		player.collider:setLinearVelocity(-100, v_y)
		isWalking = true
	end
end


local FallState = Class{}

function FallState:init(props)
end

function FallState:canTransition()
    local player = self.entity
    local v_x, v_y = player.collider:getLinearVelocity()
	if (v_y > 2) then
        return true
    end
    return false
end

function FallState:enter()
    print('fall enter')
    local player = self.entity
    local v_x, v_y = player.collider:getLinearVelocity()
    player.collider:setLinearVelocity(0, v_y)
end

function FallState:update(dt)
    local player = self.entity
    local v_x, v_y = player.collider:getLinearVelocity()
    if (v_y <= 2) then
		player.fsm:setState('WalkIdleState')
    end
end


return {LadderState = LadderState, WalkIdleState = WalkIdleState, FallState = FallState}